import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class ManuscriptBackgroundPainter extends CustomPainter {
  final double t;
  const ManuscriptBackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = kBg,
    );
    _drawStarGrid(canvas, size);
    _drawTezhipMarginBands(canvas, size);
    _drawCornerRosettes(canvas, size);
  }

  void _drawStarGrid(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = kGold.withValues(alpha: 0.038 + 0.008 * t)
      ..strokeWidth = 0.6;
    final starPaint = Paint()
      ..color = kGold.withValues(alpha: 0.065 + 0.015 * t)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    final indigoPaint = Paint()
      ..color = kIndigo.withValues(alpha: 0.035 + 0.008 * t)
      ..style = PaintingStyle.fill;

    const step = 54.0;
    final cols = (size.width / step).ceil() + 2;
    final rows = (size.height / step).ceil() + 2;
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * step + (row.isOdd ? step / 2 : 0);
        final cy = row * step * 0.866;
        canvas.drawLine(Offset(cx, cy), Offset(cx + step, cy), linePaint);
        canvas.drawLine(Offset(cx, cy), Offset(cx + step / 2, cy + step * 0.433), linePaint);
        canvas.drawLine(Offset(cx, cy), Offset(cx - step / 2, cy + step * 0.433), linePaint);
        _drawStar(canvas, Offset(cx, cy), step * 0.20, starPaint, indigoPaint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint stroke, Paint fill) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a = i * pi / 8 - pi / 2;
      final radius = i.isEven ? r : r * 0.42;
      final pt = Offset(c.dx + radius * cos(a), c.dy + radius * sin(a));
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

  void _drawTezhipMarginBands(Canvas canvas, Size size) {
    const bandW = 22.0;
    final pulse = 0.55 + 0.12 * t;

    final stemPaint = Paint()
      ..color = kGold.withValues(alpha: pulse * 0.38)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final leafFill = Paint()
      ..color = kGold.withValues(alpha: pulse * 0.18)
      ..style = PaintingStyle.fill;
    final indigoFill = Paint()
      ..color = kIndigo.withValues(alpha: pulse * 0.18)
      ..style = PaintingStyle.fill;

    _drawVerticalHatai(canvas, 0, bandW, size.height, stemPaint, leafFill, indigoFill);
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    _drawVerticalHatai(canvas, 0, bandW, size.height, stemPaint, leafFill, indigoFill);
    canvas.restore();

    final borderPaint = Paint()
      ..color = kGold.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(bandW, 0), Offset(bandW, size.height), borderPaint);
    canvas.drawLine(
      Offset(size.width - bandW, 0),
      Offset(size.width - bandW, size.height),
      borderPaint,
    );
  }

  void _drawVerticalHatai(Canvas canvas, double x, double w, double h,
      Paint stem, Paint leaf, Paint indigoFill) {
    final cx = x + w / 2;
    const unit = 30.0;
    final count = (h / unit).ceil() + 1;

    final path = Path()..moveTo(cx, 0);
    for (int i = 0; i < count; i++) {
      final y = i * unit.toDouble();
      final flip = i.isEven ? 1.0 : -1.0;
      path.cubicTo(
        cx + flip * w * 0.4, y + unit * 0.25,
        cx - flip * w * 0.4, y + unit * 0.75,
        cx, y + unit,
      );
    }
    canvas.drawPath(path, stem);

    for (int i = 0; i < count; i++) {
      final y = i * unit + unit * 0.5;
      final flip = i.isEven ? 1.0 : -1.0;
      final lx = cx + flip * w * 0.38;
      final paint = i.isEven ? leaf : indigoFill;
      _drawPetal(canvas, Offset(lx, y), flip * pi / 2, 5.5, paint);
      canvas.drawCircle(Offset(cx, y), 1.8, leaf);
    }
  }

  void _drawPetal(Canvas canvas, Offset c, double angle, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx + r * cos(angle), c.dy + r * sin(angle))
      ..quadraticBezierTo(
        c.dx + r * 0.6 * cos(angle + pi / 2),
        c.dy + r * 0.6 * sin(angle + pi / 2),
        c.dx - r * 0.5 * cos(angle),
        c.dy - r * 0.5 * sin(angle),
      )
      ..quadraticBezierTo(
        c.dx + r * 0.6 * cos(angle - pi / 2),
        c.dy + r * 0.6 * sin(angle - pi / 2),
        c.dx + r * cos(angle),
        c.dy + r * sin(angle),
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawCornerRosettes(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.1 * t;
    final outer = Paint()
      ..color = kGold.withValues(alpha: pulse * 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = kGold.withValues(alpha: pulse * 0.07);
    final ifill = Paint()..color = kIndigo.withValues(alpha: pulse * 0.08);

    for (final c in [
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      const R = 72.0;
      canvas.drawCircle(c, R, outer);
      for (int i = 0; i < 8; i++) {
        final a = i * pi / 4;
        final cc = Offset(c.dx + R * 0.5 * cos(a), c.dy + R * 0.5 * sin(a));
        canvas.drawCircle(cc, R * 0.5, outer);
        canvas.drawCircle(cc, R * 0.5, i.isEven ? fill : ifill);
      }
      _drawStar(canvas, c, R * 0.25, outer, ifill);
    }
  }

  @override
  bool shouldRepaint(ManuscriptBackgroundPainter old) => old.t != t;
}
