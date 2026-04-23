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

// ─── Renk Paleti ─────────────────────────────────────────────────────────────
// Topkapı Sarayı el yazması paleti
const _bg       = Color(0xFFF3E8CE); // parşömen sarısı
const _parchment= Color(0xFFFBF4E6); // levha iç rengi
const _green    = Color(0xFF1B4B3E); // zümrüt yeşili
const _darkBg   = Color(0xFF071912); // gece siyahı
const _gold     = Color(0xFFC9A84C); // altın
const _indigo   = Color(0xFF1A3A5C); // lapis lazuli mavi

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
  late final AnimationController _ambientCtrl;
  late final AnimationController _tesbiCtrl;
  late final Animation<double> _shutterA;

  static const _switchDuration = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _shutterCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _mysticCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    _waveCtrl      = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _waveEnterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _ambientCtrl   = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _tesbiCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 9000));
    _shutterA      = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _shutterCtrl, curve: Curves.easeInOut));

    _cameraIndex = widget.cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (_cameraIndex == -1) _cameraIndex = 0;
    _initCamera(_cameraIndex);

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _audioPlayer.onPlayerComplete.listen((_) { if (mounted) _transitionToCamera(); });
  }

  Future<void> _transitionToCamera() async {
    _waveCtrl.stop(); _tesbiCtrl.stop();
    if (mounted) setState(() { _viewState = _ViewState.camera; _capturedPhotoBytes = null; });
  }

  Future<void> _shutterFlash() async { await _shutterCtrl.forward(); await _shutterCtrl.reverse(); }

  Future<void> _initCamera(int index) async {
    await _cameraController?.dispose();
    _cameraController = CameraController(widget.cameras[index], ResolutionPreset.medium, enableAudio: false);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    final current = widget.cameras[_cameraIndex].lensDirection;
    final target  = current == CameraLensDirection.front ? CameraLensDirection.back : CameraLensDirection.front;
    final idx = widget.cameras.indexWhere((c) => c.lensDirection == target);
    if (idx == -1) return;
    _cameraIndex = idx;
    await _initCamera(_cameraIndex);
  }

  Future<void> _exitApp() async {
    final confirmed = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _parchment,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _gold.withValues(alpha: 0.5), width: 1.2),
        ),
        title: const Text('Çıkış', style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
        content: const Text('Uygulamadan çıkmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hayır', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Evet'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _audioPlayer.stop(); await _cameraController?.dispose(); exit(0);
  }

  Future<void> _analyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isLoading || _viewState != _ViewState.camera) return;
    setState(() { _isLoading = true; _ayet = null; _capturedPhotoBytes = null; });
    try {
      await _shutterFlash();
      _mysticCtrl.repeat();
      final photoFuture = _cameraController!.takePicture();
      setState(() => _viewState = _ViewState.analyzing);
      final photo = await photoFuture;
      final bytes = await photo.readAsBytes();
      if (mounted) setState(() => _capturedPhotoBytes = bytes);
      final digest  = sha256.convert(bytes);
      final first8  = Uint8List.fromList(digest.bytes.sublist(0, 8));
      final hashInt = ByteData.sublistView(first8).getInt64(0, Endian.big).abs();
      final results  = await Future.wait([
        http.get(Uri.parse(ApiConfig.nazarEndpoint(hashInt))),
        Future.delayed(const Duration(milliseconds: 2200)),
      ]);
      final response = results[0] as http.Response;
      if (response.statusCode != 200) throw Exception('Sunucu hatası: ${response.statusCode}');
      final ayet = Ayet.fromJson(jsonDecode(response.body));
      _mysticCtrl.stop();
      _waveEnterCtrl.reset(); _waveCtrl.repeat(); _tesbiCtrl.repeat(); _waveEnterCtrl.forward();
      if (!mounted) return;
      setState(() { _ayet = ayet; _viewState = _ViewState.playing; _isLoading = false; });
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(ApiConfig.audioUrl(ayet.mp3Url)));
    } catch (e) {
      _mysticCtrl.stop();
      if (mounted) {
        setState(() { _isLoading = false; _viewState = _ViewState.camera; });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause(); _waveCtrl.stop(); _tesbiCtrl.stop();
    } else {
      await _audioPlayer.resume(); _waveCtrl.repeat(); _tesbiCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _shutterCtrl.dispose(); _mysticCtrl.dispose(); _waveCtrl.dispose();
    _waveEnterCtrl.dispose(); _ambientCtrl.dispose(); _tesbiCtrl.dispose();
    _cameraController?.dispose(); _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Katman 1: Parşömen arka plan + tezhip kenar süsleri
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ManuscriptBackgroundPainter(_ambientCtrl.value),
              ),
            ),
          ),
          // Katman 2: Cami silüeti (altta sabit)
          const Positioned(
            bottom: 0, left: 0, right: 0,
            child: CustomPaint(size: Size(double.infinity, 130), painter: _MosqueSilhouettePainter()),
          ),
          // Katman 3: İçerik
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildMainFrame(),
                  _buildButton(),
                  if (_viewState == _ViewState.playing) _buildTesbiRow(),
                  if (_ayet != null) _buildResultPanel(),
                  const SizedBox(height: 150),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Üst tezhip şeridi
        const CustomPaint(
          size: Size(double.infinity, 36),
          painter: _TezhipBandPainter(isTop: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _viewState == _ViewState.camera ? _switchCamera : null,
                icon: Icon(Icons.flip_camera_ios_rounded,
                    color: _viewState == _ViewState.camera ? _green : _green.withValues(alpha: 0.25),
                    size: 26),
              ),
              const Expanded(
                child: Column(children: [
                  Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, color: _gold, fontWeight: FontWeight.w600, height: 1.7)),
                  SizedBox(height: 2),
                  Text('Nazar  &  Ferahlama',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _green, letterSpacing: 2.2)),
                ]),
              ),
              IconButton(
                  onPressed: _exitApp,
                  icon: const Icon(Icons.close_rounded, color: _green, size: 26)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: CustomPaint(size: Size(double.infinity, 14), painter: _UnvanDividerPainter()),
        ),
      ],
    );
  }

  // ─── Ana Çerçeve ───────────────────────────────────────────────────────────

  Widget _buildMainFrame() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox(height: 320,
          child: Center(child: CircularProgressIndicator(color: _green)));
    }
    final ratio        = _cameraController!.value.aspectRatio;
    final portraitRatio = ratio < 1 ? ratio : 1 / ratio;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Şemse madalyonu (arka planda, kamera çerçevesinin arkasında)
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ShemseBackgroundPainter()),
            ),
          ),
          Column(
            children: [
              CustomPaint(
                size: Size(MediaQuery.of(context).size.width - 40, 48),
                painter: const _MukarnasPainter(isTop: true),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(color: _gold.withValues(alpha: 0.6), width: 1.5),
                  ),
                ),
                child: ClipRect(
                  child: AspectRatio(
                    aspectRatio: portraitRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: _switchDuration,
                          transitionBuilder: _frameCrossfade,
                          layoutBuilder: (cur, prev) => Stack(
                            fit: StackFit.expand,
                            children: [...prev, if (cur != null) cur],
                          ),
                          child: KeyedSubtree(key: ValueKey(_viewState), child: _buildFrameContent()),
                        ),
                        const IgnorePointer(child: CustomPaint(painter: _FrameCornerPainter())),
                        AnimatedBuilder(
                          animation: _shutterCtrl,
                          builder: (_, __) => _shutterA.value > 0
                              ? IgnorePointer(
                                  child: Opacity(opacity: _shutterA.value * 0.68,
                                      child: Container(color: Colors.white)))
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: Size(MediaQuery.of(context).size.width - 40, 48),
                painter: const _MukarnasPainter(isTop: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _frameCrossfade(Widget child, Animation<double> animation) {
    final blurA  = Tween<double>(begin: 10.0, end: 0.0)
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
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
            child: content);
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
        return Stack(fit: StackFit.expand, children: [
          if (_capturedPhotoBytes != null)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5, tileMode: TileMode.decal),
              child: Image.memory(_capturedPhotoBytes!, fit: BoxFit.cover))
          else
            Container(color: _darkBg),
          Container(color: _darkBg.withValues(alpha: 0.68)),
          AnimatedBuilder(
            animation: _mysticCtrl,
            builder: (_, __) => CustomPaint(painter: _MysticPainter(_mysticCtrl.value))),
          AnimatedBuilder(
            animation: _mysticCtrl,
            builder: (_, __) => CustomPaint(painter: _ScanOverlayPainter(_mysticCtrl.value))),
        ]);
      case _ViewState.playing:
        return Container(
          color: _darkBg,
          child: AnimatedBuilder(
            animation: Listenable.merge([_waveCtrl, _waveEnterCtrl]),
            builder: (_, __) => CustomPaint(
                painter: _WavePainter(_waveCtrl.value, _isPlaying, _waveEnterCtrl.value))));
    }
  }

  // ─── Buton ─────────────────────────────────────────────────────────────────

  Widget _buildButton() {
    final isWaving    = _viewState == _ViewState.playing;
    final isAnalyzing = _viewState == _ViewState.analyzing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_isLoading || isAnalyzing) ? null : (isWaving ? _toggleAudio : _analyze),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green, foregroundColor: Colors.white,
            disabledBackgroundColor: _green.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _gold.withValues(alpha: 0.55), width: 1.0),
            ),
            elevation: 0,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child),
            ),
            child: isAnalyzing
                ? const _AnalyzingIndicator(key: ValueKey('analyzing'))
                : Text(
                    isWaving ? (_isPlaying ? 'Duraklat' : 'Devam Et') : 'Nazarımı Oku  ✦  Analiz Et',
                    key: ValueKey('$isWaving$_isPlaying'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
          ),
        ),
      ),
    );
  }

  // ─── Tesbih ────────────────────────────────────────────────────────────────

  Widget _buildTesbiRow() {
    return TweenAnimationBuilder<double>(
      key: const ValueKey('tesbih'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
        child: SizedBox(
          height: 62,
          child: AnimatedBuilder(
            animation: _tesbiCtrl,
            builder: (_, __) => CustomPaint(painter: _TesbiPainter(_tesbiCtrl.value, _isPlaying)),
          ),
        ),
      ),
    );
  }

  // ─── Sonuç Paneli (Osmanlı Levhası) ───────────────────────────────────────

  Widget _buildResultPanel() {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_ayet?.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _parchment,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: _green.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
                  BoxShadow(color: _gold.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Levha başlık şeridi (tezhip)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    child: SizedBox(
                      height: 42,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: CustomPaint(painter: _LevhaHeaderPainter()),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(_ayet!.sureIsim,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                          color: _gold.withValues(alpha: 0.92), letterSpacing: 0.6)),
                                ),
                                IconButton(
                                  onPressed: _toggleAudio,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                      color: _gold, size: 34),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // İçerik
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_ayet!.arapca,
                            textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                            style: const TextStyle(fontSize: 24, height: 2.4, color: Color(0xFF1A1A1A))),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: CustomPaint(size: Size(double.infinity, 14), painter: _UnvanDividerPainter()),
                        ),
                        Text(_ayet!.meal,
                            style: const TextStyle(fontSize: 14, height: 1.85, color: Color(0xFF3D3420))),
                        const SizedBox(height: 8),
                        // Hatime (kapanış işareti)
                        const Center(
                          child: CustomPaint(size: Size(80, 14), painter: _HatimePainter()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Levha çerçeve süsü (overlay)
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _LevhaBorderPainter())),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTER SINIFLAR
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Analiz Göstergesi ────────────────────────────────────────────────────────
class _AnalyzingIndicator extends StatelessWidget {
  const _AnalyzingIndicator({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(height: 16, width: 16,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      SizedBox(width: 10),
      Text('Analiz ediliyor...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    ],
  );
}

// ─── El Yazması Arka Plan ─────────────────────────────────────────────────────
// Parşömen zemin + 8li yıldız kafes + tezhip kenar şeritleri + köşe rozetler

class _ManuscriptBackgroundPainter extends CustomPainter {
  final double t;
  _ManuscriptBackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _bg);
    _drawStarGrid(canvas, size);
    _drawTezhipMarginBands(canvas, size);
    _drawCornerRosettes(canvas, size);
  }

  void _drawStarGrid(Canvas canvas, Size size) {
    final linePaint = Paint()..color = _gold.withValues(alpha: 0.038 + 0.008 * t)..strokeWidth = 0.6;
    final starPaint = Paint()..color = _gold.withValues(alpha: 0.065 + 0.015 * t)..strokeWidth = 0.7..style = PaintingStyle.stroke;
    final indigoPaint = Paint()..color = _indigo.withValues(alpha: 0.035 + 0.008 * t)..style = PaintingStyle.fill;

    const step = 54.0;
    final cols = (size.width / step).ceil() + 2;
    final rows = (size.height / step).ceil() + 2;
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * step + (row.isOdd ? step / 2 : 0);
        final cy = row * step * 0.866;
        canvas.drawLine(Offset(cx, cy), Offset(cx + step, cy), linePaint);
        canvas.drawLine(Offset(cx, cy), Offset(cx + step / 2, cy + step * 0.433), linePaint);
        canvas.drawLine(Offset(cx, cy), Offset(cx - step / 2, cy + step * 0.433), linePaint);
        _drawStar(canvas, Offset(cx, cy), step * 0.20, starPaint, indigoPaint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint stroke, Paint fill) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a = i * pi / 8 - pi / 2;
      final radius = i.isEven ? r : r * 0.42;
      final pt = Offset(c.dx + radius * cos(a), c.dy + radius * sin(a));
      if (i == 0) { path.moveTo(pt.dx, pt.dy); } else { path.lineTo(pt.dx, pt.dy); }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  // Tezhip kenar şeritleri — tüm 4 kenarda dar, yoğun süslü bant
  void _drawTezhipMarginBands(Canvas canvas, Size size) {
    const bandW = 22.0;
    final pulse = 0.55 + 0.12 * t;

    final stemPaint  = Paint()..color = _gold.withValues(alpha: pulse * 0.38)..strokeWidth = 0.9..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final leafFill   = Paint()..color = _gold.withValues(alpha: pulse * 0.18)..style = PaintingStyle.fill;
    final indigoFill = Paint()..color = _indigo.withValues(alpha: pulse * 0.18)..style = PaintingStyle.fill;

    // Sol şerit
    _drawVerticalHatai(canvas, 0, bandW, size.height, stemPaint, leafFill, indigoFill);
    // Sağ şerit
    canvas.save(); canvas.translate(size.width, 0); canvas.scale(-1, 1);
    _drawVerticalHatai(canvas, 0, bandW, size.height, stemPaint, leafFill, indigoFill);
    canvas.restore();

    // Sol/sağ dış çizgi
    final borderPaint = Paint()..color = _gold.withValues(alpha: 0.45)..strokeWidth = 1.0;
    canvas.drawLine(const Offset(bandW, 0), Offset(bandW, size.height), borderPaint);
    canvas.drawLine(Offset(size.width - bandW, 0), Offset(size.width - bandW, size.height), borderPaint);
  }

  void _drawVerticalHatai(Canvas canvas, double x, double w, double h,
      Paint stem, Paint leaf, Paint indigoFill) {
    final cx = x + w / 2;
    const unit = 30.0;
    final count = (h / unit).ceil() + 1;

    final path = Path()..moveTo(cx, 0);
    for (int i = 0; i < count; i++) {
      final y = i * unit.toDouble();
      final flip = i.isEven ? 1.0 : -1.0;
      path.cubicTo(cx + flip * w * 0.4, y + unit * 0.25,
          cx - flip * w * 0.4, y + unit * 0.75, cx, y + unit);
    }
    canvas.drawPath(path, stem);

    for (int i = 0; i < count; i++) {
      final y    = i * unit + unit * 0.5;
      final flip = i.isEven ? 1.0 : -1.0;
      final lx   = cx + flip * w * 0.38;
      final paint = i.isEven ? leaf : indigoFill;
      _drawPetal(canvas, Offset(lx, y), flip * pi / 2, 5.5, paint);
      canvas.drawCircle(Offset(cx, y), 1.8, leaf);
    }
  }

  void _drawPetal(Canvas canvas, Offset c, double angle, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx + r * cos(angle), c.dy + r * sin(angle))
      ..quadraticBezierTo(c.dx + r * 0.6 * cos(angle + pi / 2), c.dy + r * 0.6 * sin(angle + pi / 2),
          c.dx - r * 0.5 * cos(angle), c.dy - r * 0.5 * sin(angle))
      ..quadraticBezierTo(c.dx + r * 0.6 * cos(angle - pi / 2), c.dy + r * 0.6 * sin(angle - pi / 2),
          c.dx + r * cos(angle), c.dy + r * sin(angle))
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawCornerRosettes(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.1 * t;
    final outer = Paint()..color = _gold.withValues(alpha: pulse * 0.22)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final fill  = Paint()..color = _gold.withValues(alpha: pulse * 0.07);
    final ifill = Paint()..color = _indigo.withValues(alpha: pulse * 0.08);

    for (final c in [const Offset(0, 0), Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)]) {
      const R = 72.0;
      canvas.drawCircle(c, R, outer);
      for (int i = 0; i < 8; i++) {
        final a  = i * pi / 4;
        final cc = Offset(c.dx + R * 0.5 * cos(a), c.dy + R * 0.5 * sin(a));
        canvas.drawCircle(cc, R * 0.5, outer);
        canvas.drawCircle(cc, R * 0.5, i.isEven ? fill : ifill);
      }
      _drawStar(canvas, c, R * 0.25, outer, ifill);
    }
  }

  @override
  bool shouldRepaint(_ManuscriptBackgroundPainter old) => old.t != t;
}

// ─── Tezhip Başlık Şeridi ─────────────────────────────────────────────────────
// Osmanlı el yazması serlevha/unvan bandı

class _TezhipBandPainter extends CustomPainter {
  final bool isTop;
  const _TezhipBandPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isTop) { canvas.save(); canvas.translate(0, size.height); canvas.scale(1, -1); }

