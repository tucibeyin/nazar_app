import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_constants.dart';

/// Uyku zamanlayıcısı mantığını ve UI helper'larını sağlar.
/// HatimScreen ve CevsenScreen bu mixin'i paylaşır — kod tekrarını önler.
mixin SleepTimerMixin<T extends StatefulWidget> on State<T> {
  Timer? _sleepTimer;
  Timer? _sleepUiTimer;

  /// Kalan süre için build metodundan okunur.
  DateTime? sleepEnd;

  /// [minutes] dakika sonra [onExpired] çağrılır; [minutes]==0 zamanlayıcıyı iptal eder.
  void setSleepTimer(int minutes, VoidCallback onExpired) {
    _sleepTimer?.cancel();
    _sleepUiTimer?.cancel();
    if (minutes == 0) {
      if (mounted) setState(() => sleepEnd = null);
      return;
    }
    sleepEnd = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (mounted) {
        onExpired();
        setState(() => sleepEnd = null);
      }
    });
    // Her dakika UI'ı güncelle (kalan süre sayacı).
    _sleepUiTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() {});
  }

  void cancelSleepTimer() => setSleepTimer(0, () {});

  /// dispose() içinden çağrılmalı.
  void disposeSleepTimers() {
    _sleepTimer?.cancel();
    _sleepUiTimer?.cancel();
  }

  /// Uyku zamanlayıcısı seçim dialogunu gösterir.
  void showSleepTimerDialog(BuildContext context, VoidCallback onExpired) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kIvory,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kGold.withValues(alpha: 0.4)),
        ),
        title: Text(
          'Uyku Zamanlayıcısı',
          style: GoogleFonts.cormorantGaramond(
            color: kGreen,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final min in [15, 30, 60])
              ListTile(
                dense: true,
                title: Text(
                  '$min dakika',
                  style: GoogleFonts.cormorantGaramond(fontSize: 15, color: kInk),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setSleepTimer(min, onExpired);
                },
              ),
            if (sleepEnd != null)
              ListTile(
                dense: true,
                title: Text(
                  'İptal Et',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 15,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  cancelSleepTimer();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Kontrol satırında kullanılan kalan süre butonu.
  Widget buildSleepTimerButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bedtime_outlined,
            size: 15,
            color: sleepEnd != null ? kGold : kGold.withValues(alpha: 0.35),
          ),
          if (sleepEnd != null) ...[
            const SizedBox(width: 3),
            Text(
              '${(sleepEnd!.difference(DateTime.now()).inSeconds / 60).ceil()}dk',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 11,
                color: kGold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
