import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';
import '../providers/cevsen_provider.dart';
import '../providers/kaza_provider.dart';
import '../providers/notif_settings_provider.dart';
import '../providers/service_providers.dart';
import '../services/backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _exporting = false;
  bool _importing = false;

  // ── Yedekle ────────────────────────────────────────────────────────────────

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await BackupService.exportData();
      if (mounted) _snack('Yedek dosyası hazırlandı.', success: true);
    } catch (e) {
      if (mounted) _snack('Yedekleme başarısız: $e', success: false);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Geri Yükle ─────────────────────────────────────────────────────────────

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final count = await BackupService.importData();
      if (!mounted) return;

      if (count == 0) {
        // Kullanıcı dosya seçimini iptal etti.
        setState(() => _importing = false);
        return;
      }

      // Tüm SharedPreferences-destekli provider'ları tazele.
      ref.invalidate(kazaProvider);
      ref.invalidate(cevsenProvider);
      ref.invalidate(notifSettingsProvider);
      ref.invalidate(hatimProgressProvider);

      _snack('$count veri başarıyla geri yüklendi.', success: true);
    } catch (e) {
      if (mounted) _snack('Geri yükleme başarısız: $e', success: false);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ── Snackbar ────────────────────────────────────────────────────────────────

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: success ? kGreen : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final textColor = isDark ? kGold : kGreen;
    final subColor = isDark ? kDarkSubtext : kGreen.withValues(alpha: 0.6);
    final busy = _exporting || _importing;

    return Scaffold(
      backgroundColor: isDark ? kDarkBg : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? kDarkBg : kBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Yedekleme',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bilgi kutusu ─────────────────────────────────────────────
              _InfoBox(isDark: isDark, subColor: subColor),
              const SizedBox(height: 36),

              // ── Yedekle ──────────────────────────────────────────────────
              Text(
                'Dışa Aktar',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 13,
                  letterSpacing: 2,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.cloud_upload_rounded,
                iconColor: kGreen,
                title: 'Verilerimi Yedekle',
                subtitle: 'Kaza çetelesi, zikir sayıları, cevşen listen '
                    've bildirim ayarlarını bir JSON dosyasına aktar.',
                buttonLabel: 'Yedeği Oluştur',
                buttonColor: kGreen,
                isDark: isDark,
                isLoading: _exporting,
                onTap: busy ? null : _export,
              ),
              const SizedBox(height: 28),

              // ── Geri Yükle ───────────────────────────────────────────────
              Text(
                'İçe Aktar',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 13,
                  letterSpacing: 2,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.cloud_download_rounded,
                iconColor: kGold,
                title: 'Yedekten Geri Yükle',
                subtitle: 'Daha önce oluşturduğun yedek dosyasını seç. '
                    'Tüm veriler mevcut cihaza aktarılır.',
                buttonLabel: 'Dosya Seç',
                buttonColor: kGold,
                isDark: isDark,
                isLoading: _importing,
                onTap: busy ? null : _import,
              ),
              const SizedBox(height: 36),

              // ── Uyarı ────────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: subColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Geri yükleme işlemi mevcut verilerin üzerine yazar '
                      've geri alınamaz.',
                      style: TextStyle(
                        fontSize: 12,
                        color: subColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bilgi Kutusu ─────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final bool isDark;
  final Color subColor;
  const _InfoBox({required this.isDark, required this.subColor});

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark ? kGold.withValues(alpha: 0.18) : kGreen.withValues(alpha: 0.18);
    final bgColor =
        isDark ? kGold.withValues(alpha: 0.06) : kGreen.withValues(alpha: 0.05);
    final iconColor = isDark ? kGold : kGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Text(
                'Neler yedeklenir?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            'Kaza namazı ve oruç çetelesi',
            'Esmaül Hüsna zikir sayıları',
            'Cevşen okuma listen',
            'Hatim ilerleme durumu',
            'Ezan bildirimi ayarları',
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  const SizedBox(width: 2),
                  Icon(Icons.check_rounded,
                      size: 14, color: iconColor.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Text(
                    item,
                    style:
                        TextStyle(fontSize: 12, color: subColor, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aksiyon Kartı ────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final bool isDark;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.isDark,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.80);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.07);
    final titleColor = isDark
        ? Colors.white.withValues(alpha: 0.90)
        : kGreen;
    final subColor = isDark ? kDarkSubtext : kGreen.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: subColor, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    onTap == null ? buttonColor.withValues(alpha: 0.4) : buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      buttonLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
