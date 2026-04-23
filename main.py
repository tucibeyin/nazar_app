import json
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_data_path = Path(__file__).parent / "quran_data.json"
if not _data_path.exists():
    raise RuntimeError("quran_data.json bulunamadı. Önce build_db.py çalıştırın.")

# 1. Tüm Kuran'ı belleğe alalım
with _data_path.open(encoding="utf-8") as f:
    TUM_AYETLER: list = json.load(f)

# 2. Nazar ve Ferahlama için "Şifa Havuzu"nu tanımlayalım
SIFA_HEDEFLER = [
    # --- NAZAR VE KORUMA ---
    "002255.mp3", # Ayetel Kürsi
    "068051.mp3", "068052.mp3", # Kalem 51-52 (Nazar Ayetleri)
    "113001.mp3", "113002.mp3", "113003.mp3", "113004.mp3", "113005.mp3", # Felak Suresi
    "114001.mp3", "114002.mp3", "114003.mp3", "114004.mp3", "114005.mp3", "114006.mp3", # Nas Suresi
    
    # --- FERAHLAMA VE İÇ HUZURU ---
    "094001.mp3", "094002.mp3", "094003.mp3", "094004.mp3", 
    "094005.mp3", "094006.mp3", "094007.mp3", "094008.mp3", # İnşirah Suresi (Komple)
    "013028.mp3", # Ra'd 28 (Kalpler ancak Allah'ı anmakla huzur bulur)
    "002285.mp3", "002286.mp3", # Bakara 285-286 (Amenerrasulü)
    "009129.mp3", # Tevbe 129 (Bana Allah yeter...)
    "093001.mp3", "093002.mp3", "093003.mp3", "093004.mp3", "093005.mp3" # Duhâ 1-5 (Rabbin seni terk etmedi)
]

# 3. Sadece bu listedekileri ayıklayıp aktif havuza ekleyelim
AKTIF_SIFA_HAVUZU = []
for ayet in TUM_AYETLER:
    if any(hedef in ayet.get("mp3_url", "") for hedef in SIFA_HEDEFLER):
        AKTIF_SIFA_HAVUZU.append(ayet)

@app.get("/api/nazar/{hash_sayisi}")
async def get_ayet(hash_sayisi: int):
    # Filtrelenmiş liste boşsa (tedbir amaçlı) tüm listeye dön
    liste = AKTIF_SIFA_HAVUZU if AKTIF_SIFA_HAVUZU else TUM_AYETLER
    
    if not liste:
        raise HTTPException(status_code=404, detail="Ayet veritabanı boş.")
        
    # Kullanıcının yüz tarama hash'ine göre bu seçkin havuzdan bir ayet seç
    secilen_index = hash_sayisi % len(liste)
    return liste[secilen_index]