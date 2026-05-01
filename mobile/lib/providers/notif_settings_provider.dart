import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_times.dart';
import '../services/notification_service.dart';

class NotifSettingsNotifier extends StateNotifier<Map<String, bool>> {
  NotifSettingsNotifier() : super({}) {
    _load();
  }

  static const _kPref = 'notif_';
  static const _kVakitler = [
    'İmsak',
    'Güneş',
    'Öğle',
    'İkindi',
    'Akşam',
    'Yatsı',
  ];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      for (final v in _kVakitler) v: prefs.getBool('$_kPref$v') ?? true,
    };
  }

  bool isEnabled(String vakit) => state[vakit] ?? true;

  Future<void> toggle(String vakit, PrayerTimesData? currentData) async {
    final newVal = !(state[vakit] ?? true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPref$vakit', newVal);
    state = {...state, vakit: newVal};

    final svc = NotificationService();
    if (!newVal) {
      await svc.cancelAlarm(vakit);
    } else if (currentData != null) {
      await svc.scheduleSingleAlarm(vakit, currentData);
    }
  }
}

final notifSettingsProvider =
    StateNotifierProvider<NotifSettingsNotifier, Map<String, bool>>(
  (_) => NotifSettingsNotifier(),
);
