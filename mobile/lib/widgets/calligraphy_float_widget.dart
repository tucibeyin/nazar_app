import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';

const _esmaWords = [
  'اَللّٰهُ',
  'الرَّحْمَٰنُ',
  'الرَّحِيمُ',
  'السَّلَامُ',
  'النُّورُ',
  'الْحَكِيمُ',
  'الْكَرِيمُ',
];

class CalligraphyFloatWidget extends StatefulWidget {
  const CalligraphyFloatWidget({super.key});

  @override
  State<CalligraphyFloatWidget> createState() => _CalligraphyFloatWidgetState();
}

class _CalligraphyFloatWidgetState extends State<CalligraphyFloatWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_WordConfig> _configs;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
    final rng = Random(7);
    _configs = List.generate(_esmaWords.length, (i) => _WordConfig(
      word: _esmaWords[i],
      phaseOffset: i / _esmaWords.length,
      xFraction: 0.08 + rng.nextDouble() * 0.70,
      fontSize: 14.0 + rng.nextDouble() * 8.0,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => LayoutBuilder(
        builder: (_, constraints) => Stack(
          children: _configs.map((cfg) {
            final t = (_ctrl.value + cfg.phaseOffset) % 1.0;
            final opacity = t < 0.15
                ? t / 0.15
                : t > 0.82
                    ? (1.0 - (t - 0.82) / 0.18)
                    : 1.0;
            final yFraction = (0.88 - t * 0.68).clamp(0.0, 1.0);
            return Positioned(
              left: cfg.xFraction * constraints.maxWidth - 32,
              top: yFraction * constraints.maxHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Text(
                    cfg.word,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.amiri(
                      fontSize: cfg.fontSize,
                      color: kGold.withValues(alpha: 0.90),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _WordConfig {
  final String word;
  final double phaseOffset;
  final double xFraction;
  final double fontSize;

  const _WordConfig({
    required this.word,
    required this.phaseOffset,
    required this.xFraction,
    required this.fontSize,
  });
}
