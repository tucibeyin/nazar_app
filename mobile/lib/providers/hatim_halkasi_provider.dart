import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
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

  // Injectable for testing — null means no WebSocket (HTTP polling only).
  final WebSocketChannel Function(Uri)? _wsConnect;

  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  static const _kMaxReconnects = 3;
  static const _kReconnectDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  HatimHalkasiNotifier(this._api, {WebSocketChannel Function(Uri)? wsConnect})
      : _wsConnect = wsConnect,
        super(const HatimHalkasiState());

  Future<void> createRoom() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final room = await _api.createHatimRoom();
      state = state.copyWith(
        roomCode: room.code,
        juzler: room.juzler,
        isLoading: false,
      );
      _startLiveSync(room.code);
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
      _startLiveSync(room.code);
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
      // Polling/refresh hatası sessizce geçilir
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
      await refresh();
      state = state.copyWith(error: e.message);
    }
  }

  void leaveRoom() {
    _stopLiveSync();
    state = const HatimHalkasiState();
  }

  // ── Live Sync (WebSocket öncelikli, HTTP polling yedek) ───────────────────

  void _startLiveSync(String code) {
    _stopLiveSync();
    _reconnectAttempts = 0;
    if (_wsConnect != null) {
      _connectWebSocket(code);
    } else {
      _startHttpPolling();
    }
  }

  void _connectWebSocket(String code) {
    if (_disposed) return;
    try {
      final uri = Uri.parse(ApiConfig.wsHatimHalkasiUrl(code));
      _wsChannel = _wsConnect!(uri);
      _wsSub = _wsChannel!.stream.listen(
        (data) {
          if (_disposed || state.roomCode != code) return;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json.containsKey('code')) {
              final room = HatimRoom.fromJson(json);
              state = state.copyWith(juzler: room.juzler);
              _reconnectAttempts = 0;
            }
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(code),
        onDone: () => _scheduleReconnect(code),
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect(code);
    }
  }

  void _scheduleReconnect(String code) {
    if (_disposed || state.roomCode != code) return;
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _wsSub = null;

    if (_reconnectAttempts >= _kMaxReconnects) {
      _startHttpPolling();
      return;
    }

    final delay = _kReconnectDelays[_reconnectAttempts];
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () {
      if (!_disposed && state.roomCode == code) _connectWebSocket(code);
    });
  }

  void _startHttpPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refresh(),
    );
  }

  void _stopLiveSync() {
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _wsChannel = null;
    _wsSub = null;
    _reconnectTimer = null;
    _pollTimer = null;
    _reconnectAttempts = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopLiveSync();
    super.dispose();
  }
}

final hatimHalkasiProvider =
    StateNotifierProvider<HatimHalkasiNotifier, HatimHalkasiState>(
  (ref) => HatimHalkasiNotifier(
    ref.read(apiServiceProvider),
    wsConnect: WebSocketChannel.connect,
  ),
);
