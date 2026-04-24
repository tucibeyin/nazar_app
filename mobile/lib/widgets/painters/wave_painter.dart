import 'dart:math';

import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final double t;
  final bool isPlaying;
  final double entrance;
  const WavePainter(this.t, {required this.isPlaying, required this.entrance});

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30; const minRatio = 0.03; const maxRatio = 0.72;
    final totalW = size.width * 0.65;
    final barW = totalW / (barCount * 2 - 1);
    final startX = (size.width - totalW) / 2;
    final ec = Curves.elasticOut.transform(entrance.clamp(0.0, 1.0));

    for (int i = 0; i < barCount; i++) {
      final pct = i / (barCount - 1);
      final phase = pct * 2 * pi;
      final w1 = sin(t * 2 * pi * 2.2 + phase);
      final w2 = sin(t * 2 * pi * 3.5 + phase * 1.4 + 1.0);
      final combined = (w1 * 0.6 + w2 * 0.4).abs();
      final minH = size.height * minRatio;
      final maxH = size.height * maxRatio * ec;
      final barH = isPlaying ? minH + combined * (maxH - minH) : minH + 2;
      final envelope = sin(pct * pi);
      final color = Color.lerp(
        const Color(0xFF2E8B6E),
        const Color(0xFF7FFFD4),
        envelope * combined,
      )!.withValues(alpha: 0.75 + envelope * 0.25);
      final x = startX + i * (barW + barW) + barW / 2;
      canvas.drawLine(
        Offset(x, (size.height - barH) / 2),
        Offset(x, (size.height + barH) / 2),
        Paint()..color = color..strokeWidth = barW..strokeCap = StrokeCap.round,
      );
    }

    if (isPlaying && entrance > 0.8) {
      final glow = Paint()
        ..color = const Color(0xFF7FFFD4).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (int i = 0; i < barCount; i += 3) {
        final pct = i / (barCount - 1);
        final phase = pct * 2 * pi;
        final combined = (sin(t * 2 * pi * 2.2 + phase) * 0.6 + sin(t * 2 * pi * 3.5 + phase * 1.4 + 1.0) * 0.4).abs();
        if (combined < 0.5) continue;
        final x = startX + i * (barW + barW) + barW / 2;
        canvas.drawCircle(
          Offset(x, (size.height - combined * size.height * maxRatio * ec) / 2),
          6,
          glow,
        );
      }
    }
  }

  @override
  bool shouldRepaint(WavePainter old) =>
      old.t != t || old.isPlaying != isPlaying || old.entrance != entrance;
}
