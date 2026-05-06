import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../models/hatim_room.dart';
import '../providers/hatim_halkasi_provider.dart';
import '../providers/service_providers.dart';
import '../services/social_share_service.dart';

// ─── Ana Ekran ────────────────────────────────────────────────────────────────

class HatimHalkasiScreen extends ConsumerStatefulWidget {
  const HatimHalkasiScreen({super.key});

  @override
  ConsumerState<HatimHalkasiScreen> createState() =>
      _HatimHalkasiScreenState();
}

class _HatimHalkasiScreenState extends ConsumerState<HatimHalkasiScreen> {
  final _inviteKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hatimHalkasiProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    ref.listen<HatimHalkasiState>(hatimHalkasiProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: isDark ? kDarkBg : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? kDarkBg : kBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: isDark ? kGold : kGreen, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Hatim Halkası',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? kGold : kGreen,
          ),
        ),
        actions: state.roomCode != null
            ? [
                IconButton(
                  icon: Icon(Icons.exit_to_app_rounded,
                      color: Colors.red.shade400, size: 22),
                  tooltip: 'Halkadan Ayrıl',
                  onPressed: () => _confirmLeave(context),
                ),
              ]
            : [],
      ),
      body: state.isLoading && state.roomCode == null
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : state.roomCode == null
              ? _LobbyView(isDark: isDark)
              : _RoomView(
                  state: state,
                  isDark: isDark,
                  inviteKey: _inviteKey,
                ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Halkadan Ayrıl'),
        content: const Text(
            'Bu hatim halkasından ayrılmak istiyor musun?\nOda kodu kaybolacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(hatimHalkasiProvider.notifier).leaveRoom();
            },
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
  }
}

// ─── Lobi ─────────────────────────────────────────────────────────────────────

class _LobbyView extends ConsumerWidget {
  final bool isDark;
  const _LobbyView({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = isDark ? kGold : kGreen;
    final subColor =
        isDark ? kDarkSubtext : kGreen.withValues(alpha: 0.65);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_alt_rounded,
                  size: 68, color: textColor.withValues(alpha: 0.55)),
              const SizedBox(height: 20),
              Text(
                'Hatim Halkası',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Arkadaşlarınla 30 cüzü paylaşarak\nbirlikte hatim indir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: subColor, height: 1.5),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Yeni Hatim Halkası Oluştur'),
                  onPressed: () =>
                      ref.read(hatimHalkasiProvider.notifier).createRoom(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.login_rounded, color: textColor),
                  label: Text(
                    'Oda Kodu ile Katıl',
                    style: TextStyle(color: textColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: textColor.withValues(alpha: 0.4)),
                  ),
                  onPressed: () => _showJoinDialog(context, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oda Kodunu Gir'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Örn: X7B9K2',
            counterText: '',
          ),
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            letterSpacing: 6,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final code =
                  ctrl.text.toUpperCase().replaceAll(' ', '');
              if (code.length == 6) {
                Navigator.pop(ctx);
                ref.read(hatimHalkasiProvider.notifier).joinRoom(code);
              }
            },
            child: const Text('Katıl'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }
}

// ─── Oda Görünümü ─────────────────────────────────────────────────────────────

