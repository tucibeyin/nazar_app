import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class MysticPainter extends CustomPainter {
  final double t;
  const MysticPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final maxR = min(cx, cy) * 0.88;
    _drawLightBeams(canvas, center, maxR, t * 2 * pi * 0.12);
    _drawOrbitDots(canvas, center, maxR * 0.88, -t * 2 * pi * 0.25, 16);
    _drawArabesqueRing(canvas, center, maxR * 0.66, t * 2 * pi * 0.18);
    _drawStar(canvas, center, maxR * 0.44, maxR * 0.19, -t * 2 * pi * 0.45, filled: false);
    _drawStar(canvas, center, maxR * 0.23, maxR * 0.10, t * 2 * pi * 0.9, filled: true);
    _drawCenter(canvas, center, maxR);
  }

  void _drawLightBeams(Canvas canvas, Offset c, double r, double rot) {
    for (int i = 0; i < 8; i++) {
      final a = rot + i * pi / 4;
      final alpha = 0.035 + 0.025 * sin(t * 2 * pi + i * pi / 4).abs();
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + r * cos(a - 0.13), c.dy + r * sin(a - 0.13))
          ..lineTo(c.dx + r * cos(a + 0.13), c.dy + r * sin(a + 0.13))
          ..close(),
        Paint()..color = kGold.withValues(alpha: alpha),
      );
    }
  }

  void _drawOrbitDots(Canvas canvas, Offset c, double r, double rot, int count) {
    for (int i = 0; i < count; i++) {
      final a = rot + i * 2 * pi / count;
      final large = i.isEven;
      final pulse = large ? 1.0 + 0.2 * sin(t * 2 * pi * 2 + i * 0.8) : 1.0;
      canvas.drawCircle(
        Offset(c.dx + r * cos(a), c.dy + r * sin(a)),
        (large ? 3.2 : 1.8) * pulse,
        Paint()..color = (large ? kGold : kIndigo).withValues(alpha: large ? 0.85 : 0.55),
      );
    }
  }

  void _drawArabesqueRing(Canvas canvas, Offset c, double r, double rot) {
    const teal = Color(0xFF3DB88A);
    canvas.drawCircle(
      c, r,
      Paint()..color = teal.withValues(alpha: 0.12)..strokeWidth = 1.0..style = PaintingStyle.stroke,
    );
    final sp = Paint()
      ..color = teal.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final a = rot + i * pi / 4;
      final dc = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      final s = r * 0.14;
      canvas.drawPath(
        Path()
          ..moveTo(dc.dx + s * cos(a), dc.dy + s * sin(a))
          ..lineTo(dc.dx + s * cos(a + pi / 2) * 0.55, dc.dy + s * sin(a + pi / 2) * 0.55)
          ..lineTo(dc.dx - s * cos(a), dc.dy - s * sin(a))
          ..lineTo(dc.dx - s * cos(a + pi / 2) * 0.55, dc.dy - s * sin(a + pi / 2) * 0.55)
          ..close(),
        sp,
      );
    }
  }

  void _drawStar(Canvas canvas, Offset c, double outerR, double innerR, double rot, {required bool filled}) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a = rot + i * pi / 8 - pi / 2;
      final r = i.isEven ? outerR : innerR;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    if (filled) {
      canvas.drawPath(path, Paint()..color = kGold.withValues(alpha: 0.88));
      canvas.drawPath(
        path,
        Paint()
          ..color = kGold.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    } else {
      canvas.drawPath(
        path,
        Paint()..color = kGold.withValues(alpha: 0.65)..strokeWidth = 1.5..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawCenter(Canvas canvas, Offset c, double maxR) {
    final pulse = 0.82 + 0.18 * sin(t * 2 * pi * 2.5);
    canvas.drawCircle(
      c, maxR * 0.14 * pulse,
      Paint()
        ..color = kGold.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(c, maxR * 0.075 * pulse, Paint()..color = kGold.withValues(alpha: 0.9));
    canvas.drawCircle(c, maxR * 0.028, Paint()..color = const Color(0xFFE8D5A3));
  }

  @override
  bool shouldRepaint(MysticPainter old) => old.t != t;
}
