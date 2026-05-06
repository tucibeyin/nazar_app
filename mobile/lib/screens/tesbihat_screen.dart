import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';

class TesbihatScreen extends StatefulWidget {
  const TesbihatScreen({super.key});

  @override
  State<TesbihatScreen> createState() => _TesbihatScreenState();
}

class _DhikrItem {
  final String ad;
  final String arapca;
  final String okunus;
  final int hedef;
  const _DhikrItem({
    required this.ad,
    required this.arapca,
    required this.okunus,
    required this.hedef,
  });
}

class _TesbihatScreenState extends State<TesbihatScreen>
    with TickerProviderStateMixin {
  static const _dhikrler = [
    _DhikrItem(
      ad: 'Sübhanallah',
      arapca: 'سُبْحَانَ اللَّهِ',
      okunus: 'Sübhânallah',
      hedef: 33,
    ),
    _DhikrItem(
      ad: 'Elhamdülillah',
      arapca: 'الْحَمْدُ لِلَّهِ',
      okunus: 'Elhamdülillâh',
      hedef: 33,
    ),
    _DhikrItem(
      ad: 'Allahu Ekber',
      arapca: 'اللَّهُ أَكْبَرُ',
      okunus: 'Allâhü ekber',
      hedef: 34,
    ),
  ];

  int _aktifIndex = 0;
  final List<int> _sayilar = [0, 0, 0];
  bool _tamamlandi = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _progressCtrl;
  late final AnimationController _completeCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _completeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _completeCtrl.dispose();
    super.dispose();
  }

  void _sayTap() {
    if (_tamamlandi) return;
    HapticFeedback.lightImpact();

    final dhikr = _dhikrler[_aktifIndex];
    setState(() {
      _sayilar[_aktifIndex]++;
    });

    _pulseCtrl.forward(from: 0);

    final newVal = _sayilar[_aktifIndex];
    final target = dhikr.hedef;

    if (newVal >= target) {
      HapticFeedback.heavyImpact();
      if (_aktifIndex < _dhikrler.length - 1) {
        _progressCtrl.animateTo(1.0, curve: Curves.easeOut).then((_) {
          if (mounted) {
            setState(() => _aktifIndex++);
            _progressCtrl.value = 0;
          }
        });
      } else {
        _progressCtrl.animateTo(1.0, curve: Curves.easeOut).then((_) {
          if (mounted) {
            setState(() => _tamamlandi = true);
            _completeCtrl.forward();
          }
        });
      }
    } else {
      _progressCtrl.animateTo(newVal / target, curve: Curves.easeOut);
    }
  }

  void _sifirla() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (int i = 0; i < _sayilar.length; i++) {
        _sayilar[i] = 0;
      }
      _aktifIndex = 0;
      _tamamlandi = false;
    });
    _progressCtrl.animateTo(0, duration: const Duration(milliseconds: 300));
    _completeCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIndigo,
      appBar: AppBar(
        backgroundColor: kIndigo,
        foregroundColor: kGold,
        elevation: 0,
        title: Text(
          'Tesbihat',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: kGold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: kGold.withValues(alpha: 0.7),
            onPressed: _sifirla,
            tooltip: 'Sıfırla',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _sayTap,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            children: [
              _buildStepBar(),
              Expanded(
                child: _tamamlandi
                    ? _buildTamamlandi()
                    : _buildCounter(),
              ),
              _buildDotRow(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: List.generate(_dhikrler.length, (i) {
          final done = _sayilar[i] >= _dhikrler[i].hedef;
          final active = i == _aktifIndex && !_tamamlandi;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: done
                      ? kGold
                      : active
                          ? kGold.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCounter() {
    final dhikr = _dhikrler[_aktifIndex];
    final sayi = _sayilar[_aktifIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_progressCtrl, _pulseCtrl]),
          builder: (_, __) {
            final scale = 1.0 + _pulseCtrl.value * 0.025;
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 210,
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(210, 210),
                      painter: _RingPainter(
                        progress: _progressCtrl.value,
                        color: kGold,
                        track: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$sayi',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 68,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          '/ ${dhikr.hedef}',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 18,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 36),
        Text(
          dhikr.arapca,
          style: GoogleFonts.amiri(
            fontSize: 38,
            color: kGold,
            fontWeight: FontWeight.w700,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 10),
        Text(
          dhikr.okunus,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            color: Colors.white.withValues(alpha: 0.82),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ekrana dokun',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }

  Widget _buildTamamlandi() {
    return FadeTransition(
      opacity: _completeCtrl,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'اَلْحَمْدُ لِلّٰهِ',
            style: GoogleFonts.amiri(
              fontSize: 52,
              color: kGold,
              fontWeight: FontWeight.w700,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 18),
          Text(
            'Tamamlandı',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '33 Sübhanallah\n33 Elhamdülillah\n34 Allahu Ekber',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.8,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 44),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kIndigo,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _sifirla,
            child: Text(
              'Yeniden Başla',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_dhikrler.length, (i) {
        final done = _sayilar[i] >= _dhikrler[i].hedef;
        final active = i == _aktifIndex && !_tamamlandi;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: (done || _tamamlandi)
                ? kGold
                : active
                    ? kGold.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.18),
          ),
        );
      }),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 9;
    const sw = 7.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, 2 * math.pi, false,
      Paint()
        ..color = track
        ..strokeWidth = sw
        ..style = PaintingStyle.stroke,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color = color
          ..strokeWidth = sw
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