class _RoomView extends ConsumerWidget {
  final HatimHalkasiState state;
  final bool isDark;
  final GlobalKey inviteKey;
  const _RoomView({
    required this.state,
    required this.isDark,
    required this.inviteKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = state.juzler.where((j) => j.durum == JuzDurum.okundu).length;
    final inProgress = state.juzler.where((j) => j.durum == JuzDurum.alindi).length;

    return Column(
      children: [
        // Davet kartı + paylaş ikonu katmanı
        Stack(
          alignment: Alignment.topRight,
          children: [
            RepaintBoundary(
              key: inviteKey,
              child: _HatimInviteCard(code: state.roomCode!),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => SocialShareService.shareWidgetAsImage(
                  inviteKey,
                  text:
                      'Hatim halkamıza katıl! Oda kodu: ${state.roomCode}',
                ),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF071220).withValues(alpha: 0.82),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kGold.withValues(alpha: 0.45), width: 1),
                  ),
                  child: const Icon(
                    Icons.ios_share_rounded,
                    size: 16,
                    color: kGold,
                  ),
                ),
              ),
            ),
          ],
        ),
        // İlerleme çubuğu
        LinearProgressIndicator(
          value: completed / 30,
          backgroundColor: Colors.grey.withValues(alpha: 0.18),
          valueColor: const AlwaysStoppedAnimation<Color>(kGreen),
          minHeight: 3,
        ),
        // Özet satırı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _StatChip(
                  count: completed,
                  label: 'Tamamlandı',
                  color: kGreen),
              const SizedBox(width: 8),
              _StatChip(
                  count: inProgress,
                  label: 'Okunuyor',
                  color: kGold),
              const Spacer(),
              if (state.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kGold),
                )
              else
                GestureDetector(
                  onTap: () =>
                      ref.read(hatimHalkasiProvider.notifier).refresh(),
                  child: Icon(Icons.refresh_rounded,
                      size: 20,
                      color: isDark
                          ? kGold.withValues(alpha: 0.7)
                          : kGreen.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
        // Cüz ızgarası
        Expanded(
          child: RefreshIndicator(
            color: kGold,
            onRefresh: () =>
                ref.read(hatimHalkasiProvider.notifier).refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
              itemCount: state.juzler.length,
              itemBuilder: (ctx, i) =>
                  _JuzCard(juz: state.juzler[i], isDark: isDark),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Davet Kartı (paylaşılabilir görsel) ─────────────────────────────────────

class _HatimInviteCard extends StatelessWidget {
  final String code;
  const _HatimInviteCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071220), Color(0xFF0D2035)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          // Marka bandı
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mosque_rounded,
                  color: Color(0xFF7EC8E3), size: 14),
              SizedBox(width: 7),
              Text(
                'NAZAR & FERAHLAMA',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: Color(0xFF7EC8E3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: kGold.withValues(alpha: 0.28)),
          const SizedBox(height: 12),
          Text(
            'Hatim Halkamıza Katılın!',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kGold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'ODA KODU',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 3.5,
              color: Color(0xFF8AACBF),
            ),
          ),
          const SizedBox(height: 8),
          // Her harf ayrı kutuda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: code.split('').map((char) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 32,
                height: 38,
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: kGold.withValues(alpha: 0.45), width: 1.2),
                ),
                child: Center(
                  child: Text(
                    char,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kGold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kGold.withValues(alpha: 0.28)),
          const SizedBox(height: 10),
          Text(
            '30 cüzü birlikte okuduğumuzda Allah kabul etsin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: kGold.withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Özet Chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatChip(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Cüz Kartı ────────────────────────────────────────────────────────────────

class _JuzCard extends ConsumerWidget {
  final JuzItem juz;
  final bool isDark;
  const _JuzCard({required this.juz, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (bgColor, borderColor, labelColor, statusText, statusIcon) =
        _style();

    return GestureDetector(
      onTap: juz.durum != JuzDurum.okundu ? () => _onTap(context, ref) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: juz.durum == JuzDurum.okundu
              ? [
                  BoxShadow(
                    color: kGreen.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${juz.juzNum}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.88)
                    : kGreen,
              ),
            ),
            Text(
              'CÜZ',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 2,
                color: labelColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            if (statusIcon != null) ...[
              Icon(statusIcon, size: 15, color: labelColor),
              const SizedBox(height: 2),
            ],
            Text(
              statusText,
              style: TextStyle(
                fontSize: 9,
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, Color, String, IconData?) _style() => switch (juz.durum) {
    JuzDurum.alindi => (
      kGold.withValues(alpha: isDark ? 0.18 : 0.12),
      kGold.withValues(alpha: 0.55),
      isDark ? kGold : const Color(0xFF8B6914),
      'Okunuyor',
      Icons.auto_stories_rounded,
    ),
    JuzDurum.okundu => (
      kGreen.withValues(alpha: isDark ? 0.22 : 0.13),
      kGreen.withValues(alpha: 0.5),
      kGreen,
      'Bitti',
      Icons.check_circle_rounded,
    ),
    JuzDurum.bos => (
      isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.82),
      isDark
          ? Colors.white.withValues(alpha: 0.12)
          : kGreen.withValues(alpha: 0.15),
      isDark ? Colors.white38 : kGreen.withValues(alpha: 0.4),
      'Boş',
      null,
    ),
  };

  void _onTap(BuildContext context, WidgetRef ref) {
    if (juz.durum == JuzDurum.bos) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${juz.juzNum}. Cüz'),
          content: const Text(
              'Bu cüzü okumak üzere almak istiyor musun?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hayır'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(hatimHalkasiProvider.notifier)
                    .updateJuz(juz.juzNum, JuzDurum.alindi);
              },
              child: const Text('Evet, Al'),
            ),
          ],
        ),
      );
    } else if (juz.durum == JuzDurum.alindi) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark ? const Color(0xFF1A2830) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${juz.juzNum}. Cüz — Okunuyor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? kGold : kGreen,
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading:
                    const Icon(Icons.check_circle_rounded, color: kGreen),
                title: const Text('Cüzü Okudum (Tamamla)'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(hatimHalkasiProvider.notifier)
                      .updateJuz(juz.juzNum, JuzDurum.okundu);
                },
              ),
              ListTile(
                leading: Icon(Icons.undo_rounded,
                    color: Colors.red.shade400),
                title: const Text('Geri Bırak (Boşalt)'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(hatimHalkasiProvider.notifier)
                      .updateJuz(juz.juzNum, JuzDurum.bos);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
  }
}
