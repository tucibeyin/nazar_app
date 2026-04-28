"""Nazar API — production-ready FastAPI backend."""

import json
import os
import time
import uuid
from pathlib import Path

import structlog
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, field_validator
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from starlette.datastructures import Headers, MutableHeaders
from starlette.middleware.gzip import GZipMiddleware
from starlette.types import ASGIApp, Message, Receive, Scope, Send

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

# ─── Middleware config ────────────────────────────────────────────────────────

_API_KEY = os.getenv("API_KEY", "")
_PUBLIC_PATHS = {"/health"}
_PUBLIC_PREFIXES = ("/media/",)

# ─── Pure ASGI: Timing + Request-ID ──────────────────────────────────────────
# BaseHTTPMiddleware buffers entire response bodies (bad for streaming).
# Pure ASGI middleware wraps send() directly — no buffering, no overhead.

class _TimingMiddleware:
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


# ─── Pure ASGI: API Key ────────────────────────────────────────────────────────

class _ApiKeyMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        path: str = scope.get("path", "")
        if (
            not _API_KEY
            or path in _PUBLIC_PATHS
            or any(path.startswith(p) for p in _PUBLIC_PREFIXES)
        ):
            await self.app(scope, receive, send)
            return

        headers = Headers(scope=scope)
        if headers.get("x-api-key", "") != _API_KEY:
            resp = JSONResponse(
                {"detail": "Yetkisiz erişim. Geçerli bir X-API-Key gerekli."},
                status_code=401,
            )
            await resp(scope, receive, send)
            return

        await self.app(scope, receive, send)


app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(_TimingMiddleware)
app.add_middleware(_ApiKeyMiddleware)

# ─── Veri Yükle ───────────────────────────────────────────────────────────────

_data_path = Path(__file__).parent / "quran_data.json"
if not _data_path.exists():
    raise RuntimeError("quran_data.json bulunamadı. Önce build_db.py çalıştırın.")

# open() (builtin) yerine Path.open() kullanılmıyor — test mockability için.
with open(_data_path, encoding="utf-8") as f:
    AYETLER: list = json.load(f)

log.info("quran_data_loaded", count=len(AYETLER))

# (sure_no, ayet_no) → ayet dict — O(1) lookup; sure_no/ayet_no yoksa atla (test mocks).
_ayet_lookup: dict[tuple[int, int], dict] = {
    (int(a["sure_no"]), int(a["ayet_no"])): a
    for a in AYETLER
    if "sure_no" in a and "ayet_no" in a
}

# ─── Terapi Paketleri ─────────────────────────────────────────────────────────

TERAPI_PAKETLERI: list[dict] = [
    {
        "id": "fatiha",
        "isim": "Fatiha Suresi",
        "aciklama": "Kur'an'ın açılış suresi — her hayırlı işin başında",
        "icon": "book",
        "ayet_refs": [(1, i) for i in range(1, 8)],
    },
    {
        "id": "ayetel-kursi",
        "isim": "Ayetel Kürsi",
        "aciklama": "Kur'an'ın en büyük ayeti — Bakara 255",
        "icon": "throne",
        "ayet_refs": [(2, 255)],
    },
    {
        "id": "amenerrasulu",
        "isim": "Âmenerrasülü",
        "aciklama": "Bakara suresinin son iki ayeti — namazın mührü",
        "icon": "pray",
        "ayet_refs": [(2, 285), (2, 286)],
    },
    {
        "id": "uc-kul",
        "isim": "Üç Kul Suresi",
        "aciklama": "İhlas, Felak ve Nas — her gece ve sabah okunur",
        "icon": "star",
        "ayet_refs": (
            [(112, i) for i in range(1, 5)]
            + [(113, i) for i in range(1, 6)]
            + [(114, i) for i in range(1, 7)]
        ),
    },
    {
        "id": "nazar-korumasi",
        "isim": "Nazar Koruması",
        "aciklama": "Göz değmesinden ve kötülükten korunma ayetleri",
        "icon": "shield",
        "ayet_refs": (
            [(2, 255)]
            + [(113, i) for i in range(1, 6)]
            + [(114, i) for i in range(1, 7)]
        ),
    },
    {
        "id": "sifa-ayetleri",
        "isim": "Şifa Ayetleri",
        "aciklama": "Kur'an'daki şifa ve iyileşme ayetleri",
        "icon": "healing",
        "ayet_refs": [(9, 14), (10, 57), (16, 69), (17, 82), (26, 80), (41, 44)],
    },
    {
        "id": "stres-karsi",
        "isim": "Sıkıntı ve Stres İçin",
        "aciklama": "Zorluk anlarında teselli veren ayetler",
        "icon": "peace",
        "ayet_refs": [(94, i) for i in range(1, 9)] + [(2, 286), (65, 3)],
    },
    {
        "id": "sabah-zikri",
        "isim": "Sabah Zikri",
        "aciklama": "Güne Bismillah ile başlamak için",
        "icon": "sun",
        "ayet_refs": (
            [(1, i) for i in range(1, 8)]
            + [(2, 255)]
            + [(112, i) for i in range(1, 5)]
            + [(113, i) for i in range(1, 6)]
            + [(114, i) for i in range(1, 7)]
        ),
    },
]

