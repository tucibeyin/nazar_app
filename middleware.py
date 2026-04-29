"""Nazar API — Pure ASGI middleware sınıfları."""

import time
import uuid

import structlog
from fastapi.responses import JSONResponse
from starlette.datastructures import Headers, MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

log = structlog.get_logger()


class TimingMiddleware:
    """Her HTTP isteğine X-Response-Time ve X-Request-ID başlığı ekler."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start = time.perf_counter()
        status_code = 500
        request_id = uuid.uuid4().hex[:12]

        async def send_wrapper(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                duration_ms = round((time.perf_counter() - start) * 1000, 2)
                headers = MutableHeaders(scope=message)
                headers.append("X-Response-Time", f"{duration_ms}ms")
                headers.append("X-Request-ID", request_id)
            await send(message)

        await self.app(scope, receive, send_wrapper)

        log.info(
            "req",
            method=scope.get("method", ""),
            path=scope.get("path", ""),
            status=status_code,
            ms=round((time.perf_counter() - start) * 1000, 2),
            rid=request_id,
        )


class ApiKeyMiddleware:
    """X-API-Key header doğrulaması — public path'ler muaf tutulur."""

    _PUBLIC_PATHS: frozenset[str] = frozenset({"/health"})
    _PUBLIC_PREFIXES: tuple[str, ...] = ("/media/",)

    def __init__(self, app: ASGIApp, api_key: str) -> None:
        self.app = app
        self._api_key = api_key

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        path: str = scope.get("path", "")
        if (
            not self._api_key
            or path in self._PUBLIC_PATHS
            or any(path.startswith(p) for p in self._PUBLIC_PREFIXES)
        ):
            await self.app(scope, receive, send)
            return

        headers = Headers(scope=scope)
        if headers.get("x-api-key", "") != self._api_key:
            resp = JSONResponse(
                {"detail": "Yetkisiz erişim. Geçerli bir X-API-Key gerekli."},
                status_code=401,
            )
            await resp(scope, receive, send)
            return

        await self.app(scope, receive, send)
