enum Pozisyon { kiyam, ruku, kavme, secde, celse, kaade }

class NamazAdimi {
  final String baslik;
  final Pozisyon pozisyon;
  final String? arapca;
  final String okunus;
  final String anlam;
  final int tekrar;

  const NamazAdimi({
    required this.baslik,
    required this.pozisyon,
    this.arapca,
    required this.okunus,
    required this.anlam,
    this.tekrar = 1,
  });
}

class Rekat {
  final String baslik;
  final List<NamazAdimi> adimlar;
  const Rekat({required this.baslik, required this.adimlar});
}

class NamazProgrami {
  final String ad;
  final String aciklama;
  final List<Rekat> rekatlar;
  const NamazProgrami({
    required this.ad,
    required this.aciklama,
    required this.rekatlar,
  });
}

// ─── Ortak Adımlar ────────────────────────────────────────────────────────────

const _iftitah = NamazAdimi(
  baslik: 'İftitah Tekbiri',
  pozisyon: Pozisyon.kiyam,
  arapca: 'اللَّهُ أَكْبَرُ',
  okunus: 'Allahu Ekber.',
  anlam: 'Eller kulak hizasına kaldırılır, "Allahu Ekber" denir. Namaz başlamış olur.',
);

const _subhaneke = NamazAdimi(
  baslik: 'Sübhaneke',
  pozisyon: Pozisyon.kiyam,
  arapca: 'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ وَتَبَارَكَ اسْمُكَ وَتَعَالَى جَدُّكَ وَلَا إِلَهَ غَيْرُكَ',
  okunus:
      'Sübhânekellâhümme ve bihamdike ve tebârekesmüke ve teâlâ ceddüke ve lâ ilâhe gayrük.',
  anlam:
      'Allah\'ım, sen her türlü noksanlıktan münezzehsin. Sana hamd ile tesbih ederim. Senin adın mübarektir. Senin büyüklüğün yücedir. Senden başka ilah yoktur.',
);

const _fatiha = NamazAdimi(
  baslik: 'Fatiha Suresi',
  pozisyon: Pozisyon.kiyam,
  arapca:
      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ۝ الرَّحْمَٰنِ الرَّحِيمِ ۝ مَالِكِ يَوْمِ الدِّينِ ۝ إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ۝ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ ۝ صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
  okunus:
      'Bismillâhirrahmânirrahîm. Elhamdü lillâhi rabbil âlemîn. Errahmânirrahîm. Mâliki yevmiddîn. İyyâke na\'büdü ve iyyâke nestaîn. İhdinessırâtal müstakîm. Sırâtallezîne en\'amte aleyhim. Gayril mağdûbi aleyhim ve leddâllîn. Âmin.',
  anlam:
      'Rahman ve Rahim olan Allah\'ın adıyla. Hamd, alemlerin Rabbi olan Allah\'a mahsustur. O, Rahman ve Rahimdir. Din gününün sahibidir. Yalnız sana ibadet eder, yalnız senden yardım dileriz. Bizi doğru yola ilet; nimet verdiğin kimselerin yoluna, gazaba uğrayanların ve sapkınların yoluna değil.',
);

const _ihlas = NamazAdimi(
  baslik: 'İhlas Suresi (Zamm-ı Sure)',
  pozisyon: Pozisyon.kiyam,
  arapca:
      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
  okunus:
      'Bismillâhirrahmânirrahîm. Kul hüvallâhü ehad. Allâhüssamed. Lem yelid ve lem yûled. Ve lem yekün lehü küfüven ehad.',
  anlam:
      'Allah birdir, tektir. Her şey O\'na muhtaçtır. O, doğurmamış ve doğurulmamıştır. Hiçbir şey O\'nun dengi değildir.',
);

const _ruku = NamazAdimi(
  baslik: 'Rükû',
  pozisyon: Pozisyon.ruku,
  arapca: 'سُبْحَانَ رَبِّيَ الْعَظِيمِ',
  okunus: 'Sübhâne Rabbiyel azîm.',
  anlam: 'Yüce Rabbimi tesbih ederim.',
  tekrar: 3,
);

const _kavme = NamazAdimi(
  baslik: 'Kavme',
  pozisyon: Pozisyon.kavme,
  arapca: 'سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ ۝ رَبَّنَا لَكَ الْحَمْدُ',
  okunus: 'Semi\'allahu limen hamideh. Rabbena lekel hamd.',
  anlam: 'Allah kendine hamd edeni işitir. Rabbimiz, hamd sana aittir.',
);