    // Zemin
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _green);

    // Üst/alt altın çizgiler
    final borderLine = Paint()..color = _gold.withValues(alpha: 0.85)..strokeWidth = 1.2;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), borderLine);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), borderLine);

    // İkinci iç çizgi
    final innerLine = Paint()..color = _gold.withValues(alpha: 0.35)..strokeWidth = 0.7;
    canvas.drawLine(const Offset(0, 3.5), Offset(size.width, 3.5), innerLine);
    canvas.drawLine(Offset(0, size.height - 3.5), Offset(size.width, size.height - 3.5), innerLine);

    final cy = size.height / 2;
    const unit = 18.0;
    final count = (size.width / unit).ceil() + 2;
    final lotusF = Paint()..color = _gold.withValues(alpha: 0.52)..style = PaintingStyle.fill;
    final lotusS = Paint()..color = _gold.withValues(alpha: 0.75)..strokeWidth = 0.7..style = PaintingStyle.stroke;
    final indigoF = Paint()..color = _indigo.withValues(alpha: 0.60)..style = PaintingStyle.fill;

    // Merkez unvan madalyonu
    final mcx = size.width / 2;
    _drawUnvanMedallion(canvas, Offset(mcx, cy), size.height * 0.36, lotusF, lotusS);

    // Tekrarlayan rumi + lotus motif zinciri
    for (int i = 0; i < count; i++) {
      final x = i * unit - unit / 2;
      if ((x - mcx).abs() < 32) continue; // merkez madalyon alanını boş bırak

      if (i.isEven) {
        // Yukarı lotus
        _drawLotus(canvas, Offset(x, cy - 2), size.height * 0.28, lotusF, lotusS);
      } else {
        // Aşağı rumi
        _drawRumi(canvas, Offset(x, cy + 2), size.height * 0.26, indigoF, lotusS);
      }
      // Bağlantı noktası
      canvas.drawCircle(Offset(x, cy), 1.5, lotusF);
    }

    // Yatay merkez çizgi
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy),
        Paint()..color = _gold.withValues(alpha: 0.20)..strokeWidth = 0.6);

    if (!isTop) canvas.restore();
  }

  void _drawUnvanMedallion(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 3.4, height: r * 2),
        Paint()..color = _gold.withValues(alpha: 0.18));
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 3.4, height: r * 2), stroke);
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 2.8, height: r * 1.4), stroke);
    // İç 6-kollu yıldız
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      canvas.drawLine(
          Offset(c.dx + r * 0.3 * cos(a), c.dy + r * 0.3 * sin(a)),
          Offset(c.dx + r * 0.7 * cos(a), c.dy + r * 0.7 * sin(a)), stroke);
    }
    canvas.drawCircle(c, r * 0.22, fill);
  }

  void _drawLotus(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    for (int i = 0; i < 5; i++) {
      final a = -pi / 2 + (i - 2) * pi / 5;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(c.dx + r * 0.55 * cos(a - 0.25), c.dy + r * 0.55 * sin(a - 0.25),
            c.dx + r * 0.85 * cos(a), c.dy + r * 0.85 * sin(a) - r * 0.1,
            c.dx + r * cos(a), c.dy + r * sin(a))
        ..cubicTo(c.dx + r * 0.85 * cos(a), c.dy + r * 0.85 * sin(a) + r * 0.1,
            c.dx + r * 0.55 * cos(a + 0.25), c.dy + r * 0.55 * sin(a + 0.25),
            c.dx, c.dy)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
    canvas.drawCircle(c, r * 0.18, fill);
  }

  void _drawRumi(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    for (final dir in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(c.dx + dir * r * 0.5, c.dy + r * 0.2,
            c.dx + dir * r * 0.7, c.dy + r * 0.7,
            c.dx + dir * r * 0.3, c.dy + r)
        ..cubicTo(c.dx - dir * r * 0.2, c.dy + r * 0.8,
            c.dx - dir * r * 0.1, c.dy + r * 0.3,
            c.dx, c.dy)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_TezhipBandPainter old) => false;
}

// ─── Şemse Madalyonu ──────────────────────────────────────────────────────────
// Kamera çerçevesinin arkasında büyük, çok katmanlı Ottoman madalyonu

class _ShemseBackgroundPainter extends CustomPainter {
  const _ShemseBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final c  = Offset(cx, cy);
    final maxR = min(cx, cy) * 0.92;

    final goldStroke = Paint()..color = _gold.withValues(alpha: 0.07)..strokeWidth = 1.0..style = PaintingStyle.stroke;
    final goldFill   = Paint()..color = _gold.withValues(alpha: 0.05)..style = PaintingStyle.fill;
    final indigoS    = Paint()..color = _indigo.withValues(alpha: 0.06)..strokeWidth = 0.8..style = PaintingStyle.stroke;

    // Halka 5: dış çember + 8 ışın
    canvas.drawCircle(c, maxR, goldStroke);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(Offset(cx + maxR * 0.88 * cos(a), cy + maxR * 0.88 * sin(a)),
          Offset(cx + maxR * cos(a), cy + maxR * sin(a)), goldStroke);
    }

    // Halka 4: 16-nokta yörüngesi
    for (int i = 0; i < 16; i++) {
      final a = i * 2 * pi / 16;
      canvas.drawCircle(Offset(cx + maxR * 0.75 * cos(a), cy + maxR * 0.75 * sin(a)),
          3.0, i.isEven ? goldFill : Paint()..color = _indigo.withValues(alpha: 0.06));
    }
    canvas.drawCircle(c, maxR * 0.75, goldStroke);

    // Halka 3: arabeski halka + eşkenar dörtgen motifleri
    canvas.drawCircle(c, maxR * 0.58, indigoS);
    for (int i = 0; i < 12; i++) {
      final a  = i * pi / 6;
      final dc = Offset(cx + maxR * 0.58 * cos(a), cy + maxR * 0.58 * sin(a));
      final s  = maxR * 0.055;
      final path = Path()
        ..moveTo(dc.dx + s * cos(a), dc.dy + s * sin(a))
        ..lineTo(dc.dx + s * cos(a + pi / 2) * 0.5, dc.dy + s * sin(a + pi / 2) * 0.5)
        ..lineTo(dc.dx - s * cos(a), dc.dy - s * sin(a))
        ..lineTo(dc.dx - s * cos(a + pi / 2) * 0.5, dc.dy - s * sin(a + pi / 2) * 0.5)
        ..close();
      canvas.drawPath(path, goldFill);
      canvas.drawPath(path, goldStroke);
    }

    // Halka 2: 16-köşeli dış şemse yıldızı
    _drawShemse(canvas, c, maxR * 0.42, maxR * 0.18, goldStroke, goldFill);

    // Halka 1: 8-köşeli iç yıldız (lapis dolgulu)
    _drawShemse(canvas, c, maxR * 0.24, maxR * 0.10,
        Paint()..color = _indigo.withValues(alpha: 0.07)..strokeWidth = 1.0..style = PaintingStyle.stroke,
        Paint()..color = _indigo.withValues(alpha: 0.055));

    // Merkez halka
    canvas.drawCircle(c, maxR * 0.08,
        Paint()..color = _gold.withValues(alpha: 0.06)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(c, maxR * 0.04, goldFill);
  }

  void _drawShemse(Canvas canvas, Offset c, double outerR, double innerR, Paint stroke, Paint fill) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a  = i * pi / 8 - pi / 2;
      final r  = i.isEven ? outerR : innerR;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) { path.moveTo(pt.dx, pt.dy); } else { path.lineTo(pt.dx, pt.dy); }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ShemseBackgroundPainter old) => false;
}

