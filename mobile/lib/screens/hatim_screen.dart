import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../models/hatim_ayet.dart';
import '../providers/service_providers.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/painters/painters.dart';

// ─── Mushaf renkleri ──────────────────────────────────────────────────────────

const _kPageIvory   = Color(0xFFFAF3E0);
const _kInk         = Color(0xFF1A0800);
const _kVerseCircle = Color(0xFFF5EDD4);

// ─── Durum makinesi ───────────────────────────────────────────────────────────

enum _HatimState { idle, loading, playing, paused, error }

// ─── HatimScreen ─────────────────────────────────────────────────────────────

class HatimScreen extends ConsumerStatefulWidget {
  const HatimScreen({super.key});

  @override
  ConsumerState<HatimScreen> createState() => _HatimScreenState();
}

class _HatimScreenState extends ConsumerState<HatimScreen>
    with SingleTickerProviderStateMixin {
  late final AudioService _audio;
  late final AnimationController _ambientCtrl;

  _HatimState _hatimState = _HatimState.idle;
  HatimAyet? _current;
  String? _errorMsg;
  bool _advancing = false;

  // ── Repeat & Sleep timer ──────────────────────────────────────────────────
  bool _repeat = false;
  Timer? _sleepTimer;
  Timer? _sleepUiTimer;
  DateTime? _sleepEnd;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(vsync: this, duration: kAmbientDuration)
      ..repeat(reverse: true);
    _audio = AudioService();
    _audio.stateStream.listen((_) { if (mounted) setState(() {}); });
    _audio.completionStream.listen((_) { if (mounted) _advance(); });
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepUiTimer?.cancel();
    _ambientCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ── Oynatma mantığı ──────────────────────────────────────────────────────

  Future<void> _playFromIndex(int index) async {
    if (!mounted) return;
    setState(() { _hatimState = _HatimState.loading; _errorMsg = null; });
    try {
      final hatimAyet = await ref.read(apiServiceProvider).fetchHatimAyet(index);
      if (!mounted) return;
      setState(() { _current = hatimAyet; _hatimState = _HatimState.playing; });
      await _audio.playFromPath(hatimAyet.ayet.mp3Url);
      // Sonraki ayeti arka planda cache'e indir
      _prefetchNext(index, hatimAyet.total);
    } on ApiException catch (e) {
      if (mounted) setState(() { _hatimState = _HatimState.error; _errorMsg = e.message; });
    } catch (e) {
      if (mounted) setState(() { _hatimState = _HatimState.error; _errorMsg = 'Bir hata oluştu.'; });
    }
  }

  void _prefetchNext(int currentIndex, int total) {
    if (_repeat) return; // tekrar modunda aynı ayet çalacak, prefetch'e gerek yok
    final nextIndex = (currentIndex + 1) % total;
    ref.read(apiServiceProvider).fetchHatimAyet(nextIndex).then((next) {
      _audio.prefetch(next.ayet.mp3Url);
    }).catchError((_) {});
  }

  Future<void> _advance() async {
    if (_advancing || _hatimState == _HatimState.idle) return;
    _advancing = true;
    try {
      if (_repeat) {
        await _playFromIndex(ref.read(hatimProgressProvider));
      } else {
        final total = _current?.total ?? 6236;
        await ref.read(hatimProgressProvider.notifier).advance(total);
        await _playFromIndex(ref.read(hatimProgressProvider));
      }
    } finally {
      _advancing = false;
    }
  }

  Future<void> _onPlayPause() async {
    HapticFeedback.lightImpact();
    switch (_hatimState) {
      case _HatimState.idle:
      case _HatimState.error:
        await _playFromIndex(ref.read(hatimProgressProvider));
      case _HatimState.loading:
        break;
      case _HatimState.playing:
        await _audio.pause();
        if (mounted) setState(() => _hatimState = _HatimState.paused);
      case _HatimState.paused:
        await _audio.resume();
        if (mounted) setState(() => _hatimState = _HatimState.playing);
    }
  }

  Future<void> _resetProgress() async {
    if (mounted) setState(() { _hatimState = _HatimState.idle; _current = null; });
    await _audio.stop();
    await ref.read(hatimProgressProvider.notifier).reset();
  }

  Future<void> _stopPlayback() async {
    if (mounted) setState(() => _hatimState = _HatimState.idle);
    await _audio.stop();
  }

  // ── Sleep timer ───────────────────────────────────────────────────────────

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepUiTimer?.cancel();
    if (minutes == 0) {
      if (mounted) setState(() => _sleepEnd = null);
      return;
    }
    _sleepEnd = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (mounted) { _stopPlayback(); setState(() => _sleepEnd = null); }
    });
    _sleepUiTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() {});
  }

  void _showSleepTimerDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kPageIvory,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kGold.withValues(alpha: 0.4)),
        ),
        title: Text(
          'Uyku Zamanlayıcısı',
          style: GoogleFonts.cormorantGaramond(
            color: kGreen, fontWeight: FontWeight.w700, fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final min in [15, 30, 60])
              ListTile(
                dense: true,
                title: Text('$min dakika',
                    style: GoogleFonts.cormorantGaramond(fontSize: 15, color: _kInk)),
                onTap: () { Navigator.pop(ctx); _setSleepTimer(min); },
              ),
            if (_sleepEnd != null)
              ListTile(
                dense: true,
                title: Text('İptal Et',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 15, color: Colors.redAccent)),
                onTap: () { Navigator.pop(ctx); _setSleepTimer(0); },
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(hatimProgressProvider);
    final total = _current?.total ?? 6236;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientCtrl,
              builder: (_, __) => CustomPaint(
                painter: ManuscriptBackgroundPainter(_ambientCtrl.value),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: _buildMushafPage(),
                  ),
                ),

                _buildControls(index, total),

                const CustomPaint(
                  size: Size(double.infinity, kTezhipBandH),
                  painter: TezhipBandPainter(isTop: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Üst bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        const CustomPaint(
          size: Size(double.infinity, kTezhipBandH),
          painter: TezhipBandPainter(isTop: true),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kGold, size: 20),
        ),
        Center(
          child: Text(
            'الختم',
            style: GoogleFonts.amiri(
              fontSize: 20,
              color: kGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── Mushaf sayfası ────────────────────────────────────────────────────────

  Widget _buildMushafPage() {
    return Container(
      decoration: BoxDecoration(
        color: _kPageIvory,
        boxShadow: [
          BoxShadow(
            color: kGold.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: LevhaBorderPainter()),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSurahHeader(),
                const SizedBox(height: 14),
                Expanded(child: _buildVerseArea()),
                const SizedBox(height: 10),
                _buildFooterRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sure başlığı ──────────────────────────────────────────────────────────

  Widget _buildSurahHeader() {
    final name = _current?.ayet.sureIsim ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 46,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: LevhaHeaderPainter()),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  name.isNotEmpty ? name : 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.amiri(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            _cornerOrnament(left: true),
            _cornerOrnament(left: false),
          ],
        ),
      ),
    );
  }

  Widget _cornerOrnament({required bool left}) {
    return Positioned(
      left: left ? 6 : null,
      right: left ? null : 6,
      top: 0, bottom: 0,
      child: const Center(
        child: Text('❧', style: TextStyle(color: kGold, fontSize: 16)),
      ),
    );
  }

  // ── Ayet alanı ────────────────────────────────────────────────────────────

  Widget _buildVerseArea() {
    if (_hatimState == _HatimState.loading) {
      return const Center(
        child: CircularProgressIndicator(color: kGold, strokeWidth: 2),
      );
    }

    if (_current == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.scheherazadeNew(
                fontSize: 30,
                color: _kInk,
                height: 2.2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _hatimState == _HatimState.error
                  ? (_errorMsg ?? 'Hata oluştu')
                  : 'Okumaya başlamak için ▶',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 13,
                color: _hatimState == _HatimState.error
                    ? Colors.red.shade700
                    : kGold.withValues(alpha: 0.75),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ambientCtrl,
      builder: (_, child) {
        final isPlaying = _hatimState == _HatimState.playing;
        final glowAlpha = isPlaying
            ? (0.04 + 0.04 * _ambientCtrl.value)
            : 0.0;
        return Stack(
          children: [
            if (isPlaying)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        kGold.withValues(alpha: glowAlpha),
                        Colors.transparent,
                      ],
                      radius: 1.2,
                    ),
                  ),
                ),
              ),
            child!,
          ],
        );
      },
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            _current!.ayet.arapca,
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.scheherazadeNew(
              fontSize: 28,
              color: _kInk,
              height: 2.3,
              shadows: [
                Shadow(
                  color: _kInk.withValues(alpha: 0.18),
                  blurRadius: 0.5,
                  offset: const Offset(0.3, 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Alt bilgi satırı ──────────────────────────────────────────────────────

  Widget _buildFooterRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_current != null)
          Expanded(
            child: Text(
              _current!.ayet.meal,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: _kInk.withValues(alpha: 0.55),
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          const Spacer(),

        const SizedBox(width: 8),

        if (_current != null)
          _buildAyetMedalyon(_current!.ayet.id),
      ],
    );
  }

  Widget _buildAyetMedalyon(int id) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kVerseCircle,
        border: Border.all(color: kGold, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: kGold.withValues(alpha: 0.25),
            blurRadius: 6,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: kGold.withValues(alpha: 0.35),
                width: 0.7,
              ),
            ),
          ),
          Text(
            '$id',
            style: GoogleFonts.amiri(
              fontSize: 12,
              color: kGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Kontroller ────────────────────────────────────────────────────────────

  Widget _buildControls(int index, int total) {
    final progress = total > 0 ? (index + 1) / total : 0.0;
    final isLoading = _hatimState == _HatimState.loading;
    final isPlaying = _hatimState == _HatimState.playing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: kGold.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(kGold),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '${index + 1} / $total',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12,
                        color: kGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Repeat butonu
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _repeat = !_repeat);
                      },
                      child: Icon(
                        Icons.repeat_rounded,
                        size: 15,
                        color: _repeat ? kGold : kGold.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sleep timer butonu
                    GestureDetector(
                      onTap: _showSleepTimerDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bedtime_outlined,
                            size: 15,
                            color: _sleepEnd != null
                                ? kGold
                                : kGold.withValues(alpha: 0.35),
                          ),
                          if (_sleepEnd != null) ...[
                            const SizedBox(width: 3),
                            Text(
                              '${_sleepEnd!.difference(DateTime.now()).inMinutes}dk',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 11,
                                color: kGold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _resetProgress,
                      child: Text(
                        'Başa Dön',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 11,
                          color: kGreen.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          GestureDetector(
            onTap: isLoading ? null : _onPlayPause,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBg,
                border: Border.all(
                  color: isPlaying ? kGold : kGold.withValues(alpha: 0.55),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kGold.withValues(alpha: isPlaying ? 0.40 : 0.12),
                    blurRadius: isPlaying ? 18 : 6,
                    spreadRadius: isPlaying ? 3 : 0,
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kGold,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: kGold,
                      size: 34,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
