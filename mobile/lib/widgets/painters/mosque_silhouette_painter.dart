import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class MosqueSilhouettePainter extends CustomPainter {
  const MosqueSilhouettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = kGreen.withValues(alpha: 0.11)
      ..style = PaintingStyle.fill;
    final wallY = h * 0.48;

    final lmCx = w * 0.09; final lmHw = w * 0.025; final lmTop = h * 0.03;
    final ldCx = w * 0.24; final ldR  = w * 0.082;
    final cdCx = w * 0.50; final cdR  = w * 0.165;
    final rdCx = w * 0.76; final rdR  = w * 0.082;
    final rmCx = w * 0.91; final rmHw = w * 0.025; final rmTop = h * 0.03;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, wallY)
      ..lineTo(lmCx - lmHw, wallY)
      ..lineTo(lmCx - lmHw, lmTop + 8)
      ..quadraticBezierTo(lmCx - lmHw, lmTop, lmCx, lmTop - 5)
      ..quadraticBezierTo(lmCx + lmHw, lmTop, lmCx + lmHw, lmTop + 8)
      ..lineTo(lmCx + lmHw, wallY)
      ..lineTo(ldCx - ldR, wallY)
      ..arcToPoint(Offset(ldCx + ldR, wallY), radius: Radius.circular(ldR), clockwise: false)
      ..lineTo(cdCx - cdR, wallY)
      ..arcToPoint(Offset(cdCx + cdR, wallY), radius: Radius.circular(cdR), clockwise: false)
      ..lineTo(rdCx - rdR, wallY)
      ..arcToPoint(Offset(rdCx + rdR, wallY), radius: Radius.circular(rdR), clockwise: false)
      ..lineTo(rmCx - rmHw, wallY)
      ..lineTo(rmCx - rmHw, rmTop + 8)
      ..quadraticBezierTo(rmCx - rmHw, rmTop, rmCx, rmTop - 5)
      ..quadraticBezierTo(rmCx + rmHw, rmTop, rmCx + rmHw, rmTop + 8)
      ..lineTo(rmCx + rmHw, wallY)
      ..lineTo(w, wallY)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(path, paint);
    _drawCrescent(canvas, Offset(lmCx, lmTop - 8), h * 0.032);
    _drawCrescent(canvas, Offset(rmCx, rmTop - 8), h * 0.032);
    _drawCrescent(canvas, Offset(cdCx, wallY - cdR - h * 0.04), h * 0.050);
  }

  void _drawCrescent(Canvas canvas, Offset c, double r) {
    final p = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final p2 = Path()..addOval(
      Rect.fromCircle(center: Offset(c.dx + r * 0.38, c.dy), radius: r * 0.78),
    );
    canvas.drawPath(
      Path.combine(PathOperation.difference, p, p2),
      Paint()..color = kGreen.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(MosqueSilhouettePainter old) => false;
}