// ─── Cami Silüeti ─────────────────────────────────────────────────────────────

class _MosqueSilhouettePainter extends CustomPainter {
  const _MosqueSilhouettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final paint = Paint()..color = _green.withValues(alpha: 0.11)..style = PaintingStyle.fill;
    final wallY = h * 0.48;

    final lmCx = w * 0.09; final lmHw = w * 0.025; final lmTop = h * 0.03;
    final ldCx = w * 0.24; final ldR  = w * 0.082;
    final cdCx = w * 0.50; final cdR  = w * 0.165;
    final rdCx = w * 0.76; final rdR  = w * 0.082;
    final rmCx = w * 0.91; final rmHw = w * 0.025; final rmTop = h * 0.03;

    final path = Path()
      ..moveTo(0, h)..lineTo(0, wallY)
      ..lineTo(lmCx - lmHw, wallY)..lineTo(lmCx - lmHw, lmTop + 8)
      ..quadraticBezierTo(lmCx - lmHw, lmTop, lmCx, lmTop - 5)
      ..quadraticBezierTo(lmCx + lmHw, lmTop, lmCx + lmHw, lmTop + 8)
      ..lineTo(lmCx + lmHw, wallY)
      ..lineTo(ldCx - ldR, wallY)
      ..arcToPoint(Offset(ldCx + ldR, wallY), radius: Radius.circular(ldR), clockwise: false)
      ..lineTo(cdCx - cdR, wallY)
      ..arcToPoint(Offset(cdCx + cdR, wallY), radius: Radius.circular(cdR), clockwise: false)
      ..lineTo(rdCx - rdR, wallY)
      ..arcToPoint(Offset(rdCx + rdR, wallY), radius: Radius.circular(rdR), clockwise: false)
      ..lineTo(rmCx - rmHw, wallY)..lineTo(rmCx - rmHw, rmTop + 8)
      ..quadraticBezierTo(rmCx - rmHw, rmTop, rmCx, rmTop - 5)
      ..quadraticBezierTo(rmCx + rmHw, rmTop, rmCx + rmHw, rmTop + 8)
      ..lineTo(rmCx + rmHw, wallY)
      ..lineTo(w, wallY)..lineTo(w, h)..close();

