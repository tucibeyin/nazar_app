import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class ShemseBackgroundPainter extends CustomPainter {
  const ShemseBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final c = Offset(cx, cy);
    final maxR = min(cx, cy) * 0.92;

    final goldStroke = Paint()
      ..color = kGold.withValues(alpha: 0.07)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final goldFill = Paint()
      ..color = kGold.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    final indigoS = Paint()
      ..color = kIndigo.withValues(alpha: 0.06)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(c, maxR, goldStroke);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(
        Offset(cx + maxR * 0.88 * cos(a), cy + maxR * 0.88 * sin(a)),
        Offset(cx + maxR * cos(a), cy + maxR * sin(a)),
        goldStroke,
      );
    }

    for (int i = 0; i < 16; i++) {
      final a = i * 2 * pi / 16;
      canvas.drawCircle(
        Offset(cx + maxR * 0.75 * cos(a), cy + maxR * 0.75 * sin(a)),
        3.0,
        i.isEven ? goldFill : (Paint()..color = kIndigo.withValues(alpha: 0.06)),
      );
    }
    canvas.drawCircle(c, maxR * 0.75, goldStroke);

    canvas.drawCircle(c, maxR * 0.58, indigoS);
    for (int i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final dc = Offset(cx + maxR * 0.58 * cos(a), cy + maxR * 0.58 * sin(a));
      final s = maxR * 0.055;
      final path = Path()
        ..moveTo(dc.dx + s * cos(a), dc.dy + s * sin(a))
        ..lineTo(dc.dx + s * cos(a + pi / 2) * 0.5, dc.dy + s * sin(a + pi / 2) * 0.5)
        ..lineTo(dc.dx - s * cos(a), dc.dy - s * sin(a))
        ..lineTo(dc.dx - s * cos(a + pi / 2) * 0.5, dc.dy - s * sin(a + pi / 2) * 0.5)
        ..close();
      canvas.drawPath(path, goldFill);
      canvas.drawPath(path, goldStroke);
    }

    _drawShemse(canvas, c, maxR * 0.42, maxR * 0.18, goldStroke, goldFill);
    _drawShemse(
      canvas, c, maxR * 0.24, maxR * 0.10,
      Paint()..color = kIndigo.withValues(alpha: 0.07)..strokeWidth = 1.0..style = PaintingStyle.stroke,
      Paint()..color = kIndigo.withValues(alpha: 0.055),
    );

    canvas.drawCircle(
      c, maxR * 0.08,
      Paint()
        ..color = kGold.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(c, maxR * 0.04, goldFill);
  }

  void _drawShemse(Canvas canvas, Offset c, double outerR, double innerR, Paint stroke, Paint fill) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a = i * pi / 8 - pi / 2;
      final r = i.isEven ? outerR : innerR;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(ShemseBackgroundPainter old) => false;
}
