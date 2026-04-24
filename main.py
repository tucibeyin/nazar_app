import json
import os
import time
from pathlib import Path

import structlog
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, field_validator
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from starlette.middleware.base import BaseHTTPMiddleware

load_dotenv()

log = structlog.get_logger()

# ─── Rate Limiter ─────────────────────────────────────────────────────────────

limiter = Limiter(key_func=get_remote_address)

# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Nazar API",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

_raw_origins = os.getenv("ALLOWED_ORIGINS", "https://nazar.aracabak.com")
_allowed_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_methods=["GET"],
    allow_headers=["Accept", "Content-Type", "X-API-Key"],
)

# ─── Timing Middleware ────────────────────────────────────────────────────────


class TimingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start) * 1000, 2)
        response.headers["X-Response-Time"] = f"{duration_ms}ms"
        log.info(
            "request_completed",
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            duration_ms=duration_ms,
            client_ip=get_remote_address(request),
        )
        return response


# ─── API Key Middleware ────────────────────────────────────────────────────────

_API_KEY = os.getenv("API_KEY", "")

_PUBLIC_PATHS = {"/health"}


class ApiKeyMiddleware(BaseHTTPMiddleware):
    """X-API-Key header doğrulaması. API_KEY env boşsa devre dışı."""

    async def dispatch(self, request: Request, call_next):
        if not _API_KEY or request.url.path in _PUBLIC_PATHS:
            return await call_next(request)
        key = request.headers.get("X-API-Key", "")
        if key != _API_KEY:
            return JSONResponse(
                {"detail": "Yetkisiz erişim. Geçerli bir X-API-Key gerekli."},
                status_code=401,
            )
        return await call_next(request)


app.add_middleware(TimingMiddleware)
app.add_middleware(ApiKeyMiddleware)

# ─── Veri Yükle ───────────────────────────────────────────────────────────────

_data_path = Path(__file__).parent / "quran_data.json"
if not _data_path.exists():
    raise RuntimeError("quran_data.json bulunamadı. Önce build_db.py çalıştırın.")

with _data_path.open(encoding="utf-8") as f:
    AYETLER: list = json.load(f)

log.info("quran_data_loaded", count=len(AYETLER))

# ─── Modeller ─────────────────────────────────────────────────────────────────


class AyetResponse(BaseModel):
    id: int
    sure_isim: str
    arapca: str
    meal: str
    mp3_url: str

    @field_validator("mp3_url")
    @classmethod
    def mp3_url_not_empty(cls, v: str) -> str:
        if not v:
            raise ValueError("mp3_url boş olamaz")
        return v


class HealthResponse(BaseModel):
    status: str
    ayet_count: int
    version: str


# ─── Endpoint'ler ─────────────────────────────────────────────────────────────


@app.get("/health", response_model=HealthResponse, tags=["system"])
async def health_check() -> HealthResponse:
    return HealthResponse(
        status="ok",
        ayet_count=len(AYETLER),
        version=app.version,
    )


@app.get("/api/nazar/{hash_sayisi}", response_model=AyetResponse, tags=["nazar"])
@limiter.limit(os.getenv("RATE_LIMIT", "30/minute"))
async def get_ayet(request: Request, hash_sayisi: int) -> AyetResponse:
    if hash_sayisi < 0:
        raise HTTPException(status_code=422, detail="Hash negatif olamaz.")

    if not AYETLER:
        raise HTTPException(status_code=503, detail="Ayet veritabanı boş.")

    secilen_index = hash_sayisi % len(AYETLER)
    raw = AYETLER[secilen_index]

    log.info("ayet_served", index=secilen_index, remote=get_remote_address(request))

    return AyetResponse(
        id=int(raw.get("id", 0) or 0),
        sure_isim=str(raw.get("sure_isim", "")),
        arapca=str(raw.get("arapca", "")),
        meal=str(raw.get("meal", "")),
        mp3_url=str(raw.get("mp3_url", "")),
    )
