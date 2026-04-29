import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class TesbihPainter extends CustomPainter {
  final double t;
  final bool isPlaying;
  const TesbihPainter(this.t, {required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    const beadCount = 33;
    final cx = size.width / 2;
    final cy = size.height * 0.72;
    final arcW = size.width * 0.90;

    final positions = <Offset>[];
    for (int i = 0; i < beadCount; i++) {
      final pct = i / (beadCount - 1);
      final x = cx - arcW / 2 + pct * arcW;
      final norm = 2 * pct - 1;
      positions.add(Offset(x, cy - size.height * 0.50 * (1 - norm * norm)));
    }

    // Kord
    final cordPath = Path()..moveTo(positions[0].dx, positions[0].dy);
    for (int i = 1; i < beadCount; i++) {
      cordPath.lineTo(positions[i].dx, positions[i].dy);
    }
    canvas.drawPath(
      cordPath,
      Paint()
        ..color = kGold.withValues(alpha: 0.62)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // İmame tassel (püskül)
    final imp = positions[16];
    for (final dx in [-3.5, 0.0, 3.5]) {
      canvas.drawLine(
        Offset(imp.dx, imp.dy + 14),
        Offset(imp.dx + dx, imp.dy + 26),
        Paint()
          ..color = kGold.withValues(alpha: 0.58)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawLine(
      Offset(imp.dx, imp.dy + 10.5),
      Offset(imp.dx, imp.dy + 15),
      Paint()
        ..color = kGold.withValues(alpha: 0.72)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    // Püskül bağı boncuğu
    canvas.drawCircle(
      Offset(imp.dx, imp.dy + 12),
      3.5,
      Paint()..color = kGold.withValues(alpha: 0.80),
    );
    canvas.drawCircle(
      Offset(imp.dx, imp.dy + 12),
      3.5,
      Paint()
        ..color = kGold
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke,
    );

    final activeBead = isPlaying ? (t * beadCount).floor() % beadCount : -1;

    for (int i = 0; i < beadCount; i++) {
      final pos = positions[i];
      final isImame = i == 16;
      final isDurak = i == 5 || i == 27;
      final r = isImame ? 10.5 : (isDurak ? 7.5 : 5.5);
      final isActive = i == activeBead;

      // Aktif tane ışıması
      if (isActive) {
        canvas.drawCircle(
          pos,
          r + 8,
          Paint()
            ..color = kGold.withValues(alpha: 0.38)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      // Derinlik gölgesi
      canvas.drawCircle(
        Offset(pos.dx + 1.0, pos.dy + 1.2),
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );

      // Tane dolgu rengi
      final Color fillColor;
      if (isImame) {
        fillColor = kGold;
      } else if (isDurak) {
        fillColor = const Color(0xFF235940);
      } else {
        fillColor = kGreen;
      }
      canvas.drawCircle(pos, r, Paint()..color = fillColor);

      // Altın çerçeve
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = kGold.withValues(alpha: isActive ? 1.0 : (isImame ? 0.92 : 0.72))
          ..strokeWidth = isImame ? 1.6 : 1.1
          ..style = PaintingStyle.stroke,
      );

      // Işık vurgusu (3D etki)
      canvas.drawCircle(
        Offset(pos.dx - r * 0.28, pos.dy - r * 0.28),
        r * 0.24,
        Paint()
          ..color = Colors.white.withValues(alpha: isImame ? 0.62 : 0.38),
      );

      // İmame yıldız nakışı
      if (isImame) {
        for (int s = 0; s < 6; s++) {
          final a = s * pi / 3;
          canvas.drawLine(
            Offset(pos.dx + 2.2 * cos(a), pos.dy + 2.2 * sin(a)),
            Offset(pos.dx + 6.5 * cos(a), pos.dy + 6.5 * sin(a)),
            Paint()
              ..color = kIndigo.withValues(alpha: 0.78)
              ..strokeWidth = 1.2,
          );
        }
        canvas.drawCircle(pos, 3.8, Paint()..color = kIndigo.withValues(alpha: 0.55));
        canvas.drawCircle(
          pos,
          3.8,
          Paint()
            ..color = kGold.withValues(alpha: 0.72)
            ..strokeWidth = 0.9
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TesbihPainter old) => old.t != t || old.isPlaying != isPlaying;
}
