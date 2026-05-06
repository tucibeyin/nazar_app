import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../models/esma.dart';
import '../services/social_share_service.dart';
import '../widgets/tesbih_widget.dart';

const _kZikirHedefi = 33;

class EsmaDhikrScreen extends StatefulWidget {
  final Esma esma;
  const EsmaDhikrScreen({super.key, required this.esma});

  @override
  State<EsmaDhikrScreen> createState() => _EsmaDhikrScreenState();
}

class _EsmaDhikrScreenState extends State<EsmaDhikrScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tesbihCtrl;
  final _shareKey = GlobalKey();
  int _count = 0;

  String get _spKey => 'zikir_${widget.esma.id}';

  @override
  void initState() {
    super.initState();
    _tesbihCtrl = AnimationController(vsync: this, duration: Duration.zero);
    _loadCount();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_spKey) ?? 0;
    if (mounted) {
      setState(() => _count = saved);
      _tesbihCtrl.value = (saved % _kZikirHedefi) / _kZikirHedefi;
    }
  }

  Future<void> _saveCount(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_spKey, value);
  }

  void _increment() {
    HapticFeedback.lightImpact();
    setState(() => _count++);
    _tesbihCtrl.value = (_count % _kZikirHedefi) / _kZikirHedefi;
    _saveCount(_count);

    if (_count % _kZikirHedefi == 0) {
      HapticFeedback.mediumImpact();
      _showCelebration();
    }
  }

  void _reset() {
    HapticFeedback.heavyImpact();
    setState(() => _count = 0);
    _tesbihCtrl.value = 0.0;
    _saveCount(0);
  }

  void _showCelebration() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0D2035),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kGold.withValues(alpha: 0.35), width: 1),
        ),
        content: Text(
          '${_count ~/ _kZikirHedefi} × $_kZikirHedefi tamamlandı',
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 15,
            color: kGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tesbihCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final esma = widget.esma;
    final roundsDone = _count ~/ _kZikirHedefi;
    final inRound = _count % _kZikirHedefi;

    return Scaffold(
      backgroundColor: const Color(0xFF071220),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF071220), Color(0xFF0C1F35), Color(0xFF071220)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(child: _buildBody(esma, roundsDone, inRound)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Geri',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Color(0xFF7EC8E3), size: 20),
          ),
          Expanded(
            child: Text(
              'Zikir',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kGold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Paylaş',
            onPressed: () => SocialShareService.shareWidgetAsImage(
              _shareKey,
              text: '${widget.esma.isim} — ${widget.esma.anlam}',
            ),
            icon: Icon(
              Icons.ios_share_rounded,
              color: const Color(0xFF7EC8E3).withValues(alpha: 0.8),
              size: 21,
            ),
          ),
          IconButton(
            tooltip: 'Sıfırla',
            onPressed: _reset,
            icon: Icon(
              Icons.refresh_rounded,
              color: const Color(0xFF7EC8E3).withValues(alpha: 0.7),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Esma esma, int roundsDone, int inRound) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Paylaşılabilir esma kartı
        RepaintBoundary(
          key: _shareKey,
          child: _EsmaShareCard(esma: esma),
        ),
        const SizedBox(height: 20),
        // Tesbih widget — driven by controller.value
        TesbihWidget(controller: _tesbihCtrl, isPlaying: _count > 0),
        const SizedBox(height: 8),
        // Progress text
        Text(
          '$inRound / $_kZikirHedefi',
          style: const TextStyle(
            color: Color(0xFF5D8AA0),
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        if (roundsDone > 0) ...[
          const SizedBox(height: 4),
          Text(
            '$roundsDone tur tamamlandı',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 13,
              color: kGold.withValues(alpha: 0.7),
            ),
          ),
        ],
        const Spacer(),
        // Tap button
        GestureDetector(
          onTap: _increment,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A5F7A).withValues(alpha: 0.45),
              border: Border.all(
                color: const Color(0xFF7EC8E3).withValues(alpha: 0.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E86AB).withValues(alpha: 0.30),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$_count',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Dokunarak zikret',
          style: TextStyle(
            color: Color(0xFF5D8AA0),
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─── Paylaşılabilir Esma Kartı ────────────────────────────────────────────────

class _EsmaShareCard extends StatelessWidget {
  final Esma esma;
  const _EsmaShareCard({required this.esma});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071220), Color(0xFF0C1F35)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.30), width: 1),
      ),
      child: Column(
        children: [
          // Başlık
          const Text(
            'ESMAÜL HÜSNA',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 3,
              color: Color(0xFF7EC8E3),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
              height: 1,
              color: kGold.withValues(alpha: 0.25)),
          const SizedBox(height: 14),
          // Arapça isim
          Text(
            esma.arapca,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.amiri(
              fontSize: 38,
              color: kGold.withValues(alpha: 0.9),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          // Türkçe isim
          Text(
            esma.isim,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7EC8E3),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          // Anlam
          Text(
            esma.anlam,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8AACBF),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
              height: 1,
              color: kGold.withValues(alpha: 0.25)),
          const SizedBox(height: 10),
          // Fazilet
          Text(
            esma.fazilet,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 11,
              color: kGold.withValues(alpha: 0.52),
              fontStyle: FontStyle.italic,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          Container(
              height: 1,
              color: kGold.withValues(alpha: 0.25)),
          const SizedBox(height: 8),
          // Marka alt bandı
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mosque_rounded,
                  color: Color(0xFF7EC8E3), size: 11),
              SizedBox(width: 6),
              Text(
                'NAZAR & FERAHLAMA',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: Color(0xFF7EC8E3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
