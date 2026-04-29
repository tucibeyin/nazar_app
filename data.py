"""Nazar API — Kuran verisi yükleme ve terapi paket tanımları."""

import json
from pathlib import Path

import structlog

log = structlog.get_logger()

# ─── Kuran Verisi ─────────────────────────────────────────────────────────────

_data_path = Path(__file__).parent / "quran_data.json"
if not _data_path.exists():
    raise RuntimeError("quran_data.json bulunamadı. Önce build_db.py çalıştırın.")

# open() (builtin) kullanılır — test mockability için Path.open() tercih edilmez.
with open(_data_path, encoding="utf-8") as f:
    AYETLER: list[dict] = json.load(f)

log.info("quran_data_loaded", count=len(AYETLER))

# (sure_no, ayet_no) → ayet dict — O(1) lookup; sure_no/ayet_no yoksa atla.
ayet_lookup: dict[tuple[int, int], dict] = {
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

# Paket listesi startup'ta hesaplanır — her istekte yeniden hesaplamak yerine.
PACKAGES_RESPONSE: list[dict] = [
    {
        "id": p["id"],
        "isim": p["isim"],
        "aciklama": p["aciklama"],
        "icon": p["icon"],
        "ayet_sayisi": sum(1 for ref in p["ayet_refs"] if ref in ayet_lookup),
    }
    for p in TERAPI_PAKETLERI
]

log.info("terapi_paketleri_loaded", count=len(TERAPI_PAKETLERI))
