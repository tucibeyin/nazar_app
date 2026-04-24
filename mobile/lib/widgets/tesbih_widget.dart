import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import 'painters/painters.dart';

class TesbihWidget extends StatelessWidget {
  final AnimationController controller;
  final bool isPlaying;

  const TesbihWidget({
    super.key,
    required this.controller,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const ValueKey('tesbih'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
        child: SizedBox(
          height: kTesbihH,
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => CustomPaint(
              painter: TesbihPainter(controller.value, isPlaying: isPlaying),
            ),
          ),
        ),
      ),
    );
  }
}
