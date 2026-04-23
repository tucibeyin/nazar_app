import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  Uint8List? _capturedPhotoBytes;

  late final AnimationController _shutterCtrl;
  late final AnimationController _mysticCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _waveEnterCtrl;
  late final AnimationController _ambientCtrl; // arka plan hafif nefes animasyonu
  late final Animation<double> _shutterA;

  static const _green  = Color(0xFF1B4B3E);
  static const _gold   = Color(0xFFC9A84C);
  static const _bg     = Color(0xFFF5F0E8);
  static const _darkBg = Color(0xFF071912);
  static const _switchDuration = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();

    _shutterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _mysticCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200));
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _waveEnterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _ambientCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);

    _shutterA = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shutterCtrl, curve: Curves.easeInOut));

    _cameraIndex = widget.cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front);
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
    _waveCtrl.stop();
    if (mounted) {
      setState(() {
        _viewState = _ViewState.camera;
        _capturedPhotoBytes = null;
      });
    }
  }

  Future<void> _shutterFlash() async {
    await _shutterCtrl.forward();
    await _shutterCtrl.reverse();
  }

  Future<void> _initCamera(int index) async {
    await _cameraController?.dispose();
    _cameraController = CameraController(
        widget.cameras[index], ResolutionPreset.medium, enableAudio: false);
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
              child: const Text('Hayır', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_isLoading || _viewState != _ViewState.camera) return;

    setState(() {
      _isLoading = true;
      _ayet = null;
      _capturedPhotoBytes = null;
    });

    try {
      await _shutterFlash();

      _mysticCtrl.repeat();
      final photoFuture = _cameraController!.takePicture();
      setState(() => _viewState = _ViewState.analyzing);

      final photo = await photoFuture;
      final bytes = await photo.readAsBytes();
      if (mounted) setState(() => _capturedPhotoBytes = bytes);
      final digest = sha256.convert(bytes);
      final first8 = Uint8List.fromList(digest.bytes.sublist(0, 8));
      final hashInt =
          ByteData.sublistView(first8).getInt64(0, Endian.big).abs();

      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.nazarEndpoint(hashInt))),
        Future.delayed(const Duration(milliseconds: 2200)),
      ]);
      final response = results[0] as http.Response;
      if (response.statusCode != 200) {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }
      final ayet = Ayet.fromJson(jsonDecode(response.body));

      _mysticCtrl.stop();
      _waveEnterCtrl.reset();
      _waveCtrl.repeat();
      _waveEnterCtrl.forward();

      if (!mounted) return;
      setState(() {
        _ayet = ayet;
        _viewState = _ViewState.playing;
        _isLoading = false;
      });

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(ApiConfig.audioUrl(ayet.mp3Url)));
    } catch (e) {
      _mysticCtrl.stop();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _viewState = _ViewState.camera;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _waveCtrl.stop();
    } else {
      await _audioPlayer.resume();
      _waveCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _shutterCtrl.dispose();
    _mysticCtrl.dispose();
    _waveCtrl.dispose();
    _waveEnterCtrl.dispose();
    _ambientCtrl.dispose();
    _cameraController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: _ambientCtrl,
        builder: (_, child) => CustomPaint(
          painter: _IslamicBackgroundPainter(_ambientCtrl.value),
          child: child,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildMainFrame(),
                _buildButton(),
                if (_ayet != null) _buildResultPanel(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Başlık satırı
          Row(
            children: [
              IconButton(
                onPressed: _viewState == _ViewState.camera ? _switchCamera : null,
                icon: Icon(Icons.flip_camera_ios_rounded,
                    color: _viewState == _ViewState.camera
                        ? _green
                        : _green.withValues(alpha: 0.25),
                    size: 26),
              ),
              const Expanded(
                child: Column(
                  children: [
                    Text('بِسْمِ اللَّهِ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18,
                            color: _gold,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2)),
                    SizedBox(height: 2),
                    Text('Nazar & Ferahlama',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _green,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: _exitApp,
                  icon: const Icon(Icons.close_rounded, color: _green, size: 26)),
            ],
          ),
          // Altın ayırıcı çizgi
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 6, 8, 12),
            child: CustomPaint(
              size: Size(double.infinity, 12),
              painter: _DividerOrnamentPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainFrame() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox(
          height: 320,
          child: Center(child: CircularProgressIndicator(color: _green)));
    }

    final ratio = _cameraController!.value.aspectRatio;
    final portraitRatio = ratio < 1 ? ratio : 1 / ratio;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Mukarnas üst kemer
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width - 40, 44),
            painter: const _MukarnasPainter(isTop: true),
          ),
          // Kamera/analiz çerçevesi
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(
                    color: _gold.withValues(alpha: 0.55), width: 1.5),
              ),
            ),
            child: ClipRect(
              child: AspectRatio(
                aspectRatio: portraitRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Ana çerçeve içeriği
                    AnimatedSwitcher(
                      duration: _switchDuration,
                      transitionBuilder: _frameCrossfade,
                      layoutBuilder: (cur, prev) => Stack(
                        fit: StackFit.expand,
                        children: [...prev, if (cur != null) cur],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_viewState),
                        child: _buildFrameContent(),
                      ),
                    ),
                    // Köşe süslemeleri (her zaman görünür)
                    const IgnorePointer(
                      child: CustomPaint(
                        painter: _FrameCornerPainter(),
                      ),
                    ),
                    // Shutter flash
                    AnimatedBuilder(
                      animation: _shutterCtrl,
                      builder: (_, __) => _shutterA.value > 0
                          ? IgnorePointer(
                              child: Opacity(
                                  opacity: _shutterA.value * 0.68,
                                  child: Container(color: Colors.white)))
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Mukarnas alt kemer
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width - 40, 44),
            painter: const _MukarnasPainter(isTop: false),
          ),
        ],
      ),
    );
  }

  /// Blur + scale + fade — hem giriş hem çıkış için simetrik profesyonel geçiş
  Widget _frameCrossfade(Widget child, Animation<double> animation) {
    final blurA = Tween<double>(begin: 10.0, end: 0.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    final scaleA = Tween<double>(begin: 1.07, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return AnimatedBuilder(
      animation: animation,
      builder: (_, ch) {
        final sigma = blurA.value;
        Widget content = Transform.scale(scale: scaleA.value, child: ch);
        if (sigma > 0.3) {
          content = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
            child: content,
          );
        }
        return Opacity(opacity: animation.value, child: content);
      },
      child: child,
    );
  }

  Widget _buildFrameContent() {
    switch (_viewState) {
      case _ViewState.camera:
        return CameraPreview(_cameraController!);

      case _ViewState.analyzing:
        return Stack(
          fit: StackFit.expand,
          children: [
            // Katman 1: Bulanık fotoğraf arka planı
            if (_capturedPhotoBytes != null)
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                    sigmaX: 4.5, sigmaY: 4.5, tileMode: TileMode.decal),
                child: Image.memory(_capturedPhotoBytes!, fit: BoxFit.cover),
              )
            else
              Container(color: _darkBg),
            // Katman 2: Koyu örtü
            Container(color: _darkBg.withValues(alpha: 0.68)),
            // Katman 3: Mistik geometri
            AnimatedBuilder(
              animation: _mysticCtrl,
              builder: (_, __) =>
                  CustomPaint(painter: _MysticPainter(_mysticCtrl.value)),
            ),
            // Katman 4: Tarama çizgisi + köşe braketleri
            AnimatedBuilder(
              animation: _mysticCtrl,
              builder: (_, __) =>
                  CustomPaint(painter: _ScanOverlayPainter(_mysticCtrl.value)),
            ),
          ],
        );

      case _ViewState.playing:
        return Container(
          color: _darkBg,
          child: AnimatedBuilder(
            animation: Listenable.merge([_waveCtrl, _waveEnterCtrl]),
            builder: (_, __) => CustomPaint(
              painter:
                  _WavePainter(_waveCtrl.value, _isPlaying, _waveEnterCtrl.value),
            ),
          ),
        );
    }
  }

  Widget _buildButton() {
    final isWaving    = _viewState == _ViewState.playing;
    final isAnalyzing = _viewState == _ViewState.analyzing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
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
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.35), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: isAnalyzing
                ? const _AnalyzingIndicator(key: ValueKey('analyzing'))
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
    return TweenAnimationBuilder<double>(
      key: ValueKey(_ayet?.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withValues(alpha: 0.35), width: 1),
          boxShadow: [
            BoxShadow(
                color: _green.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6)),
            BoxShadow(
                color: _gold.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel başlık süsü
            const ClipRRect(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(17)),
              child: CustomPaint(
                size: Size(double.infinity, 20),
                painter: _PanelTopOrnamentPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(_ayet!.sureIsim,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _green))),
                    IconButton(
                      onPressed: _toggleAudio,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: _green,
                          size: 34),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(_ayet!.arapca,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          fontSize: 22,
                          height: 2.2,
                          color: Color(0xFF1A1A1A))),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CustomPaint(
                        size: Size(double.infinity, 10),
                        painter: _DividerOrnamentPainter(),
                      )),
                  Text(_ayet!.meal,
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: Color(0xFF4A4A4A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Analiz göstergesi ───────────────────────────────────────────────────────

class _AnalyzingIndicator extends StatelessWidget {
  const _AnalyzingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2)),
        SizedBox(width: 10),
        Text('Analiz ediliyor...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── İslami Arka Plan ────────────────────────────────────────────────────────
// Zımba kafes deseni + hafif nefes eden altın noktalar

class _IslamicBackgroundPainter extends CustomPainter {
  final double t; // 0→1 (ambient, reverse: true)
  _IslamicBackgroundPainter(this.t);

  static const _bg   = Color(0xFFF5F0E8);
  static const _gold = Color(0xFFC9A84C);
  static const _green = Color(0xFF1B4B3E);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _bg);
    _drawGeometricGrid(canvas, size);
    _drawCornerRosettes(canvas, size);
    _drawSideVines(canvas, size);
  }

  // 8-köşeli yıldız kafes deseni — çok hafif
  void _drawGeometricGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gold.withValues(alpha: 0.07 + 0.02 * t)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const step = 52.0;
    final cols = (size.width / step).ceil() + 2;
    final rows = (size.height / step).ceil() + 2;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * step + (row.isOdd ? step / 2 : 0);
        final cy = row * step * 0.866;
        _drawSmallStar(canvas, Offset(cx, cy), step * 0.22, paint);
      }
    }

    // Bağlantı çizgileri
    final linePaint = Paint()
      ..color = _gold.withValues(alpha: 0.045)
      ..strokeWidth = 0.6;
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * step + (row.isOdd ? step / 2 : 0);
        final cy = row * step * 0.866;
        canvas.drawLine(
            Offset(cx, cy), Offset(cx + step, cy), linePaint);
        canvas.drawLine(Offset(cx, cy),
            Offset(cx + step / 2, cy + step * 0.433), linePaint);
        canvas.drawLine(Offset(cx, cy),
            Offset(cx - step / 2, cy + step * 0.433), linePaint);
      }
    }
  }

  void _drawSmallStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a = i * pi / 8 - pi / 2;
      final radius = i.isEven ? r : r * 0.45;
      final pt = Offset(c.dx + radius * cos(a), c.dy + radius * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // Köşe rozet süsleri
  void _drawCornerRosettes(Canvas canvas, Size size) {
    final pulse = 0.55 + 0.1 * t;
    final paint = Paint()
      ..color = _gold.withValues(alpha: pulse * 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = _gold.withValues(alpha: pulse * 0.06);

    final corners = [
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    for (final c in corners) {
      _drawRosette(canvas, c, 72, paint, fillPaint);
    }
  }

  void _drawRosette(Canvas canvas, Offset c, double r,
      Paint stroke, Paint fill) {
    // Dış çember
    canvas.drawCircle(c, r, stroke);
    // 8 iç çember (rozet)
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final cc = Offset(c.dx + r * 0.5 * cos(a), c.dy + r * 0.5 * sin(a));
      canvas.drawCircle(cc, r * 0.5, stroke);
      canvas.drawCircle(cc, r * 0.5, fill);
    }
    // Merkez yıldız
    _drawSmallStar(canvas, c, r * 0.28, stroke);
  }

  // Yan arabesk sarmaşık şeridi
  void _drawSideVines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _green.withValues(alpha: 0.055 + 0.015 * t)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const bandW = 18.0;

    for (final xBase in [0.0, size.width - bandW]) {
      final path = Path();
      const step = 28.0;
      final count = (size.height / step).ceil() + 2;
      for (int i = 0; i < count; i++) {
        final y = i * step.toDouble();
        final flip = i.isEven ? 1.0 : -1.0;
        final cx = xBase + bandW / 2 + flip * bandW * 0.35;
        path.addOval(Rect.fromCenter(
            center: Offset(cx, y + step / 2),
            width: bandW * 0.7,
            height: step * 0.72));
      }
      canvas.drawPath(path, paint);

      // Merkez dikey çizgi
      canvas.drawLine(Offset(xBase + bandW / 2, 0),
          Offset(xBase + bandW / 2, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_IslamicBackgroundPainter old) => old.t != t;
}

// ─── Mukarnas Kemeri ─────────────────────────────────────────────────────────

class _MukarnasPainter extends CustomPainter {
  final bool isTop;
  const _MukarnasPainter({required this.isTop});

  static const _gold  = Color(0xFFC9A84C);
  static const _green = Color(0xFF1B4B3E);
  static const _bg    = Color(0xFFF5F0E8);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;

    if (!isTop) {
      canvas.save();
      canvas.translate(0, h);
      canvas.scale(1, -1);
    }

    // Arkaplan dolgu — kemerin arkasını bg rengine boyuyoruz
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = _bg);

    // Stalaktit niş dizisi
    final nichePaint = Paint()
      ..color = _gold.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = _gold.withValues(alpha: 0.72)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final accentPaint = Paint()
      ..color = _green.withValues(alpha: 0.55)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const niches = 7;
    final nw = w / niches;

    for (int i = 0; i < niches; i++) {
      final x = i * nw;
      _drawMuqarnasNiche(canvas, x, nw, h, nichePaint, strokePaint, accentPaint);
    }

    // Üst yatay şerit
    canvas.drawLine(const Offset(0, 1), Offset(w, 1), strokePaint);

    // Merkez rozet
    _drawMiniRosette(canvas, Offset(w / 2, h * 0.38), h * 0.22, strokePaint);

    if (!isTop) canvas.restore();
  }

  void _drawMuqarnasNiche(Canvas canvas, double x, double nw, double h,
      Paint fill, Paint stroke, Paint accent) {
    final cx = x + nw / 2;
    final archW = nw * 0.88;

    // Sivri kemer (ogive arch)
    final path = Path();
    // Sol yay
    path.moveTo(cx - archW / 2, h);
    path.quadraticBezierTo(
        cx - archW / 2, h * 0.15, cx, h * 0.05);
    // Sağ yay
    path.quadraticBezierTo(
        cx + archW / 2, h * 0.15, cx + archW / 2, h);
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // İç küçük kemer
    final innerPath = Path();
    final iw = archW * 0.6;
    innerPath.moveTo(cx - iw / 2, h);
    innerPath.quadraticBezierTo(cx - iw / 2, h * 0.28, cx, h * 0.17);
    innerPath.quadraticBezierTo(cx + iw / 2, h * 0.28, cx + iw / 2, h);
    canvas.drawPath(innerPath, accent);

    // Kilit taşı noktası
    canvas.drawCircle(Offset(cx, h * 0.1), 2.8,
        Paint()..color = _gold.withValues(alpha: 0.8));
    canvas.drawCircle(Offset(cx, h * 0.1), 1.2,
        Paint()..color = _gold);

    // Kemer ayakları
    canvas.drawLine(Offset(x, 0), Offset(x, h), stroke);
  }

  void _drawMiniRosette(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawCircle(c, r, paint);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(c,
          Offset(c.dx + r * cos(a), c.dy + r * sin(a)), paint);
    }
    canvas.drawCircle(c, r * 0.45, paint);
    canvas.drawCircle(c, r * 0.18, Paint()..color = _gold.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_MukarnasPainter old) => false;
}

// ─── Çerçeve Köşe Süsü ───────────────────────────────────────────────────────

class _FrameCornerPainter extends CustomPainter {
  const _FrameCornerPainter();

  static const _gold = Color(0xFFC9A84C);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gold.withValues(alpha: 0.75)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    const arm = 22.0;
    const dot = 3.0;

    final corners = [
      (Offset.zero, 1.0, 1.0),
      (Offset(size.width, 0), -1.0, 1.0),
      (Offset(0, size.height), 1.0, -1.0),
      (Offset(size.width, size.height), -1.0, -1.0),
    ];

    for (final (c, xd, yd) in corners) {
      // L-çizgileri
      canvas.drawLine(c, Offset(c.dx + arm * xd, c.dy), paint);
      canvas.drawLine(c, Offset(c.dx, c.dy + arm * yd), paint);
      // Köşe noktası
      canvas.drawCircle(
          Offset(c.dx + 5.5 * xd, c.dy + 5.5 * yd), dot,
          Paint()..color = _gold);
      // Küçük iç L
      canvas.drawLine(
          Offset(c.dx + 6 * xd, c.dy + 6 * yd),
          Offset(c.dx + 14 * xd, c.dy + 6 * yd),
          paint..color = _gold.withValues(alpha: 0.45));
      canvas.drawLine(
          Offset(c.dx + 6 * xd, c.dy + 6 * yd),
          Offset(c.dx + 6 * xd, c.dy + 14 * yd),
          paint..color = _gold.withValues(alpha: 0.45));
    }
  }

  @override
  bool shouldRepaint(_FrameCornerPainter old) => false;
}

