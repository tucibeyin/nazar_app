import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../models/ayet.dart';
import 'painters/painters.dart';

class ResultPanelWidget extends StatelessWidget {
  final Ayet ayet;
  final bool isPlaying;
  final VoidCallback onToggleAudio;

  const ResultPanelWidget({
    super.key,
    required this.ayet,
    required this.isPlaying,
    required this.onToggleAudio,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(ayet.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kScreenPaddingH, 4, kScreenPaddingH, 8,
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: kParchment,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: kGreen.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: kGold.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  _buildContent(),
                ],
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: LevhaBorderPainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
      child: SizedBox(
        height: 42,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: LevhaHeaderPainter()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ayet.sureIsim,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kGold.withValues(alpha: 0.92),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleAudio,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: kGold,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ayet.arapca,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 24,
              height: 2.4,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: CustomPaint(
              size: Size(double.infinity, 14),
              painter: UnvanDividerPainter(),
            ),
          ),
          Text(
            ayet.meal,
            style: const TextStyle(
              fontSize: 14,
              height: 1.85,
              color: Color(0xFF3D3420),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: CustomPaint(size: Size(80, 14), painter: HatimePainter()),
          ),
        ],
      ),
    );
  }
}
