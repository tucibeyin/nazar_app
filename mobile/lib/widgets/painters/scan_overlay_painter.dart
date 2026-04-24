import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class ScanOverlayPainter extends CustomPainter {
  final double t;
  const ScanOverlayPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const teal = Color(0xFF3DB88A);
    final progress = (t * 2.2) % 1.0;
    final scanY = progress * size.height;
    final fade = sin(progress * pi).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.width / 2, scanY), width: size.width, height: 28),
      Paint()
        ..color = teal.withValues(alpha: fade * 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      Paint()..color = teal.withValues(alpha: fade * 0.72)..strokeWidth = 1.4,
    );

    final bp = Paint()
      ..color = kGold.withValues(alpha: 0.68)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final m = size.width * 0.10;
    final l = size.width * 0.07;
    for (final (c, xd, yd) in [
      (Offset(m, m), 1.0, 1.0),
      (Offset(size.width - m, m), -1.0, 1.0),
      (Offset(m, size.height - m), 1.0, -1.0),
      (Offset(size.width - m, size.height - m), -1.0, -1.0),
    ]) {
      canvas.drawLine(c, Offset(c.dx + l * xd, c.dy), bp);
      canvas.drawLine(c, Offset(c.dx, c.dy + l * yd), bp);
    }
  }

  @override
  bool shouldRepaint(ScanOverlayPainter old) => old.t != t;
}
