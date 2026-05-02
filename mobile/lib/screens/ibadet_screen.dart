import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../config/app_constants.dart';
import '../models/prayer_times.dart';
import '../providers/notif_settings_provider.dart';
import '../providers/vakitler_provider.dart';
import '../services/notification_service.dart';

class IbadetScreen extends ConsumerStatefulWidget {
  const IbadetScreen({super.key});

  @override
  ConsumerState<IbadetScreen> createState() => _IbadetScreenState();
}

class _IbadetScreenState extends ConsumerState<IbadetScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Bildirim iznini iste (kullanıcı daha önce reddettiyse sessizce geçer)
    NotificationService().requestPermissions().ignore();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vakitlerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF071220),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF071220), Color(0xFF0B1D30), Color(0xFF071220)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: async.when(
                    loading: _buildLoading,
                    error: (e, _) => _buildError(e.toString()),
                    data: _buildContent,
                  ),
                ),
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
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF7EC8E3), size: 20),
          ),
          Expanded(
            child: Text(
              'İbadet Asistanı',
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
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(vakitlerProvider),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7EC8E3), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF7EC8E3), strokeWidth: 1.5),
          SizedBox(height: 16),
          Text(
            'Konum alınıyor…',
            style: TextStyle(color: Color(0xFF5D8AA0), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    final isPermission = msg.contains('izni') || msg.contains('kapalı');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermission ? Icons.location_off_rounded : Icons.wifi_off_rounded,
              color: const Color(0xFF5D8AA0),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9FB8CC), fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => ref.invalidate(vakitlerProvider),
              child: const Text('Tekrar Dene', style: TextStyle(color: Color(0xFF7EC8E3))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(PrayerTimesData pt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      child: Column(
        children: [
          _buildCountdown(pt),
          const SizedBox(height: 14),
          _buildVakitlerList(pt),
          const SizedBox(height: 24),
          _buildQiblaSection(pt),
        ],
      ),
    );
  }

  // ── Geri Sayım ────────────────────────────────────────────────────────────

  Widget _buildCountdown(PrayerTimesData pt) {
    final next = pt.nextVakit(_now);
    final current = pt.currentVakit(_now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D2035),
            Color(0xFF0A1A2A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: kGold.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: kGold.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: next == null
          ? _buildAllPrayersDone(current)
          : _buildNextPrayerInfo(next.$1, next.$2, pt),
    );
  }

  Widget _buildNextPrayerInfo(String name, DateTime time, PrayerTimesData pt) {
    final diff = time.difference(_now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    final label = h > 0
        ? '$h sa $m dk'
        : m > 0
            ? '$m dk $s sn'
            : '$s sn';

    // Progress: fraction of day elapsed between previous and next prayer
    final vakitler = pt.vakitler;
    DateTime? prevTime;
    for (final (_, t) in vakitler) {
      if (!t.isAfter(_now)) prevTime = t;
    }
    double progress = 0;
    if (prevTime != null) {
      final total = time.difference(prevTime).inSeconds;
      final elapsed = _now.difference(prevTime).inSeconds;
      progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sıradaki Namaz',
          style: TextStyle(fontSize: 11, color: Color(0xFF5D8AA0), letterSpacing: 1.5),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              name,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              time.hour.toString().padLeft(2, '0'),
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                color: const Color(0xFF7EC8E3),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ':${time.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                color: const Color(0xFF5D8AA0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: const Color(0xFF1A3A5C).withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation<Color>(kGold.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$label kaldı',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 15,
            color: kGold.withValues(alpha: 0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAllPrayersDone(String? lastVakit) {
    return Column(
      children: [
        Icon(Icons.nightlight_round, color: kGold.withValues(alpha: 0.7), size: 32),
        const SizedBox(height: 8),
        Text(
          'Günün tüm vakitleri geçti',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (lastVakit != null) ...[
          const SizedBox(height: 4),
          Text(
            'Son vakit: $lastVakit',
            style: const TextStyle(fontSize: 12, color: Color(0xFF5D8AA0)),
          ),
        ],
      ],
    );
  }

  // ── Vakitler Listesi ───────────────────────────────────────────────────────

  Widget _buildVakitlerList(PrayerTimesData pt) {
    final current = pt.currentVakit(_now);
    final ikonlar = [
      Icons.nightlight_outlined,
      Icons.wb_sunny_outlined,
      Icons.sunny,
      Icons.wb_cloudy_outlined,
      Icons.wb_twilight_outlined,
      Icons.nights_stay_outlined,
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0D2035),
        border: Border.all(
          color: const Color(0xFF7EC8E3).withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Column(
        children: List.generate(pt.vakitler.length, (i) {
          final (name, time) = pt.vakitler[i];
          final isCurrent = name == current;
          final isPast = time.isBefore(_now);
          final isLast = i == pt.vakitler.length - 1;

          return Column(
            children: [
              _VakitRow(
                icon: ikonlar[i],
                name: name,
                time: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                isCurrent: isCurrent,
                isPast: isPast,
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  endIndent: 16,
                  color: const Color(0xFF1A3A5C).withValues(alpha: 0.6),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ── Kıble Bölümü ──────────────────────────────────────────────────────────

  Widget _buildQiblaSection(PrayerTimesData pt) {
    final distKm = pt.distanceToMecca;
    final distLabel = distKm < 1000
        ? '${distKm.round()} km'
        : '${(distKm / 1000).toStringAsFixed(1)} bin km';

    return Column(
      children: [
        Text(
          'Kıble Yönü',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 15,
            color: const Color(0xFF7EC8E3),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Mekke'ye uzaklık: $distLabel",
          style: const TextStyle(fontSize: 11, color: Color(0xFF5D8AA0)),
        ),
        const SizedBox(height: 20),
        StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            final heading = snapshot.data?.heading ?? 0.0;
            return Column(
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: _CompassPainter(
                      headingDeg: heading,
                      qiblaDeg: pt.qibla,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kıble: ${pt.qibla.round()}° | Yön: ${heading.round()}°',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5D8AA0),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Vakit Satırı ──────────────────────────────────────────────────────────────

class _VakitRow extends ConsumerWidget {
  final IconData icon;
  final String name;
  final String time;
  final bool isCurrent;
  final bool isPast;

  const _VakitRow({
    required this.icon,
    required this.name,
    required this.time,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notifSettingsProvider)[name] ?? true;

    final nameColor = isCurrent
        ? kGold
        : isPast
            ? const Color(0xFF3D6480)
            : Colors.white;
    final timeColor = isCurrent
        ? kGold
        : isPast
            ? const Color(0xFF3D6480)
            : const Color(0xFF7EC8E3);
    final bellColor = enabled
        ? kGold.withValues(alpha: 0.55)
        : const Color(0xFF2A4A62);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: isCurrent
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: kGold.withValues(alpha: 0.07),
            )
          : null,
      child: Row(
        children: [
          Icon(icon, size: 18, color: nameColor.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Text(
            name,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: nameColor,
              letterSpacing: 0.3,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: kGold.withValues(alpha: 0.18),
              ),
              child: const Text(
                'ŞİMDİ',
                style: TextStyle(fontSize: 9, color: kGold, letterSpacing: 1.2),
              ),
            ),
          ],
          const Spacer(),
          // Bildirim toggle
          GestureDetector(
            onTap: () {
              final pt = ref.read(vakitlerProvider).valueOrNull;
              ref.read(notifSettingsProvider.notifier).toggle(name, pt);
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                enabled
                    ? Icons.notifications_rounded
                    : Icons.notifications_off_outlined,
                key: ValueKey(enabled),
                size: 17,
                color: bellColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: timeColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pusula CustomPainter ──────────────────────────────────────────────────────

class _CompassPainter extends CustomPainter {
  final double headingDeg;
  final double qiblaDeg;

  const _CompassPainter({required this.headingDeg, required this.qiblaDeg});

  static const _kGold = Color(0xFFC9A84C);
  static const _kTeal = Color(0xFF7EC8E3);
  static const _kBg = Color(0xFF0D2035);
  static const _kDim = Color(0xFF1A3A5C);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // ── Arka plan (ekran koordinatlarında) ───────────────────────────────
    _drawBackground(canvas, c, r);

    // ── Dünya koordinatlarında (heading'e göre döner) ─────────────────────
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-headingDeg * math.pi / 180);

    _drawTicks(canvas, r);
    _drawCardinals(canvas, r);
    _drawQiblaArrow(canvas, r, qiblaDeg * math.pi / 180);

    canvas.restore();

    // Merkez nokta (döndürülmez)
    canvas.drawCircle(
      c,
      5,
      Paint()..color = _kGold,
    );
    canvas.drawCircle(
      c,
      5,
      Paint()
        ..color = _kBg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawBackground(Canvas canvas, Offset c, double r) {
    // Dış parıltı
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _kTeal.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // Ana daire
    canvas.drawCircle(c, r - 4, Paint()..color = _kBg);
    // Altın dış halka
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..color = _kGold.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // İç ince halka
    canvas.drawCircle(
      c,
      r - 22,
      Paint()
        ..color = _kDim.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawTicks(Canvas canvas, double r) {
    final majorPaint = Paint()
      ..color = _kTeal.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = _kDim.withValues(alpha: 0.9)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    for (int deg = 0; deg < 360; deg += 5) {
      final rad = deg * math.pi / 180;
      final isCardinal = deg % 90 == 0;
      final is45 = deg % 45 == 0;
      final tickLen = isCardinal ? 18.0 : is45 ? 13.0 : 7.0;
      final outerR = r - 6;
      final innerR = outerR - tickLen;
      final dx = math.sin(rad);
      final dy = -math.cos(rad);
      canvas.drawLine(
        Offset(dx * outerR, dy * outerR),
        Offset(dx * innerR, dy * innerR),
        (isCardinal || is45) ? majorPaint : minorPaint,
      );
    }
  }

  void _drawCardinals(Canvas canvas, double r) {
    final textR = r - 36.0;
    final entries = [
      ('N', 0.0, _kGold, 16.0, FontWeight.w700),
      ('S', math.pi, Colors.white, 13.0, FontWeight.w500),
      ('E', math.pi / 2, _kTeal, 13.0, FontWeight.w500),
      ('W', -math.pi / 2, _kTeal, 13.0, FontWeight.w500),
    ];
    for (final (label, rad, color, size, weight) in entries) {
      final pos = Offset(math.sin(rad) * textR, -math.cos(rad) * textR);
      _paintText(canvas, label, pos, color, size, weight);
    }
  }

  void _paintText(Canvas canvas, String text, Offset pos, Color color, double size, FontWeight weight) {
    final tp = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: size,
      fontWeight: weight,
    ))
      ..pushStyle(ui.TextStyle(color: color))
      ..addText(text);
    final para = tp.build()..layout(ui.ParagraphConstraints(width: size * 2));
    canvas.drawParagraph(para, pos - Offset(para.longestLine / 2, size / 2));
  }

  void _drawQiblaArrow(Canvas canvas, double r, double qiblaRad) {
    canvas.save();
    canvas.rotate(qiblaRad);

    final arrowR = r * 0.55;

    // Ok gövdesi
    final shaftPaint = Paint()
      ..color = _kGold.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, arrowR * 0.12), Offset(0, -arrowR + 18), shaftPaint);

    // Ok başı (üçgen)
    final arrowPath = Path()
      ..moveTo(-7, -arrowR + 20)
      ..lineTo(0, -arrowR)
      ..lineTo(7, -arrowR + 20)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = _kGold);

    // Kabe sembolü (küçük kare, ok ucunun üstünde)
    final kabeRect = Rect.fromCenter(
      center: Offset(0, -arrowR - 9),
      width: 9,
      height: 9,
    );
    canvas.drawRect(kabeRect, Paint()..color = _kGold.withValues(alpha: 0.9));
    canvas.drawRect(
      kabeRect,
      Paint()
        ..color = _kBg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Kuyruk (yarı saydam, ters yönde)
    canvas.drawLine(
      Offset(0, arrowR * 0.12),
      Offset(0, arrowR * 0.35),
      Paint()
        ..color = _kGold.withValues(alpha: 0.30)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.headingDeg != headingDeg || old.qiblaDeg != qiblaDeg;
}
