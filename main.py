"""Nazar API — FastAPI uygulama girişi ve endpoint tanımları."""

import os

import structlog
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from starlette.middleware.gzip import GZipMiddleware

from data import AYETLER, PACKAGES_RESPONSE, TERAPI_PAKETLERI, ayet_lookup
from middleware import ApiKeyMiddleware, TimingMiddleware
from schemas import (
    AyetResponse,
    HealthResponse,
    HatimAyetResponse,
    PackageDetailResponse,
    PackageResponse,
)

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

_allowed_origins = [
    o.strip()
    for o in os.getenv("ALLOWED_ORIGINS", "https://nazar.aracabak.com").split(",")
    if o.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_methods=["GET"],
    allow_headers=["Accept", "Content-Type", "X-API-Key"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(TimingMiddleware)
app.add_middleware(ApiKeyMiddleware, api_key=os.getenv("API_KEY", ""))

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
    return PACKAGES_RESPONSE  # type: ignore[return-value]


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

    ayetler = [
        AyetResponse(
            id=int(raw.get("id", 0) or 0),
            sure_isim=str(raw.get("sure_isim", "")),
            arapca=str(raw.get("arapca", "")),
            meal=str(raw.get("meal", "")),
            mp3_url=str(raw.get("mp3_url", "")),
        )
        for ref in paket["ayet_refs"]
        if (raw := ayet_lookup.get(ref))
    ]

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