const _secde = NamazAdimi(
  baslik: 'Secde',
  pozisyon: Pozisyon.secde,
  arapca: 'سُبْحَانَ رَبِّيَ الْأَعْلَى',
  okunus: 'Sübhâne Rabbiyel a\'lâ.',
  anlam: 'En yüce Rabbimi tesbih ederim.',
  tekrar: 3,
);

const _celse = NamazAdimi(
  baslik: 'Celse',
  pozisyon: Pozisyon.celse,
  arapca: 'اللَّهُ أَكْبَرُ',
  okunus: 'Allahu Ekber.',
  anlam: 'İki secde arasında tekbir söylenerek oturulur.',
);

const _kadeUla = NamazAdimi(
  baslik: 'Ka\'de-i Ûlâ — Ettehiyyatü',
  pozisyon: Pozisyon.kaade,
  arapca:
      'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
  okunus:
      'Ettehiyyâtü lillâhi vessalevâtü vettayyibât. Esselâmü aleyke eyyühennebiyyü ve rahmetullâhi ve berekâtüh. Esselâmü aleynâ ve alâ ibâdillâhissâlihîn. Eşhedü en lâ ilâhe illallâh. Ve eşhedü enne Muhammeden abdühü ve resûlüh.',
  anlam: 'Orta oturuş — sadece Ettehiyyatü okunur, ardından üçüncü rekâta kalkılır.',
);

const _ettehiyyatu = NamazAdimi(
  baslik: 'Ettehiyyatü',
  pozisyon: Pozisyon.kaade,
  arapca:
      'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
  okunus:
      'Ettehiyyâtü lillâhi vessalevâtü vettayyibât. Esselâmü aleyke eyyühennebiyyü ve rahmetullâhi ve berekâtüh. Esselâmü aleynâ ve alâ ibâdillâhissâlihîn. Eşhedü en lâ ilâhe illallâh. Ve eşhedü enne Muhammeden abdühü ve resûlüh.',
  anlam:
      'Dil ile, beden ile ve mal ile yapılan ibadetlerin hepsi Allah\'a aittir. Selam sana ey Peygamber, Allah\'ın rahmeti ve bereketi üzerine olsun. Selam bize ve Allah\'ın salih kullarına olsun. Şehadet ederim ki Allah\'tan başka ilah yoktur. Şehadet ederim ki Muhammed O\'nun kulu ve elçisidir.',
);

const _salli = NamazAdimi(
  baslik: 'Allahümme Salli',
  pozisyon: Pozisyon.kaade,
  arapca:
      'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ',
  okunus:
      'Allâhümme salli alâ Muhammedin ve alâ âli Muhammed. Kemâ salleyte alâ İbrâhîme ve alâ âli İbrâhîm. İnneke hamîdün mecîd.',
  anlam:
      'Allah\'ım! Hz. Muhammed\'e ve ailesine rahmet et, Hz. İbrahim\'e ve ailesine rahmet ettiğin gibi. Şüphesiz sen övgüye layıksın, yücesin.',
);

const _barik = NamazAdimi(
  baslik: 'Allahümme Bârik',
  pozisyon: Pozisyon.kaade,
  arapca:
      'اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ',
  okunus:
      'Allâhümme bârik alâ Muhammedin ve alâ âli Muhammed. Kemâ bârekte alâ İbrâhîme ve alâ âli İbrâhîm. İnneke hamîdün mecîd.',
  anlam:
      'Allah\'ım! Hz. Muhammed\'e ve ailesine bereket ver, Hz. İbrahim\'e ve ailesine bereket verdiğin gibi. Şüphesiz sen övgüye layıksın, yücesin.',
);

const _rabbenaDua = NamazAdimi(
  baslik: 'Duâ — Rabbenâ Âtinâ',
  pozisyon: Pozisyon.kaade,
  arapca: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
  okunus:
      'Rabbenâ âtinâ fiddünyâ haseneten ve fil âhireti haseneten ve kınâ azâbennâr.',
  anlam: 'Rabbimiz! Bize dünyada iyilik ver, ahirette de iyilik ver. Bizi cehennem azabından koru.',
);

const _selamSag = NamazAdimi(
  baslik: 'Selam (Sağa)',
  pozisyon: Pozisyon.kaade,
  arapca: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ',
  okunus: 'Esselâmü aleyküm ve rahmetullah.',
  anlam: 'Baş sağ omuza çevrilerek selam verilir.',
);

const _selamSol = NamazAdimi(
  baslik: 'Selam (Sola)',
  pozisyon: Pozisyon.kaade,
  arapca: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ',
  okunus: 'Esselâmü aleyküm ve rahmetullah.',
  anlam: 'Baş sol omuza çevrilerek selam verilir. Namaz tamamlanmış olur.',
);