    canvas.drawPath(path, paint);
    _drawCrescent(canvas, Offset(lmCx, lmTop - 8), h * 0.032);
    _drawCrescent(canvas, Offset(rmCx, rmTop - 8), h * 0.032);
    _drawCrescent(canvas, Offset(cdCx, wallY - cdR - h * 0.04), h * 0.050);
  }

  void _drawCrescent(Canvas canvas, Offset c, double r) {
    final p  = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final p2 = Path()..addOval(Rect.fromCircle(center: Offset(c.dx + r * 0.38, c.dy), radius: r * 0.78));
    canvas.drawPath(Path.combine(PathOperation.difference, p, p2),
        Paint()..color = _green.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(_MosqueSilhouettePainter old) => false;
}

// ─── Mukarnas Kemeri ──────────────────────────────────────────────────────────

class _MukarnasPainter extends CustomPainter {
  final bool isTop;
  const _MukarnasPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    if (!isTop) { canvas.save(); canvas.translate(0, h); canvas.scale(1, -1); }

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _bg);

    const niches = 7;
    final nw = w / niches;
    for (int i = 0; i < niches; i++) { _drawNiche(canvas, i * nw, nw, h); }

    // Üst yatay çizgiler
    canvas.drawLine(const Offset(0, 1), Offset(w, 1),
        Paint()..color = _gold.withValues(alpha: 0.75)..strokeWidth = 1.3);
    canvas.drawLine(const Offset(0, 4), Offset(w, 4),
        Paint()..color = _gold.withValues(alpha: 0.30)..strokeWidth = 0.7);

    // Merkez rozet
    _drawMiniRosette(canvas, Offset(w / 2, h * 0.38), h * 0.22);

    if (!isTop) canvas.restore();
  }

  void _drawNiche(Canvas canvas, double x, double nw, double h) {
    final cx    = x + nw / 2;
    final archW = nw * 0.88;

    // 3D etki: degrade dolgu (açık üst → koyu alt)
    final gradRect = Rect.fromLTWH(cx - archW / 2, 0, archW, h);
    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_gold.withValues(alpha: 0.18), _gold.withValues(alpha: 0.05)],
      ).createShader(gradRect)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(cx - archW / 2, h)
      ..quadraticBezierTo(cx - archW / 2, h * 0.15, cx, h * 0.04)
      ..quadraticBezierTo(cx + archW / 2, h * 0.15, cx + archW / 2, h)
      ..close();
    canvas.drawPath(path, gradPaint);
    canvas.drawPath(path, Paint()..color = _gold.withValues(alpha: 0.70)..strokeWidth = 1.2..style = PaintingStyle.stroke);

    // İç küçük kemer
    final iw = archW * 0.60;
    final innerPath = Path()
      ..moveTo(cx - iw / 2, h)
      ..quadraticBezierTo(cx - iw / 2, h * 0.28, cx, h * 0.16)
      ..quadraticBezierTo(cx + iw / 2, h * 0.28, cx + iw / 2, h);
    canvas.drawPath(innerPath, Paint()..color = _indigo.withValues(alpha: 0.40)..strokeWidth = 0.8..style = PaintingStyle.stroke);

    // Kilit taşı — 4 yapraklı çiçek
    _drawKeystoneFlower(canvas, Offset(cx, h * 0.09), h * 0.055);

    // Gölge çizgisi (kemer tabanı)
    canvas.drawLine(Offset(x, h - 1), Offset(x + nw, h - 1),
        Paint()..color = _gold.withValues(alpha: 0.22)..strokeWidth = 1.5);
    canvas.drawLine(Offset(x, 0), Offset(x, h),
        Paint()..color = _gold.withValues(alpha: 0.55)..strokeWidth = 1.0);
  }

  void _drawKeystoneFlower(Canvas canvas, Offset c, double r) {
    final fillPaint = Paint()..color = _gold.withValues(alpha: 0.75);
    final strokeP   = Paint()..color = _gold.withValues(alpha: 0.90)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(c.dx + r * 0.5 * cos(a - 0.4), c.dy + r * 0.5 * sin(a - 0.4),
            c.dx + r * cos(a), c.dy + r * sin(a) - r * 0.1,
            c.dx + r * cos(a), c.dy + r * sin(a))
        ..cubicTo(c.dx + r * cos(a), c.dy + r * sin(a) + r * 0.1,
            c.dx + r * 0.5 * cos(a + 0.4), c.dy + r * 0.5 * sin(a + 0.4),
            c.dx, c.dy)
        ..close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokeP);
    }
    canvas.drawCircle(c, r * 0.2, Paint()..color = _gold);
  }

  void _drawMiniRosette(Canvas canvas, Offset c, double r) {
    final p = Paint()..color = _gold.withValues(alpha: 0.55)..strokeWidth = 1.0..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r, p); canvas.drawCircle(c, r * 0.45, p);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(c, Offset(c.dx + r * cos(a), c.dy + r * sin(a)), p);
    }
    canvas.drawCircle(c, r * 0.16, Paint()..color = _gold.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_MukarnasPainter old) => false;
}

