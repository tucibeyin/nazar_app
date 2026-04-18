from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

AYETLER = [
  {
    "id": 0,
    "sure_isim": "Bakara Suresi 255. Ayet (Ayetel Kürsi)",
    "arapca": "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ",
    "meal": "Allah, kendisinden başka hiçbir ilâh bulunmayandır. Diridir, kayyumdur. Onu ne bir uyuklama tutabilir, ne de bir uyku. Göklerdeki her şey, yerdeki her şey onundur...",
    "mp3_url": "/media/quran_audio/002255.mp3"
  },
  {
    "id": 1,
    "sure_isim": "Kalem Suresi 51. Ayet (Nazar Ayeti)",
    "arapca": "وَإِنْ يَكَادُ الَّذِينَ كَفَرُوا لَيُزْلِقُونَكَ بِأَبْصَارِهِمْ لَمَّا سَمِعُوا الذِّكْرَ وَيَقُولُونَ إِنَّهُ لَمَجْنُونٌ",
    "meal": "Şüphesiz inkâr edenler Zikr’i (Kur’an’ı) duydukları zaman neredeyse seni gözleriyle devireceklerdi. 'O, muhakkak delidir' diyorlar.",
    "mp3_url": "/media/quran_audio/068051.mp3"
  },
  {
    "id": 2,
    "sure_isim": "Kalem Suresi 52. Ayet (Nazar Ayeti)",
    "arapca": "وَمَا هُوَ إِلَّا ذِكْرٌ لِلْعَالَمِينَ",
    "meal": "Oysa o (Kur'an), âlemler için yalnızca bir öğüttür.",
    "mp3_url": "/media/quran_audio/068052.mp3"
  },
  {
    "id": 3,
    "sure_isim": "Felak Suresi 1. Ayet",
    "arapca": "قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ",
    "meal": "De ki: Sığınırım o sabahın Rabbine,",
    "mp3_url": "/media/quran_audio/113001.mp3"
  },
  {
    "id": 4,
    "sure_isim": "Felak Suresi 2. Ayet",
    "arapca": "مِنْ شَرِّ مَا خَلَقَ",
    "meal": "Yarattığı şeylerin şerrinden,",
    "mp3_url": "/media/quran_audio/113002.mp3"
  },
  {
    "id": 5,
    "sure_isim": "Felak Suresi 3. Ayet",
    "arapca": "وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ",
    "meal": "Karanlığı çöktüğü zaman gecenin şerrinden,",
    "mp3_url": "/media/quran_audio/113003.mp3"
  },
  {
    "id": 6,
    "sure_isim": "Felak Suresi 4. Ayet",
    "arapca": "وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ",
    "meal": "Düğümlere üfleyenlerin şerrinden,",
    "mp3_url": "/media/quran_audio/113004.mp3"
  },
  {
    "id": 7,
    "sure_isim": "Felak Suresi 5. Ayet",
    "arapca": "وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ",
    "meal": "Ve haset ettiği zaman hasetçinin şerrinden.",
    "mp3_url": "/media/quran_audio/113005.mp3"
  },
  {
    "id": 8,
    "sure_isim": "Nas Suresi 1. Ayet",
    "arapca": "قُلْ أَعُوذُ بِرَبِّ النَّاسِ",
    "meal": "De ki: İnsanların Rabbine sığınırım,",
    "mp3_url": "/media/quran_audio/114001.mp3"
  },
  {
    "id": 9,
    "sure_isim": "Nas Suresi 2. Ayet",
    "arapca": "مَلِكِ النَّاسِ",
    "meal": "İnsanların malikine,",
    "mp3_url": "/media/quran_audio/114002.mp3"
  },
  {
    "id": 10,
    "sure_isim": "Nas Suresi 3. Ayet",
    "arapca": "إِلَٰهِ النَّاسِ",
    "meal": "İnsanların ilahına;",
    "mp3_url": "/media/quran_audio/114003.mp3"
  },
  {
    "id": 11,
    "sure_isim": "Nas Suresi 4. Ayet",
    "arapca": "مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ",
    "meal": "O sinsi vesvesecinin şerrinden,",
    "mp3_url": "/media/quran_audio/114004.mp3"
  },
  {
    "id": 12,
    "sure_isim": "Nas Suresi 5. Ayet",
    "arapca": "الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ",
    "meal": "O ki, insanların göğüslerine vesvese verir.",
    "mp3_url": "/media/quran_audio/114005.mp3"
  },
  {
    "id": 13,
    "sure_isim": "Nas Suresi 6. Ayet",
    "arapca": "مِنَ الْجِنَّةِ وَالنَّاسِ",
    "meal": "Gerek cinlerden, gerekse insanlardan.",
    "mp3_url": "/media/quran_audio/114006.mp3"
  }
]


@app.get("/api/nazar/{hash_sayisi}")
async def get_ayet(hash_sayisi: int):
    secilen_index = hash_sayisi % 14
    return AYETLER[secilen_index]
