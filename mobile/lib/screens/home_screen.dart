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

enum _ViewState { camera, playing }

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
  late final AnimationController _transitionController;
  late final AnimationController _shutterController;

  late final Animation<double> _cameraOpacity;
  late final Animation<double> _waveOpacity;
  late final Animation<double> _cameraScale;
  late final Animation<double> _waveScale;
  late final Animation<double> _shutterOpacity;

  static const _green = Color(0xFF1B4B3E);
  static const _bg = Color(0xFFF5F0E8);
  static const _waveBg = Color(0xFF0D2B23);

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _cameraOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );
    _waveOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );
    _cameraScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );
    _waveScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
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

  Future<void> _transitionToWave() async {
    setState(() => _viewState = _ViewState.playing);
    _waveController.repeat();
    await _transitionController.forward();
  }

  Future<void> _transitionToCamera() async {
    await _transitionController.reverse();
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
    if (_isLoading || _viewState == _ViewState.playing) return;

    setState(() {
      _isLoading = true;
      _ayet = null;
    });

    try {
      _shutterFlash();

      final photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      final digest = sha256.convert(bytes);
      final first8 = Uint8List.fromList(digest.bytes.sublist(0, 8));
      final hashInt =
          ByteData.sublistView(first8).getInt64(0, Endian.big).abs();

      final uri = Uri.parse(ApiConfig.nazarEndpoint(hashInt));
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }

      final ayet = Ayet.fromJson(jsonDecode(response.body));
      setState(() {
        _ayet = ayet;
        _isLoading = false;
      });

      await _transitionToWave();
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(ApiConfig.audioUrl(ayet.mp3Url)));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
    _transitionController.dispose();
    _shutterController.dispose();
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
              if (_ayet != null && _viewState == _ViewState.playing)
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: Listenable.merge([_transitionController, _shutterController]),
          builder: (context, child) {
            return Stack(
              children: [
                // Camera layer
                Opacity(
                  opacity: _cameraOpacity.value,
                  child: Transform.scale(
                    scale: _cameraScale.value,
                    child: _buildCameraWidget(),
                  ),
                ),

                // Wave layer
                if (_transitionController.value > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: _waveOpacity.value,
                      child: Transform.scale(
                        scale: _waveScale.value,
                        child: _buildWaveWidget(),
                      ),
                    ),
                  ),

                // Shutter flash
                if (_shutterController.value > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _shutterOpacity.value * 0.65,
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCameraWidget() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    }
    final ratio = _cameraController!.value.aspectRatio;
    final portraitRatio = ratio < 1 ? ratio : 1 / ratio;
    return AspectRatio(
      aspectRatio: portraitRatio,
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildWaveWidget() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final ratio = _cameraController!.value.aspectRatio;
    final portraitRatio = ratio < 1 ? ratio : 1 / ratio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w > 0 ? w / portraitRatio : 320.0;
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            color: _waveBg,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => CustomPaint(
                painter: _WavePainter(_waveController.value, _isPlaying),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton() {
    final isWaving = _viewState == _ViewState.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : (isWaving ? _toggleAudio : _analyze),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _green.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
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

class _WavePainter extends CustomPainter {
  final double progress;
  final bool isPlaying;

  _WavePainter(this.progress, this.isPlaying);

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30;
    const minBarRatio = 0.03;
    const maxBarRatio = 0.72;

    final totalBarWidth = size.width * 0.65;
    final barW = totalBarWidth / (barCount * 2 - 1);
    final gap = barW;
    final startX = (size.width - totalBarWidth) / 2;

    for (int i = 0; i < barCount; i++) {
      final t = i / (barCount - 1);
      final phase = t * 2 * pi;

      final w1 = sin(progress * 2 * pi * 2.2 + phase);
      final w2 = sin(progress * 2 * pi * 3.5 + phase * 1.4 + 1.0);
      final combined = ((w1 * 0.6 + w2 * 0.4)).abs();

      final minH = size.height * minBarRatio;
      final maxH = size.height * maxBarRatio;
      final barH = isPlaying ? minH + combined * (maxH - minH) : minH + 2;

      final envelope = sin(t * pi);
      final color = Color.lerp(
        const Color(0xFF2E8B6E),
        const Color(0xFF7FFFD4),
        envelope * combined,
      )!
          .withValues(alpha: 0.75 + envelope * 0.25);

      final paint = Paint()
        ..color = color
        ..strokeWidth = barW
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final x = startX + i * (barW + gap) + barW / 2;
      final y1 = (size.height - barH) / 2;
      final y2 = y1 + barH;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }

    // Glow at tall bars
    if (isPlaying) {
      final glowPaint = Paint()
        ..color = const Color(0xFF7FFFD4).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      for (int i = 0; i < barCount; i += 3) {
        final t = i / (barCount - 1);
        final phase = t * 2 * pi;
        final w1 = sin(progress * 2 * pi * 2.2 + phase);
        final w2 = sin(progress * 2 * pi * 3.5 + phase * 1.4 + 1.0);
        final combined = ((w1 * 0.6 + w2 * 0.4)).abs();
        if (combined < 0.5) continue;

        final maxH = size.height * maxBarRatio;
        final barH = combined * maxH;
        final x = startX + i * (barW + gap) + barW / 2;
        final y = (size.height - barH) / 2;
        canvas.drawCircle(Offset(x, y), 6, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.isPlaying != isPlaying;
}
