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

# Artık tekli ayetler yerine kendi ürettiğimiz uzun soluklu terapi paketlerini çekiyoruz
_data_path = Path(__file__).parent / "paket_db.json"
if not _data_path.exists():
    raise RuntimeError("paket_db.json bulunamadı. Önce otomatik_paketleyici.py çalıştırın.")

with _data_path.open(encoding="utf-8") as f:
    TERAPI_PAKETLERI: list = json.load(f)

@app.get("/api/nazar/{hash_sayisi}")
async def get_ayet(hash_sayisi: int):
    if not TERAPI_PAKETLERI:
        raise HTTPException(status_code=404, detail="Paket bulunamadı")
        
    secilen_index = hash_sayisi % len(TERAPI_PAKETLERI)
    return TERAPI_PAKETLERI[secilen_index]