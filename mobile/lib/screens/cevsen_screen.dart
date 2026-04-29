import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../core/sleep_timer_mixin.dart';
import '../models/ayet.dart';
import '../models/paket.dart';
import '../providers/cevsen_provider.dart';
import '../providers/service_providers.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/painters/painters.dart';

// ─── Oynatma durumu ───────────────────────────────────────────────────────────

enum _PlayState { idle, loading, playing, paused, error }

// ─── Playlist girişi — her ayetin hangi pakete ait olduğunu taşır ─────────────

class _Entry {
  final Ayet ayet;
  final String paketId;
  const _Entry({required this.ayet, required this.paketId});
}

// ─── CevsenScreen ─────────────────────────────────────────────────────────────

class CevsenScreen extends ConsumerStatefulWidget {
  const CevsenScreen({super.key});

  @override
  ConsumerState<CevsenScreen> createState() => _CevsenScreenState();
}

class _CevsenScreenState extends ConsumerState<CevsenScreen>
    with SingleTickerProviderStateMixin, SleepTimerMixin {
  late final AudioService _audio;
  late final AnimationController _ambientCtrl;
  StreamSubscription<void>? _completionSub;
  StreamSubscription<dynamic>? _stateSub;

  _PlayState _playState = _PlayState.idle;
  List<_Entry> _playlist = [];
  int _playIndex = 0;
  String? _errorMsg;
  bool _advancing = false;
  bool _repeat = false;

  static const _kProgressKey = 'cevsen_play_index';

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(vsync: this, duration: kAmbientDuration)
      ..repeat(reverse: true);
    _audio = ref.read(audioServiceProvider);
    _stateSub = _audio.stateStream.listen((_) { if (mounted) setState(() {}); });
    _completionSub = _audio.completionStream.listen((_) { if (mounted) _advancePlayback(); });
  }

  @override
  void dispose() {
    disposeSleepTimers();
    _stateSub?.cancel();
    _completionSub?.cancel();
    _audio.stop();
    _ambientCtrl.dispose();
    super.dispose();
  }

  // ── İlerleme kaydı ────────────────────────────────────────────────────────

  Future<void> _saveProgress(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kProgressKey, index);
  }

  Future<int> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kProgressKey) ?? 0;
  }

  // ── Oynatma akışı ─────────────────────────────────────────────────────────

  Future<void> _startPlayback() async {
    final cevsen = ref.read(cevsenProvider);
    if (cevsen.isEmpty) return;
    setState(() { _playState = _PlayState.loading; _errorMsg = null; });
    try {
      final details = await Future.wait(
        cevsen.map((p) => ref.read(apiServiceProvider).fetchPackageDetail(p.id)),
      );
      _playlist = [
        for (int i = 0; i < cevsen.length; i++)
          for (final ayet in details[i].ayetler)
            _Entry(ayet: ayet, paketId: cevsen[i].id),
      ];

      if (_playlist.isEmpty) {
        if (mounted) setState(() => _playState = _PlayState.idle);
        return;
      }

      final saved = await _loadProgress();
      _playIndex = (saved < _playlist.length) ? saved : 0;

      setState(() => _playState = _PlayState.playing);
      await _audio.playFromPath(_playlist[_playIndex].ayet.mp3Url);
      _prefetchNext(_playIndex);
    } on ApiException catch (e) {
      if (mounted) setState(() { _playState = _PlayState.error; _errorMsg = e.message; });
    } catch (_) {
      if (mounted) setState(() { _playState = _PlayState.error; _errorMsg = 'Bir hata oluştu.'; });
    }
  }

  Future<void> _advancePlayback() async {
    if (_advancing || _playState == _PlayState.idle) return;
    _advancing = true;
    try {
      if (_repeat) {
        await _audio.playFromPath(_playlist[_playIndex].ayet.mp3Url);
      } else if (_playIndex + 1 < _playlist.length) {
        if (mounted) setState(() => _playIndex++);
        _saveProgress(_playIndex);
        _prefetchNext(_playIndex);
        await _audio.playFromPath(_playlist[_playIndex].ayet.mp3Url);
      } else {
        _saveProgress(0);
        if (mounted) setState(() { _playState = _PlayState.idle; _playlist = []; _playIndex = 0; });
      }
    } catch (_) {
      if (mounted) setState(() { _playState = _PlayState.error; _errorMsg = 'Ses çalınamadı.'; });
    } finally {
      _advancing = false;
    }
  }

  void _prefetchNext(int currentIndex) {
    if (_repeat) return;
    final nextIndex = currentIndex + 1;
    if (nextIndex < _playlist.length) {
      _audio.prefetch(_playlist[nextIndex].ayet.mp3Url);
    }
  }

  Future<void> _togglePlayPause() async {
    HapticFeedback.lightImpact();
    switch (_playState) {
      case _PlayState.idle:
      case _PlayState.error:
        await _startPlayback();
      case _PlayState.loading:
        break;
      case _PlayState.playing:
        await _audio.pause();
        if (mounted) setState(() => _playState = _PlayState.paused);
      case _PlayState.paused:
        await _audio.resume();
        if (mounted) setState(() => _playState = _PlayState.playing);
    }
  }

  Future<void> _stopPlayback() async {
    if (mounted) setState(() { _playState = _PlayState.idle; _playlist = []; _playIndex = 0; });
    await _audio.stop();
  }

  // ── Paket silme ───────────────────────────────────────────────────────────

  Future<void> _onRemovePackage(String paketId) async {
    HapticFeedback.lightImpact();
    ref.read(cevsenProvider.notifier).remove(paketId);

    if (_playlist.isEmpty) return;

    final currentId     = _playlist[_playIndex].paketId;
    final removedBefore = _playlist.take(_playIndex)
        .where((e) => e.paketId == paketId).length;

    final newPlaylist = _playlist.where((e) => e.paketId != paketId).toList();

    if (newPlaylist.isEmpty) {
      await _audio.stop();
      if (mounted) setState(() { _playlist = []; _playIndex = 0; _playState = _PlayState.idle; });
      return;
    }

    if (currentId == paketId) {
      final int newIndex = (_playIndex - removedBefore).clamp(0, newPlaylist.length - 1);
      setState(() { _playlist = newPlaylist; _playIndex = newIndex; _playState = _PlayState.playing; });
      await _audio.playFromPath(newPlaylist[newIndex].ayet.mp3Url);
      _prefetchNext(newIndex);
    } else {
      setState(() {
        _playlist = newPlaylist;
        _playIndex = (_playIndex - removedBefore).clamp(0, newPlaylist.length - 1);
      });
    }
  }

  // ── Paket ekleme ──────────────────────────────────────────────────────────

  Future<void> _onAddPackage(Paket paket) async {
    await ref.read(cevsenProvider.notifier).add(paket);

    if (_playState == _PlayState.playing || _playState == _PlayState.paused) {
      try {
        final detail = await ref.read(apiServiceProvider).fetchPackageDetail(paket.id);
        final newEntries = detail.ayetler
            .map((a) => _Entry(ayet: a, paketId: paket.id))
            .toList();
        if (mounted) {
          setState(() => _playlist = [..._playlist, ...newEntries]);
          if (newEntries.isNotEmpty) _audio.prefetch(newEntries.first.ayet.mp3Url);
        }
      } catch (_) {}
    }
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  bool _isPackagePlaying(String paketId) {
    if (_playState != _PlayState.playing && _playState != _PlayState.paused) return false;
    if (_playlist.isEmpty || _playIndex >= _playlist.length) return false;
    return _playlist[_playIndex].paketId == paketId;
  }

  Paket? _currentPaket(List<Paket> cevsen) {
    if (_playlist.isEmpty || _playIndex >= _playlist.length) return null;
    final id = _playlist[_playIndex].paketId;
    for (final p in cevsen) { if (p.id == id) return p; }
    return null;
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PackageCatalogSheet(onAdd: _onAddPackage),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cevsen  = ref.watch(cevsenProvider);
    final isActive = _playState == _PlayState.playing || _playState == _PlayState.paused;

    return Scaffold(
      backgroundColor: kBg,
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
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
                  child: cevsen.isEmpty ? _buildEmptyState() : _buildList(cevsen),
                ),
                if (cevsen.isNotEmpty || isActive) _buildPlayControls(cevsen),
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
            'الجَوْشَن',
            style: GoogleFonts.amiri(fontSize: 20, color: kGold, fontWeight: FontWeight.w700),
          ),
        ),
        Positioned(
          right: 12,
          child: Text(
            'Benim Cevşenim',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 10, color: kGold.withValues(alpha: 0.65),
              letterSpacing: 0.5, fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  // ── Boş durum ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: kGold.withValues(alpha: 0.25), size: 72),
            const SizedBox(height: 20),
            Text(
              'Cevşeniniz boş',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20, color: kGold, fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Aşağıdaki + butonuna basarak manevi zırhınızı oluşturun',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 13, color: kGreen.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic, height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Liste ─────────────────────────────────────────────────────────────────

  Widget _buildList(List<Paket> cevsen) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: cevsen.length,
      onReorder: (oldIndex, newIndex) {
        final updated = [...cevsen];
        if (newIndex > oldIndex) newIndex--;
        updated.insert(newIndex, updated.removeAt(oldIndex));
        ref.read(cevsenProvider.notifier).reorder(updated);
      },
      itemBuilder: (_, i) {
        final paket = cevsen[i];
        return _buildPaketCard(paket, _isPackagePlaying(paket.id),
            key: ValueKey(paket.id));
      },
    );
  }

  Widget _buildPaketCard(Paket paket, bool isNowPlaying, {required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        decoration: BoxDecoration(
          color: kIvory,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNowPlaying ? kGold : kGold.withValues(alpha: 0.28),
            width: isNowPlaying ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: kGold.withValues(alpha: isNowPlaying ? 0.22 : 0.07),
              blurRadius: isNowPlaying ? 14 : 6,
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNowPlaying
                      ? kGold.withValues(alpha: 0.15)
                      : kGreen.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isNowPlaying ? kGold : kGold.withValues(alpha: 0.35),
                    width: isNowPlaying ? 1.5 : 1.0,
                  ),
                ),
                child: Icon(_iconFor(paket.icon),
                    color: isNowPlaying ? kGold : kGreen, size: 20),
              ),
              if (isNowPlaying)
                const Positioned(bottom: -2, right: -2, child: _PulseDot()),
            ],
          ),
          title: Text(
            paket.isim,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: isNowPlaying ? kGreen : kInk,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paket.aciklama,
                style: TextStyle(fontSize: 11, color: kInk.withValues(alpha: 0.55), height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '${paket.ayetSayisi} ayet',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 11, color: kGold, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Cevşenden çıkar',
                onPressed: () => _onRemovePackage(paket.id),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.redAccent, size: 22),
              ),
              const Icon(Icons.drag_handle_rounded, color: kGold, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Oynatma kontrolleri ───────────────────────────────────────────────────

  Widget _buildPlayControls(List<Paket> cevsen) {
    final isLoading  = _playState == _PlayState.loading;
    final isPlaying  = _playState == _PlayState.playing;
    final isActive   = isPlaying || _playState == _PlayState.paused;
    final total      = isActive ? _playlist.length : 0;
    final totalAyets = cevsen.fold(0, (s, p) => s + p.ayetSayisi);
    final current    = _currentPaket(cevsen);

    return Container(
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: kGold.withValues(alpha: 0.18))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildProgressSection(
              isActive: isActive,
              isPlaying: isPlaying,
              total: total,
              totalAyets: totalAyets,
              current: current,
            ),
          ),
          const SizedBox(width: 20),
          _buildCirclePlayButton(
            isLoading: isLoading,
            isPlaying: isPlaying,
            cevsenEmpty: cevsen.isEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection({
    required bool isActive,
    required bool isPlaying,
    required int total,
    required int totalAyets,
    required Paket? current,
  }) {
    final progress = total > 0 ? (_playIndex + 1) / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: kGold.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(kGold),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isActive && current != null
              ? Align(
                  key: ValueKey(current.id),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    current.isim,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 13, color: kGreen, fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
        if (isActive && current != null) const SizedBox(height: 2),
        Row(
          children: [
            if (!isActive && _playState == _PlayState.error)
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); _startPlayback(); },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 13, color: Colors.red.shade600),
                    const SizedBox(width: 3),
                    Text(
                      _errorMsg ?? 'Hata oluştu — tekrar dene',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12, color: Colors.red.shade600, letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                isActive ? '${_playIndex + 1} / $total ayet' : '$totalAyets ayet hazır',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 12, color: kGreen.withValues(alpha: 0.7), letterSpacing: 0.3,
                ),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _repeat = !_repeat); },
              child: Icon(
                Icons.repeat_rounded,
                size: 15,
                color: _repeat ? kGold : kGold.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(width: 8),
            buildSleepTimerButton(
              () => showSleepTimerDialog(context, _stopPlayback),
            ),
            const Spacer(),
            if (isActive)
              GestureDetector(
                onTap: _stopPlayback,
                child: Text(
                  'Durdur',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 11,
                    color: Colors.redAccent.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCirclePlayButton({
    required bool isLoading,
    required bool isPlaying,
    required bool cevsenEmpty,
  }) {
    return GestureDetector(
      onTap: (isLoading || cevsenEmpty) ? null : _togglePlayPause,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 60, height: 60,
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
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
              )
            : Icon(
                _playState == _PlayState.error
                    ? Icons.refresh_rounded
                    : (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                color: cevsenEmpty ? kGold.withValues(alpha: 0.3) : kGold,
                size: 32,
              ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showAddSheet,
      backgroundColor: kGreen,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: kGold),
      label: Text(
        'Paket Ekle',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 14, color: kGold, fontWeight: FontWeight.w600, letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Nabız noktası ────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.45, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kGold.withValues(alpha: _anim.value),
          border: Border.all(color: kBg, width: 1.5),
        ),
      ),
    );
  }
}

// ─── İkon yardımcısı ──────────────────────────────────────────────────────────

IconData _iconFor(String icon) => switch (icon) {
      'shield'  => Icons.verified_user_rounded,
      'healing' => Icons.favorite_rounded,
      'star'    => Icons.auto_awesome_rounded,
      'book'    => Icons.menu_book_rounded,
      'throne'  => Icons.account_balance_rounded,
      'pray'    => Icons.self_improvement_rounded,
      'peace'   => Icons.spa_rounded,
      'sun'     => Icons.wb_sunny_rounded,
      _         => Icons.circle_outlined,
    };

// ─── Paket Katalog Sheet ──────────────────────────────────────────────────────

class _PackageCatalogSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Paket) onAdd;
  const _PackageCatalogSheet({required this.onAdd});

  @override
  ConsumerState<_PackageCatalogSheet> createState() => _PackageCatalogSheetState();
}