// ─── Altın Ayırıcı Çizgi ─────────────────────────────────────────────────────

class _DividerOrnamentPainter extends CustomPainter {
  const _DividerOrnamentPainter();

  static const _gold  = Color(0xFFC9A84C);
  static const _green = Color(0xFF1B4B3E);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final linePaint = Paint()
      ..color = _gold.withValues(alpha: 0.55)
      ..strokeWidth = 1.0;

    // Sol çizgi
    canvas.drawLine(Offset(0, cy), Offset(cx - 18, cy), linePaint);
    // Sağ çizgi
    canvas.drawLine(Offset(cx + 18, cy), Offset(size.width, cy), linePaint);

    // Merkez elmas
    final diamond = Path()
      ..moveTo(cx, cy - 5)
      ..lineTo(cx + 8, cy)
      ..lineTo(cx, cy + 5)
      ..lineTo(cx - 8, cy)
      ..close();
    canvas.drawPath(diamond,
        Paint()..color = _gold.withValues(alpha: 0.6));
    canvas.drawPath(
        diamond,
        Paint()
          ..color = _green.withValues(alpha: 0.4)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke);

    // Yan küçük noktalar
    for (final dx in [-14.0, 14.0]) {
      canvas.drawCircle(Offset(cx + dx, cy), 1.8,
          Paint()..color = _gold.withValues(alpha: 0.65));
    }
  }

  @override
  bool shouldRepaint(_DividerOrnamentPainter old) => false;
}

