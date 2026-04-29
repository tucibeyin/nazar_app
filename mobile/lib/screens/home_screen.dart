import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../core/logger.dart';
import '../models/ayet.dart';
import '../providers/service_providers.dart';
import '../services/api_service.dart';
import '../utils/hash_util.dart';
import '../widgets/analyzing_indicator.dart';
import '../widgets/camera_frame_widget.dart';
import '../widgets/connectivity_banner_widget.dart';
import '../widgets/painters/painters.dart';
import '../widgets/result_panel_widget.dart';
import '../widgets/tesbih_widget.dart';

// ─── Uygulama Görünüm Durumu ──────────────────────────────────────────────────

enum AppViewState { camera, analyzing, playing }

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  // ── Scaffold key (drawer açmak için) ──────────────────────────────────────
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Kamera ────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  int _cameraIndex = 0;

  // ── UI Durumu ─────────────────────────────────────────────────────────────
  AppViewState _viewState = AppViewState.camera;
  Ayet? _ayet;
  bool _isLoading = false;
  bool _isPlaying = false;
  Uint8List? _capturedPhotoBytes;

  // ── Ses abonelikleri ──────────────────────────────────────────────────────
  StreamSubscription<dynamic>? _audioStateSub;
  StreamSubscription<void>? _audioCompletionSub;

  // ── Animasyon Kontrolcüleri ────────────────────────────────────────────────
  late final AnimationController _shutterCtrl;
  late final AnimationController _mysticCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _waveEnterCtrl;
  late final AnimationController _ambientCtrl;
  late final AnimationController _tesbihCtrl;
  late final AnimationController _inkCtrl;

  @override
  void initState() {
    super.initState();
    _shutterCtrl   = AnimationController(vsync: this, duration: kShutterDuration);
    _mysticCtrl    = AnimationController(vsync: this, duration: kMysticDuration);
    _waveCtrl      = AnimationController(vsync: this, duration: kWaveDuration);
    _waveEnterCtrl = AnimationController(vsync: this, duration: kWaveEnterDuration);
    _ambientCtrl   = AnimationController(vsync: this, duration: kAmbientDuration)
      ..repeat(reverse: true);
    _tesbihCtrl    = AnimationController(vsync: this, duration: kTesbihDuration);
    _inkCtrl       = AnimationController(vsync: this, duration: kInkSplashDuration);

    _cameraIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_cameraIndex == -1) _cameraIndex = 0;
    if (widget.cameras.isNotEmpty) _initCamera(_cameraIndex);

    final audio = ref.read(audioServiceProvider);
    _audioStateSub = audio.stateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _audioCompletionSub = audio.completionStream.listen((_) {
      if (mounted && _viewState == AppViewState.playing) _transitionToCamera();
    });
  }

  // ── Kamera Yönetimi ───────────────────────────────────────────────────────

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

  // ── Analiz Akışı ──────────────────────────────────────────────────────────

  Future<void> _analyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isLoading || _viewState != AppViewState.camera) return;
    HapticFeedback.lightImpact();

    // Çevrimdışı kontrolü
    final isOnline = ref.read(connectivityProvider);
    if (!isOnline) {
      _handleError('İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.', canRetry: false);
      return;
    }

    setState(() { _isLoading = true; _ayet = null; _capturedPhotoBytes = null; });

    try {
      await _shutterFlash();
      _mysticCtrl.repeat();
      setState(() => _viewState = AppViewState.analyzing);

      final photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      if (mounted) setState(() => _capturedPhotoBytes = bytes);

      final hashInt = HashUtil.fromBytes(bytes);
      AppLogger.info('Analysis started');

      final repo = ref.read(ayetRepositoryProvider);
      final results = await Future.wait([
        repo.fetchAyet(hashInt),
        Future<void>.delayed(kMinAnalysisPause),
      ]);
      final ayet = results[0] as Ayet;

      _mysticCtrl.stop();
      _waveEnterCtrl.reset();
      _waveCtrl.repeat();
      _tesbihCtrl.repeat();
      _waveEnterCtrl.forward();

      if (!mounted) return;
      setState(() {
        _ayet = ayet;
        _viewState = AppViewState.playing;
        _isLoading = false;
      });

      final audio = ref.read(audioServiceProvider);
      await audio.playFromPath(ayet.mp3Url);
    } on ApiException catch (e) {
      _handleError(_friendlyApiError(e));
    } on CameraException catch (e) {
      AppLogger.error('CameraException', e.code, null);
      _handleError(
        kDebugMode
            ? '[DEBUG] CameraException(${e.code}): ${e.description}'
            : 'Kamera hatası. Lütfen izinleri kontrol edin.',
      );
    } catch (e, st) {
      AppLogger.error('Unexpected analysis error', e, st);
      _handleError(
        kDebugMode
            ? '[DEBUG] ${e.runtimeType}: $e'
            : 'Beklenmedik bir hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  String _friendlyApiError(ApiException e) {
    if (e.statusCode == 429) return 'Çok fazla istek gönderildi. Lütfen bekleyin.';
    if (e.statusCode == 401) return 'Yetkilendirme hatası. Lütfen uygulamayı güncelleyin.';
    if (e.message.contains('bağlantı') || e.message.contains('internet')) {
      return 'İnternet bağlantısı bulunamadı.';
    }
    return 'Sunucuya ulaşılamadı. Lütfen tekrar deneyin.';
  }

  void _handleError(String message, {bool canRetry = true}) {
    _mysticCtrl.stop();
    if (!mounted) return;
    setState(() { _isLoading = false; _viewState = AppViewState.camera; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: canRetry
            ? SnackBarAction(
                label: 'Tekrar Dene',
                textColor: Colors.white,
                onPressed: _analyze,
              )
            : null,
      ),
    );
  }

  Future<void> _toggleAudio() async {
    HapticFeedback.lightImpact();
    final audio = ref.read(audioServiceProvider);
    if (_isPlaying) {
      await audio.pause();
      _waveCtrl.stop();
      _tesbihCtrl.stop();
    } else {
      await audio.resume();
      _waveCtrl.repeat();
      _tesbihCtrl.repeat();
    }
  }

  Future<void> _transitionToCamera() async {
    _waveCtrl.stop();
    _tesbihCtrl.stop();
    if (mounted) {
      setState(() {
        _viewState = AppViewState.camera;
        _capturedPhotoBytes = null;
      });
    }
  }

  Future<void> _shutterFlash() async {
    _inkCtrl.forward(from: 0);
    await _shutterCtrl.forward();
    await _shutterCtrl.reverse();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _audioStateSub?.cancel();
    _audioCompletionSub?.cancel();
    _shutterCtrl.dispose();
    _mysticCtrl.dispose();
    _waveCtrl.dispose();
    _waveEnterCtrl.dispose();
    _ambientCtrl.dispose();
    _tesbihCtrl.dispose();
    _inkCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? kDarkBg : kBg,
      drawer: _buildDrawer(isDark),
      body: Stack(
        children: [
          // Katman 1: Parşömen/Gece arka planı
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientCtrl,
              builder: (_, __) => CustomPaint(
                painter: ManuscriptBackgroundPainter(
                  _ambientCtrl.value,
                  isDark: isDark,
                ),
              ),
            ),
          ),
          // Katman 2: Cami silüeti (altta sabit)
          const Positioned(
            bottom: 0, left: 0, right: 0,
            child: CustomPaint(
              size: Size(double.infinity, kMosqueSilH),
              painter: MosqueSilhouettePainter(),
            ),
          ),
          // Katman 3: Mürekkep sıçrama efekti (enstantane sırasında)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _inkCtrl,
                builder: (_, __) {
                  final v = _inkCtrl.value;
                  if (v == 0) return const SizedBox.shrink();
                  final radius = v * 1.8;
                  final opacity = v < 0.5 ? v * 2 : (1 - v) * 2;
                  return CustomPaint(
                    painter: _InkSplashPainter(
                      radius: radius,
                      opacity: opacity.clamp(0.0, 1.0),
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
          ),
          // Katman 4: İçerik
          SafeArea(
            child: Column(
              children: [
                const ConnectivityBannerWidget(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildMainFrame(),
                        _buildButton(),
                        if (_viewState == AppViewState.playing)
                          TesbihWidget(controller: _tesbihCtrl, isPlaying: _isPlaying),
                        if (_ayet != null)
                          ResultPanelWidget(
                            ayet: _ayet!,
                            isPlaying: _isPlaying,
                            onToggleAudio: _toggleAudio,
                          ),
                        const SizedBox(height: 150),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final iconColor = isDark ? kGold : kGreen;
    final subtitleColor = isDark ? kDarkSubtext : kGreen;

    return Column(
      children: [
        const CustomPaint(
          size: Size(double.infinity, kTezhipBandH),
          painter: TezhipBandPainter(isTop: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Menüyü aç',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: Icon(Icons.menu_rounded, color: iconColor, size: 26),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(
                        fontSize: 22,
                        color: kGold,
                        fontWeight: FontWeight.w700,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nazar  &  Ferahlama',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Kamerayı çevir',
                onPressed: _viewState == AppViewState.camera ? _switchCamera : null,
                icon: Icon(
                  Icons.flip_camera_ios_rounded,
                  color: _viewState == AppViewState.camera
                      ? iconColor
                      : iconColor.withValues(alpha: 0.25),
                  size: 26,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: CustomPaint(
            size: Size(double.infinity, 14),
            painter: UnvanDividerPainter(),
          ),
        ),
      ],
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────

  Widget _buildDrawer(bool isDark) {
    final bg = isDark ? kDarkBg : kBg;
    final textColor = isDark ? kGold : kGreen;
    final subColor = isDark ? kDarkSubtext : kGreen.withValues(alpha: 0.6);

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Nazar & Ferahlama',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: CustomPaint(
                size: Size(double.infinity, 12),
                painter: UnvanDividerPainter(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.auto_stories_rounded, color: textColor),
              title: Text(
                'Hatim İndir',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                'Kaldığın yerden devam et',
                style: TextStyle(fontSize: 12, color: subColor),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/hatim');
              },
            ),
            ListTile(
              leading: Icon(Icons.shield_rounded, color: textColor),
              title: Text(
                'Benim Cevşenim',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                'Kişisel okuma listen',
                style: TextStyle(fontSize: 12, color: subColor),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/cevsen');
              },
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: CustomPaint(
                size: Size(double.infinity, 12),
                painter: UnvanDividerPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: _DrawerIconBtn(
                icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                label: isDark ? 'Gündüz Modu' : 'Gece Modu',
                color: textColor,
                onTap: () => ref.read(themeProvider.notifier).toggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ana Çerçeve ───────────────────────────────────────────────────────────

  Widget _buildMainFrame() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    return CameraFrameWidget(
      cameraController: _cameraController!,
      frameState: _toFrameState(_viewState),
      capturedPhotoBytes: _capturedPhotoBytes,
      shutterController: _shutterCtrl,
      mysticController: _mysticCtrl,
      waveController: _waveCtrl,
      waveEnterController: _waveEnterCtrl,
      isPlaying: _isPlaying,
    );
  }

  CameraFrameState _toFrameState(AppViewState s) => switch (s) {
    AppViewState.camera    => CameraFrameState.camera,
    AppViewState.analyzing => CameraFrameState.analyzing,
    AppViewState.playing   => CameraFrameState.playing,
  };

  // ── Buton ─────────────────────────────────────────────────────────────────

  Widget _buildButton() {
    final isWaving    = _viewState == AppViewState.playing;
    final isAnalyzing = _viewState == AppViewState.analyzing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_isLoading || isAnalyzing)
              ? null
              : (isWaving ? _toggleAudio : _analyze),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.35),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: isAnalyzing
                ? const AnalyzingIndicator(key: ValueKey('analyzing'))
                : Text(
                    isWaving
                        ? (_isPlaying ? 'Duraklat' : 'Devam Et')
                        : 'Nazarımı Oku  ✦  Analiz Et',
                    key: ValueKey('$isWaving$_isPlaying'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Drawer icon button ───────────────────────────────────────────────────────

class _DrawerIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DrawerIconBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mürekkep Sıçrama Painter ─────────────────────────────────────────────────

class _InkSplashPainter extends CustomPainter {
  final double radius;
  final double opacity;
  final bool isDark;

  const _InkSplashPainter({
    required this.radius,
    required this.opacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.shortestSide * radius;
    final color = isDark ? kGold : kGreen;

    canvas.drawCircle(
      Offset(cx, cy),
      maxR,
      Paint()
        ..color = color.withValues(alpha: opacity * 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      maxR,
      Paint()
        ..color = color.withValues(alpha: opacity * 0.45)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_InkSplashPainter old) =>
      old.radius != radius || old.opacity != opacity;
}
