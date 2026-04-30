"""Nazar API — FastAPI uygulama girişi ve endpoint tanımları."""

import os
import sys

import httpx
import structlog
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from starlette.middleware.gzip import GZipMiddleware

from data import AYETLER, ESMAUL_HUSNA, PACKAGES_RESPONSE, TERAPI_PAKETLERI, ayet_lookup
from middleware import ApiKeyMiddleware, TimingMiddleware
from schemas import (
    AyetResponse,
    EsmaResponse,
    HealthResponse,
    HatimAyetResponse,
    PackageDetailResponse,
    PackageResponse,
    PrayerTimesResponse,
)

load_dotenv()

# ─── Loglama — üretimde JSON, geliştirmede renkli konsol ─────────────────────
_is_dev = os.getenv("DEV_MODE", "").lower() in ("1", "true", "yes")
structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        structlog.dev.ConsoleRenderer() if _is_dev else structlog.processors.JSONRenderer(),
    ],
    logger_factory=structlog.PrintLoggerFactory(sys.stdout),
    cache_logger_on_first_use=True,
)

log = structlog.get_logger()

# ─── Rate Limiter ─────────────────────────────────────────────────────────────

_RATE_LIMIT = os.getenv("RATE_LIMIT", "30/minute")
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


@app.get("/api/v1/nazar/{hash_sayisi}", response_model=AyetResponse, tags=["nazar"])
@limiter.limit(_RATE_LIMIT)
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
    return AyetResponse.from_raw(raw)


@app.get("/api/v1/hatim/{index}", response_model=HatimAyetResponse, tags=["hatim"])
@limiter.limit(_RATE_LIMIT)
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
        **AyetResponse.from_raw(raw).model_dump(),
    )


@app.get("/api/v1/packages", response_model=list[PackageResponse], tags=["packages"])
@limiter.limit(_RATE_LIMIT)
async def get_packages(request: Request, response: Response) -> list[PackageResponse]:
    response.headers["Cache-Control"] = "public, max-age=3600"
    return PACKAGES_RESPONSE  # type: ignore[return-value]


@app.get(
    "/api/v1/packages/{package_id}", response_model=PackageDetailResponse, tags=["packages"]
)
@limiter.limit(_RATE_LIMIT)
async def get_package_detail(
    request: Request, response: Response, package_id: str
) -> PackageDetailResponse:
    paket = next((p for p in TERAPI_PAKETLERI if p["id"] == package_id), None)
    if paket is None:
        raise HTTPException(status_code=404, detail="Paket bulunamadı.")

    ayetler = [
        AyetResponse.from_raw(raw)
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


_ALADHAN_URL = "https://api.aladhan.com/v1/timings"
_PRAYER_RATE = os.getenv("PRAYER_RATE_LIMIT", "10/minute")


@app.get("/api/v1/prayer-times", response_model=PrayerTimesResponse, tags=["prayer-times"])
@limiter.limit(_PRAYER_RATE)
async def get_prayer_times(
    request: Request,
    response: Response,
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
) -> PrayerTimesResponse:
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            r = await client.get(
                _ALADHAN_URL,
                params={"latitude": lat, "longitude": lng, "method": 13},
            )
            r.raise_for_status()
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Namaz vakitleri servisi yanıt vermedi.")
    except httpx.HTTPStatusError as exc:
        raise HTTPException(status_code=502, detail=f"Namaz vakitleri alınamadı ({exc.response.status_code}).")
    except httpx.RequestError:
        raise HTTPException(status_code=502, detail="Namaz vakitleri servisine ulaşılamadı.")

    t = r.json()["data"]["timings"]
    response.headers["Cache-Control"] = "public, max-age=3600"
    log.info("prayer_times_served", lat=lat, lng=lng)
    return PrayerTimesResponse(
        imsak=t["Imsak"],
        gunes=t["Sunrise"],
        ogle=t["Dhuhr"],
        ikindi=t["Asr"],
        aksam=t["Maghrib"],
        yatsi=t["Isha"],
    )


@app.get("/api/v1/esmaul-husna", response_model=list[EsmaResponse], tags=["esmaul-husna"])
@limiter.limit(_RATE_LIMIT)
async def get_esmaul_husna(request: Request, response: Response) -> list[EsmaResponse]:
    response.headers["Cache-Control"] = "public, max-age=86400, immutable"
    return ESMAUL_HUSNA  # type: ignore[return-value]


# ── Statik Medya ──────────────────────────────────────────────────────────────
# Prodüksiyonda nginx bu rotayı doğrudan karşılar (infra/nginx.conf).
# Geliştirme ortamında FastAPI servis eder.
_media_path = Path(__file__).parent / "media"
if _media_path.exists():
    app.mount("/media", StaticFiles(directory=str(_media_path), check_dir=False), name="media")
