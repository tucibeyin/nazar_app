import json
import time
import requests

AR_URL = "https://api.alquran.cloud/v1/quran/ar.alafasy"
TR_URL = "https://api.alquran.cloud/v1/quran/tr.diyanet"
OUTPUT  = "quran_data.json"


def fetch(url: str) -> list:
    for attempt in range(1, 4):
        try:
            print(f"  GET {url}  (deneme {attempt}/3)")
            r = requests.get(url, timeout=60)
            r.raise_for_status()
            return r.json()["data"]["surahs"]
        except Exception as exc:
            print(f"  Hata: {exc}")
            if attempt < 3:
                time.sleep(10)
    raise RuntimeError(f"API'den veri alınamadı: {url}")


def build():
    print("Arapça metin indiriliyor...")
    ar_surahs = fetch(AR_URL)

    print("Türkçe meal indiriliyor...")
    tr_surahs = fetch(TR_URL)

    ayetler = []
    idx = 0

    for ar_sure, tr_sure in zip(ar_surahs, tr_surahs):
        sure_no   = ar_sure["number"]
        sure_isim = ar_sure["englishName"]

        for ar_ayet, tr_ayet in zip(ar_sure["ayahs"], tr_sure["ayahs"]):
            ayet_no = ar_ayet["numberInSurah"]
            ayetler.append({
                "id":        idx,
                "sure_isim": f"{sure_isim} Suresi, {ayet_no}. Ayet",
                "sure_no":   sure_no,
                "ayet_no":   ayet_no,
                "arapca":    ar_ayet["text"],
                "meal":      tr_ayet["text"],
                "mp3_url":   f"/media/quran_audio/{sure_no:03d}{ayet_no:03d}.mp3",
            })
            idx += 1

    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(ayetler, f, ensure_ascii=False, indent=2)

    print(f"\nTamamlandı! {len(ayetler)} ayet → {OUTPUT}")


if __name__ == "__main__":
    build()
