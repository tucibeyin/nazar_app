import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
