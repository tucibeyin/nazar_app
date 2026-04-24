import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class FrameCornerPainter extends CustomPainter {
  const FrameCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 24.0;
    for (final (c, xd, yd) in [
      (Offset.zero, 1.0, 1.0),
      (Offset(size.width, 0), -1.0, 1.0),
      (Offset(0, size.height), 1.0, -1.0),
      (Offset(size.width, size.height), -1.0, -1.0),
    ]) {
      final p1 = Paint()
        ..color = kGold.withValues(alpha: 0.8)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(c, Offset(c.dx + arm * xd, c.dy), p1);
      canvas.drawLine(c, Offset(c.dx, c.dy + arm * yd), p1);

      canvas.drawCircle(
        Offset(c.dx + 5.5 * xd, c.dy + 5.5 * yd),
        3.2,
        Paint()..color = kGold,
      );
      canvas.drawCircle(
        Offset(c.dx + 5.5 * xd, c.dy + 5.5 * yd),
        1.4,
        Paint()..color = kIndigo.withValues(alpha: 0.7),
      );

      final p2 = Paint()
        ..color = kGold.withValues(alpha: 0.38)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(c.dx + 7 * xd, c.dy + 7 * yd),
        Offset(c.dx + 15 * xd, c.dy + 7 * yd),
        p2,
      );
      canvas.drawLine(
        Offset(c.dx + 7 * xd, c.dy + 7 * yd),
        Offset(c.dx + 7 * xd, c.dy + 15 * yd),
        p2,
      );
    }
  }

  @override
  bool shouldRepaint(FrameCornerPainter old) => false;
}
