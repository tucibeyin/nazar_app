import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../providers/kaza_provider.dart';

class KazaScreen extends ConsumerStatefulWidget {
  const KazaScreen({super.key});

  @override
  ConsumerState<KazaScreen> createState() => _KazaScreenState();
}

class _KazaScreenState extends ConsumerState<KazaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showDebtDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const _DebtDialog(),
    );
  }

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
                  colors: [Color(0xFF071220), Color(0xFF0C1F35), Color(0xFF071220)],
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
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildNamazlarTab(),
                      _buildOrucTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Geri',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF7EC8E3), size: 20),
          ),
          Expanded(
            child: Text(
              'Kaza Çetelesi',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kGold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Borçları Ayarla',
            onPressed: _showDebtDialog,
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF7EC8E3), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabCtrl,
      indicatorColor: kGold,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorWeight: 2,
      labelColor: kGold,
      unselectedLabelColor: const Color(0xFF5D8AA0),
      labelStyle: GoogleFonts.cormorantGaramond(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: GoogleFonts.cormorantGaramond(fontSize: 14),
      dividerColor: const Color(0xFF1A3A5C),
      tabs: const [
        Tab(text: 'Namazlar'),
        Tab(text: 'Oruç'),
      ],
    );
  }

  Widget _buildNamazlarTab() {
    final entries = ref.watch(kazaProvider).where((e) => e.id != 'oruc').toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: entries.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _KazaItemCard(entryId: entries[i].id),
      ),
    );
  }

  Widget _buildOrucTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        children: [
          const _KazaItemCard(entryId: 'oruc', large: true),
          const SizedBox(height: 28),
          Text(
            '« Ramazan ayında hasta olan veya yolcu bulunan kimse, tutamadığı günler kadar diğer günlerde kaza eder. »\n— Bakara 2:185',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 13,
              color: kGold.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kaza Item Card ─────────────────────────────────────────────────────────────

class _KazaItemCard extends ConsumerWidget {
  final String entryId;
  final bool large;

  const _KazaItemCard({required this.entryId, this.large = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(kazaProvider).firstWhere((e) => e.id == entryId);
    final notifier = ref.read(kazaProvider.notifier);
    final isDone = entry.tamamlandi;
    final hasDebt = entry.borc > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(large ? 20 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0D2035),
        border: Border.all(
          color: isDone
              ? kGold.withValues(alpha: 0.45)
              : const Color(0xFF7EC8E3).withValues(alpha: 0.12),
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDone
                ? kGold.withValues(alpha: 0.08)
                : const Color(0xFF1A5F7A).withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Satır 1: isim + sayaç
          Row(
            children: [
              if (isDone)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: kGold.withValues(alpha: 0.8),
                    size: 16,
                  ),
                ),
              Text(
                entry.isim,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: large ? 22 : 16,
                  fontWeight: FontWeight.w700,
                  color: isDone ? kGold : Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (hasDebt) ...[
                Text(
                  '${entry.kilinen}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: large ? 24 : 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7EC8E3),
                  ),
                ),
                Text(
                  ' / ${entry.borc}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: large ? 17 : 13,
                    color: const Color(0xFF5D8AA0),
                  ),
                ),
              ] else
                const Text(
                  'Borç girilmedi',
                  style: TextStyle(fontSize: 11, color: Color(0xFF3D6480)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // İlerleme çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: entry.progress,
              minHeight: large ? 8 : 5,
              backgroundColor: const Color(0xFF1A3A5C).withValues(alpha: 0.45),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? kGold : const Color(0xFF5DADE2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Satır 3: kalan bilgisi + butonlar
          Row(
            children: [
              if (isDone)
                Text(
                  'Tamamlandı',
                  style: TextStyle(
                    fontSize: 11,
                    color: kGold.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (hasDebt)
                Text(
                  '${entry.kalan} kaldı',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5D8AA0)),
                ),
              const Spacer(),
              // -1 butonu (uzun bas)
              Tooltip(
                message: 'Geri al (basılı tut)',
                child: GestureDetector(
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    notifier.decrement(entryId);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A3A5C).withValues(alpha: 0.35),
                      border: Border.all(
                        color: const Color(0xFF5D8AA0).withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.remove,
                      size: 15,
                      color: Color(0xFF5D8AA0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // +1 butonu
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  notifier.increment(entryId);
                  final updated = ref.read(kazaProvider).firstWhere((e) => e.id == entryId);
                  if (updated.tamamlandi && updated.kilinen == updated.borc) {
                    _showCompletion(context, entry.isim);
                  }
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF1A5F7A).withValues(alpha: 0.65),
                    border: Border.all(
                      color: const Color(0xFF7EC8E3).withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '+ Kıldım',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCompletion(BuildContext context, String isim) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF0D2035),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kGold.withValues(alpha: 0.4), width: 1),
        ),
        content: Text(
          '$isim kazası tamamlandı — Allah kabul etsin',
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 14,
            color: kGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Borç Ayarları Dialogu ──────────────────────────────────────────────────────

class _DebtDialog extends ConsumerStatefulWidget {
  const _DebtDialog();

  @override
  ConsumerState<_DebtDialog> createState() => _DebtDialogState();
}

class _DebtDialogState extends ConsumerState<_DebtDialog> {
  final Map<String, TextEditingController> _ctrl = {};

  @override
  void initState() {
    super.initState();
    for (final e in ref.read(kazaProvider)) {
      _ctrl[e.id] = TextEditingController(
        text: e.borc > 0 ? '${e.borc}' : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(kazaProvider.notifier);
    final entries = ref.read(kazaProvider);
    for (final e in entries) {
      final val = int.tryParse(_ctrl[e.id]?.text.trim() ?? '') ?? 0;
      await notifier.setBorc(e.id, val);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.read(kazaProvider);
    final namazlar = entries.where((e) => e.id != 'oruc').toList();
    final oruc = entries.firstWhere((e) => e.id == 'oruc');

    return AlertDialog(
      backgroundColor: const Color(0xFF0D2035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kGold.withValues(alpha: 0.25), width: 1),
      ),
      title: Text(
        'Kaza Borçları',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: kGold,
          letterSpacing: 1,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Her vakit için toplam kaza borç sayısını gir.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5D8AA0), height: 1.5),
            ),
            const SizedBox(height: 16),
            // Namazlar
            ...namazlar.map((e) => _DebtRow(name: e.isim, controller: _ctrl[e.id]!)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFF1A3A5C), height: 1),
            ),
            // Oruç
            _DebtRow(name: oruc.isim, controller: _ctrl[oruc.id]!),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal', style: TextStyle(color: Color(0xFF5D8AA0))),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A5F7A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  final String name;
  final TextEditingController controller;

  const _DebtRow({required this.name, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                hintText: '0',
                hintStyle: const TextStyle(color: Color(0xFF3D6480)),
                filled: true,
                fillColor: const Color(0xFF1A3A5C).withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kGold.withValues(alpha: 0.2), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: const Color(0xFF7EC8E3).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kGold.withValues(alpha: 0.5), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
