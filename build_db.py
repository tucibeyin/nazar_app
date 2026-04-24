import json
import time

import requests
from pydantic import BaseModel, ValidationError

AR_URL = "https://api.alquran.cloud/v1/quran/ar.alafasy"
TR_URL = "https://api.alquran.cloud/v1/quran/tr.diyanet"
OUTPUT = "quran_data.json"


class AyetSchema(BaseModel):
    id: int
    sure_isim: str
    sure_no: int
    ayet_no: int
    arapca: str
    meal: str
    mp3_url: str


def fetch(url: str) -> list:
    for attempt in range(1, 4):
        try:
            print(f"  GET {url}  (deneme {attempt}/3)")
            r = requests.get(url, timeout=60)
            r.raise_for_status()
            data = r.json()
            if "data" not in data or "surahs" not in data["data"]:
                raise ValueError(f"Beklenmeyen API yanıt yapısı: {list(data.keys())}")
            return data["data"]["surahs"]
        except (requests.HTTPError, requests.Timeout, requests.ConnectionError) as exc:
            print(f"  Ağ hatası: {exc}")
        except ValueError as exc:
            print(f"  Veri hatası: {exc}")
            raise
        if attempt < 3:
            time.sleep(10)
    raise RuntimeError(f"API'den veri alınamadı: {url}")


def build() -> None:
    print("Arapça metin indiriliyor...")
    ar_surahs = fetch(AR_URL)

    print("Türkçe meal indiriliyor...")
    tr_surahs = fetch(TR_URL)

    ayetler: list[dict] = []
    skipped = 0
    idx = 0

    for ar_sure, tr_sure in zip(ar_surahs, tr_surahs):
        sure_no = ar_sure["number"]
        sure_isim = ar_sure["englishName"]

        for ar_ayet, tr_ayet in zip(ar_sure["ayahs"], tr_sure["ayahs"]):
            ayet_no = ar_ayet["numberInSurah"]
            raw = {
                "id": idx,
                "sure_isim": f"{sure_isim} {ayet_no}",
                "sure_no": sure_no,
                "ayet_no": ayet_no,
                "arapca": ar_ayet.get("text", ""),
                "meal": tr_ayet.get("text", ""),
                "mp3_url": f"/media/quran_audio/{str(sure_no).zfill(3)}{str(ayet_no).zfill(3)}.mp3",
            }
            try:
                validated = AyetSchema(**raw)
                ayetler.append(validated.model_dump())
            except ValidationError as exc:
                print(f"  Doğrulama hatası (idx={idx}): {exc}")
                skipped += 1
            idx += 1

    if skipped:
        print(f"\n  ⚠ {skipped} ayet doğrulama hatasıyla atlandı.")

    if not ayetler:
        raise RuntimeError("Hiçbir ayet üretilemedi — çıktı dosyası yazılmıyor.")

    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(ayetler, f, ensure_ascii=False, indent=2)

    print(f"\nTamamlandı! {len(ayetler)} ayet → {OUTPUT}")


if __name__ == "__main__":
    build()