class _PackageCatalogSheetState extends ConsumerState<_PackageCatalogSheet> {
  List<Paket>? _packages;
  String? _error;
  bool _loading = true;
  final _adding = <String>{};

  @override
  void initState() { super.initState(); _fetchPackages(); }

  Future<void> _fetchPackages() async {
    try {
      final pkgs = await ref.read(apiServiceProvider).fetchPackages();
      if (mounted) setState(() { _packages = pkgs; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Paketler yüklenemedi.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cevsen = ref.watch(cevsenProvider);

    return Container(
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: kGold.withValues(alpha: 0.3), width: 1),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
            child: Row(
              children: [
                Text(
                  'Paket Kataloğu',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: kGold, size: 22),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: CustomPaint(
              size: Size(double.infinity, 12),
              painter: UnvanDividerPainter(),
            ),
          ),
          Flexible(child: _buildBody(cevsen)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Paket> cevsen) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator(color: kGold, strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 44),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _fetchPackages();
              },
              icon: const Icon(Icons.refresh_rounded, color: kGold),
              label: Text('Tekrar Dene',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 14, color: kGold, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    final packages = _packages ?? [];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: packages.length,
      itemBuilder: (_, i) {
        final p     = packages[i];
        final added = cevsen.any((c) => c.id == p.id);
        return _buildCatalogItem(p, added, _adding.contains(p.id));
      },
    );
  }

  Widget _buildCatalogItem(Paket paket, bool added, bool isAdding) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: kIvory,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: added ? kGold : kGold.withValues(alpha: 0.22),
            width: added ? 1.5 : 1.0,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGreen.withValues(alpha: 0.08),
              border: Border.all(color: kGold.withValues(alpha: 0.35), width: 1),
            ),
            child: Icon(_iconFor(paket.icon), color: kGreen, size: 18),
          ),
          title: Text(
            paket.isim,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 14, fontWeight: FontWeight.w700, color: kInk,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paket.aciklama,
                style: TextStyle(fontSize: 11, color: kInk.withValues(alpha: 0.65), height: 1.35),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${paket.ayetSayisi} ayet',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 11, color: kGold, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          trailing: added
              ? const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle_rounded, color: kGold, size: 28),
                )
              : isAdding
                  ? const SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
                    )
                  : IconButton(
                      onPressed: () async {
                        setState(() => _adding.add(paket.id));
                        await widget.onAdd(paket);
                        if (mounted) setState(() => _adding.remove(paket.id));
                      },
                      icon: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kGreen.withValues(alpha: 0.08),
                          border: Border.all(color: kGold, width: 1.2),
                        ),
                        child: const Icon(Icons.add_rounded, color: kGold, size: 18),
                      ),
                    ),
        ),
      ),
    );
  }
}
