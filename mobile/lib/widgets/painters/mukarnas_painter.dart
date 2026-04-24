import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class MukarnasPainter extends CustomPainter {
  final bool isTop;
  const MukarnasPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (!isTop) {
      canvas.save();
      canvas.translate(0, h);
      canvas.scale(1, -1);
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = kBg);

    const niches = 7;
    final nw = w / niches;
    for (int i = 0; i < niches; i++) {
      _drawNiche(canvas, i * nw, nw, h);
    }

    canvas.drawLine(
      const Offset(0, 1), Offset(w, 1),
      Paint()..color = kGold.withValues(alpha: 0.75)..strokeWidth = 1.3,
    );
    canvas.drawLine(
      const Offset(0, 4), Offset(w, 4),
      Paint()..color = kGold.withValues(alpha: 0.30)..strokeWidth = 0.7,
    );

    _drawMiniRosette(canvas, Offset(w / 2, h * 0.38), h * 0.22);

    if (!isTop) canvas.restore();
  }

  void _drawNiche(Canvas canvas, double x, double nw, double h) {
    final cx = x + nw / 2;
    final archW = nw * 0.88;

    final gradRect = Rect.fromLTWH(cx - archW / 2, 0, archW, h);
    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kGold.withValues(alpha: 0.18), kGold.withValues(alpha: 0.05)],
      ).createShader(gradRect)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(cx - archW / 2, h)
      ..quadraticBezierTo(cx - archW / 2, h * 0.15, cx, h * 0.04)
      ..quadraticBezierTo(cx + archW / 2, h * 0.15, cx + archW / 2, h)
      ..close();
    canvas.drawPath(path, gradPaint);
    canvas.drawPath(
      path,
      Paint()..color = kGold.withValues(alpha: 0.70)..strokeWidth = 1.2..style = PaintingStyle.stroke,
    );

    final iw = archW * 0.60;
    final innerPath = Path()
      ..moveTo(cx - iw / 2, h)
      ..quadraticBezierTo(cx - iw / 2, h * 0.28, cx, h * 0.16)
      ..quadraticBezierTo(cx + iw / 2, h * 0.28, cx + iw / 2, h);
    canvas.drawPath(
      innerPath,
      Paint()..color = kIndigo.withValues(alpha: 0.40)..strokeWidth = 0.8..style = PaintingStyle.stroke,
    );

    _drawKeystoneFlower(canvas, Offset(cx, h * 0.09), h * 0.055);

    canvas.drawLine(
      Offset(x, h - 1), Offset(x + nw, h - 1),
      Paint()..color = kGold.withValues(alpha: 0.22)..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(x, 0), Offset(x, h),
      Paint()..color = kGold.withValues(alpha: 0.55)..strokeWidth = 1.0,
    );
  }

  void _drawKeystoneFlower(Canvas canvas, Offset c, double r) {
    final fillPaint = Paint()..color = kGold.withValues(alpha: 0.75);
    final strokeP = Paint()
      ..color = kGold.withValues(alpha: 0.90)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(
          c.dx + r * 0.5 * cos(a - 0.4), c.dy + r * 0.5 * sin(a - 0.4),
          c.dx + r * cos(a), c.dy + r * sin(a) - r * 0.1,
          c.dx + r * cos(a), c.dy + r * sin(a),
        )
        ..cubicTo(
          c.dx + r * cos(a), c.dy + r * sin(a) + r * 0.1,
          c.dx + r * 0.5 * cos(a + 0.4), c.dy + r * 0.5 * sin(a + 0.4),
          c.dx, c.dy,
        )
        ..close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokeP);
    }
    canvas.drawCircle(c, r * 0.2, Paint()..color = kGold);
  }

  void _drawMiniRosette(Canvas canvas, Offset c, double r) {
    final p = Paint()
      ..color = kGold.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(c, r * 0.45, p);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(c, Offset(c.dx + r * cos(a), c.dy + r * sin(a)), p);
    }
    canvas.drawCircle(c, r * 0.16, Paint()..color = kGold.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(MukarnasPainter old) => false;
}
