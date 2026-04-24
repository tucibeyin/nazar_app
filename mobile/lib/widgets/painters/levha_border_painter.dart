import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class LevhaBorderPainter extends CustomPainter {
  const LevhaBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const m = 4.0; const m2 = 10.0; const cr = 17.0; const cr2 = 13.0;
    final outer = Paint()
      ..color = kGold.withValues(alpha: 0.65)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final inner = Paint()
      ..color = kIndigo.withValues(alpha: 0.22)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final mid = Paint()
      ..color = kGold.withValues(alpha: 0.20)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(m, m, size.width - 2 * m, size.height - 2 * m),
        const Radius.circular(cr),
      ),
      outer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(m2, m2, size.width - 2 * m2, size.height - 2 * m2),
        const Radius.circular(cr2),
      ),
      inner,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (m + m2) / 2, (m + m2) / 2,
          size.width - (m + m2), size.height - (m + m2),
        ),
        const Radius.circular((cr + cr2) / 2),
      ),
      mid,
    );

    for (final (cx, cy) in [
      (m + cr, m + cr),
      (size.width - m - cr, m + cr),
      (m + cr, size.height - m - cr),
      (size.width - m - cr, size.height - m - cr),
    ]) {
      final c = Offset(cx, cy);
      canvas.drawCircle(c, 8, outer);
      canvas.drawCircle(c, 3, Paint()..color = kIndigo.withValues(alpha: 0.55));
      canvas.drawCircle(c, 1.5, Paint()..color = kGold.withValues(alpha: 0.85));
      for (int i = 0; i < 8; i++) {
        final a = i * pi / 4;
        canvas.drawLine(
          Offset(c.dx + 3.5 * cos(a), c.dy + 3.5 * sin(a)),
          Offset(c.dx + 8 * cos(a), c.dy + 8 * sin(a)),
          outer,
        );
      }
    }

    _drawLeafRow(canvas, size, outer);
  }

  void _drawLeafRow(Canvas canvas, Size size, Paint paint) {
    const spacing = 20.0;
    final count = (size.width / spacing).floor();
    for (int i = 2; i < count - 1; i++) {
      final x = i * spacing;
      _drawLeafMotif(canvas, Offset(x, 7), pi / 2, paint);
      _drawLeafMotif(canvas, Offset(x, size.height - 7), -pi / 2, paint);
    }
  }

  void _drawLeafMotif(Canvas canvas, Offset c, double angle, Paint paint) {
    const len = 3.8; const hw = 2.0;
    final path = Path()
      ..moveTo(c.dx + len * cos(angle), c.dy + len * sin(angle))
      ..quadraticBezierTo(
        c.dx + hw * cos(angle + pi / 2), c.dy + hw * sin(angle + pi / 2),
        c.dx - len * 0.5 * cos(angle), c.dy - len * 0.5 * sin(angle),
      )
      ..quadraticBezierTo(
        c.dx + hw * cos(angle - pi / 2), c.dy + hw * sin(angle - pi / 2),
        c.dx + len * cos(angle), c.dy + len * sin(angle),
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LevhaBorderPainter old) => false;
}
