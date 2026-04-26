import json
import os
import time
from pathlib import Path

import structlog
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
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
_PUBLIC_PREFIXES = ("/media/",)


class ApiKeyMiddleware(BaseHTTPMiddleware):
    """X-API-Key header doğrulaması. API_KEY env boşsa devre dışı."""

    async def dispatch(self, request: Request, call_next):
        if not _API_KEY or request.url.path in _PUBLIC_PATHS or request.url.path.startswith(_PUBLIC_PREFIXES):
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

# (sure_no, ayet_no) → raw ayet dict — O(1) arama
_ayet_lookup: dict[tuple[int, int], dict] = {
    (int(a["sure_no"]), int(a["ayet_no"])): a for a in AYETLER
}

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
    index: int   # AYETLER içindeki gerçek 0-tabanlı konum
    total: int   # toplam ayet sayısı


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


@app.get("/api/hatim/{index}", response_model=HatimAyetResponse, tags=["hatim"])
@limiter.limit(os.getenv("RATE_LIMIT", "30/minute"))
async def get_hatim_ayet(request: Request, index: int) -> HatimAyetResponse:
    if index < 0:
        raise HTTPException(status_code=422, detail="Index negatif olamaz.")
    if not AYETLER:
        raise HTTPException(status_code=503, detail="Ayet veritabanı boş.")
    actual = index % len(AYETLER)
    raw = AYETLER[actual]
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
async def get_packages(request: Request) -> list[PackageResponse]:
    result = []
    for p in TERAPI_PAKETLERI:
        count = sum(1 for ref in p["ayet_refs"] if ref in _ayet_lookup)
        result.append(PackageResponse(
            id=p["id"],
            isim=p["isim"],
            aciklama=p["aciklama"],
            icon=p["icon"],
            ayet_sayisi=count,
        ))
    return result


@app.get("/api/packages/{package_id}", response_model=PackageDetailResponse, tags=["packages"])
@limiter.limit(os.getenv("RATE_LIMIT", "30/minute"))
async def get_package_detail(request: Request, package_id: str) -> PackageDetailResponse:
    paket = next((p for p in TERAPI_PAKETLERI if p["id"] == package_id), None)
    if paket is None:
        raise HTTPException(status_code=404, detail="Paket bulunamadı.")
    ayetler = []
    for ref in paket["ayet_refs"]:
        raw = _ayet_lookup.get(ref)
        if raw:
            ayetler.append(AyetResponse(
                id=int(raw.get("id", 0) or 0),
                sure_isim=str(raw.get("sure_isim", "")),
                arapca=str(raw.get("arapca", "")),
                meal=str(raw.get("meal", "")),
                mp3_url=str(raw.get("mp3_url", "")),
            ))
    return PackageDetailResponse(
        id=paket["id"],
        isim=paket["isim"],
        aciklama=paket["aciklama"],
        icon=paket["icon"],
        ayetler=ayetler,
    )


# ── Statik Medya ──────────────────────────────────────────────────────────────
# MP3 dosyaları /media/quran_audio/ altında, auth gerektirmez (_PUBLIC_PREFIXES).
_media_path = Path(__file__).parent / "media"
if _media_path.exists():
    app.mount("/media", StaticFiles(directory=str(_media_path)), name="media")
