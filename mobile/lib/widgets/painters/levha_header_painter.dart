import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class LevhaHeaderPainter extends CustomPainter {
  const LevhaHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = kGreen,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 3, size.width, 1.5),
      Paint()..color = kGold.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1.5, size.width, 1.5),
      Paint()..color = kIndigo.withValues(alpha: 0.45),
    );

    final cy = size.height / 2 - 1;
    const unit = 20.0;
    final count = (size.width / unit).ceil() + 1;
    final gf = Paint()
      ..color = kGold.withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    final gs = Paint()
      ..color = kGold.withValues(alpha: 0.55)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < count; i++) {
      final x = i * unit;
      _drawSmallLotus(canvas, Offset(x, cy), size.height * 0.28, gf, gs);
    }

    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()..color = kGold.withValues(alpha: 0.18)..strokeWidth = 0.5,
    );
  }

  void _drawSmallLotus(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    for (int i = 0; i < 3; i++) {
      final a = -pi / 2 + (i - 1) * pi / 3.5;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(
          c.dx + r * 0.5 * cos(a - 0.3), c.dy + r * 0.5 * sin(a - 0.3),
          c.dx + r * cos(a), c.dy + r * sin(a),
          c.dx + r * cos(a), c.dy + r * sin(a),
        )
        ..cubicTo(
          c.dx + r * cos(a), c.dy + r * sin(a),
          c.dx + r * 0.5 * cos(a + 0.3), c.dy + r * 0.5 * sin(a + 0.3),
          c.dx, c.dy,
        )
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(LevhaHeaderPainter old) => false;
}
