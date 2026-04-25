import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class MedallionFramePainter extends CustomPainter {
  final double t;
  const MedallionFramePainter({this.t = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy);
    final pulse = 0.75 + 0.25 * sin(t * 2 * pi);

    // Three concentric rings
    _ring(canvas, Offset(cx, cy), r - 1.0, 2.4, kGold.withValues(alpha: 0.92 * pulse));
    _ring(canvas, Offset(cx, cy), r - 7.0, 1.2, kGold.withValues(alpha: 0.60 * pulse));
    _ring(canvas, Offset(cx, cy), r - 11.5, 0.7, kGold.withValues(alpha: 0.38 * pulse));

    // 8 star-petal ornaments on outer ring
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final pt = Offset(cx + (r - 4) * cos(a), cy + (r - 4) * sin(a));
      _starKnot(canvas, pt, 5.5, pulse);
    }

    // 16 small dot accents between stars
    for (int i = 0; i < 16; i++) {
      final a = i * pi / 8 + pi / 16;
      final pt = Offset(cx + (r - 5.5) * cos(a), cy + (r - 5.5) * sin(a));
      canvas.drawCircle(
        pt,
        1.4,
        Paint()
          ..color = kGold.withValues(alpha: 0.55 * pulse)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _ring(Canvas canvas, Offset c, double r, double w, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color
        ..strokeWidth = w
        ..style = PaintingStyle.stroke,
    );
  }

  void _starKnot(Canvas canvas, Offset c, double r, double pulse) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a = i * pi / 8;
      final radius = i.isEven ? r : r * 0.44;
      final pt = Offset(c.dx + radius * cos(a), c.dy + radius * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = kGold.withValues(alpha: 0.22 * pulse)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = kGold.withValues(alpha: 0.82 * pulse)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(MedallionFramePainter old) => old.t != t;
}