// ─── Çerçeve Köşe Süsü ────────────────────────────────────────────────────────

class _FrameCornerPainter extends CustomPainter {
  const _FrameCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 24.0;
    for (final (c, xd, yd) in [
      (Offset.zero, 1.0, 1.0),
      (Offset(size.width, 0), -1.0, 1.0),
      (Offset(0, size.height), 1.0, -1.0),
      (Offset(size.width, size.height), -1.0, -1.0),
    ]) {
      final p1 = Paint()..color = _gold.withValues(alpha: 0.8)..strokeWidth = 1.8..style = PaintingStyle.stroke;
      canvas.drawLine(c, Offset(c.dx + arm * xd, c.dy), p1);
      canvas.drawLine(c, Offset(c.dx, c.dy + arm * yd), p1);
      // Altın köşe noktası (dolgulu)
      canvas.drawCircle(Offset(c.dx + 5.5 * xd, c.dy + 5.5 * yd), 3.2, Paint()..color = _gold);
      canvas.drawCircle(Offset(c.dx + 5.5 * xd, c.dy + 5.5 * yd), 1.4, Paint()..color = _indigo.withValues(alpha: 0.7));
      // İkinci küçük L
      final p2 = Paint()..color = _gold.withValues(alpha: 0.38)..strokeWidth = 1.0..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(c.dx + 7 * xd, c.dy + 7 * yd), Offset(c.dx + 15 * xd, c.dy + 7 * yd), p2);
      canvas.drawLine(Offset(c.dx + 7 * xd, c.dy + 7 * yd), Offset(c.dx + 7 * xd, c.dy + 15 * yd), p2);
    }
  }

  @override
  bool shouldRepaint(_FrameCornerPainter old) => false;
}

