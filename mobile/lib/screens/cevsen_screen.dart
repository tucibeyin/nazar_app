import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../models/ayet.dart';
import '../models/paket.dart';
import '../providers/cevsen_provider.dart';
import '../providers/service_providers.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/painters/painters.dart';

// ─── Renk sabitler ────────────────────────────────────────────────────────────

const _kIvory = Color(0xFFFAF3E0);
const _kInk   = Color(0xFF1A0800);

// ─── Oynatma durumu ───────────────────────────────────────────────────────────

enum _PlayState { idle, loading, playing, paused, error }

// ─── CevsenScreen ─────────────────────────────────────────────────────────────

class CevsenScreen extends ConsumerStatefulWidget {
  const CevsenScreen({super.key});

  @override
  ConsumerState<CevsenScreen> createState() => _CevsenScreenState();
}

class _CevsenScreenState extends ConsumerState<CevsenScreen>
    with SingleTickerProviderStateMixin {
  late final AudioService _audio;
  late final AnimationController _ambientCtrl;

  _PlayState _playState = _PlayState.idle;
  List<Ayet> _playlist = [];
  int _playIndex = 0;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(vsync: this, duration: kAmbientDuration)
      ..repeat(reverse: true);
    _audio = AudioService();
    _audio.stateStream.listen((_) { if (mounted) setState(() {}); });
    _audio.completionStream.listen((_) { if (mounted) _advancePlayback(); });
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ── Oynatma mantığı ──────────────────────────────────────────────────────

  Future<void> _startPlayback() async {
    final cevsen = ref.read(cevsenProvider);
    if (cevsen.isEmpty) return;

    setState(() { _playState = _PlayState.loading; _errorMsg = null; });

    try {
      final details = await Future.wait(
        cevsen.map((p) => ref.read(apiServiceProvider).fetchPackageDetail(p.id)),
      );
      _playlist = details.expand((d) => d.ayetler).toList();
      _playIndex = 0;

      if (_playlist.isEmpty) {
        if (mounted) setState(() => _playState = _PlayState.idle);
        return;
      }

      setState(() => _playState = _PlayState.playing);
      await _audio.playFromPath(_playlist[_playIndex].mp3Url);
    } on ApiException catch (e) {
      if (mounted) setState(() { _playState = _PlayState.error; _errorMsg = e.message; });
    } catch (e) {
      if (mounted) setState(() { _playState = _PlayState.error; _errorMsg = 'Bir hata oluştu.'; });
    }
  }

  void _advancePlayback() {
    if (_playIndex + 1 < _playlist.length) {
      setState(() => _playIndex++);
      _audio.playFromPath(_playlist[_playIndex].mp3Url);
    } else {
      setState(() {
        _playState = _PlayState.idle;
        _playlist = [];
        _playIndex = 0;
      });
    }
  }

  Future<void> _togglePlayPause() async {
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
    await _audio.stop();
    if (mounted) {
      setState(() {
        _playState = _PlayState.idle;
        _playlist = [];
        _playIndex = 0;
      });
    }
  }

  // ── Paket ekleme sheet ────────────────────────────────────────────────────

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _PackageCatalogSheet(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cevsen = ref.watch(cevsenProvider);
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
                  child: cevsen.isEmpty
                      ? _buildEmptyState()
                      : _buildList(cevsen),
                ),
                if (cevsen.isNotEmpty || isActive)
                  _buildPlayControls(cevsen),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الجَوْشَن',
                style: GoogleFonts.amiri(
                  fontSize: 20, color: kGold, fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          child: Text(
            'Benim Cevşenim',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 10,
              color: kGold.withValues(alpha: 0.65),
              letterSpacing: 0.5,
              fontStyle: FontStyle.italic,
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
            Icon(Icons.shield_rounded,
                color: kGold.withValues(alpha: 0.25), size: 72),
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
                fontSize: 13,
                color: kGreen.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
                height: 1.5,
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
        final notifier = ref.read(cevsenProvider.notifier);
        final updated = [...cevsen];
        if (newIndex > oldIndex) newIndex--;
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex, item);
        notifier.reorder(updated);
      },
      itemBuilder: (_, i) {
        final paket = cevsen[i];
        final isCurrentPaket = _playState == _PlayState.playing &&
            _playlist.isNotEmpty &&
            _currentPaketIndex(cevsen) == i;

        return _buildPaketCard(paket, i, isCurrentPaket, key: ValueKey(paket.id));
      },
    );
  }

  int _currentPaketIndex(List<Paket> cevsen) {
    int accumulated = 0;
    for (int i = 0; i < cevsen.length; i++) {
      accumulated += cevsen[i].ayetSayisi;
      if (_playIndex < accumulated) return i;
    }
    return cevsen.length - 1;
  }

  Widget _buildPaketCard(Paket paket, int index, bool isActive,
      {required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _kIvory,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? kGold : kGold.withValues(alpha: 0.28),
            width: isActive ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: kGold.withValues(alpha: isActive ? 0.22 : 0.07),
              blurRadius: isActive ? 14 : 6,
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGreen.withValues(alpha: 0.08),
              border: Border.all(color: kGold.withValues(alpha: 0.35), width: 1),
            ),
            child: Icon(_iconFor(paket.icon), color: kGreen, size: 20),
          ),
          title: Text(
            paket.isim,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 15, fontWeight: FontWeight.w700, color: _kInk,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paket.aciklama,
                style: TextStyle(
                    fontSize: 11, color: _kInk.withValues(alpha: 0.55), height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
              if (isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.volume_up_rounded, color: kGold, size: 18),
                ),
              IconButton(
                onPressed: () =>
                    ref.read(cevsenProvider.notifier).remove(paket.id),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.redAccent, size: 22),
              ),
              const Icon(Icons.drag_handle_rounded,
                  color: Color(0xFFC9A84C), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Oynatma kontrolleri ───────────────────────────────────────────────────

  Widget _buildPlayControls(List<Paket> cevsen) {
    final isLoading = _playState == _PlayState.loading;
    final isPlaying = _playState == _PlayState.playing;
    final isActivePlay = isPlaying || _playState == _PlayState.paused;
    final totalPlaylist = isActivePlay ? _playlist.length : 0;
    final progress = totalPlaylist > 0
        ? (_playIndex + 1) / totalPlaylist
        : 0.0;
    final totalAyets = cevsen.fold(0, (s, p) => s + p.ayetSayisi);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
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
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      isActivePlay
                          ? '${_playIndex + 1} / $totalPlaylist ayet'
                          : _playState == _PlayState.error
                              ? (_errorMsg ?? 'Hata oluştu')
                              : '$totalAyets ayet hazır',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12,
                        color: _playState == _PlayState.error
                            ? Colors.red.shade600
                            : kGreen,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    if (isActivePlay)
                      GestureDetector(
                        onTap: _stopPlayback,
                        child: Text(
                          'Durdur',
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
            onTap: (isLoading || cevsen.isEmpty) ? null : _togglePlayPause,
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
                    color: kGold.withValues(
                        alpha: isPlaying ? 0.40 : 0.12),
                    blurRadius: isPlaying ? 18 : 6,
                    spreadRadius: isPlaying ? 3 : 0,
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kGold),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: cevsen.isEmpty
                          ? kGold.withValues(alpha: 0.3)
                          : kGold,
                      size: 34,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showAddSheet,
      backgroundColor: kGreen,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: kGold),
      label: Text(
        'Paket Ekle',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 14,
          color: kGold,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
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
  const _PackageCatalogSheet();

  @override
  ConsumerState<_PackageCatalogSheet> createState() =>
      _PackageCatalogSheetState();
}

class _PackageCatalogSheetState extends ConsumerState<_PackageCatalogSheet> {
  List<Paket>? _packages;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  Future<void> _fetchPackages() async {
    try {
      final packages = await ref.read(apiServiceProvider).fetchPackages();
      if (mounted) setState(() { _packages = packages; _loading = false; });
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
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
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

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: kGold.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
      child: Row(
        children: [
          Text(
            'Paket Kataloğu',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kGreen,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: kGold, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Paket> cevsen) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
            child: CircularProgressIndicator(color: kGold, strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.red.shade400, size: 44),
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Colors.red.shade600),
                textAlign: TextAlign.center),
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
        final p = packages[i];
        final added = cevsen.any((c) => c.id == p.id);
        return _buildCatalogItem(p, added);
      },
    );
  }

  Widget _buildCatalogItem(Paket paket, bool added) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF3E0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: added ? kGold : kGold.withValues(alpha: 0.22),
            width: added ? 1.5 : 1.0,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          leading: Container(
            width: 40,
            height: 40,
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A0800),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paket.aciklama,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1A0800),
                    height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${paket.ayetSayisi} ayet',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 11,
                    color: kGold,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          trailing: added
              ? const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle_rounded, color: kGold, size: 28),
                )
              : IconButton(
                  onPressed: () =>
                      ref.read(cevsenProvider.notifier).add(paket),
                  icon: Container(
                    width: 32,
                    height: 32,
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
