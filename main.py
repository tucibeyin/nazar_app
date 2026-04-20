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

with _data_path.open(encoding="utf-8") as f:
    AYETLER: list = json.load(f)


@app.get("/api/nazar/{hash_sayisi}")
async def get_ayet(hash_sayisi: int):
    secilen_index = hash_sayisi % len(AYETLER)
    return AYETLER[secilen_index]
