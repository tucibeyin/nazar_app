import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../models/esma.dart';
import '../providers/esmaul_husna_provider.dart';

class EsmaListScreen extends ConsumerWidget {
  const EsmaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(esmaulHusnaProvider);

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
                _buildAppBar(context),
                Expanded(
                  child: async.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7EC8E3),
                        strokeWidth: 1.5,
                      ),
                    ),
                    error: (e, _) => _buildError(ref, e.toString()),
                    data: (list) => _buildGrid(context, list),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
              'Esmaül Hüsna',
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

  Widget _buildError(WidgetRef ref, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFF5D8AA0), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Liste yüklenemedi.\nİnternet bağlantınızı kontrol edin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9FB8CC), fontSize: 14, height: 1.7),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => ref.invalidate(esmaulHusnaProvider),
              child: const Text('Tekrar Dene', style: TextStyle(color: Color(0xFF7EC8E3))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<Esma> list) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.88,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _EsmaCard(esma: list[i]),
    );
  }
}

class _EsmaCard extends StatelessWidget {
  final Esma esma;
  const _EsmaCard({required this.esma});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/esma-dhikr', extra: esma),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0D2035),
          border: Border.all(
            color: const Color(0xFF7EC8E3).withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A5F7A).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ebced badge
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: kGold.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    '${esma.ebcedDegeri}',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 11,
                      color: kGold.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Arabic
              Text(
                esma.arapca,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.amiri(
                  fontSize: 24,
                  color: kGold.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              // Turkish name
              Text(
                esma.isim,
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7EC8E3),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  esma.anlam,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8AACBF),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