// ─── Unvan Ayırıcı ────────────────────────────────────────────────────────────

class _UnvanDividerPainter extends CustomPainter {
  const _UnvanDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;

    // Ana çizgiler
    final lp = Paint()..color = _gold.withValues(alpha: 0.55)..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, cy), Offset(cx - 22, cy), lp);
    canvas.drawLine(Offset(cx + 22, cy), Offset(size.width, cy), lp);
    // İkincil çizgiler (hafif)
    final lp2 = Paint()..color = _gold.withValues(alpha: 0.22)..strokeWidth = 0.6;
    canvas.drawLine(Offset(0, cy - 3), Offset(cx - 22, cy - 3), lp2);
    canvas.drawLine(Offset(cx + 22, cy - 3), Offset(size.width, cy - 3), lp2);
    canvas.drawLine(Offset(0, cy + 3), Offset(cx + 22, cy + 3), lp2);
    canvas.drawLine(Offset(cx + 22, cy + 3), Offset(size.width, cy + 3), lp2);

    // Merkez kompozit madalyon
    // Altın elmas
    final diamond = Path()
      ..moveTo(cx, cy - 6)..lineTo(cx + 10, cy)..lineTo(cx, cy + 6)..lineTo(cx - 10, cy)..close();
    canvas.drawPath(diamond, Paint()..color = _gold.withValues(alpha: 0.65));
    canvas.drawPath(diamond, Paint()..color = _green.withValues(alpha: 0.4)..strokeWidth = 0.8..style = PaintingStyle.stroke);
    // Merkez lapis noktası
    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = _indigo.withValues(alpha: 0.8));
    // Yan noktalar
    for (final dx in [-16.0, 16.0]) {
      canvas.drawCircle(Offset(cx + dx, cy), 2.0, Paint()..color = _gold.withValues(alpha: 0.70));
    }
    for (final dx in [-27.0, 27.0]) {
      canvas.drawCircle(Offset(cx + dx, cy), 1.4, Paint()..color = _gold.withValues(alpha: 0.45));
    }
  }

  @override
  bool shouldRepaint(_UnvanDividerPainter old) => false;
}

// ─── Levha Başlık Süsü ────────────────────────────────────────────────────────

class _LevhaHeaderPainter extends CustomPainter {
  const _LevhaHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Koyu yeşil zemin
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _green);

    // Alt altın şerit + lapis çizgi
    canvas.drawRect(Rect.fromLTWH(0, size.height - 3, size.width, 1.5),
        Paint()..color = _gold.withValues(alpha: 0.85));
    canvas.drawRect(Rect.fromLTWH(0, size.height - 1.5, size.width, 1.5),
        Paint()..color = _indigo.withValues(alpha: 0.45));

    // Tekrarlayan rumi zinciri
    final cy = size.height / 2 - 1;
    const unit = 20.0;
    final count = (size.width / unit).ceil() + 1;
    final gf = Paint()..color = _gold.withValues(alpha: 0.32)..style = PaintingStyle.fill;
    final gs = Paint()..color = _gold.withValues(alpha: 0.55)..strokeWidth = 0.7..style = PaintingStyle.stroke;

    for (int i = 0; i < count; i++) {
      final x = i * unit;
      _drawSmallLotus(canvas, Offset(x, cy), size.height * 0.28, gf, gs);
    }

    // Yatay merkez çizgi
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy),
        Paint()..color = _gold.withValues(alpha: 0.18)..strokeWidth = 0.5);
  }

  void _drawSmallLotus(Canvas canvas, Offset c, double r, Paint fill, Paint stroke) {
    for (int i = 0; i < 3; i++) {
      final a = -pi / 2 + (i - 1) * pi / 3.5;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(c.dx + r * 0.5 * cos(a - 0.3), c.dy + r * 0.5 * sin(a - 0.3),
            c.dx + r * cos(a), c.dy + r * sin(a), c.dx + r * cos(a), c.dy + r * sin(a))
        ..cubicTo(c.dx + r * cos(a), c.dy + r * sin(a),
            c.dx + r * 0.5 * cos(a + 0.3), c.dy + r * 0.5 * sin(a + 0.3), c.dx, c.dy)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_LevhaHeaderPainter old) => false;
}

// ─── Levha Çerçeve Süsü ───────────────────────────────────────────────────────

