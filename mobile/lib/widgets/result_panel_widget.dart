import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkPanel : kParchment;
    final shadowColor = isDark ? kGold.withValues(alpha: 0.10) : kGreen.withValues(alpha: 0.12);
    final glowColor = isDark ? kGold.withValues(alpha: 0.22) : kGold.withValues(alpha: 0.18);

    return TweenAnimationBuilder<double>(
      key: ValueKey(ayet.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: v,
          child: Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: child,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kScreenPaddingH, 4, kScreenPaddingH, 8),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(isDark),
                  _buildContent(isDark),
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

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? kDarkSubtext : kGold.withValues(alpha: 0.92);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
      child: SizedBox(
        height: 42,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: LevhaHeaderPainter())),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ayet.sureIsim,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
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

  Widget _buildContent(bool isDark) {
    final arabicColor = isDark ? kDarkText : const Color(0xFF1A1A1A);
    final mealColor = isDark ? kDarkText.withValues(alpha: 0.88) : const Color(0xFF3D3420);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ayet.arapca,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.amiri(
              fontSize: 25,
              height: 2.4,
              color: arabicColor,
              fontWeight: FontWeight.w700,
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
            style: GoogleFonts.cormorantGaramond(
              fontSize: 15,
              height: 1.85,
              color: mealColor,
              fontWeight: FontWeight.w500,
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
