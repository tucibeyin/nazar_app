"""Nazar API — FastAPI uygulama girişi ve endpoint tanımları."""

import os
import sys
from contextlib import asynccontextmanager

import asyncio
from datetime import date as _date

import httpx
import structlog
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query, Request, Response, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from starlette.middleware.gzip import GZipMiddleware

from data import AYETLER, ESMAUL_HUSNA, PACKAGES_RESPONSE, TERAPI_PAKETLERI_MAP, ayet_lookup
from hatim_db import create_room, get_room, init_db, update_juz
from middleware import ApiKeyMiddleware, TimingMiddleware
from schemas import (
    AyetResponse,
    EsmaResponse,
    HealthResponse,
    HatimAyetResponse,
    JuzResponse,
    JuzUpdateRequest,
    PackageDetailResponse,
    PackageResponse,
    PrayerTimesResponse,
    RoomResponse,
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

# ─── Yapılandırma ─────────────────────────────────────────────────────────────

_RATE_LIMIT  = os.getenv("RATE_LIMIT", "30/minute")
_PRAYER_RATE = os.getenv("PRAYER_RATE_LIMIT", "10/minute")
_HALKA_RATE  = os.getenv("HALKA_RATE_LIMIT", "20/minute")
_ALADHAN_URL = "https://api.aladhan.com/v1/timings"

# ─── Rate Limiter ─────────────────────────────────────────────────────────────

limiter = Limiter(key_func=get_remote_address)

# ─── App ──────────────────────────────────────────────────────────────────────


@asynccontextmanager
async def _lifespan(_app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title="Nazar API",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    lifespan=_lifespan,
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
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["Accept", "Content-Type", "X-API-Key"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(TimingMiddleware)
app.add_middleware(ApiKeyMiddleware, api_key=os.getenv("API_KEY", ""))

# ─── WebSocket Bağlantı Yöneticisi ───────────────────────────────────────────


class _WsConnectionManager:
    """Oda koduna göre WebSocket bağlantılarını yönetir."""

    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}

    async def connect(self, room_code: str, ws: WebSocket) -> None:
        await ws.accept()
        self._rooms.setdefault(room_code, set()).add(ws)

    def disconnect(self, room_code: str, ws: WebSocket) -> None:
        room = self._rooms.get(room_code)
        if room:
            room.discard(ws)
            if not room:
                del self._rooms[room_code]

    async def broadcast(self, room_code: str, payload: dict) -> None:
        for ws in list(self._rooms.get(room_code, set())):
            try:
                await ws.send_json(payload)
            except Exception:
                self.disconnect(room_code, ws)


_ws_manager = _WsConnectionManager()

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
    return HatimAyetResponse.from_raw(raw, index=actual, total=len(AYETLER))


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
    paket = TERAPI_PAKETLERI_MAP.get(package_id)
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


async def _fetch_aladhan(lat: float, lng: float) -> dict | None:
    """aladhan.com'dan vakitleri çeker; ulaşamazsa None döner."""
    try:
        async with httpx.AsyncClient(timeout=6, follow_redirects=True) as client:
            r = await client.get(
                _ALADHAN_URL,
                params={"latitude": lat, "longitude": lng, "method": 13},
            )
            r.raise_for_status()
        return r.json()["data"]["timings"]
    except Exception as exc:
        log.warning("aladhan_fetch_failed", error=str(exc))
        return None


@app.get("/api/v1/prayer-times", response_model=PrayerTimesResponse, tags=["prayer-times"])
@limiter.limit(_PRAYER_RATE)
async def get_prayer_times(
    request: Request,
    response: Response,
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
) -> PrayerTimesResponse:
    # ── Birincil kaynak: aladhan.com (Diyanet method 13) ──────────────────────
    t = await _fetch_aladhan(lat, lng)

    if t is None:
        # ── Yedek: yerel astronomik hesaplama ─────────────────────────────────
        log.warning("aladhan_unreachable_fallback", lat=lat, lng=lng)
        try:
            from prayer_calc import prayer_times_local  # noqa: PLC0415
            t = await asyncio.get_running_loop().run_in_executor(
                None, prayer_times_local, lat, lng, _date.today()
            )
        except Exception as exc:
            log.error("prayer_times_local_error", error=str(exc))
            raise HTTPException(status_code=503, detail="Namaz vakitleri alınamadı.")

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


# ─── Hatim Halkaları ──────────────────────────────────────────────────────────


@app.post(
    "/api/v1/hatim-halkasi/create",
    response_model=RoomResponse,
    status_code=201,
    tags=["hatim-halkasi"],
)
@limiter.limit(_HALKA_RATE)
async def create_hatim_room(request: Request) -> RoomResponse:
    try:
        room = await create_room()
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc))
    log.info("hatim_room_created", code=room["code"])
    return RoomResponse(**room)


@app.get(
    "/api/v1/hatim-halkasi/{room_code}",
    response_model=RoomResponse,
    tags=["hatim-halkasi"],
)
@limiter.limit(_HALKA_RATE)
async def get_hatim_room(
    request: Request, response: Response, room_code: str
) -> RoomResponse:
    room = await get_room(room_code.upper())
    if room is None:
        raise HTTPException(status_code=404, detail="Oda bulunamadı.")
    response.headers["Cache-Control"] = "no-store"
    return RoomResponse(**room)


@app.patch(
    "/api/v1/hatim-halkasi/{room_code}/juz/{juz_num}",
    response_model=JuzResponse,
    tags=["hatim-halkasi"],
)
@limiter.limit(_HALKA_RATE)
async def update_hatim_juz(
    request: Request,
    room_code: str,
    juz_num: int,
    body: JuzUpdateRequest,
) -> JuzResponse:
    if not 1 <= juz_num <= 30:
        raise HTTPException(status_code=422, detail="Cüz numarası 1–30 arasında olmalı.")
    code = room_code.upper()
    updated = await update_juz(code, juz_num, body.durum)
    if not updated:
        raise HTTPException(status_code=404, detail="Cüz bulunamadı.")
    log.info("juz_updated", room=code, juz=juz_num, durum=body.durum)
    # Odadaki WebSocket istemcilerine güncel durumu yayınla
    if updated_room := await get_room(code):
        await _ws_manager.broadcast(code, updated_room)
    return JuzResponse(juz_num=juz_num, durum=body.durum)


# ─── Hatim Halkası — WebSocket ───────────────────────────────────────────────


@app.websocket("/ws/hatim-halkasi/{room_code}")
async def ws_hatim_room(ws: WebSocket, room_code: str, api_key: str = Query(default="")) -> None:
    expected = os.getenv("API_KEY", "")
    if expected and not secrets.compare_digest(api_key, expected):
        await ws.close(code=4001)
        return

    code = room_code.upper()
    room = await get_room(code)
    if room is None:
        await ws.close(code=4004)
        return

    await _ws_manager.connect(code, ws)
    try:
        await ws.send_json(room)
        while True:
            await ws.receive_text()
    except (WebSocketDisconnect, Exception):
        pass
    finally:
        _ws_manager.disconnect(code, ws)


# ── Statik Medya ──────────────────────────────────────────────────────────────
# Prodüksiyonda nginx bu rotayı doğrudan karşılar (infra/nginx.conf).
# Geliştirme ortamında FastAPI servis eder.
_media_path = Path(__file__).parent / "media"
if _media_path.exists():
    app.mount("/media", StaticFiles(directory=str(_media_path), check_dir=False), name="media")
