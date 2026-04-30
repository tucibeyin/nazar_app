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
        "id": "insira",
        "isim": "İnşirah Suresi",
        "aciklama": "Kalplere huzur veren sure — zorluktan sonra kolaylık",
        "icon": "heart",
        "ayet_refs": [(94, i) for i in range(1, 9)],
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

# ─── Esmaül Hüsna ─────────────────────────────────────────────────────────────

ESMAUL_HUSNA: list[dict] = [
    {"id": 1, "isim": "Er-Rahman", "arapca": "الرحمن", "anlam": "Dünyada bütün varlıklara merhamet eden", "fazilet": "Her gün 100 kez okuyan, gaflet ve dalgınlıktan kurtulur; kalbi uyanık ve diri olur.", "ebced_degeri": 329},
    {"id": 2, "isim": "Er-Rahim", "arapca": "الرحيم", "anlam": "Ahirette müminlere özel merhamet eden", "fazilet": "Sabah namazından sonra 100 kez okuyan, herkes tarafından sevilir ve merhamet görür.", "ebced_degeri": 258},
    {"id": 3, "isim": "El-Melik", "arapca": "الملك", "anlam": "Mülkün gerçek sahibi ve hükümdarı", "fazilet": "Her gün sabah namazından sonra okuyan, kalp zenginliğine ve huzuruna kavuşur.", "ebced_degeri": 90},
    {"id": 4, "isim": "El-Kuddüs", "arapca": "القدوس", "anlam": "Her noksanlıktan münezzeh, her türlü kusurdan pak olan", "fazilet": "Her gün 100 kez okuyan, kalp hastalıklarından ve vesveseden kurtulur.", "ebced_degeri": 170},
    {"id": 5, "isim": "Es-Selam", "arapca": "السلام", "anlam": "Esenliğin ve selamın kaynağı", "fazilet": "Hasta ziyaretinde 160 kez okuyan, Allah'ın izniyle hastanın şifasına vesile olur.", "ebced_degeri": 131},
    {"id": 6, "isim": "El-Mü'min", "arapca": "المؤمن", "anlam": "Güven veren, kalplere iman nurunu yerleştiren", "fazilet": "Her gün 630 kez okuyan, korkulardan emin olur; kalbi sükûnet ve güvenlik bulur.", "ebced_degeri": 136},
    {"id": 7, "isim": "El-Müheymin", "arapca": "المهيمن", "anlam": "Her şeyi gözetip koruyan, hâkimiyet sahibi", "fazilet": "Gece abdest alarak 100 kez okuyan, kalbi aydınlanır ve rüyaları açık olur.", "ebced_degeri": 145},
    {"id": 8, "isim": "El-Aziz", "arapca": "العزيز", "anlam": "Üstün, güçlü, yenilmez olan", "fazilet": "Sabah namazından sonra 40 gün boyunca 40 kez okuyan, ihtiyaçsızlık ve izzet bulur.", "ebced_degeri": 94},
    {"id": 9, "isim": "El-Cebbar", "arapca": "الجبار", "anlam": "İradesini her şeye geçiren, kırıkları onaran", "fazilet": "Her gün okuyan, zorbalara ve zalimlere karşı korunur; kalbi cesaret bulur.", "ebced_degeri": 206},
    {"id": 10, "isim": "El-Mütekebbir", "arapca": "المتكبر", "anlam": "Büyüklüğü her şeyin üstünde olan", "fazilet": "Büyüklük ve kibir hastalığından kurtulmak isteyen bu ismi okur; tevazu kapısı açılır.", "ebced_degeri": 662},
    {"id": 11, "isim": "El-Halik", "arapca": "الخالق", "anlam": "Her şeyi yoktan var eden yaratıcı", "fazilet": "Her gün okuyan, işlerinde kolaylık bulur; Allah'ın takdirine teslim olur.", "ebced_degeri": 731},
    {"id": 12, "isim": "El-Bari", "arapca": "البارئ", "anlam": "Varlıkları en mükemmel şekilde yaratan", "fazilet": "Bir işe başlarken okuyan, o işin güzel ve sağlam olmasına vesile olur.", "ebced_degeri": 214},
    {"id": 13, "isim": "El-Musavvir", "arapca": "المصور", "anlam": "Her şeye şekil ve suret veren", "fazilet": "Çocuk sahibi olmak isteyenler için dua olarak okunur; hayırlı nesil niyetiyle.", "ebced_degeri": 336},
    {"id": 14, "isim": "El-Gaffar", "arapca": "الغفار", "anlam": "Günahları tekrar tekrar örten ve bağışlayan", "fazilet": "Cuma günleri okunursa, günahların örtülmesine ve affedilmeye vesile olur.", "ebced_degeri": 1281},
    {"id": 15, "isim": "El-Kahhar", "arapca": "القهار", "anlam": "Her şeye galip gelen, herkesin üstünde hükmeden", "fazilet": "Dünya hırsı ve nefs baskısından kurtulmak için okunur; kalp özgürleşir.", "ebced_degeri": 306},
    {"id": 16, "isim": "El-Vehhab", "arapca": "الوهاب", "anlam": "Karşılıksız ve durmaksızın bağışlayan", "fazilet": "Sıkıntılı zamanlarda okunursa, beklenmedik bir yardım ve ihsana kapı açılır.", "ebced_degeri": 14},
    {"id": 17, "isim": "Er-Rezzak", "arapca": "الرزاق", "anlam": "Her canlıya rızkını ulaştıran", "fazilet": "Rızık darlığında her gün okunursa, bereket ve bolluk kapıları açılır.", "ebced_degeri": 308},
    {"id": 18, "isim": "El-Fettah", "arapca": "الفتاح", "anlam": "Her türlü hayır kapısını açan, galibiyeti veren", "fazilet": "Sabah namazı sonrası okunursa, gün içinde kapalı kapılar ve zorluklar kolaylaşır.", "ebced_degeri": 489},
    {"id": 19, "isim": "El-Alim", "arapca": "العليم", "anlam": "Her şeyi bütün ayrıntısıyla bilen", "fazilet": "İlim ve anlayış isteyenler her gün okursa, hikmet ve feraset kapısı açılır.", "ebced_degeri": 150},
    {"id": 20, "isim": "El-Kabid", "arapca": "القابض", "anlam": "Rızıkları ve ruhları tutan, daraltan", "fazilet": "Şiddetli hüzün ve daralma anında okunursa, sıkıntının geçici olduğu idrak edilir.", "ebced_degeri": 903},
    {"id": 21, "isim": "El-Basit", "arapca": "الباسط", "anlam": "Rızıkları ve rahmet genişleten, açan", "fazilet": "Rızık ve bereket duasında okunursa, genişlik ve rahatlık kapısı açılır.", "ebced_degeri": 72},
    {"id": 22, "isim": "El-Hafid", "arapca": "الخافض", "anlam": "Hak etmeyen kibirli kişileri alçaltan", "fazilet": "Zalim ve zorbalara karşı korunmak için okunur; Allah'ın adaleti devreye girer.", "ebced_degeri": 1481},
    {"id": 23, "isim": "Er-Rafi", "arapca": "الرافع", "anlam": "Dostlarını derece derece yükselten", "fazilet": "Her gün okuyan, manevi derecesini artırır; Allah katında değeri yükselir.", "ebced_degeri": 351},
    {"id": 24, "isim": "El-Muizz", "arapca": "المعز", "anlam": "Dilediğine izzet ve şeref veren", "fazilet": "Haksız yere küçük düşürülen kişi okuduğunda, Allah onu izzete kavuşturur.", "ebced_degeri": 117},
    {"id": 25, "isim": "El-Müzill", "arapca": "المذل", "anlam": "Haktan sapanları zillete düşüren", "fazilet": "Haksızlık ve zulüm karşısında okunursa, zalimin zilletine ve geri çekilmesine işaret eder.", "ebced_degeri": 770},
    {"id": 26, "isim": "Es-Semi", "arapca": "السميع", "anlam": "Her sesi ve gizli düşünceyi işiten", "fazilet": "Duadan önce okunursa, o duanın Allah tarafından işitildiği bilinci kuvvetlenir.", "ebced_degeri": 180},
    {"id": 27, "isim": "El-Basir", "arapca": "البصير", "anlam": "Her şeyi gören, en gizliyi de fark eden", "fazilet": "Cuma gecesi 100 kez okuyan, basiret ve feraset kazanır; kalbinin gözü açılır.", "ebced_degeri": 302},
    {"id": 28, "isim": "El-Hakem", "arapca": "الحكم", "anlam": "Hakkaniyet üzere hükmeden tek hakim", "fazilet": "Haksızlığa uğrayan kişi okuduğunda, hakkın tecellisi için Allah'a güveni artar.", "ebced_degeri": 68},
    {"id": 29, "isim": "El-Adl", "arapca": "العدل", "anlam": "Mutlak adaletle hükmeden", "fazilet": "Zulme uğrayanlar okuduğunda, ilahi adaletin işleyeceğine olan iman tazelenir.", "ebced_degeri": 104},
    {"id": 30, "isim": "El-Latif", "arapca": "اللطيف", "anlam": "En ince sırları bilen, nazik ve lütufkâr olan", "fazilet": "Sıkıntı ve darlık içinde çok okuyanın durumunu Allah en ince şekilde halleder.", "ebced_degeri": 129},
    {"id": 31, "isim": "El-Habir", "arapca": "الخبير", "anlam": "Her şeyin iç yüzünden ve gizlisinden haberdar olan", "fazilet": "Karar vermekte güçlük çekenlere okunursa, işlerin iç yüzü görülmeye başlanır.", "ebced_degeri": 812},
    {"id": 32, "isim": "El-Halim", "arapca": "الحليم", "anlam": "Öfkeye rağmen cezalandırmakta acele etmeyen", "fazilet": "Öfke ve sabırsızlık sorununda okunursa, yumuşaklık ve hilm hâli kalbe yerleşir.", "ebced_degeri": 88},
    {"id": 33, "isim": "El-Azim", "arapca": "العظيم", "anlam": "Yüce, pek büyük, azameti sonsuz olan", "fazilet": "Her gün okuyan, işlerinde Allah'ın büyüklüğüne sığınmayı öğrenir; tevazu artar.", "ebced_degeri": 1020},
    {"id": 34, "isim": "El-Gafur", "arapca": "الغفور", "anlam": "Günahları örten ve bağışlaması bol olan", "fazilet": "Pişmanlık ve tövbe anlarında çok okuyan, affedileceği müjdesini kalbinde hisseder.", "ebced_degeri": 1286},
    {"id": 35, "isim": "Eş-Şekur", "arapca": "الشكور", "anlam": "Az iyiliği bile büyük mükâfatla karşılayan", "fazilet": "Şükür ve nankörlükten kurtulma için okunursa, nimete şükredebilme hâli açılır.", "ebced_degeri": 526},
    {"id": 36, "isim": "El-Ali", "arapca": "العلي", "anlam": "En yüce olan, hiçbir şey O'nun üstünde değil", "fazilet": "Her gün okuyan, yüce ahlak ve maneviyat sahibi olmaya doğru yönelir.", "ebced_degeri": 110},
    {"id": 37, "isim": "El-Kebir", "arapca": "الكبير", "anlam": "Büyüklükte herşeyi aşan, azameti sınırsız", "fazilet": "Kalbe heybet ve saygı kazandırmak isteyenler için okunur; vakar artar.", "ebced_degeri": 232},
    {"id": 38, "isim": "El-Hafiz", "arapca": "الحفيظ", "anlam": "Her şeyi koruyan, unutmadan kayıt eden", "fazilet": "Yolculuk ve tehlike anlarında okunursa, Allah'ın özel koruması devreye girer.", "ebced_degeri": 998},
    {"id": 39, "isim": "El-Mukit", "arapca": "المقيت", "anlam": "Her canlının gıdasını ve kuvvetini veren", "fazilet": "Zayıflık ve yorgunluk anlarında okunursa, beden ve ruh kuvvet kazanır.", "ebced_degeri": 550},
    {"id": 40, "isim": "El-Hasib", "arapca": "الحسيب", "anlam": "Herkesi hesaba çeken ve herkese yeten", "fazilet": "Haksızlığa uğrayan kişi 70 kez okuduğunda, hesabını Allah'a havale etmiş olur.", "ebced_degeri": 80},
    {"id": 41, "isim": "El-Celil", "arapca": "الجليل", "anlam": "Büyüklük, ululuk ve haşmet sahibi", "fazilet": "Her gün okunursa, kişide Allah'a karşı derin bir heybet ve saygı hâli oluşur.", "ebced_degeri": 73},
    {"id": 42, "isim": "El-Kerim", "arapca": "الكريم", "anlam": "Cömertliği ve ikramı sonsuz olan", "fazilet": "Uyumadan önce okunursa, kişi uyurken de Allah'ın keremiyle kuşatılmış olur.", "ebced_degeri": 270},
    {"id": 43, "isim": "Er-Rakib", "arapca": "الرقيب", "anlam": "Her an her şeyi gözetip denetleyen", "fazilet": "Sürekli okuyan, gizli ve açık her hâlinde Allah'ın nezaretini hisseder; takva artar.", "ebced_degeri": 312},
    {"id": 44, "isim": "El-Mücib", "arapca": "المجيب", "anlam": "Duaları ve niyazları kabul eden", "fazilet": "Duadan önce okunursa, yapılan duanın kabul olacağına olan ümit ve iman güçlenir.", "ebced_degeri": 55},
    {"id": 45, "isim": "El-Vasi", "arapca": "الواسع", "anlam": "Rahmeti, ilmi ve gücü her şeyi kuşatan", "fazilet": "Darlık ve çaresizlikte okunursa, Allah'ın rahmetinin genişliği idrak edilir.", "ebced_degeri": 137},
    {"id": 46, "isim": "El-Hakim", "arapca": "الحكيم", "anlam": "Her işi en doğru ve hikmetli şekilde yapan", "fazilet": "Anlaşılmaz olaylar karşısında okunursa, kalbe hikmet ve teslimiyetle sükûnet gelir.", "ebced_degeri": 78},
    {"id": 47, "isim": "El-Vedud", "arapca": "الودود", "anlam": "Kullarını çok seven ve sevilmeye en layık olan", "fazilet": "Aralarında soğukluk bulunan kişiler okuduğunda, muhabbet ve yumuşaklık kapısı açılır.", "ebced_degeri": 20},
    {"id": 48, "isim": "El-Mecid", "arapca": "المجيد", "anlam": "Şan ve şerefi çok büyük, ihsanı bol olan", "fazilet": "Her gün okuyan, şeref ve itibar sahibi olma yolunda Allah'ın desteğini alır.", "ebced_degeri": 57},
    {"id": 49, "isim": "El-Bais", "arapca": "الباعث", "anlam": "Ölüleri diriltecek olan, gönülleri uyandıran", "fazilet": "Gaflet ve ölü kalp için okunursa, kalbi uyandırır; ahiret şuuru canlanır.", "ebced_degeri": 573},
    {"id": 50, "isim": "Eş-Şehid", "arapca": "الشهيد", "anlam": "Her şeye bizzat şahit olan", "fazilet": "Sözünde durma ve dürüstlük için okuyanın kalbinde hesap duygusu güçlenir.", "ebced_degeri": 319},
    {"id": 51, "isim": "El-Hakk", "arapca": "الحق", "anlam": "Varlığı ve hükmü gerçek olan", "fazilet": "Şüphe ve karmaşa anında okunursa, gerçeğe yönelme ve hakikate ulaşma kolaylaşır.", "ebced_degeri": 108},
    {"id": 52, "isim": "El-Vekil", "arapca": "الوكيل", "anlam": "İşleri en iyi yürüten vekil, tevekkül edilen", "fazilet": "Endişeli kalpler bu ismi okursa, tevekkül hâli güçlenir ve huzur gelir.", "ebced_degeri": 66},
    {"id": 53, "isim": "El-Kaviyy", "arapca": "القوي", "anlam": "Gücü sonsuz ve her şeye yeten", "fazilet": "Güçsüzlük ve çaresizlik anında okunursa, kalp kuvvet bulur; yılgınlık kalkar.", "ebced_degeri": 116},
    {"id": 54, "isim": "El-Metin", "arapca": "المتين", "anlam": "Kuvveti sonsuz ve sağlamlığı tartışılmaz olan", "fazilet": "Kararlılık ve azim isteyen kişi bu ismi okursa, sebat ve direnç hâli artar.", "ebced_degeri": 500},
    {"id": 55, "isim": "El-Veliyy", "arapca": "الولي", "anlam": "Müminlerin dostu ve koruyucu velisi", "fazilet": "Her gün okuyan, Allah'ın dostluğuna yaklaşır; yalnızlık hissi yerini güvene bırakır.", "ebced_degeri": 46},
    {"id": 56, "isim": "El-Hamid", "arapca": "الحميد", "anlam": "Her türlü övgüye layık olan", "fazilet": "Şükür ve hamd bilinci için okunursa, nimete karşı farkındalık ve minnet artar.", "ebced_degeri": 62},
    {"id": 57, "isim": "El-Muhsi", "arapca": "المحصي", "anlam": "Her şeyi sayıp kaydeden, hiçbir şeyi gözden kaçırmayan", "fazilet": "Kötü alışkanlıklardan kurtulmak için okunursa, her davranışın kaydedildiği bilinci artar.", "ebced_degeri": 148},
    {"id": 58, "isim": "El-Mübdi", "arapca": "المبدئ", "anlam": "Yaratmaya başlayan, ilk varlığı yoktan var eden", "fazilet": "Yeni bir başlangıç ve yenilenme için okunursa, hayırlı bir ilk adım atılmasına kapı açar.", "ebced_degeri": 56},
    {"id": 59, "isim": "El-Muiyd", "arapca": "المعيد", "anlam": "Varlıkları yeniden yaratan, öldükten sonra dirilten", "fazilet": "Ümitsizlik anında okunursa, her şeyin yeniden mümkün olduğu iman edilir.", "ebced_degeri": 124},
    {"id": 60, "isim": "El-Muhyi", "arapca": "المحيي", "anlam": "Hayat veren, cansıza can üfleyen", "fazilet": "Yorgun ve bitkin kalp için okunursa, manevi diriliş ve enerji yenilenir.", "ebced_degeri": 68},
    {"id": 61, "isim": "El-Mümit", "arapca": "المميت", "anlam": "Ölümü yaratan ve veren", "fazilet": "Ölüm korkusunu yenmek ve ahirete hazırlanmak için okunursa, derin bir teslimiyet gelir.", "ebced_degeri": 490},
    {"id": 62, "isim": "El-Hayy", "arapca": "الحي", "anlam": "Diri ve hayat sahibi olan, ölümü olmayan", "fazilet": "Hastalık ve zayıflık anında okunursa, diri olan Allah'a sığınma hâli güçlenir.", "ebced_degeri": 18},
    {"id": 63, "isim": "El-Kayyum", "arapca": "القيوم", "anlam": "Her şeyi kendi gücüyle ayakta tutan", "fazilet": "Hayy ve Kayyum isimleri birlikte okunursa, iman ve tevekkül kuvvetlenir.", "ebced_degeri": 156},
    {"id": 64, "isim": "El-Vacid", "arapca": "الواجد", "anlam": "Her ihtiyacını bizzat bulan, hiçbir şeyden yoksun olmayan", "fazilet": "Yoksunluk ve eksiklik hisseden kişi okuduğunda, kanaatkârlık ve rıza hâli artar.", "ebced_degeri": 14},
    {"id": 65, "isim": "El-Macid", "arapca": "الماجد", "anlam": "Şan ve şerefi yüce, keremi bol olan", "fazilet": "Her gün okuyan, manevî değer ve itibar kazanma yolunda ilahi desteği alır.", "ebced_degeri": 48},
    {"id": 66, "isim": "El-Vahid", "arapca": "الواحد", "anlam": "Birliği ve tekliği tartışılmaz olan", "fazilet": "Tevhit bilincini derinleştirmek isteyenler için okunan temel isimlerden biridir.", "ebced_degeri": 19},
    {"id": 67, "isim": "El-Ehad", "arapca": "الأحد", "anlam": "Zat ve sıfatlarında kesinlikle bir ve tek olan", "fazilet": "Şirk ve yanılgıdan korunmak için okunursa, kalpteki tevhit inancı sağlamlaşır.", "ebced_degeri": 13},
    {"id": 68, "isim": "Es-Samed", "arapca": "الصمد", "anlam": "Her şeyin kendisine muhtaç olduğu, hiçbir şeye muhtaç olmayan", "fazilet": "İhtiyaç ve sıkıntı anında sadece Allah'a yönelmek için okunur; tam teslimiyet gelir.", "ebced_degeri": 134},
    {"id": 69, "isim": "El-Kadir", "arapca": "القادر", "anlam": "Her şeye gücü yeten, dilediğini yaratan", "fazilet": "İmkânsız görünen işler için dua ederken okunursa, her şeye kadir olana sığınılmış olur.", "ebced_degeri": 305},
    {"id": 70, "isim": "El-Muktedir", "arapca": "المقتدر", "anlam": "Gücünü eksiksiz kullanan, her şeye hâkim", "fazilet": "Güç ve yetki sahibi olmak isteyenler için değil, Allah'ın kudretini anmak için okunur.", "ebced_degeri": 744},
    {"id": 71, "isim": "El-Mukaddim", "arapca": "المقدم", "anlam": "Dilediğini öne geçiren, ilerleten", "fazilet": "Hayırlı işlerde öne geçmek için okunursa, Allah'ın takdiriyle öncelik verilir.", "ebced_degeri": 184},
    {"id": 72, "isim": "El-Muahhar", "arapca": "المؤخر", "anlam": "Dilediğini geri bırakan, geciktiren", "fazilet": "Her işin zamanının Allah'a ait olduğunu hissetmek için okunursa, sabır kolaylaşır.", "ebced_degeri": 846},
    {"id": 73, "isim": "El-Evvel", "arapca": "الأول", "anlam": "Başlangıcı olmayan, her şeyden önce var olan", "fazilet": "Sefere çıkarken dört kez okunursa, yolculukta korunma ve güvenlik hâsıl olur.", "ebced_degeri": 37},
    {"id": 74, "isim": "El-Ahir", "arapca": "الآخر", "anlam": "Sonu olmayan, her şeyden sonra da var olan", "fazilet": "Ahiret bilincini canlı tutmak için okunursa, dünyanın geçiciliği idrak edilir.", "ebced_degeri": 801},
    {"id": 75, "isim": "Ez-Zahir", "arapca": "الظاهر", "anlam": "Varlığının delilleri her yerde aşikâr olan", "fazilet": "Allah'ın varlığını kâinatta görmek için okunursa, iman basiret kazanır.", "ebced_degeri": 1106},
    {"id": 76, "isim": "El-Batin", "arapca": "الباطن", "anlam": "Akılların idrak edemeyeceği şekilde gizli olan", "fazilet": "Sırlar ve gizlilikler hakkında okunursa, Allah'ın her şeyi bildiğine iman derinleşir.", "ebced_degeri": 62},
    {"id": 77, "isim": "El-Vali", "arapca": "الوالي", "anlam": "Tüm kâinatı ve işleri yöneten", "fazilet": "Karmaşık ve zor durumlar için okunursa, her şeyin bir yöneticisi olduğu huzur verir.", "ebced_degeri": 47},
    {"id": 78, "isim": "El-Müteal", "arapca": "المتعالي", "anlam": "Sınırsız yüceliğiyle her şeyin üstünde olan", "fazilet": "Büyüklük ve kibir hislerinden arınmak için okunursa, kul, Allah'a teslim olur.", "ebced_degeri": 551},
    {"id": 79, "isim": "El-Berr", "arapca": "البر", "anlam": "İyilik ve ihsanı bol, kullarına karşı çok lütufkâr", "fazilet": "Çocuklar için okunursa, Allah'ın hayır ve iyilikle büyütmesi için niyaz edilmiş olur.", "ebced_degeri": 202},
    {"id": 80, "isim": "Et-Tevvab", "arapca": "التواب", "anlam": "Tövbeleri defalarca kabul eden, tövbeye teşvik eden", "fazilet": "Tövbe ve istiğfar duasından önce okunursa, tövbenin kabul kapısına yaklaşılmış olur.", "ebced_degeri": 409},
    {"id": 81, "isim": "El-Müntekim", "arapca": "المنتقم", "anlam": "Suçluları ve zalimleri hak ettikleri gibi cezalandıran", "fazilet": "İntikam duygusunu Allah'a bırakmak için okunursa, kalpten kin ve öfke çekilir.", "ebced_degeri": 630},
    {"id": 82, "isim": "El-Afuvv", "arapca": "العفو", "anlam": "Günahları tamamen silen ve affeden", "fazilet": "Kadir Gecesi'nde en çok okunması tavsiye edilen isimlerden biridir; af niyetiyle.", "ebced_degeri": 156},
    {"id": 83, "isim": "Er-Rauf", "arapca": "الرؤوف", "anlam": "Kullarına karşı çok şefkatli ve nazik olan", "fazilet": "Sertlik ve katı kalplilikten kurtulmak için okunursa, yumuşaklık ve şefkat artar.", "ebced_degeri": 286},
    {"id": 84, "isim": "Malikül-Mülk", "arapca": "مالك الملك", "anlam": "Mülkün gerçek ve tek sahibi", "fazilet": "Makam ve mevki hırsından kurtulmak için okunursa, her mülkün geçici olduğu görülür.", "ebced_degeri": 212},
    {"id": 85, "isim": "Zülcelal vel-İkram", "arapca": "ذو الجلال والإكرام", "anlam": "Celal ve ikram sahibi, azamet ve ihsanı birleştiren", "fazilet": "Hz. Peygamber duaların Allah'ın bu isimleriyle yapılmasını tavsiye etmiştir.", "ebced_degeri": 1100},
    {"id": 86, "isim": "El-Muksit", "arapca": "المقسط", "anlam": "Adaleti eksiksiz yerine getiren, hakkaniyetli olan", "fazilet": "Haklarının çiğnendiğini hisseden kişi okuduğunda, adalete olan güven tazelenir.", "ebced_degeri": 209},
    {"id": 87, "isim": "El-Cami", "arapca": "الجامع", "anlam": "Dağınık şeyleri bir araya toplayan", "fazilet": "Ayrılık ve dağınıklık içinde okunursa, Allah'ın toplayıcılığına sığınılmış olur.", "ebced_degeri": 114},
    {"id": 88, "isim": "El-Ğani", "arapca": "الغني", "anlam": "Zenginliği sonsuz, hiçbir şeye muhtaç olmayan", "fazilet": "Fakirlik ve yoksulluk kaygısında okunan önemli isimlerden biridir; kanaat artar.", "ebced_degeri": 1060},
    {"id": 89, "isim": "El-Muğni", "arapca": "المغني", "anlam": "Kullarını zenginleştiren ve müstağni kılan", "fazilet": "Her Cuma 1000 kez okuyanın fakirlik ve ihtiyaç sıkıntısından kurtulacağı rivayet edilir.", "ebced_degeri": 1100},
    {"id": 90, "isim": "El-Mani", "arapca": "المانع", "anlam": "Dilediği şeyleri ve zararları engelleyen", "fazilet": "Kötülük ve belalardan korunmak için okunursa, Allah'ın engelleyiciliğine sığınılır.", "ebced_degeri": 161},
    {"id": 91, "isim": "Ed-Darr", "arapca": "الضار", "anlam": "Hikmetiyle zarar ve sıkıntı veren", "fazilet": "Her sıkıntının bir hikmeti olduğuna iman etmek için okunursa, sabır kuvvetlenir.", "ebced_degeri": 1001},
    {"id": 92, "isim": "En-Nafi", "arapca": "النافع", "anlam": "Kullarına fayda ve yarar ulaştıran", "fazilet": "Hayırlı ve faydalı işlere başlarken okunursa, Allah'ın o işi faydalı kılması umulur.", "ebced_degeri": 201},
    {"id": 93, "isim": "En-Nur", "arapca": "النور", "anlam": "Her şeyi aydınlatan, gönüllere nur saçan", "fazilet": "Kalp karanlığı ve sıkıntısında okunursa, ilahi nurun gönle dolması için dua edilmiş olur.", "ebced_degeri": 256},
    {"id": 94, "isim": "El-Hadi", "arapca": "الهادي", "anlam": "Doğru yola ileten tek rehber", "fazilet": "Yanlış yolda olduğunu hisseden kişi okuduğunda, hidayet yolu aydınlanmaya başlar.", "ebced_degeri": 20},
    {"id": 95, "isim": "El-Bedi", "arapca": "البديع", "anlam": "Eşsiz ve benzersiz şekilde yaratan", "fazilet": "Sanata ve ibdaa yönelen kişi okuduğunda, yaratıcılık ve ilham Allah'tan dilenir.", "ebced_degeri": 86},
    {"id": 96, "isim": "El-Baki", "arapca": "الباقي", "anlam": "Varlığı sonsuz ve kalıcı olan", "fazilet": "Geçiciliğin hüznü içinde okunursa, asıl kalıcı olanın Allah olduğu bilinci huzur verir.", "ebced_degeri": 113},
    {"id": 97, "isim": "El-Varis", "arapca": "الوارث", "anlam": "Her şey yok olduğunda her şeyi O'na miras kalan", "fazilet": "Dünya bağlılıklarından kurtulmak için okunursa, gerçek mirasın ahiret olduğu idrak edilir.", "ebced_degeri": 707},
    {"id": 98, "isim": "Er-Reşid", "arapca": "الرشيد", "anlam": "Her şeyi doğru ve isabetli şekilde düzenleyen", "fazilet": "Karar anlarında ve yol ayrımlarında okunursa, doğru yolu göstermesi için Allah'a iltica edilir.", "ebced_degeri": 514},
    {"id": 99, "isim": "Es-Sabur", "arapca": "الصبور", "anlam": "Kullarına karşı çok sabırlı ve cezada acele etmeyen", "fazilet": "Sabır sınavında en çok okunması tavsiye edilen isim; sabır ve tahammül kapısını açar.", "ebced_degeri": 298},
]

log.info("esmaul_husna_loaded", count=len(ESMAUL_HUSNA))