class _LevhaBorderPainter extends CustomPainter {
  const _LevhaBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const m  = 4.0; const m2 = 10.0; const cr = 17.0; const cr2 = 13.0;
    final outer = Paint()..color = _gold.withValues(alpha: 0.65)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final inner = Paint()..color = _indigo.withValues(alpha: 0.22)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    final mid   = Paint()..color = _gold.withValues(alpha: 0.20)..strokeWidth = 0.7..style = PaintingStyle.stroke;

    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(m, m, size.width - 2*m, size.height - 2*m), const Radius.circular(cr)), outer);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(m2, m2, size.width - 2*m2, size.height - 2*m2), const Radius.circular(cr2)), inner);
    // Orta ara çizgi
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH((m+m2)/2, (m+m2)/2, size.width - (m+m2), size.height - (m+m2)),
        const Radius.circular((cr+cr2)/2)), mid);

    // Köşe rozetleri (dış + iç çember + 8-kollu yıldız)
    for (final (cx, cy) in [
      (m + cr, m + cr),
      (size.width - m - cr, m + cr),
      (m + cr, size.height - m - cr),
      (size.width - m - cr, size.height - m - cr),
    ]) {
      final c = Offset(cx, cy);
      canvas.drawCircle(c, 8, outer);
      canvas.drawCircle(c, 3, Paint()..color = _indigo.withValues(alpha: 0.55));
      canvas.drawCircle(c, 1.5, Paint()..color = _gold.withValues(alpha: 0.85));
      for (int i = 0; i < 8; i++) {
        final a = i * pi / 4;
        canvas.drawLine(Offset(c.dx + 3.5 * cos(a), c.dy + 3.5 * sin(a)),
            Offset(c.dx + 8 * cos(a), c.dy + 8 * sin(a)), outer);
      }
    }

    // Üst/alt yaprak-lotus sırası (iki çizgi arasında)
    _drawLeafRow(canvas, size, outer);
  }

  void _drawLeafRow(Canvas canvas, Size size, Paint paint) {
    const spacing = 20.0;
    final count = (size.width / spacing).floor();
    for (int i = 2; i < count - 1; i++) {
      final x = i * spacing;
      // Üst
      _drawLeafMotif(canvas, Offset(x, 7), pi / 2, paint);
      // Alt
      _drawLeafMotif(canvas, Offset(x, size.height - 7), -pi / 2, paint);
    }
  }

  void _drawLeafMotif(Canvas canvas, Offset c, double angle, Paint paint) {
    const len = 3.8; const hw = 2.0;
    final path = Path()
      ..moveTo(c.dx + len * cos(angle), c.dy + len * sin(angle))
      ..quadraticBezierTo(c.dx + hw * cos(angle + pi / 2), c.dy + hw * sin(angle + pi / 2),
          c.dx - len * 0.5 * cos(angle), c.dy - len * 0.5 * sin(angle))
      ..quadraticBezierTo(c.dx + hw * cos(angle - pi / 2), c.dy + hw * sin(angle - pi / 2),
          c.dx + len * cos(angle), c.dy + len * sin(angle))
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LevhaBorderPainter old) => false;
}

// ─── Hatime (Kapanış İşareti) ─────────────────────────────────────────────────

class _HatimePainter extends CustomPainter {
  const _HatimePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final gp = Paint()..color = _gold.withValues(alpha: 0.55)..strokeWidth = 0.9..style = PaintingStyle.stroke;
    final gf = Paint()..color = _gold.withValues(alpha: 0.45);
    final ip = Paint()..color = _indigo.withValues(alpha: 0.50);

    // Merkez çiçek
    canvas.drawCircle(Offset(cx, cy), 5, gp);
    canvas.drawCircle(Offset(cx, cy), 2, gf);
    canvas.drawCircle(Offset(cx, cy), 1, ip);
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      canvas.drawLine(Offset(cx + 2.5 * cos(a), cy + 2.5 * sin(a)),
          Offset(cx + 5 * cos(a), cy + 5 * sin(a)), gp);
    }
    // Yan noktalar
    for (final dx in [-12.0, -8.0, 8.0, 12.0]) {
      canvas.drawCircle(Offset(cx + dx, cy), dx.abs() > 10 ? 1.2 : 1.8, dx.abs() > 10 ? gf : ip);
    }
    // Çizgiler
    canvas.drawLine(Offset(0, cy), Offset(cx - 14, cy), gp);
    canvas.drawLine(Offset(cx + 14, cy), Offset(size.width, cy), gp);
  }

  @override
  bool shouldRepaint(_HatimePainter old) => false;
}

// ─── Tesbih ────────────────────────────────────────────────────────────────────

class _TesbiPainter extends CustomPainter {
  final double t;
  final bool isPlaying;
  _TesbiPainter(this.t, this.isPlaying);

