"""
Yerel namaz vakti hesaplayıcı — Diyanet yöntemi (method 13).

Fajr: 18°, İşa: 17°, Asr: Hanefi (gölge katsayısı = 2).
Tüm vakitler koordinatın yerel saatiyle döner (timezonefinder kullanır).
"""

import math
from datetime import date, datetime
from zoneinfo import ZoneInfo

from timezonefinder import TimezoneFinder

_tf = TimezoneFinder()

# ── Astronomik yardımcılar ─────────────────────────────────────────────────────

def _dtr(d: float) -> float: return math.radians(d)
def _rtd(r: float) -> float: return math.degrees(r)
def _fix(a: float, b: float) -> float: return a - b * math.floor(a / b)
def _fix_angle(a: float) -> float: return _fix(a, 360)
def _fix_hour(a: float) -> float: return _fix(a, 24)


def _julian_date(y: int, m: int, d: int) -> float:
    if m <= 2:
        y -= 1
        m += 12
    a = math.floor(y / 100)
    b = 2 - a + math.floor(a / 4)
    return math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1)) + d + b - 1524.5


def _sun_position(jd: float) -> tuple[float, float]:
    """(güneş sapması °, zaman denklemi saat) döner."""
    d = jd - 2451545.0
    g = _fix_angle(357.529 + 0.98560028 * d)
    q = _fix_angle(280.459 + 0.98564736 * d)
    ll = _fix_angle(q + 1.915 * math.sin(_dtr(g)) + 0.020 * math.sin(_dtr(2 * g)))
    e = 23.439 - 0.00000036 * d
    ra = _rtd(math.atan2(math.cos(_dtr(e)) * math.sin(_dtr(ll)), math.cos(_dtr(ll)))) / 15
    ra = _fix_hour(ra)
    dec = _rtd(math.asin(math.sin(_dtr(e)) * math.sin(_dtr(ll))))
    eqt = q / 15 - ra
    return dec, eqt


# ── Ana hesaplama ──────────────────────────────────────────────────────────────

def prayer_times_local(lat: float, lng: float, dt: date) -> dict[str, str]:
    """
    Verilen koordinat ve tarih için namaz vakitlerini koordinatın
    yerel saatiyle HH:MM formatında döner.

    Anahtarlar: Imsak, Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
    """
    jd = _julian_date(dt.year, dt.month, dt.day)
    dec, eqt = _sun_position(jd - lng / (15 * 24))

    # Yerel güneş saatiyle öğle vakti
    dhuhr = 12 - eqt

    def _hour_angle(angle: float, after: bool) -> float:
        try:
            cos_t = (
                math.sin(_dtr(angle))
                - math.sin(_dtr(lat)) * math.sin(_dtr(dec))
            ) / (math.cos(_dtr(lat)) * math.cos(_dtr(dec)))
        except ZeroDivisionError:
            return float("nan")
        if abs(cos_t) > 1:
            return float("nan")
        t = _rtd(math.acos(cos_t)) / 15
        return dhuhr + (t if after else -t)

    def _asr() -> float:
        # Hanefi: gölge katsayısı 2
        a = _rtd(math.atan(1.0 / (2 + math.tan(_dtr(abs(lat - dec))))))
        try:
            cos_t = (
                math.sin(_dtr(a))
                - math.sin(_dtr(lat)) * math.sin(_dtr(dec))
            ) / (math.cos(_dtr(lat)) * math.cos(_dtr(dec)))
        except ZeroDivisionError:
            return float("nan")
        if abs(cos_t) > 1:
            return float("nan")
        return dhuhr + _rtd(math.acos(cos_t)) / 15

    fajr    = _hour_angle(-18.0,  after=False)
    sunrise = _hour_angle(-0.833, after=False)
    asr     = _asr()
    maghrib = _hour_angle(-0.833, after=True)
    isha    = _hour_angle(-17.0,  after=True)
    imsak   = fajr - 10.0 / 60          # Fajr'dan 10 dk önce

    # UTC'ye çevir: yerel güneş saati - boylam/15
    lng_offset = lng / 15.0
    utc_times = {
        "Imsak":   _fix_hour(imsak   - lng_offset),
        "Fajr":    _fix_hour(fajr    - lng_offset),
        "Sunrise": _fix_hour(sunrise - lng_offset),
        "Dhuhr":   _fix_hour(dhuhr   - lng_offset),
        "Asr":     _fix_hour(asr     - lng_offset),
        "Maghrib": _fix_hour(maghrib - lng_offset),
        "Isha":    _fix_hour(isha    - lng_offset),
    }

    # Koordinatın yerel saatine çevir
    tz_name = _tf.timezone_at(lat=lat, lng=lng) or "UTC"
    tz = ZoneInfo(tz_name)

    result: dict[str, str] = {}
    for key, utc_h in utc_times.items():
        if math.isnan(utc_h):
            result[key] = "--:--"
            continue
        h = int(utc_h) % 24
        m = int(round((utc_h - int(utc_h)) * 60)) % 60
        utc_dt = datetime(dt.year, dt.month, dt.day, h, m, tzinfo=ZoneInfo("UTC"))
        local_dt = utc_dt.astimezone(tz)
        result[key] = local_dt.strftime("%H:%M")

    return result
