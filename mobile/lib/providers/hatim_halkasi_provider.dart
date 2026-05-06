import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hatim_room.dart';
import '../providers/service_providers.dart';
import '../services/api_service.dart';

class HatimHalkasiState {
  final String? roomCode;
  final List<JuzItem> juzler;
  final bool isLoading;
  final String? error;

  const HatimHalkasiState({
    this.roomCode,
    this.juzler = const [],
    this.isLoading = false,
    this.error,
  });

  HatimHalkasiState copyWith({
    String? roomCode,
    bool clearRoomCode = false,
    List<JuzItem>? juzler,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      HatimHalkasiState(
        roomCode: clearRoomCode ? null : roomCode ?? this.roomCode,
        juzler: juzler ?? this.juzler,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class HatimHalkasiNotifier extends StateNotifier<HatimHalkasiState> {
  final ApiService _api;
  Timer? _pollTimer;

  HatimHalkasiNotifier(this._api) : super(const HatimHalkasiState());

  Future<void> createRoom() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final room = await _api.createHatimRoom();
      state = state.copyWith(
        roomCode: room.code,
        juzler: room.juzler,
        isLoading: false,
      );
      _startPolling();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> joinRoom(String code) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final room = await _api.getHatimRoom(code.toUpperCase());
      state = state.copyWith(
        roomCode: room.code,
        juzler: room.juzler,
        isLoading: false,
      );
      _startPolling();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> refresh() async {
    final code = state.roomCode;
    if (code == null) return;
    try {
      final room = await _api.getHatimRoom(code);
      state = state.copyWith(juzler: room.juzler);
    } on ApiException {
      // Polling hatası sessizce geçilir; manual refresh hata gösterir
    }
  }

  Future<void> updateJuz(int juzNum, JuzDurum durum) async {
    final code = state.roomCode;
    if (code == null) return;
    // Optimistic update
    final optimistic = state.juzler
        .map((j) => j.juzNum == juzNum ? j.copyWith(durum: durum) : j)
        .toList();
    state = state.copyWith(juzler: optimistic);
    try {
      await _api.updateHatimJuz(code, juzNum, durum.name);
    } on ApiException catch (e) {
      // Rollback ve hata göster
      await refresh();
      state = state.copyWith(error: e.message);
    }
  }

  void leaveRoom() {
    _stopPolling();
    state = const HatimHalkasiState();
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => refresh(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

final hatimHalkasiProvider =
    StateNotifierProvider<HatimHalkasiNotifier, HatimHalkasiState>(
  (ref) => HatimHalkasiNotifier(ref.read(apiServiceProvider)),
);
