import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import 'painters/painters.dart';

enum CameraFrameState { camera, analyzing, playing }

class CameraFrameWidget extends StatelessWidget {
  final CameraController cameraController;
  final CameraFrameState frameState;
  final Uint8List? capturedPhotoBytes;
  final AnimationController shutterController;
  final AnimationController mysticController;
  final AnimationController waveController;
  final AnimationController waveEnterController;
  final bool isPlaying;

  const CameraFrameWidget({
    super.key,
    required this.cameraController,
    required this.frameState,
    required this.capturedPhotoBytes,
    required this.shutterController,
    required this.mysticController,
    required this.waveController,
    required this.waveEnterController,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = cameraController.value.aspectRatio;
    final portraitRatio = ratio < 1 ? ratio : 1 / ratio;

    final shutterA = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: shutterController, curve: Curves.easeInOut),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: ShemseBackgroundPainter()),
            ),
          ),
          Column(
            children: [
              CustomPaint(
                size: Size(MediaQuery.of(context).size.width - kScreenPaddingH * 2, kMuqarnasH),
                painter: const MukarnasPainter(isTop: true),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(color: kGold.withValues(alpha: 0.6), width: 1.5),
                  ),
                ),
                child: ClipRect(
                  child: AspectRatio(
                    aspectRatio: portraitRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: kSwitchDuration,
                          transitionBuilder: _frameCrossfade,
                          layoutBuilder: (cur, prev) => Stack(
                            fit: StackFit.expand,
                            children: [...prev, if (cur != null) cur],
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(frameState),
                            child: _buildFrameContent(),
                          ),
                        ),
                        const IgnorePointer(child: CustomPaint(painter: FrameCornerPainter())),
                        AnimatedBuilder(
                          animation: shutterController,
                          builder: (_, __) => shutterA.value > 0
                              ? IgnorePointer(
                                  child: Opacity(
                                    opacity: shutterA.value * 0.68,
                                    child: Container(color: Colors.white),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: Size(MediaQuery.of(context).size.width - kScreenPaddingH * 2, kMuqarnasH),
                painter: const MukarnasPainter(isTop: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _frameCrossfade(Widget child, Animation<double> animation) {
    final blurA = Tween<double>(begin: 10.0, end: 0.0)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    final scaleA = Tween<double>(begin: 1.07, end: 1.0)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: animation,
      builder: (_, ch) {
        final sigma = blurA.value;
        Widget content = Transform.scale(scale: scaleA.value, child: ch);
        if (sigma > 0.3) {
          content = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal,
            ),
            child: content,
          );
        }
        return Opacity(opacity: animation.value, child: content);
      },
      child: child,
    );
  }

  Widget _buildFrameContent() {
    switch (frameState) {
      case CameraFrameState.camera:
        return CameraPreview(cameraController);
      case CameraFrameState.analyzing:
        return Stack(
          fit: StackFit.expand,
          children: [
            if (capturedPhotoBytes != null)
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5, tileMode: TileMode.decal),
                child: Image.memory(capturedPhotoBytes!, fit: BoxFit.cover),
              )
            else
              Container(color: kDarkBg),
            Container(color: kDarkBg.withValues(alpha: 0.68)),
            AnimatedBuilder(
              animation: mysticController,
              builder: (_, __) => CustomPaint(painter: MysticPainter(mysticController.value)),
            ),
            AnimatedBuilder(
              animation: mysticController,
              builder: (_, __) => CustomPaint(painter: ScanOverlayPainter(mysticController.value)),
            ),
          ],
        );
      case CameraFrameState.playing:
        return Container(
          color: kDarkBg,
          child: AnimatedBuilder(
            animation: Listenable.merge([waveController, waveEnterController]),
            builder: (_, __) => CustomPaint(
              painter: WavePainter(
                waveController.value,
                isPlaying: isPlaying,
                entrance: waveEnterController.value,
              ),
            ),
          ),
        );
    }
  }
}