// ─── Sonuç Paneli Üst Süsü ───────────────────────────────────────────────────

class _PanelTopOrnamentPainter extends CustomPainter {
  const _PanelTopOrnamentPainter();

  static const _gold  = Color(0xFFC9A84C);
  static const _green = Color(0xFF1B4B3E);

  @override
  void paint(Canvas canvas, Size size) {
    // Altın gradient şerit
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _green.withValues(alpha: 0.85),
              _green,
              _green.withValues(alpha: 0.85),
            ],
          ).createShader(rect));

    // Tekrarlayan küçük elmas motifi
    final diamondPaint = Paint()
      ..color = _gold.withValues(alpha: 0.45);

    const spacing = 28.0;
    final count = (size.width / spacing).ceil() + 1;
    for (int i = 0; i < count; i++) {
      final cx = i * spacing + spacing / 2;
      final cy = size.height / 2;
      final path = Path()
        ..moveTo(cx, cy - 4)
        ..lineTo(cx + 5, cy)
        ..lineTo(cx, cy + 4)
        ..lineTo(cx - 5, cy)
        ..close();
      canvas.drawPath(path, diamondPaint);
    }
  }

  @override
  bool shouldRepaint(_PanelTopOrnamentPainter old) => false;
}

// ─── Mistik Animasyon ────────────────────────────────────────────────────────