# Paket listesi statik — her istekte yeniden hesaplamak yerine startup'ta yap.
_PACKAGES_RESPONSE: list[dict] = [
    {
        "id": p["id"],
        "isim": p["isim"],
        "aciklama": p["aciklama"],
        "icon": p["icon"],
        "ayet_sayisi": sum(1 for ref in p["ayet_refs"] if ref in _ayet_lookup),
    }
    for p in TERAPI_PAKETLERI
]

log.info("terapi_paketleri_loaded", count=len(TERAPI_PAKETLERI))

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


class HatimAyetResponse(AyetResponse):
    index: int
    total: int


class PackageResponse(BaseModel):
    id: str
    isim: str
    aciklama: str
    icon: str
    ayet_sayisi: int


class PackageDetailResponse(BaseModel):
    id: str
    isim: str
    aciklama: str
    icon: str
    ayetler: list[AyetResponse]


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
async def get_ayet(
    request: Request, response: Response, hash_sayisi: int
) -> AyetResponse:
    if hash_sayisi < 0:
        raise HTTPException(status_code=422, detail="Hash negatif olamaz.")
    if not AYETLER:
        raise HTTPException(status_code=503, detail="Ayet veritabanı boş.")

    secilen_index = hash_sayisi % len(AYETLER)
    raw = AYETLER[secilen_index]

    # Sonuç deterministik — aynı hash her zaman aynı ayeti döndürür.
    response.headers["Cache-Control"] = "public, max-age=86400, immutable"

    log.info("ayet_served", index=secilen_index, remote=get_remote_address(request))
    return AyetResponse(
        id=int(raw.get("id", 0) or 0),
        sure_isim=str(raw.get("sure_isim", "")),
        arapca=str(raw.get("arapca", "")),
        meal=str(raw.get("meal", "")),
        mp3_url=str(raw.get("mp3_url", "")),
    )


@app.get("/api/hatim/{index}", response_model=HatimAyetResponse, tags=["hatim"])
@limiter.limit(os.getenv("RATE_LIMIT", "30/minute"))
async def get_hatim_ayet(
    request: Request, response: Response, index: int
) -> HatimAyetResponse:
    if index < 0:
        raise HTTPException(status_code=422, detail="Index negatif olamaz.")
    if not AYETLER:
        raise HTTPException(status_code=503, detail="Ayet veritabanı boş.")

    actual = index % len(AYETLER)
    raw = AYETLER[actual]

    response.headers["Cache-Control"] = "public, max-age=86400, immutable"

    log.info("hatim_ayet_served", index=actual, remote=get_remote_address(request))
    return HatimAyetResponse(
        index=actual,
        total=len(AYETLER),
        id=int(raw.get("id", 0) or 0),
        sure_isim=str(raw.get("sure_isim", "")),
        arapca=str(raw.get("arapca", "")),
        meal=str(raw.get("meal", "")),
        mp3_url=str(raw.get("mp3_url", "")),
    )


@app.get("/api/packages", response_model=list[PackageResponse], tags=["packages"])
@limiter.limit(os.getenv("RATE_LIMIT", "30/minute"))
async def get_packages(request: Request, response: Response) -> list[PackageResponse]:
    response.headers["Cache-Control"] = "public, max-age=3600"
    return _PACKAGES_RESPONSE  # type: ignore[return-value]


@app.get(
    "/api/packages/{package_id}", response_model=PackageDetailResponse, tags=["packages"]
)
@limiter.limit(os.getenv("RATE_LIMIT", "30/minute"))
async def get_package_detail(
    request: Request, response: Response, package_id: str
) -> PackageDetailResponse:
    paket = next((p for p in TERAPI_PAKETLERI if p["id"] == package_id), None)
    if paket is None:
        raise HTTPException(status_code=404, detail="Paket bulunamadı.")

    ayetler = []
    for ref in paket["ayet_refs"]:
        raw = _ayet_lookup.get(ref)
        if raw:
            ayetler.append(
                AyetResponse(
                    id=int(raw.get("id", 0) or 0),
                    sure_isim=str(raw.get("sure_isim", "")),
                    arapca=str(raw.get("arapca", "")),
                    meal=str(raw.get("meal", "")),
                    mp3_url=str(raw.get("mp3_url", "")),
                )
            )

    response.headers["Cache-Control"] = "public, max-age=3600"
    return PackageDetailResponse(
        id=paket["id"],
        isim=paket["isim"],
        aciklama=paket["aciklama"],
        icon=paket["icon"],
        ayetler=ayetler,
    )


# ── Statik Medya ──────────────────────────────────────────────────────────────
# Prodüksiyonda nginx bu rotayı doğrudan karşılar (infra/nginx.conf).
# Geliştirme ortamında FastAPI servis eder.
_media_path = Path(__file__).parent / "media"
if _media_path.exists():
    app.mount("/media", StaticFiles(directory=str(_media_path), check_dir=False), name="media")
