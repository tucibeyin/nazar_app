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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUnvan(isDark),
            _buildPanel(isDark),
          ],
        ),
      ),
    );
  }

  // ── Unvan: sure adı başlık şeridi ─────────────────────────────────────────

  Widget _buildUnvan(bool isDark) {
    final bg = isDark ? const Color(0xFF0A2416) : kGreen;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: BorderSide(color: kGold.withValues(alpha: 0.65), width: 1.5),
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: LevhaHeaderPainter(drawBackground: false),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  const SizedBox(width: 38),
                  Expanded(
                    child: Text(
                      ayet.sureIsim,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kGold,
                        letterSpacing: 1.4,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: GestureDetector(
                      onTap: onToggleAudio,
                      child: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: kGold,
                        size: 36,
                      ),
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

  // ── İçerik paneli (LevhaBorderPainter artık sure ismiyle çakışmaz) ────────

  Widget _buildPanel(bool isDark) {
    final bgColor = isDark ? kDarkPanel : kParchment;
    final shadowColor =
        isDark ? kGold.withValues(alpha: 0.10) : kGreen.withValues(alpha: 0.12);
    final glowColor =
        isDark ? kGold.withValues(alpha: 0.22) : kGold.withValues(alpha: 0.18);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(18)),
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
          child: _buildContent(isDark),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: LevhaBorderPainter()),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(bool isDark) {
    final arabicColor = isDark ? kDarkText : const Color(0xFF1A1A1A);
    final mealColor = isDark
        ? kDarkText.withValues(alpha: 0.88)
        : const Color(0xFF3D3420);

    return Padding(
      // top=32: LevhaBorderPainter köşe süsü y=29'a kadar uzanır, metni geçiyor
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
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
