import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/paket.dart';

class CevsenNotifier extends StateNotifier<List<Paket>> {
  static const _key = 'cevsen_paketler';

  CevsenNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    if (mounted) {
      state = raw
          .map((s) => Paket.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> add(Paket paket) async {
    if (state.any((p) => p.id == paket.id)) return;
    state = [...state, paket];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
  }

  Future<void> reorder(List<Paket> newOrder) async {
    state = newOrder;
    await _save();
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  bool contains(String id) => state.any((p) => p.id == id);

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      state.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}

final cevsenProvider = StateNotifierProvider<CevsenNotifier, List<Paket>>(
  (_) => CevsenNotifier(),
);
