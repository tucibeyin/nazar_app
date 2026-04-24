import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class TezhipBandPainter extends CustomPainter {
  final bool isTop;
  const TezhipBandPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isTop) {
      canvas.save();
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = kGreen,
    );

    final borderLine = Paint()
      ..color = kGold.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), borderLine);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      borderLine,
    );

    final innerLine = Paint()
      ..color = kGold.withValues(alpha: 0.35)
      ..strokeWidth = 0.7;
    canvas.drawLine(const Offset(0, 3.5), Offset(size.width, 3.5), innerLine);
    canvas.drawLine(
      Offset(0, size.height - 3.5),
      Offset(size.width, size.height - 3.5),
      innerLine,
    );

    final cy = size.height / 2;
    const unit = 18.0;
    final count = (size.width / unit).ceil() + 2;
    final lotusF = Paint()
      ..color = kGold.withValues(alpha: 0.52)
      ..style = PaintingStyle.fill;
    final lotusS = Paint()
      ..color = kGold.withValues(alpha: 0.75)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    final indigoF = Paint()
      ..color = kIndigo.withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;

    final mcx = size.width / 2;
    _drawUnvanMedallion(canvas, Offset(mcx, cy), size.height * 0.36, lotusF, lotusS);

    for (int i = 0; i < count; i++) {
      final x = i * unit - unit / 2;
      if ((x - mcx).abs() < 32) continue;

      if (i.isEven) {
        _drawLotus(canvas, Offset(x, cy - 2), size.height * 0.28, lotusF, lotusS);
      } else {
        _drawRumi(canvas, Offset(x, cy + 2), size.height * 0.26, indigoF, lotusS);
      }
      canvas.drawCircle(Offset(x, cy), 1.5, lotusF);
    }

    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()..color = kGold.withValues(alpha: 0.20)..strokeWidth = 0.6,
    );

    if (!isTop) canvas.restore();
  }

  void _drawUnvanMedallion(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 3.4, height: r * 2),
      Paint()..color = kGold.withValues(alpha: 0.18),
    );
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 3.4, height: r * 2), stroke);
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 2.8, height: r * 1.4), stroke);
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      canvas.drawLine(
        Offset(c.dx + r * 0.3 * cos(a), c.dy + r * 0.3 * sin(a)),
        Offset(c.dx + r * 0.7 * cos(a), c.dy + r * 0.7 * sin(a)),
        stroke,
      );
    }
    canvas.drawCircle(c, r * 0.22, fill);
  }

  void _drawLotus(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    for (int i = 0; i < 5; i++) {
      final a = -pi / 2 + (i - 2) * pi / 5;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(
          c.dx + r * 0.55 * cos(a - 0.25), c.dy + r * 0.55 * sin(a - 0.25),
          c.dx + r * 0.85 * cos(a), c.dy + r * 0.85 * sin(a) - r * 0.1,
          c.dx + r * cos(a), c.dy + r * sin(a),
        )
        ..cubicTo(
          c.dx + r * 0.85 * cos(a), c.dy + r * 0.85 * sin(a) + r * 0.1,
          c.dx + r * 0.55 * cos(a + 0.25), c.dy + r * 0.55 * sin(a + 0.25),
          c.dx, c.dy,
        )
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
    canvas.drawCircle(c, r * 0.18, fill);
  }

  void _drawRumi(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    for (final dir in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(
          c.dx + dir * r * 0.5, c.dy + r * 0.2,
          c.dx + dir * r * 0.7, c.dy + r * 0.7,
          c.dx + dir * r * 0.3, c.dy + r,
        )
        ..cubicTo(
          c.dx - dir * r * 0.2, c.dy + r * 0.8,
          c.dx - dir * r * 0.1, c.dy + r * 0.3,
          c.dx, c.dy,
        )
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(TezhipBandPainter old) => false;
}