// ─── Namaz Programları ────────────────────────────────────────────────────────

const sabahFarz = NamazProgrami(
  ad: 'Sabah',
  aciklama: '2 rekât farz',
  rekatlar: [
    Rekat(
      baslik: '1. Rekât',
      adimlar: [_iftitah, _subhaneke, _fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde],
    ),
    Rekat(
      baslik: '2. Rekât — Son Oturuş',
      adimlar: [
        _fatiha,
        _ihlas,
        _ruku,
        _kavme,
        _secde,
        _celse,
        _secde,
        _ettehiyyatu,
        _salli,
        _barik,
        _rabbenaDua,
        _selamSag,
        _selamSol,
      ],
    ),
  ],
);

const ogleFarz = NamazProgrami(
  ad: 'Öğle',
  aciklama: '4 rekât farz',
  rekatlar: [
    Rekat(
      baslik: '1. Rekât',
      adimlar: [_iftitah, _subhaneke, _fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde],
    ),
    Rekat(
      baslik: '2. Rekât — Orta Oturuş',
      adimlar: [_fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde, _kadeUla],
    ),
    Rekat(
      baslik: '3. Rekât',
      adimlar: [_fatiha, _ruku, _kavme, _secde, _celse, _secde],
    ),
    Rekat(
      baslik: '4. Rekât — Son Oturuş',
      adimlar: [
        _fatiha,
        _ruku,
        _kavme,
        _secde,
        _celse,
        _secde,
        _ettehiyyatu,
        _salli,
        _barik,
        _rabbenaDua,
        _selamSag,
        _selamSol,
      ],
    ),
  ],
);

const ikindiFarz = NamazProgrami(
  ad: 'İkindi',
  aciklama: '4 rekât farz',
  rekatlar: [
    Rekat(
      baslik: '1. Rekât',
      adimlar: [_iftitah, _subhaneke, _fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde],
    ),
    Rekat(
      baslik: '2. Rekât — Orta Oturuş',
      adimlar: [_fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde, _kadeUla],
    ),
    Rekat(
      baslik: '3. Rekât',
      adimlar: [_fatiha, _ruku, _kavme, _secde, _celse, _secde],
    ),
    Rekat(
      baslik: '4. Rekât — Son Oturuş',
      adimlar: [
        _fatiha,
        _ruku,
        _kavme,
        _secde,
        _celse,
        _secde,
        _ettehiyyatu,
        _salli,
        _barik,
        _rabbenaDua,
        _selamSag,
        _selamSol,
      ],
    ),
  ],
);

const aksamFarz = NamazProgrami(
  ad: 'Akşam',
  aciklama: '3 rekât farz',
  rekatlar: [
    Rekat(
      baslik: '1. Rekât',
      adimlar: [_iftitah, _subhaneke, _fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde],
    ),
    Rekat(
      baslik: '2. Rekât — Orta Oturuş',
      adimlar: [_fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde, _kadeUla],
    ),
    Rekat(
      baslik: '3. Rekât — Son Oturuş',
      adimlar: [
        _fatiha,
        _ruku,
        _kavme,
        _secde,
        _celse,
        _secde,
        _ettehiyyatu,
        _salli,
        _barik,
        _rabbenaDua,
        _selamSag,
        _selamSol,
      ],
    ),
  ],
);

const yatsiFarz = NamazProgrami(
  ad: 'Yatsı',
  aciklama: '4 rekât farz',
  rekatlar: [
    Rekat(
      baslik: '1. Rekât',
      adimlar: [_iftitah, _subhaneke, _fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde],
    ),
    Rekat(
      baslik: '2. Rekât — Orta Oturuş',
      adimlar: [_fatiha, _ihlas, _ruku, _kavme, _secde, _celse, _secde, _kadeUla],
    ),
    Rekat(
      baslik: '3. Rekât',
      adimlar: [_fatiha, _ruku, _kavme, _secde, _celse, _secde],
    ),
    Rekat(
      baslik: '4. Rekât — Son Oturuş',
      adimlar: [
        _fatiha,
        _ruku,
        _kavme,
        _secde,
        _celse,
        _secde,
        _ettehiyyatu,
        _salli,
        _barik,
        _rabbenaDua,
        _selamSag,
        _selamSol,
      ],
    ),
  ],
);

const namazliste = [sabahFarz, ogleFarz, ikindiFarz, aksamFarz, yatsiFarz];
