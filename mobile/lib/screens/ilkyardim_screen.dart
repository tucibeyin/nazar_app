import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../core/logger.dart';
import '../models/ayet.dart';
import '../providers/service_providers.dart';
import '../services/api_service.dart';

const _kCalmingPackageId = 'insira';

class IlkyardimScreen extends ConsumerStatefulWidget {
  const IlkyardimScreen({super.key});

  @override
  ConsumerState<IlkyardimScreen> createState() => _IlkyardimScreenState();
}

class _IlkyardimScreenState extends ConsumerState<IlkyardimScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim;

  List<Ayet> _ayetler = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isPlaying = false;
  String? _errorMessage;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completionSub;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _breathAnim = CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut);
    _setup();
  }

  Future<void> _setup() async {
    final audio = ref.read(audioServiceProvider);
    await audio.stop();

    _stateSub = audio.stateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _completionSub = audio.completionStream.listen((_) {
      if (mounted) _advance();
    });

    await _loadAndPlay();
  }

  Future<void> _loadAndPlay() async {
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final detay = await ref.read(apiServiceProvider).fetchPackageDetail(_kCalmingPackageId);
      if (!mounted) return;
      if (detay.ayetler.isEmpty) {
        setState(() { _isLoading = false; _errorMessage = 'Ses paketi boş.'; });
        return;
      }
      setState(() { _ayetler = detay.ayetler; _isLoading = false; });
      await _playAt(0);
    } on ApiException catch (e) {
      AppLogger.error('IlkyardimScreen._loadAndPlay', e);
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Ses paketi yüklenemedi.\nİnternet bağlantınızı kontrol edin.'; });
    } catch (e, st) {
      AppLogger.error('IlkyardimScreen._loadAndPlay unexpected', e, st);
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Beklenmedik bir hata oluştu.'; });
    }
  }

  Future<void> _playAt(int index) async {
    if (_ayetler.isEmpty || index >= _ayetler.length) return;
    if (mounted) setState(() => _currentIndex = index);
    await ref.read(audioServiceProvider).playFromPath(_ayetler[index].mp3Url);
  }

  void _advance() {
    if (_ayetler.isEmpty) return;
    _playAt((_currentIndex + 1) % _ayetler.length);
  }

  Future<void> _toggleAudio() async {
    HapticFeedback.lightImpact();
    final audio = ref.read(audioServiceProvider);
    if (_isPlaying) {
      await audio.pause();
    } else if (_ayetler.isNotEmpty) {
      await audio.resume();
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _stateSub?.cancel();
    _completionSub?.cancel();
    ref.read(audioServiceProvider).stop();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071220),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF071220), Color(0xFF0C2035), Color(0xFF071220)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Geri',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF7EC8E3), size: 20),
          ),
          Expanded(
            child: Text(
              'Manevi İlkyardım',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kGold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7EC8E3), strokeWidth: 1.5),
      );
    }
    if (_errorMessage != null) return _buildError();
    return _buildMain();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBreathCircles(const SizedBox.shrink()),
            const SizedBox(height: 32),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9FB8CC), fontSize: 14, height: 1.7),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _loadAndPlay,
              child: const Text('Tekrar Dene', style: TextStyle(color: Color(0xFF7EC8E3))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain() {
    final ayet = _ayetler.isNotEmpty ? _ayetler[_currentIndex] : null;

    return Column(
      children: [
        // Breathing circle + Arabic verse
        Expanded(
          flex: 5,
          child: Center(
            child: _buildBreathCircles(
              ayet == null
                  ? const SizedBox.shrink()
                  : SizedBox(
                      width: 180,
                      child: Text(
                        ayet.arapca,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.amiri(
                          fontSize: 18,
                          color: kGold.withValues(alpha: 0.9),
                          height: 2.1,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        // Breath guidance
        AnimatedBuilder(
          animation: _breathCtrl,
          builder: (_, __) {
            final expanding = _breathCtrl.status == AnimationStatus.forward;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: Text(
                expanding ? 'Nefes Al...' : 'Nefes Ver...',
                key: ValueKey(expanding),
                style: const TextStyle(
                  color: Color(0xFF5DADE2),
                  fontSize: 11,
                  letterSpacing: 2.5,
                ),
              ),
            );
          },
        ),
        // Sure name + meal
        if (ayet != null) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              children: [
                Text(
                  ayet.sureIsim,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 13,
                    color: const Color(0xFF7EC8E3),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ayet.meal,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB0C8DE), fontSize: 13, height: 1.7),
                ),
              ],
            ),
          ),
        ],
        // Sabit ayet
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 20, 36, 0),
          child: Text(
            '« Kalpler ancak Allah\'ı anmakla mutmain olur. »',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 14,
              color: kGold.withValues(alpha: 0.55),
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ),
        // Oynat/Duraklat + sıra sayacı
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 40),
          child: Column(
            children: [
              _buildPlayButton(),
              if (_ayetler.length > 1) ...[
                const SizedBox(height: 10),
                Text(
                  '${_currentIndex + 1} / ${_ayetler.length}',
                  style: const TextStyle(color: Color(0xFF5D8AA0), fontSize: 11, letterSpacing: 1),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreathCircles(Widget innerChild) {
    return AnimatedBuilder(
      animation: _breathAnim,
      builder: (_, child) {
        final v = _breathAnim.value;
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dış halo
              Transform.scale(
                scale: 0.78 + 0.22 * v,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A5F7A).withValues(alpha: 0.04 + 0.04 * v),
                  ),
                ),
              ),
              // Orta halka
              Transform.scale(
                scale: 0.68 + 0.22 * v,
                child: Container(
                  width: 255,
                  height: 255,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A5F7A).withValues(alpha: 0.07 + 0.06 * v),
                    border: Border.all(
                      color: const Color(0xFF5DADE2).withValues(alpha: 0.09 + 0.14 * v),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // İç parıltı
              Transform.scale(
                scale: 0.58 + 0.18 * v,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2E86AB).withValues(alpha: 0.20 + 0.15 * v),
                        const Color(0xFF1A5F7A).withValues(alpha: 0.10 + 0.08 * v),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF7EC8E3).withValues(alpha: 0.12 + 0.18 * v),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: innerChild,
    );
  }

  Widget _buildPlayButton() {
    return Semantics(
      button: true,
      label: _isPlaying ? 'Duraklat' : 'Oynat',
      child: GestureDetector(
        onTap: _ayetler.isEmpty ? null : _toggleAudio,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A5F7A).withValues(alpha: _isPlaying ? 0.85 : 0.50),
            border: Border.all(
              color: const Color(0xFF7EC8E3).withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E86AB).withValues(alpha: _isPlaying ? 0.35 : 0.12),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 30,
          ),
        ),
      ),
    );
  }
}
