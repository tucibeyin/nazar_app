import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/ayet.dart';

enum _ViewState { camera, analyzing, playing }

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Ayet? _ayet;
  bool _isLoading = false;
  bool _isPlaying = false;
  int _cameraIndex = 0;
  _ViewState _viewState = _ViewState.camera;

  late final AnimationController _waveController;
  late final AnimationController _waveFadeController;
  late final AnimationController _shutterController;
  late final AnimationController _mysticController;
  late final AnimationController _mysticFadeController;

  late final Animation<double> _shutterOpacity;

  static const _green = Color(0xFF1B4B3E);
  static const _bg = Color(0xFFF5F0E8);
  static const _darkBg = Color(0xFF071912);

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _waveFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _mysticController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _mysticFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shutterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shutterController, curve: Curves.easeInOut),
    );

    _cameraIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_cameraIndex == -1) _cameraIndex = 0;
    _initCamera(_cameraIndex);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) _transitionToCamera();
    });
  }

  Future<void> _transitionToCamera() async {
    await _waveFadeController.reverse();
    _waveController.stop();
    if (mounted) setState(() => _viewState = _ViewState.camera);
  }

  Future<void> _shutterFlash() async {
    await _shutterController.forward();
    await _shutterController.reverse();
  }

  Future<void> _initCamera(int index) async {
    await _cameraController?.dispose();
    _cameraController = CameraController(
      widget.cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    final current = widget.cameras[_cameraIndex].lensDirection;
    final target = current == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final idx = widget.cameras.indexWhere((c) => c.lensDirection == target);
    if (idx == -1) return;
    _cameraIndex = idx;
    await _initCamera(_cameraIndex);
  }

  Future<void> _exitApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış',
            style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
        content: const Text('Uygulamadan çıkmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hayır', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Evet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _audioPlayer.stop();
    await _cameraController?.dispose();
    exit(0);
  }

  Future<void> _analyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isLoading || _viewState != _ViewState.camera) return;

    setState(() {
      _isLoading = true;
      _ayet = null;
    });

    try {
      // 1. Shutter flash
      await _shutterFlash();

      // 2. Take photo & compute hash in parallel with mystic fade-in
      final photoFuture = _cameraController!.takePicture();
      setState(() => _viewState = _ViewState.analyzing);
      _mysticController.repeat();
      _mysticFadeController.forward();

      final photo = await photoFuture;
      final bytes = await photo.readAsBytes();
      final digest = sha256.convert(bytes);
      final first8 = Uint8List.fromList(digest.bytes.sublist(0, 8));
      final hashInt = ByteData.sublistView(first8).getInt64(0, Endian.big).abs();

      // 3. API call + minimum mystic display time
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.nazarEndpoint(hashInt))),
        Future.delayed(const Duration(milliseconds: 1800)),
      ]);
      final response = results[0] as http.Response;

      if (response.statusCode != 200) throw Exception('Sunucu hatası: ${response.statusCode}');
      final ayet = Ayet.fromJson(jsonDecode(response.body));

      // 4. Mystic → wave transition
      await _mysticFadeController.reverse();
      _mysticController.stop();

      if (!mounted) return;
      setState(() {
        _ayet = ayet;
        _viewState = _ViewState.playing;
        _isLoading = false;
      });
      _waveController.repeat();
      await _waveFadeController.forward();

      // 5. Play audio
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(ApiConfig.audioUrl(ayet.mp3Url)));
    } catch (e) {
      await _mysticFadeController.reverse();
      _mysticController.stop();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _viewState = _ViewState.camera;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _waveController.stop();
    } else {
      await _audioPlayer.resume();
      _waveController.repeat();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _waveFadeController.dispose();
    _shutterController.dispose();
    _mysticController.dispose();
    _mysticFadeController.dispose();
    _cameraController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildMainFrame(),
              _buildButton(),
              if (_ayet != null)
                _buildResultPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _viewState == _ViewState.camera ? _switchCamera : null,
            icon: Icon(
              Icons.flip_camera_ios_rounded,
              color: _viewState == _ViewState.camera
                  ? _green
                  : _green.withValues(alpha: 0.25),
              size: 26,
            ),
          ),
          const Expanded(
            child: Text(
              'Nazar & Ferahlama',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _green,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: _exitApp,
            icon: const Icon(Icons.close_rounded, color: _green, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildMainFrame() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    final ratio = _cameraController!.value.aspectRatio;
    final portraitRatio = ratio < 1 ? ratio : 1 / ratio;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: portraitRatio,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _mysticFadeController,
              _waveFadeController,
              _shutterController,
            ]),
            builder: (context, child) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Camera layer
                  if (_viewState == _ViewState.camera)
                    CameraPreview(_cameraController!),

                  // Dark background (mystic & wave states)
                  if (_viewState != _ViewState.camera)
                    Container(color: _darkBg),

                  // Mystic layer
                  if (_mysticFadeController.value > 0)
                    Opacity(
                      opacity: _mysticFadeController.value,
                      child: AnimatedBuilder(
                        animation: _mysticController,
                        builder: (_, __) => CustomPaint(
                          painter: _MysticPainter(_mysticController.value),
                        ),
                      ),
                    ),

                  // Wave layer
                  if (_waveFadeController.value > 0)
                    Opacity(
                      opacity: _waveFadeController.value,
                      child: AnimatedBuilder(
                        animation: _waveController,
                        builder: (_, __) => CustomPaint(
                          painter: _WavePainter(
                              _waveController.value, _isPlaying),
                        ),
                      ),
                    ),

                  // Shutter flash
                  if (_shutterController.value > 0)
                    IgnorePointer(
                      child: Opacity(
                        opacity: _shutterOpacity.value * 0.65,
                        child: Container(color: Colors.white),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildButton() {
    final isWaving = _viewState == _ViewState.playing;
    final isAnalyzing = _viewState == _ViewState.analyzing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_isLoading || isAnalyzing)
              ? null
              : (isWaving ? _toggleAudio : _analyze),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _green.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: isAnalyzing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Analiz ediliyor...',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  )
                : Text(
                    isWaving
                        ? (_isPlaying ? 'Duraklat' : 'Devam Et')
                        : 'Nazarımı Oku / Analiz Et',
                    key: ValueKey('$isWaving$_isPlaying'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    final ayet = _ayet!;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ayet.sureIsim,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleAudio,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: _green,
                    size: 34,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ayet.arapca,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 22,
                height: 2.2,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFFE0D8CC)),
            ),
            Text(
              ayet.meal,
              style: const TextStyle(
                fontSize: 14,
                height: 1.7,
                color: Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mistik Animasyon ───────────────────────────────────────────────────────

class _MysticPainter extends CustomPainter {
  final double t;
  _MysticPainter(this.t);

  static const _gold = Color(0xFFC9A84C);
  static const _lightGold = Color(0xFFE8D5A3);
  static const _teal = Color(0xFF3DB88A);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final maxR = min(cx, cy) * 0.88;

    _drawLightBeams(canvas, center, maxR, t * 2 * pi * 0.12);
    _drawOrbitDots(canvas, center, maxR * 0.88, -t * 2 * pi * 0.25, 16);
    _drawArabesqueRing(canvas, center, maxR * 0.66, t * 2 * pi * 0.18);
    _drawIslamicStar(canvas, center, maxR * 0.44, maxR * 0.19,
        -t * 2 * pi * 0.45, filled: false);
    _drawIslamicStar(canvas, center, maxR * 0.23, maxR * 0.10,
        t * 2 * pi * 0.9, filled: true);
    _drawCenter(canvas, center, maxR, t);
  }

  void _drawLightBeams(
      Canvas canvas, Offset center, double r, double rotation) {
    for (int i = 0; i < 8; i++) {
      final angle = rotation + i * pi / 4;
      final alpha = 0.035 + 0.025 * sin(t * 2 * pi + i * pi / 4).abs();
      final paint = Paint()
        ..color = _gold.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
            center.dx + r * cos(angle - 0.13), center.dy + r * sin(angle - 0.13))
        ..lineTo(
            center.dx + r * cos(angle + 0.13), center.dy + r * sin(angle + 0.13))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawOrbitDots(Canvas canvas, Offset center, double r, double rotation,
      int count) {
    for (int i = 0; i < count; i++) {
      final angle = rotation + i * 2 * pi / count;
      final isLarge = i.isEven;
      final pulse = isLarge
          ? 1.0 + 0.2 * sin(t * 2 * pi * 2 + i * 0.8)
          : 1.0;
      final dotR = (isLarge ? 3.2 : 1.8) * pulse;
      final alpha = isLarge ? 0.85 : 0.45;
      canvas.drawCircle(
        Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)),
        dotR,
        Paint()..color = _lightGold.withValues(alpha: alpha),
      );
    }
  }

  void _drawArabesqueRing(
      Canvas canvas, Offset center, double r, double rotation) {
    // Faint ring
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = _teal.withValues(alpha: 0.12)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // 8 diamond lozenges
    final strokePaint = Paint()
      ..color = _teal.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final angle = rotation + i * pi / 4;
      final dc = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      final s = r * 0.14;
      final path = Path()
        ..moveTo(dc.dx + s * cos(angle), dc.dy + s * sin(angle))
        ..lineTo(dc.dx + s * cos(angle + pi / 2) * 0.55,
            dc.dy + s * sin(angle + pi / 2) * 0.55)
        ..lineTo(dc.dx - s * cos(angle), dc.dy - s * sin(angle))
        ..lineTo(dc.dx - s * cos(angle + pi / 2) * 0.55,
            dc.dy - s * sin(angle + pi / 2) * 0.55)
        ..close();
      canvas.drawPath(path, strokePaint);
    }
  }

  void _drawIslamicStar(Canvas canvas, Offset center, double outerR,
      double innerR, double rotation,
      {required bool filled}) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final angle = rotation + i * pi / 8 - pi / 2;
      final r = i.isEven ? outerR : innerR;
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    if (filled) {
      canvas.drawPath(path,
          Paint()..color = _gold.withValues(alpha: 0.88)..style = PaintingStyle.fill);
      // Glow
      canvas.drawPath(
          path,
          Paint()
            ..color = _gold.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
            ..style = PaintingStyle.fill);
    } else {
      canvas.drawPath(
          path,
          Paint()
            ..color = _gold.withValues(alpha: 0.65)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }
  }

  void _drawCenter(Canvas canvas, Offset center, double maxR, double t) {
    final pulse = 0.82 + 0.18 * sin(t * 2 * pi * 2.5);

    // Outer glow
    canvas.drawCircle(
      center,
      maxR * 0.14 * pulse,
      Paint()
        ..color = _gold.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Inner circle
    canvas.drawCircle(
        center, maxR * 0.075 * pulse, Paint()..color = _gold.withValues(alpha: 0.9));
    // Core dot
    canvas.drawCircle(
        center, maxR * 0.028, Paint()..color = _lightGold);
  }

  @override
  bool shouldRepaint(_MysticPainter old) => old.t != t;
}

// ─── Ses Dalgası ────────────────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double t;
  final bool isPlaying;
  _WavePainter(this.t, this.isPlaying);

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30;
    const minBarRatio = 0.03;
    const maxBarRatio = 0.72;

    final totalW = size.width * 0.65;
    final barW = totalW / (barCount * 2 - 1);
    final gap = barW;
    final startX = (size.width - totalW) / 2;

    for (int i = 0; i < barCount; i++) {
      final pct = i / (barCount - 1);
      final phase = pct * 2 * pi;
      final w1 = sin(t * 2 * pi * 2.2 + phase);
      final w2 = sin(t * 2 * pi * 3.5 + phase * 1.4 + 1.0);
      final combined = (w1 * 0.6 + w2 * 0.4).abs();

      final minH = size.height * minBarRatio;
      final maxH = size.height * maxBarRatio;
      final barH = isPlaying ? minH + combined * (maxH - minH) : minH + 2;

      final envelope = sin(pct * pi);
      final color = Color.lerp(
        const Color(0xFF2E8B6E),
        const Color(0xFF7FFFD4),
        envelope * combined,
      )!.withValues(alpha: 0.75 + envelope * 0.25);

      final x = startX + i * (barW + gap) + barW / 2;
      canvas.drawLine(
        Offset(x, (size.height - barH) / 2),
        Offset(x, (size.height + barH) / 2),
        Paint()
          ..color = color
          ..strokeWidth = barW
          ..strokeCap = StrokeCap.round,
      );
    }

    if (isPlaying) {
      final glowPaint = Paint()
        ..color = const Color(0xFF7FFFD4).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (int i = 0; i < barCount; i += 3) {
        final pct = i / (barCount - 1);
        final phase = pct * 2 * pi;
        final w1 = sin(t * 2 * pi * 2.2 + phase);
        final w2 = sin(t * 2 * pi * 3.5 + phase * 1.4 + 1.0);
        final combined = (w1 * 0.6 + w2 * 0.4).abs();
        if (combined < 0.5) continue;
        final maxH = size.height * maxBarRatio;
        final x = startX + i * (barW + gap) + barW / 2;
        canvas.drawCircle(
            Offset(x, (size.height - combined * maxH) / 2), 6, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.t != t || old.isPlaying != isPlaying;
}
