import json
import os
from pathlib import Path

import structlog
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

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
    allow_headers=["Accept", "Content-Type"],
)

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
