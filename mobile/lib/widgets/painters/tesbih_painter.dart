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
    final cy = size.height * 0.62;
    final arcW = size.width * 0.84;

    final positions = <Offset>[];
    for (int i = 0; i < beadCount; i++) {
      final pct = i / (beadCount - 1);
      final x = cx - arcW / 2 + pct * arcW;
      final norm = 2 * pct - 1;
      positions.add(Offset(x, cy - size.height * 0.28 * (1 - norm * norm)));
    }

    final strPath = Path()..moveTo(positions[0].dx, positions[0].dy);
    for (int i = 1; i < beadCount; i++) {
      strPath.lineTo(positions[i].dx, positions[i].dy);
    }
    canvas.drawPath(
      strPath,
      Paint()..color = kGold.withValues(alpha: 0.28)..strokeWidth = 0.9..style = PaintingStyle.stroke,
    );

    final imp = positions[16];
    canvas.drawLine(
      imp, Offset(imp.dx, imp.dy + 14),
      Paint()..color = kGold.withValues(alpha: 0.40)..strokeWidth = 1.4..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(imp.dx, imp.dy + 17), 2.8, Paint()..color = kGold.withValues(alpha: 0.55));

    final activeBead = isPlaying ? (t * beadCount).floor() % beadCount : -1;

    for (int i = 0; i < beadCount; i++) {
      final pos     = positions[i];
      final isImame = i == 16;
      final isDurak = i == 5 || i == 27;
      final r       = isImame ? 6.5 : (isDurak ? 5.0 : 3.8);
      final isActive = i == activeBead;

      if (isActive) {
        canvas.drawCircle(
          pos, r + 5,
          Paint()
            ..color = kGold.withValues(alpha: 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }

      canvas.drawCircle(
        pos, r,
        Paint()..color = isImame ? kGold : (isDurak ? kGreen : kGreen.withValues(alpha: 0.72)),
      );
      canvas.drawCircle(
        pos, r,
        Paint()
          ..color = kGold.withValues(alpha: isActive ? 0.95 : 0.55)
          ..strokeWidth = isImame ? 1.2 : 0.8
          ..style = PaintingStyle.stroke,
      );

      if (isImame) {
        for (int s = 0; s < 6; s++) {
          final a = s * pi / 3;
          canvas.drawLine(
            Offset(pos.dx + 1.5 * cos(a), pos.dy + 1.5 * sin(a)),
            Offset(pos.dx + 4.5 * cos(a), pos.dy + 4.5 * sin(a)),
            Paint()..color = kIndigo.withValues(alpha: 0.65)..strokeWidth = 0.9,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(TesbihPainter old) => old.t != t || old.isPlaying != isPlaying;
}
