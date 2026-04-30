import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logger.dart';

class KazaEntry {
  final String id;
  final String isim;
  final int borc;
  final int kilinen;

  const KazaEntry({
    required this.id,
    required this.isim,
    this.borc = 0,
    this.kilinen = 0,
  });

  KazaEntry copyWith({int? borc, int? kilinen}) => KazaEntry(
        id: id,
        isim: isim,
        borc: borc ?? this.borc,
        kilinen: kilinen ?? this.kilinen,
      );

  double get progress => borc <= 0 ? 0.0 : (kilinen / borc).clamp(0.0, 1.0);
  int get kalan => borc <= kilinen ? 0 : borc - kilinen;
  bool get tamamlandi => borc > 0 && kilinen >= borc;
}

class KazaNotifier extends StateNotifier<List<KazaEntry>> {
  static const List<KazaEntry> _initial = [
    KazaEntry(id: 'sabah',  isim: 'Sabah'),
    KazaEntry(id: 'ogle',   isim: 'Öğle'),
    KazaEntry(id: 'ikindi', isim: 'İkindi'),
    KazaEntry(id: 'aksam',  isim: 'Akşam'),
    KazaEntry(id: 'yatsi',  isim: 'Yatsı'),
    KazaEntry(id: 'vitir',  isim: 'Vitir'),
    KazaEntry(id: 'oruc',   isim: 'Kaza Orucu'),
  ];

  KazaNotifier() : super(_initial) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state
          .map((e) => e.copyWith(
                borc: prefs.getInt('kaza_borc_${e.id}') ?? 0,
                kilinen: prefs.getInt('kaza_done_${e.id}') ?? 0,
              ))
          .toList();
    } catch (e, st) {
      AppLogger.error('KazaNotifier._load', e, st);
    }
  }

  Future<void> _persist(String id, {int? borc, int? kilinen}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (borc != null) await prefs.setInt('kaza_borc_$id', borc);
      if (kilinen != null) await prefs.setInt('kaza_done_$id', kilinen);
    } catch (e, st) {
      AppLogger.error('KazaNotifier._persist', e, st);
    }
  }

  void _update(String id, KazaEntry Function(KazaEntry) fn) {
    state = state.map((e) => e.id == id ? fn(e) : e).toList();
  }

  Future<void> setBorc(String id, int value) async {
    final v = value.clamp(0, 99999);
    _update(id, (e) => e.copyWith(borc: v));
    await _persist(id, borc: v);
  }

  Future<void> increment(String id) async {
    int newVal = 0;
    _update(id, (e) {
      newVal = e.kilinen + 1;
      return e.copyWith(kilinen: newVal);
    });
    await _persist(id, kilinen: newVal);
  }

  Future<void> decrement(String id) async {
    int newVal = 0;
    bool changed = false;
    _update(id, (e) {
      if (e.kilinen <= 0) return e;
      newVal = e.kilinen - 1;
      changed = true;
      return e.copyWith(kilinen: newVal);
    });
    if (changed) await _persist(id, kilinen: newVal);
  }
}

final kazaProvider = StateNotifierProvider<KazaNotifier, List<KazaEntry>>(
  (_) => KazaNotifier(),
);
