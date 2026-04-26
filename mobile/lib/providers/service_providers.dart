import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/ayet_repository.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

// ─── Servis Providers ─────────────────────────────────────────────────────────

final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  ref.onDispose(service.dispose);
  return service;
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});

// ─── Repository Provider ──────────────────────────────────────────────────────

final ayetRepositoryProvider = Provider<AyetRepository>((ref) {
  final api = ref.watch(apiServiceProvider);
  final repo = AyetRepository(api);
  ref.onDispose(repo.dispose);
  return repo;
});

// ─── Connectivity Provider ────────────────────────────────────────────────────

class _ConnectivityNotifier extends StateNotifier<bool> {
  _ConnectivityNotifier() : super(true) {
    _init();
  }

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _init() async {
    final initial = await _connectivity.checkConnectivity();
    if (mounted) state = _isOnline(initial);
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      if (mounted) state = _isOnline(results);
    });
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      !results.contains(ConnectivityResult.none);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// `true` = çevrimiçi, `false` = çevrimdışı
final connectivityProvider = StateNotifierProvider<_ConnectivityNotifier, bool>(
  (_) => _ConnectivityNotifier(),
);

// ─── Tema Provider ────────────────────────────────────────────────────────────

class _ThemeNotifier extends StateNotifier<ThemeMode> {
  _ThemeNotifier() : super(ThemeMode.light);

  void toggle() => state =
      state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

  bool get isDark => state == ThemeMode.dark;
}

final themeProvider = StateNotifierProvider<_ThemeNotifier, ThemeMode>(
  (_) => _ThemeNotifier(),
);

// ─── Hatim İlerleme Provider ──────────────────────────────────────────────────

class HatimProgressNotifier extends StateNotifier<int> {
  static const _key = 'hatim_index';

  HatimProgressNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = prefs.getInt(_key) ?? 0;
  }

  Future<void> advance(int total) async {
    state = (state + 1) % total;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, state);
  }

  Future<void> reset() async {
    state = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, 0);
  }
}

final hatimProgressProvider = StateNotifierProvider<HatimProgressNotifier, int>(
  (_) => HatimProgressNotifier(),
);
