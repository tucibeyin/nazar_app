import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../models/hatim_ayet.dart';
import '../providers/service_providers.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/painters/painters.dart';

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
  // Hatim ekranına özel ses oynatıcı — HomeScreen'inkiyle çakışmaz.
  late final AudioService _audio;
  late final AnimationController _ambientCtrl;

  _HatimState _hatimState = _HatimState.idle;
  HatimAyet? _current;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(vsync: this, duration: kAmbientDuration)
      ..repeat(reverse: true);
    _audio = AudioService();
    _audio.stateStream.listen((s) {
      if (mounted) setState(() {});
    });
    _audio.completionStream.listen((_) {
      if (mounted) _advance();
    });
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ── Oynatma mantığı ──────────────────────────────────────────────────────

  Future<void> _playFromIndex(int index) async {
    if (!mounted) return;
    setState(() { _hatimState = _HatimState.loading; _errorMsg = null; });

    try {
      final api = ref.read(apiServiceProvider);
      final hatimAyet = await api.fetchHatimAyet(index);
      if (!mounted) return;
      setState(() {
        _current = hatimAyet;
        _hatimState = _HatimState.playing;
      });
      await _audio.playFromPath(hatimAyet.ayet.mp3Url);
    } on ApiException catch (e) {
      if (mounted) setState(() { _hatimState = _HatimState.error; _errorMsg = e.message; });
    } catch (e) {
      if (mounted) setState(() { _hatimState = _HatimState.error; _errorMsg = 'Bir hata oluştu.'; });
    }
  }

  Future<void> _advance() async {
    final total = _current?.total ?? 6236;
    await ref.read(hatimProgressProvider.notifier).advance(total);
    final nextIndex = ref.read(hatimProgressProvider);
    _playFromIndex(nextIndex);
  }

  Future<void> _onPlayPause() async {
    switch (_hatimState) {
      case _HatimState.idle:
      case _HatimState.error:
        final index = ref.read(hatimProgressProvider);
        await _playFromIndex(index);
      case _HatimState.loading:
        break; // bekle
      case _HatimState.playing:
        await _audio.pause();
        if (mounted) setState(() => _hatimState = _HatimState.paused);
      case _HatimState.paused:
        await _audio.resume();
        if (mounted) setState(() => _hatimState = _HatimState.playing);
    }
  }

  Future<void> _resetProgress() async {
    await _audio.stop();
    await ref.read(hatimProgressProvider.notifier).reset();
    if (mounted) setState(() { _hatimState = _HatimState.idle; _current = null; });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(hatimProgressProvider);
    final total = _current?.total ?? 6236;
    final progress = total > 0 ? index / total : 0.0;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Parşömen arka plan
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
                // Üst tezhip bandı + geri butonu
                Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    const CustomPaint(
                      size: Size(double.infinity, kTezhipBandH),
                      painter: TezhipBandPainter(isTop: true),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: kGold, size: 20),
                    ),
                  ],
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Başlık
                        Text(
                          'Hatim',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: kGreen,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الختم',
                          style: GoogleFonts.amiri(
                            fontSize: 18,
                            color: kGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // İlerleme
                        _buildProgress(index, total, progress),
                        const SizedBox(height: 32),

                        // Ayet bilgisi
                        _buildAyetInfo(),
                        const SizedBox(height: 40),

                        // Play / Pause butonu
                        _buildPlayButton(),
                        const SizedBox(height: 16),

                        // Hata mesajı
                        if (_errorMsg != null)
                          Text(
                            _errorMsg!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Alt tezhip bandı + sıfırla butonu
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton.icon(
                    onPressed: _resetProgress,
                    icon: Icon(Icons.restart_alt_rounded,
                        color: kGreen.withValues(alpha: 0.6), size: 16),
                    label: Text(
                      'Başa Dön',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 13,
                        color: kGreen.withValues(alpha: 0.6),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
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

  Widget _buildProgress(int index, int total, double progress) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: kGold.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(kGold),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${index + 1} / $total',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 14,
            color: kGreen,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildAyetInfo() {
    if (_current == null) {
      return Text(
        _hatimState == _HatimState.loading
            ? 'Yükleniyor...'
            : 'Başlamak için play\'e bas',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 15,
          color: kGreen.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: [
        Text(
          _current!.ayet.sureIsim,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kGreen,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _current!.ayet.arapca,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.amiri(
            fontSize: 22,
            color: kGold,
            height: 1.9,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    final isLoading = _hatimState == _HatimState.loading;
    final isPlaying = _hatimState == _HatimState.playing;

    return GestureDetector(
      onTap: isLoading ? null : _onPlayPause,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kBg,
          border: Border.all(color: kGold, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: kGold.withValues(alpha: isPlaying ? 0.35 : 0.15),
              blurRadius: isPlaying ? 20 : 8,
              spreadRadius: isPlaying ? 4 : 0,
            ),
          ],
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: kGold,
                ),
              )
            : Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: kGold,
                size: 40,
              ),
      ),
    );
  }
}
