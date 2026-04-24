import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class UnvanDividerPainter extends CustomPainter {
  const UnvanDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final lp = Paint()..color = kGold.withValues(alpha: 0.55)..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, cy), Offset(cx - 22, cy), lp);
    canvas.drawLine(Offset(cx + 22, cy), Offset(size.width, cy), lp);

    final lp2 = Paint()..color = kGold.withValues(alpha: 0.22)..strokeWidth = 0.6;
    canvas.drawLine(Offset(0, cy - 3), Offset(cx - 22, cy - 3), lp2);
    canvas.drawLine(Offset(cx + 22, cy - 3), Offset(size.width, cy - 3), lp2);
    canvas.drawLine(Offset(0, cy + 3), Offset(cx + 22, cy + 3), lp2);
    canvas.drawLine(Offset(cx + 22, cy + 3), Offset(size.width, cy + 3), lp2);

    final diamond = Path()
      ..moveTo(cx, cy - 6)
      ..lineTo(cx + 10, cy)
      ..lineTo(cx, cy + 6)
      ..lineTo(cx - 10, cy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = kGold.withValues(alpha: 0.65));
    canvas.drawPath(
      diamond,
      Paint()..color = kGreen.withValues(alpha: 0.4)..strokeWidth = 0.8..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = kIndigo.withValues(alpha: 0.8));

    for (final dx in [-16.0, 16.0]) {
      canvas.drawCircle(Offset(cx + dx, cy), 2.0, Paint()..color = kGold.withValues(alpha: 0.70));
    }
    for (final dx in [-27.0, 27.0]) {
      canvas.drawCircle(Offset(cx + dx, cy), 1.4, Paint()..color = kGold.withValues(alpha: 0.45));
    }
  }

  @override
  bool shouldRepaint(UnvanDividerPainter old) => false;
}