class _MysticPainter extends CustomPainter {
  final double t;
  _MysticPainter(this.t);

  static const _gold      = Color(0xFFC9A84C);
  static const _lightGold = Color(0xFFE8D5A3);
  static const _teal      = Color(0xFF3DB88A);

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
    _drawCenter(canvas, center, maxR);
  }

  void _drawLightBeams(Canvas canvas, Offset c, double r, double rot) {
    for (int i = 0; i < 8; i++) {
      final a = rot + i * pi / 4;
      final alpha = 0.035 + 0.025 * sin(t * 2 * pi + i * pi / 4).abs();
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * cos(a - 0.13), c.dy + r * sin(a - 0.13))
        ..lineTo(c.dx + r * cos(a + 0.13), c.dy + r * sin(a + 0.13))
        ..close();
      canvas.drawPath(path, Paint()..color = _gold.withValues(alpha: alpha));
    }
  }

  void _drawOrbitDots(
      Canvas canvas, Offset c, double r, double rot, int count) {
    for (int i = 0; i < count; i++) {
      final a = rot + i * 2 * pi / count;
      final large = i.isEven;
      final pulse = large ? 1.0 + 0.2 * sin(t * 2 * pi * 2 + i * 0.8) : 1.0;
      canvas.drawCircle(
          Offset(c.dx + r * cos(a), c.dy + r * sin(a)),
          (large ? 3.2 : 1.8) * pulse,
          Paint()
            ..color = _lightGold.withValues(alpha: large ? 0.85 : 0.45));
    }
  }

  void _drawArabesqueRing(Canvas canvas, Offset c, double r, double rot) {
    canvas.drawCircle(
        c, r,
        Paint()
          ..color = _teal.withValues(alpha: 0.12)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);

    final strokePaint = Paint()
      ..color = _teal.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final a = rot + i * pi / 4;
      final dc = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      final s = r * 0.14;
      final path = Path()
        ..moveTo(dc.dx + s * cos(a), dc.dy + s * sin(a))
        ..lineTo(dc.dx + s * cos(a + pi / 2) * 0.55,
            dc.dy + s * sin(a + pi / 2) * 0.55)
        ..lineTo(dc.dx - s * cos(a), dc.dy - s * sin(a))
        ..lineTo(dc.dx - s * cos(a + pi / 2) * 0.55,
            dc.dy - s * sin(a + pi / 2) * 0.55)
        ..close();
      canvas.drawPath(path, strokePaint);
    }
  }

  void _drawIslamicStar(Canvas canvas, Offset c, double outerR, double innerR,
      double rot, {required bool filled}) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a = rot + i * pi / 8 - pi / 2;
      final r = i.isEven ? outerR : innerR;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    if (filled) {
      canvas.drawPath(path, Paint()..color = _gold.withValues(alpha: 0.88));
      canvas.drawPath(
          path,
          Paint()
            ..color = _gold.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    } else {
      canvas.drawPath(
          path,
          Paint()
            ..color = _gold.withValues(alpha: 0.65)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }
  }

  void _drawCenter(Canvas canvas, Offset c, double maxR) {
    final pulse = 0.82 + 0.18 * sin(t * 2 * pi * 2.5);
    canvas.drawCircle(
        c, maxR * 0.14 * pulse,
        Paint()
          ..color = _gold.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawCircle(c, maxR * 0.075 * pulse,
        Paint()..color = _gold.withValues(alpha: 0.9));
    canvas.drawCircle(c, maxR * 0.028, Paint()..color = _lightGold);
  }

  @override
  bool shouldRepaint(_MysticPainter old) => old.t != t;
}

// ─── Ses Dalgası ─────────────────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double t;
  final bool isPlaying;
  final double entrance;

  _WavePainter(this.t, this.isPlaying, this.entrance);

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30;
    const minRatio = 0.03;
    const maxRatio = 0.72;

    final totalW = size.width * 0.65;
    final barW = totalW / (barCount * 2 - 1);
    final startX = (size.width - totalW) / 2;

    final entranceCurve = Curves.elasticOut.transform(entrance.clamp(0.0, 1.0));

    for (int i = 0; i < barCount; i++) {
      final pct = i / (barCount - 1);
      final phase = pct * 2 * pi;
      final w1 = sin(t * 2 * pi * 2.2 + phase);
      final w2 = sin(t * 2 * pi * 3.5 + phase * 1.4 + 1.0);
      final combined = (w1 * 0.6 + w2 * 0.4).abs();

      final minH = size.height * minRatio;
      final maxH = size.height * maxRatio * entranceCurve;
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
        Paint()
          ..color = color
          ..strokeWidth = barW
          ..strokeCap = StrokeCap.round,
      );
    }

    if (isPlaying && entrance > 0.8) {
      final glowPaint = Paint()
        ..color = const Color(0xFF7FFFD4).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (int i = 0; i < barCount; i += 3) {
        final pct = i / (barCount - 1);
        final phase = pct * 2 * pi;
        final combined =
            (sin(t * 2 * pi * 2.2 + phase) * 0.6 +
                    sin(t * 2 * pi * 3.5 + phase * 1.4 + 1.0) * 0.4)
                .abs();
        if (combined < 0.5) continue;
        final maxH = size.height * maxRatio * entranceCurve;
        final x = startX + i * (barW + barW) + barW / 2;
        canvas.drawCircle(Offset(x, (size.height - combined * maxH) / 2), 6,
            glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.t != t || old.isPlaying != isPlaying || old.entrance != entrance;
}

// ─── Tarama Katmanı ──────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  final double t;
  _ScanOverlayPainter(this.t);

  static const _teal = Color(0xFF3DB88A);
  static const _gold = Color(0xFFC9A84C);

  @override
  void paint(Canvas canvas, Size size) {
    _drawScanLine(canvas, size);
    _drawCornerBrackets(canvas, size);
  }

  void _drawScanLine(Canvas canvas, Size size) {
    final progress = (t * 2.2) % 1.0;
    final scanY = progress * size.height;
    final fade = sin(progress * pi).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width / 2, scanY),
          width: size.width,
          height: 28),
      Paint()
        ..color = _teal.withValues(alpha: fade * 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      Paint()
        ..color = _teal.withValues(alpha: fade * 0.72)
        ..strokeWidth = 1.4,
    );
  }

  void _drawCornerBrackets(Canvas canvas, Size size) {
    final bp = Paint()
      ..color = _gold.withValues(alpha: 0.68)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final m = size.width * 0.10;
    final l = size.width * 0.07;

    final corners = [
      (Offset(m, m), 1.0, 1.0),
      (Offset(size.width - m, m), -1.0, 1.0),
      (Offset(m, size.height - m), 1.0, -1.0),
      (Offset(size.width - m, size.height - m), -1.0, -1.0),
    ];

    for (final (c, xd, yd) in corners) {
      canvas.drawLine(c, Offset(c.dx + l * xd, c.dy), bp);
      canvas.drawLine(c, Offset(c.dx, c.dy + l * yd), bp);
    }
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => old.t != t;
}
