import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../data/namaz_data.dart';

class NamazKilavuzuScreen extends StatefulWidget {
  const NamazKilavuzuScreen({super.key});

  @override
  State<NamazKilavuzuScreen> createState() => _NamazKilavuzuScreenState();
}

class _NamazKilavuzuScreenState extends State<NamazKilavuzuScreen>
    with TickerProviderStateMixin {
  NamazProgrami? _secili;

  // Flat step list derived from selected NamazProgrami
  List<_Step> _adimlar = [];
  int _adimIndex = 0;
  bool _ttsOynuyor = false;
  bool _ttsHazir = false;
  bool _ttsArapca = false;

  late final FlutterTts _tts;
  late final AnimationController _slideCtrl;
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();

    // Cihazda Arapça TTS sesi var mı kontrol et
    try {
      final langs = await _tts.getLanguages as List<dynamic>?;
      final arAvailable = langs?.any(
            (l) => l.toString().toLowerCase().startsWith('ar'),
          ) ??
          false;
      if (arAvailable) {
        await _tts.setLanguage('ar-SA');
        _ttsArapca = true;
      } else {
        await _tts.setLanguage('tr-TR');
      }
    } catch (_) {
      await _tts.setLanguage('tr-TR');
    }

    await _tts.setSpeechRate(_ttsArapca ? 0.46 : 0.42);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _ttsOynuyor = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _ttsOynuyor = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _ttsOynuyor = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _ttsOynuyor = false);
    });

    if (mounted) setState(() => _ttsHazir = true);
  }

  @override
  void dispose() {
    _tts.stop();
    _slideCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _secNamaz(NamazProgrami p) {
    setState(() {
      _secili = p;
      _adimlar = _flattenSteps(p);
      _adimIndex = 0;
    });
  }

  List<_Step> _flattenSteps(NamazProgrami p) {
    final steps = <_Step>[];
    for (final rekat in p.rekatlar) {
      steps.add(_Step.rekatHeader(rekat.baslik));
      for (final adim in rekat.adimlar) {
        steps.add(_Step.adim(adim));
      }
    }
    return steps;
  }

  Future<void> _ileri() async {
    if (_adimIndex >= _adimlar.length - 1) return;
    HapticFeedback.lightImpact();
    await _tts.stop();
    await _animateTransition(() {
      setState(() => _adimIndex++);
    });
    _autoOku();
  }

  Future<void> _geri() async {
    if (_adimIndex <= 0) return;
    HapticFeedback.lightImpact();
    await _tts.stop();
    await _animateTransition(() {
      setState(() => _adimIndex--);
    });
  }

  Future<void> _animateTransition(VoidCallback update) async {
    await _fadeCtrl.animateTo(0, duration: const Duration(milliseconds: 120));
    update();
    await _fadeCtrl.animateTo(1, duration: const Duration(milliseconds: 200));
  }

  void _autoOku() {
    final step = _adimlar[_adimIndex];
    if (step.adim == null || !_ttsHazir) return;
    final adim = step.adim!;
    // Arapça TTS varsa Arapça metni oku, yoksa Türkçe okunuşu
    final text = (_ttsArapca && adim.arapca != null) ? adim.arapca! : adim.okunus;
    _tts.speak(text);
  }

  Future<void> _toggleTts() async {
    if (_ttsOynuyor) {
      await _tts.stop();
    } else {
      _autoOku();
    }
  }

  Future<void> _cikis() async {
    await _tts.stop();
    setState(() {
      _secili = null;
      _adimlar = [];
      _adimIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kGreen,
        elevation: 0,
        title: Text(
          _secili == null ? 'Namaz Kılavuzu' : '${_secili!.ad} Namazı',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: kGreen,
          ),
        ),
        leading: _secili != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: _cikis,
              )
            : null,
      ),
      body: _secili == null ? _buildPicker() : _buildGuide(),
    );
  }

  // ── Namaz Seçici ─────────────────────────────────────────────────────────

  Widget _buildPicker() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hangi namazı kılacaksınız?',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: kGreen,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: namazliste.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _NamazKartWidget(
                  namaz: namazliste[i],
                  onTap: () => _secNamaz(namazliste[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Adım Kılavuzu ─────────────────────────────────────────────────────────

  Widget _buildGuide() {
    final step = _adimlar[_adimIndex];
    final total = _adimlar.length;
    final progress = (_adimIndex + 1) / total;

    return SafeArea(
      child: Column(
        children: [
          // Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adım ${_adimIndex + 1} / $total',
                      style: TextStyle(
                        fontSize: 12,
                        color: kGreen.withValues(alpha: 0.55),
                      ),
                    ),
                    Text(
                      _secili!.aciklama,
                      style: TextStyle(
                        fontSize: 12,
                        color: kGreen.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: kGreen.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(kGold),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),

          // Step content
          Expanded(
            child: FadeTransition(
              opacity: _fadeCtrl,
              child: step.isHeader
                  ? _buildRekatHeader(step.headerTitle!)
                  : _buildAdimCard(step.adim!),
            ),
          ),

          // Navigation
          _buildNavBar(),
        ],
      ),
    );
  }

  Widget _buildRekatHeader(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGold.withValues(alpha: 0.12),
              border: Border.all(color: kGold.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(Icons.mosque_rounded, color: kGold, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: kGreen,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'İleri\'ye basarak başlayın',
            style: TextStyle(
              fontSize: 14,
              color: kGreen.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdimCard(NamazAdimi adim) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pozisyon badge + başlık
          Row(
            children: [
              _PozisyonBadge(pozisyon: adim.pozisyon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  adim.baslik,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kGreen,
                  ),
                ),
              ),
              if (adim.tekrar > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: kGold.withValues(alpha: 0.15),
                    border: Border.all(color: kGold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '×${adim.tekrar}',
                    style: TextStyle(
                      fontSize: 13,
                      color: kGold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Arabic text
          if (adim.arapca != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: kGreen.withValues(alpha: 0.06),
                border: Border.all(color: kGold.withValues(alpha: 0.2)),
              ),
              child: Text(
                adim.arapca!,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.amiri(
                  fontSize: 26,
                  color: kGreen,
                  fontWeight: FontWeight.w700,
                  height: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Romanization
          Text(
            adim.okunus,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              color: kGreen.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 14),

          // Meaning
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: kGold.withValues(alpha: 0.06),
            ),
            child: Text(
              adim.anlam,
              style: TextStyle(
                fontSize: 14,
                color: kGreen.withValues(alpha: 0.7),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final isFirst = _adimIndex == 0;
    final isLast = _adimIndex == _adimlar.length - 1;
    final step = _adimlar[_adimIndex];
    final hasAudio = !step.isHeader && _ttsHazir;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kGold.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          // Geri
          _NavBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Geri',
            enabled: !isFirst,
            onTap: _geri,
            outlined: true,
          ),

          const SizedBox(width: 10),

          // TTS
          Expanded(
            child: GestureDetector(
              onTap: hasAudio ? _toggleTts : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _ttsOynuyor
                      ? kGold.withValues(alpha: 0.18)
                      : kGreen.withValues(alpha: 0.08),
                  border: Border.all(
                    color: _ttsOynuyor
                        ? kGold.withValues(alpha: 0.6)
                        : kGreen.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  _ttsOynuyor
                      ? Icons.stop_rounded
                      : Icons.volume_up_rounded,
                  color: hasAudio
                      ? (_ttsOynuyor ? kGold : kGreen)
                      : kGreen.withValues(alpha: 0.25),
                  size: 22,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // İleri / Bitti
          _NavBtn(
            icon: isLast ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
            label: isLast ? 'Bitti' : 'İleri',
            enabled: true,
            onTap: isLast ? _cikis : _ileri,
            outlined: false,
          ),
        ],
      ),
    );
  }
}

// ─── Yardımcı Sınıflar ────────────────────────────────────────────────────────

class _Step {
  final bool isHeader;
  final String? headerTitle;
  final NamazAdimi? adim;

  const _Step._({this.isHeader = false, this.headerTitle, this.adim});

  factory _Step.rekatHeader(String title) =>
      _Step._(isHeader: true, headerTitle: title);

  factory _Step.adim(NamazAdimi a) => _Step._(adim: a);
}

class _NamazKartWidget extends StatelessWidget {
  final NamazProgrami namaz;
  final VoidCallback onTap;
  const _NamazKartWidget({required this.namaz, required this.onTap});

  static const _icons = [
    Icons.wb_twilight_rounded,
    Icons.wb_sunny_rounded,
    Icons.sunny_snowing,
    Icons.nights_stay_rounded,
    Icons.bedtime_rounded,
  ];
  static const _colors = [
    Color(0xFFE8934A),
    Color(0xFFD4A017),
    Color(0xFFE06B2D),
    Color(0xFF6B5B95),
    Color(0xFF2E4A7B),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'].indexOf(namaz.ad);
    final ic = _icons[idx < 0 ? 0 : idx];
    final cl = _colors[idx < 0 ? 0 : idx];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: cl.withValues(alpha: 0.08),
          border: Border.all(color: cl.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cl.withValues(alpha: 0.14),
              ),
              child: Icon(ic, color: cl, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${namaz.ad} Namazı',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kGreen,
                    ),
                  ),
                  Text(
                    namaz.aciklama,
                    style: TextStyle(
                      fontSize: 13,
                      color: kGreen.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: cl.withValues(alpha: 0.5),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _PozisyonBadge extends StatelessWidget {
  final Pozisyon pozisyon;
  const _PozisyonBadge({required this.pozisyon});

  static const _labels = {
    Pozisyon.kiyam: 'Kıyam',
    Pozisyon.ruku: 'Rükû',
    Pozisyon.kavme: 'Kavme',
    Pozisyon.secde: 'Secde',
    Pozisyon.celse: 'Celse',
    Pozisyon.kaade: 'Oturuş',
  };

  static const _colors = {
    Pozisyon.kiyam: Color(0xFF1B4B3E),
    Pozisyon.ruku: Color(0xFF7B3A10),
    Pozisyon.kavme: Color(0xFF1B4B3E),
    Pozisyon.secde: Color(0xFF5B1A1A),
    Pozisyon.celse: Color(0xFF1A3A5C),
    Pozisyon.kaade: Color(0xFF1A3A5C),
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[pozisyon] ?? '';
    final color = _colors[pozisyon] ?? kGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool outlined;

  const _NavBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.outlined,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: outlined
              ? Colors.transparent
              : (enabled ? kGreen : kGreen.withValues(alpha: 0.3)),
          border: outlined
              ? Border.all(
                  color: enabled
                      ? kGreen.withValues(alpha: 0.4)
                      : kGreen.withValues(alpha: 0.15),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (outlined) ...[
              Icon(
                icon,
                size: 16,
                color: enabled
                    ? kGreen.withValues(alpha: 0.7)
                    : kGreen.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? kGreen.withValues(alpha: 0.7)
                      : kGreen.withValues(alpha: 0.25),
                ),
              ),
            ] else ...[
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
