import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class HatimePainter extends CustomPainter {
  const HatimePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final gp = Paint()..color = kGold.withValues(alpha: 0.55)..strokeWidth = 0.9..style = PaintingStyle.stroke;
    final gf = Paint()..color = kGold.withValues(alpha: 0.45);
    final ip = Paint()..color = kIndigo.withValues(alpha: 0.50);

    canvas.drawCircle(Offset(cx, cy), 5, gp);
    canvas.drawCircle(Offset(cx, cy), 2, gf);
    canvas.drawCircle(Offset(cx, cy), 1, ip);
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      canvas.drawLine(
        Offset(cx + 2.5 * cos(a), cy + 2.5 * sin(a)),
        Offset(cx + 5 * cos(a), cy + 5 * sin(a)),
        gp,
      );
    }

    for (final dx in [-12.0, -8.0, 8.0, 12.0]) {
      canvas.drawCircle(
        Offset(cx + dx, cy),
        dx.abs() > 10 ? 1.2 : 1.8,
        dx.abs() > 10 ? gf : ip,
      );
    }

    canvas.drawLine(Offset(0, cy), Offset(cx - 14, cy), gp);
    canvas.drawLine(Offset(cx + 14, cy), Offset(size.width, cy), gp);
  }

  @override
  bool shouldRepaint(HatimePainter old) => false;
}