  @override
  void paint(Canvas canvas, Size size) {
    const beadCount = 33;
    final cx = size.width / 2; final cy = size.height * 0.62;
    final arcW = size.width * 0.84;

    final positions = <Offset>[];
    for (int i = 0; i < beadCount; i++) {
      final pct  = i / (beadCount - 1);
      final x    = cx - arcW / 2 + pct * arcW;
      final norm = 2 * pct - 1;
      positions.add(Offset(x, cy - size.height * 0.28 * (1 - norm * norm)));
    }

    // İp
    final strPath = Path()..moveTo(positions[0].dx, positions[0].dy);
    for (int i = 1; i < beadCount; i++) { strPath.lineTo(positions[i].dx, positions[i].dy); }
    canvas.drawPath(strPath, Paint()..color = _gold.withValues(alpha: 0.28)..strokeWidth = 0.9..style = PaintingStyle.stroke);

    // Kuyruk
    final imp = positions[16];
    canvas.drawLine(imp, Offset(imp.dx, imp.dy + 14),
        Paint()..color = _gold.withValues(alpha: 0.40)..strokeWidth = 1.4..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(imp.dx, imp.dy + 17), 2.8, Paint()..color = _gold.withValues(alpha: 0.55));

    final activeBead = isPlaying ? (t * beadCount).floor() % beadCount : -1;

    for (int i = 0; i < beadCount; i++) {
      final pos      = positions[i];
      final isImame  = i == 16;
      final isDurak  = i == 5 || i == 27;
      final r        = isImame ? 6.5 : (isDurak ? 5.0 : 3.8);
      final isActive = i == activeBead;

      if (isActive) {
        canvas.drawCircle(pos, r + 5, Paint()
          ..color = _gold.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }

      canvas.drawCircle(pos, r, Paint()
        ..color = isImame ? _gold : (isDurak ? _green : _green.withValues(alpha: 0.72)));
      canvas.drawCircle(pos, r, Paint()
        ..color = _gold.withValues(alpha: isActive ? 0.95 : 0.55)
        ..strokeWidth = isImame ? 1.2 : 0.8..style = PaintingStyle.stroke);

      if (isImame) {
        for (int s = 0; s < 6; s++) {
          final a = s * pi / 3;
          canvas.drawLine(
              Offset(pos.dx + 1.5 * cos(a), pos.dy + 1.5 * sin(a)),
              Offset(pos.dx + 4.5 * cos(a), pos.dy + 4.5 * sin(a)),
              Paint()..color = _indigo.withValues(alpha: 0.65)..strokeWidth = 0.9);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TesbiPainter old) => old.t != t || old.isPlaying != isPlaying;
}

// ─── Mistik Animasyon ─────────────────────────────────────────────────────────

class _MysticPainter extends CustomPainter {
  final double t;
  _MysticPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final center = Offset(cx, cy); final maxR = min(cx, cy) * 0.88;
    _drawLightBeams(canvas, center, maxR, t * 2 * pi * 0.12);
    _drawOrbitDots(canvas, center, maxR * 0.88, -t * 2 * pi * 0.25, 16);
    _drawArabesqueRing(canvas, center, maxR * 0.66, t * 2 * pi * 0.18);
    _drawStar(canvas, center, maxR * 0.44, maxR * 0.19, -t * 2 * pi * 0.45, filled: false);
    _drawStar(canvas, center, maxR * 0.23, maxR * 0.10, t * 2 * pi * 0.9, filled: true);
    _drawCenter(canvas, center, maxR);
  }

  void _drawLightBeams(Canvas canvas, Offset c, double r, double rot) {
    for (int i = 0; i < 8; i++) {
      final a = rot + i * pi / 4;
      final alpha = 0.035 + 0.025 * sin(t * 2 * pi + i * pi / 4).abs();
      canvas.drawPath(
          Path()..moveTo(c.dx, c.dy)
            ..lineTo(c.dx + r * cos(a - 0.13), c.dy + r * sin(a - 0.13))
            ..lineTo(c.dx + r * cos(a + 0.13), c.dy + r * sin(a + 0.13))..close(),
          Paint()..color = _gold.withValues(alpha: alpha));
    }
  }

  void _drawOrbitDots(Canvas canvas, Offset c, double r, double rot, int count) {
    for (int i = 0; i < count; i++) {
      final a = rot + i * 2 * pi / count; final large = i.isEven;
      final pulse = large ? 1.0 + 0.2 * sin(t * 2 * pi * 2 + i * 0.8) : 1.0;
      canvas.drawCircle(Offset(c.dx + r * cos(a), c.dy + r * sin(a)),
          (large ? 3.2 : 1.8) * pulse,
          Paint()..color = (large ? _gold : _indigo).withValues(alpha: large ? 0.85 : 0.55));
    }
  }

  void _drawArabesqueRing(Canvas canvas, Offset c, double r, double rot) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3DB88A).withValues(alpha: 0.12)..strokeWidth = 1.0..style = PaintingStyle.stroke);
    final sp = Paint()..color = const Color(0xFF3DB88A).withValues(alpha: 0.55)..strokeWidth = 1.4..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final a = rot + i * pi / 4; final dc = Offset(c.dx + r * cos(a), c.dy + r * sin(a)); final s = r * 0.14;
      canvas.drawPath(
          Path()..moveTo(dc.dx + s * cos(a), dc.dy + s * sin(a))
            ..lineTo(dc.dx + s * cos(a + pi / 2) * 0.55, dc.dy + s * sin(a + pi / 2) * 0.55)
            ..lineTo(dc.dx - s * cos(a), dc.dy - s * sin(a))
            ..lineTo(dc.dx - s * cos(a + pi / 2) * 0.55, dc.dy - s * sin(a + pi / 2) * 0.55)..close(),
          sp);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double outerR, double innerR, double rot, {required bool filled}) {
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final a = rot + i * pi / 8 - pi / 2; final r = i.isEven ? outerR : innerR;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) { path.moveTo(pt.dx, pt.dy); } else { path.lineTo(pt.dx, pt.dy); }
    }
    path.close();
    if (filled) {
      canvas.drawPath(path, Paint()..color = _gold.withValues(alpha: 0.88));
      canvas.drawPath(path, Paint()..color = _gold.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    } else {
      canvas.drawPath(path, Paint()..color = _gold.withValues(alpha: 0.65)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }
  }

  void _drawCenter(Canvas canvas, Offset c, double maxR) {
    final pulse = 0.82 + 0.18 * sin(t * 2 * pi * 2.5);
    canvas.drawCircle(c, maxR * 0.14 * pulse, Paint()..color = _gold.withValues(alpha: 0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawCircle(c, maxR * 0.075 * pulse, Paint()..color = _gold.withValues(alpha: 0.9));
    canvas.drawCircle(c, maxR * 0.028, Paint()..color = const Color(0xFFE8D5A3));
  }

  @override
  bool shouldRepaint(_MysticPainter old) => old.t != t;
}

// ─── Ses Dalgası ──────────────────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double t; final bool isPlaying; final double entrance;
  _WavePainter(this.t, this.isPlaying, this.entrance);

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30; const minRatio = 0.03; const maxRatio = 0.72;
    final totalW = size.width * 0.65; final barW = totalW / (barCount * 2 - 1);
    final startX = (size.width - totalW) / 2;
    final ec     = Curves.elasticOut.transform(entrance.clamp(0.0, 1.0));
    for (int i = 0; i < barCount; i++) {
      final pct = i / (barCount - 1); final phase = pct * 2 * pi;
      final w1 = sin(t * 2 * pi * 2.2 + phase); final w2 = sin(t * 2 * pi * 3.5 + phase * 1.4 + 1.0);
      final combined = (w1 * 0.6 + w2 * 0.4).abs();
      final minH = size.height * minRatio; final maxH = size.height * maxRatio * ec;
      final barH = isPlaying ? minH + combined * (maxH - minH) : minH + 2;
      final envelope = sin(pct * pi);
      final color = Color.lerp(const Color(0xFF2E8B6E), const Color(0xFF7FFFD4), envelope * combined)!
          .withValues(alpha: 0.75 + envelope * 0.25);
      final x = startX + i * (barW + barW) + barW / 2;
      canvas.drawLine(Offset(x, (size.height - barH) / 2), Offset(x, (size.height + barH) / 2),
          Paint()..color = color..strokeWidth = barW..strokeCap = StrokeCap.round);
    }
    if (isPlaying && entrance > 0.8) {
      final glow = Paint()..color = const Color(0xFF7FFFD4).withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (int i = 0; i < barCount; i += 3) {
        final pct = i / (barCount - 1); final phase = pct * 2 * pi;
        final combined = (sin(t * 2 * pi * 2.2 + phase) * 0.6 + sin(t * 2 * pi * 3.5 + phase * 1.4 + 1.0) * 0.4).abs();
        if (combined < 0.5) continue;
        final x = startX + i * (barW + barW) + barW / 2;
        canvas.drawCircle(Offset(x, (size.height - combined * size.height * maxRatio * ec) / 2), 6, glow);
      }
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t || old.isPlaying != isPlaying || old.entrance != entrance;
}

// ─── Tarama Katmanı ───────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  final double t;
  _ScanOverlayPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const teal = Color(0xFF3DB88A);
    final progress = (t * 2.2) % 1.0; final scanY = progress * size.height;
    final fade = sin(progress * pi).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width / 2, scanY), width: size.width, height: 28),
        Paint()..color = teal.withValues(alpha: fade * 0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY),
        Paint()..color = teal.withValues(alpha: fade * 0.72)..strokeWidth = 1.4);
    final bp = Paint()..color = _gold.withValues(alpha: 0.68)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final m = size.width * 0.10; final l = size.width * 0.07;
    for (final (c, xd, yd) in [
      (Offset(m, m), 1.0, 1.0), (Offset(size.width - m, m), -1.0, 1.0),
      (Offset(m, size.height - m), 1.0, -1.0), (Offset(size.width - m, size.height - m), -1.0, -1.0),
    ]) {
      canvas.drawLine(c, Offset(c.dx + l * xd, c.dy), bp);
      canvas.drawLine(c, Offset(c.dx, c.dy + l * yd), bp);
    }
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => old.t != t;
}
