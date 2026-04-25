import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../widgets/painters/painters.dart';

class SplashScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const SplashScreen({super.key, required this.cameras});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _ambientCtrl;
  late final AnimationController _topBandCtrl;
  late final AnimationController _bottomBandCtrl;
  late final AnimationController _centralCtrl;
  late final AnimationController _subtitleCtrl;
  late final AnimationController _mosqueCtrl;
  late final AnimationController _exitCtrl;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _ambientCtrl    = AnimationController(vsync: this, duration: kAmbientDuration)
      ..repeat(reverse: true);
    _topBandCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _bottomBandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _centralCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
    _subtitleCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _mosqueCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _exitCtrl       = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

    _playEntranceThenExit();
  }

  Future<void> _playEntranceThenExit() async {
    // Bands slide in first — continuous with LaunchScreen bands
    _topBandCtrl.forward();
    _bottomBandCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    // Bismillah scales + fades in
    await _centralCtrl.forward();
    if (!mounted) return;

    // Subtitle, mosque, and loading dots
    _subtitleCtrl.forward();
    _mosqueCtrl.forward();

    // Minimum display time from now
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _navigated) return;
    _navigated = true;

    // Brief pause, dissolve, then navigate
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    await _exitCtrl.forward();
    if (mounted) {
      context.go('/home', extra: widget.cameras);
    }
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _topBandCtrl.dispose();
    _bottomBandCtrl.dispose();
    _centralCtrl.dispose();
    _subtitleCtrl.dispose();
    _mosqueCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topBandCurve    = CurvedAnimation(parent: _topBandCtrl,    curve: Curves.easeOutCubic);
    final bottomBandCurve = CurvedAnimation(parent: _bottomBandCtrl, curve: Curves.easeOutCubic);
    final centralScale = Tween<double>(begin: 0.70, end: 1.0)
        .animate(CurvedAnimation(parent: _centralCtrl, curve: Curves.easeOutBack));
    final centralOpacity  = CurvedAnimation(parent: _centralCtrl,  curve: Curves.easeOut);
    final subtitleOpacity = CurvedAnimation(parent: _subtitleCtrl, curve: Curves.easeOut);
    final mosqueOpacity   = CurvedAnimation(parent: _mosqueCtrl,   curve: Curves.easeOut);
    final exitOpacity     = CurvedAnimation(parent: _exitCtrl,     curve: Curves.easeIn);

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Layer 1: animated parchment background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientCtrl,
              builder: (_, __) => CustomPaint(
                painter: ManuscriptBackgroundPainter(_ambientCtrl.value),
              ),
            ),
          ),

          // Layer 2: mosque silhouette fades in
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: mosqueOpacity,
              builder: (_, __) => Opacity(
                opacity: mosqueOpacity.value,
                child: const CustomPaint(
                  size: Size(double.infinity, kMosqueSilH),
                  painter: MosqueSilhouettePainter(),
                ),
              ),
            ),
          ),

          // Layer 3: top tezhip band slides down
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: topBandCurve,
              builder: (_, __) {
                final v = topBandCurve.value;
                return Transform.translate(
                  offset: Offset(0, -kTezhipBandH * (1 - v)),
                  child: Opacity(
                    opacity: v,
                    child: const CustomPaint(
                      size: Size(double.infinity, kTezhipBandH),
                      painter: TezhipBandPainter(isTop: true),
                    ),
                  ),
                );
              },
            ),
          ),

          // Layer 4: bottom tezhip band slides up
          Positioned(
            bottom: kMosqueSilH, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: bottomBandCurve,
              builder: (_, __) {
                final v = bottomBandCurve.value;
                return Transform.translate(
                  offset: Offset(0, kTezhipBandH * (1 - v)),
                  child: Opacity(
                    opacity: v,
                    child: const CustomPaint(
                      size: Size(double.infinity, kTezhipBandH),
                      painter: TezhipBandPainter(isTop: false),
                    ),
                  ),
                );
              },
            ),
          ),

          // Layer 5: central content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH + 12),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ornamental hatim
                  AnimatedBuilder(
                    animation: centralOpacity,
                    builder: (_, __) => Opacity(
                      opacity: centralOpacity.value,
                      child: const CustomPaint(
                        size: Size(72, 16),
                        painter: HatimePainter(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Bismillah — scale + fade
                  AnimatedBuilder(
                    animation: _centralCtrl,
                    builder: (_, __) => Transform.scale(
                      scale: centralScale.value,
                      child: Opacity(
                        opacity: centralOpacity.value,
                        child: Text(
                          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.amiri(
                            fontSize: 28,
                            color: kGold,
                            fontWeight: FontWeight.w700,
                            height: 1.9,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Unvan divider
                  AnimatedBuilder(
                    animation: subtitleOpacity,
                    builder: (_, __) => Opacity(
                      opacity: subtitleOpacity.value,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: CustomPaint(
                          size: Size(double.infinity, 14),
                          painter: UnvanDividerPainter(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // App name
                  AnimatedBuilder(
                    animation: subtitleOpacity,
                    builder: (_, __) => Opacity(
                      opacity: subtitleOpacity.value,
                      child: Text(
                        'Nazar  ✦  Ferahlama',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kGreen,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 52),

                  // Pulsing loading dots
                  AnimatedBuilder(
                    animation: Listenable.merge([_subtitleCtrl, _ambientCtrl]),
                    builder: (_, __) => Opacity(
                      opacity: subtitleOpacity.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final phase = (_ambientCtrl.value + i / 3) % 1.0;
                          final dy = -7.0 * sin(phase * pi).clamp(0.0, 1.0);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Transform.translate(
                              offset: Offset(0, dy),
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: kGold.withValues(alpha: 0.62),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Layer 6: parchment dissolve on exit
          AnimatedBuilder(
            animation: exitOpacity,
            builder: (_, __) {
              final v = exitOpacity.value;
              if (v == 0) return const SizedBox.shrink();
              return IgnorePointer(
                child: Container(color: kBg.withValues(alpha: v)),
              );
            },
          ),
        ],
      ),
    );
  }
}
