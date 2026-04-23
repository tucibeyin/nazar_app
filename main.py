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

# 2. ŞİFA, KORUNMA VE PSİKOLOJİK FERAHLAMA HAVUZU (Genişletilmiş Versiyon)
SIFA_HEDEFLER = [
    # --- 🛡️ 1. GÜÇLÜ KORUMA VE NAZAR (ZIRH AYETLERİ) ---
    "001001.mp3", "001002.mp3", "001003.mp3", "001004.mp3", "001005.mp3", "001006.mp3", "001007.mp3", # Fatiha (Şifa Suresi)
    "002255.mp3", # Ayetel Kürsi (En büyük koruma)
    "068051.mp3", "068052.mp3", # Kalem 51-52 (Nazar Ayetleri)
    "113001.mp3", "113002.mp3", "113003.mp3", "113004.mp3", "113005.mp3", # Felak Suresi
    "114001.mp3", "114002.mp3", "114003.mp3", "114004.mp3", "114005.mp3", "114006.mp3", # Nas Suresi
    "112001.mp3", "112002.mp3", "112003.mp3", "112004.mp3", # İhlas Suresi
    "109001.mp3", "109002.mp3", "109003.mp3", "109004.mp3", "109005.mp3", "109006.mp3", # Kafirun (Kötü enerjilere sınır çekme)
    "023097.mp3", "023098.mp3", # Mü'minûn 97-98 (Şeytanların vesvesesinden Allah'a sığınma)
    "059022.mp3", "059023.mp3", "059024.mp3", # Haşr 22-24 (Lev Enzelna - Şifa ve Güven)

    # --- 🍃 2. FERAHLAMA, İÇ HUZURU VE SEVGİ ---
    "094001.mp3", "094002.mp3", "094003.mp3", "094004.mp3", "094005.mp3", "094006.mp3", "094007.mp3", "094008.mp3", # İnşirah Suresi (Göğüs ferahlaması)
    "093001.mp3", "093002.mp3", "093003.mp3", "093004.mp3", "093005.mp3", # Duhâ 1-5 (Rabbin seni terk etmedi ve darılmadı)
    "013028.mp3", # Ra'd 28 (Kalpler ancak Allah'ı anmakla huzur bulur)
    "017082.mp3", # İsra 82 (Kuran'dan şifa ve rahmet)
    "036058.mp3", # Yâsîn 58 (Merhametli Rab'den Selam sözü)
    "050016.mp3", # Kaf 16 (Biz ona şah damarından daha yakınız)

    # --- 🕊️ 3. ZORLUK, STRES VE KAYGI YÖNETİMİ (ANTİ-ANKSİYETE) ---
    "039036.mp3", # Zümer 36 (Allah kuluna yetmez mi?)
    "002216.mp3", # Bakara 216 (Şer görünende hayır, hayır görünende şer olabilir)
    "009051.mp3", # Tevbe 51 (Allah'ın yazdığından başkası isabet etmez)
    "003139.mp3", # Al-i İmran 139 (Gevşemeyin, hüzünlenmeyin)
    "003173.mp3", # Al-i İmran 173 (Allah bize yeter, O ne güzel vekildir - Hasbunallah)
    "009040.mp3", # Tevbe 40 (Üzülme, Allah bizimle beraberdir)
    "009129.mp3", # Tevbe 129 (Bana Allah yeter, O'ndan başka ilah yoktur)
    "012086.mp3", # Yusuf 86 (Ben hüznümü ve derdimi sadece Allah'a şikayet ediyorum)
    "020046.mp3", # Taha 46 (Korkmayın, ben sizinle beraberim, işitirim ve görürüm)
    "040044.mp3", # Mümin 44 (Ben işimi Allah'a havale ediyorum)
    "011056.mp3", # Hûd 56 (Ben, benim de Rabbim sizin de Rabbiniz olan Allah'a tevekkül ettim)
    "033003.mp3", # Ahzâb 3 (Allah'a tevekkül et, vekil olarak Allah yeter)

    # --- 🤲 4. DUALAR, ÇIKIŞ YOLU VE RIZIK KORKUSU ---
    "002285.mp3", "002286.mp3", # Bakara 285-286 (Amenerrasulü - Güç yetiremeyeceğimiz yükü yükleme)
    "021083.mp3", # Enbiya 83 (Hz. Eyyub'un şifa duası: Zarar bana dokundu, sen merhametlilerin en merhametlisisin)
    "021087.mp3", # Enbiya 87 (Hz. Yunus'un duası: Senden başka ilah yoktur, seni tenzih ederim)
    "065002.mp3", "065003.mp3", # Talâk 2-3 (Kim Allah'a karşı gelmekten sakınırsa ona bir çıkış yolu açar)
    "029060.mp3", # Ankebût 60 (Nice canlılar var ki rızkını taşıyamaz, onları da sizi de Allah rızıklandırır)
    "039053.mp3", # Zümer 53 (Ey nefisleri aleyhine haddi aşan kullarım, Allah'ın rahmetinden ümit kesmeyin)

    # --- 🧭 5. HAYAT ÖĞÜDÜ, SABIR VE TESLİMİYET ---
    "031017.mp3", "031018.mp3", "031019.mp3", # Lokman 17-19 (Kibirlenme, başına gelene sabret, yürüyüşünde mutedil ol)
    "103001.mp3", "103002.mp3", "103003.mp3", # Asr 1-3 (Zamanın değeri ve sabrı tavsiye)
    "014007.mp3", # İbrahim 7 (Eğer şükrederseniz, size olan nimetimi kesinlikle artırırım)
    "089027.mp3", "089028.mp3", "089029.mp3", "089030.mp3", # Fecr 27-30 (Ey huzura ermiş nefis, razı olmuş olarak Rabbine dön)
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