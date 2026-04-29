import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../config/api_config.dart';
import '../core/logger.dart';

// 300 ses dosyası, 30 gün TTL — sınırsız büyümesini engeller.
class _AudioCacheManager extends CacheManager {
  static const _key = 'nazar_audio';
  static final _AudioCacheManager _instance = _AudioCacheManager._();
  factory _AudioCacheManager() => _instance;

  _AudioCacheManager._()
      : super(Config(
          _key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 300,
        ));
}

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;

  late final Stream<void> completionStream = _player.onPlayerStateChanged
      .where((s) => s == PlayerState.completed)
      .map((_) {});

  bool get isPlaying => _player.state == PlayerState.playing;

  AudioService() {
    _configureSession();
  }

  Future<void> _configureSession() async {
    try {
      final session = await audio_session.AudioSession.instance;
      await session.configure(const audio_session.AudioSessionConfiguration(
        avAudioSessionCategory:
            audio_session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
        avAudioSessionSetActiveOptions:
            audio_session.AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: audio_session.AndroidAudioAttributes(
          contentType: audio_session.AndroidAudioContentType.music,
          flags: audio_session.AndroidAudioFlags.none,
          usage: audio_session.AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            audio_session.AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
    } catch (e) {
      AppLogger.warning('AudioSession configure failed: $e');
    }
  }

  Future<void> playFromPath(String mp3Path) async {
    if (mp3Path.isEmpty) {
      AppLogger.warning('AudioService.play: mp3Path boş, atlanıyor');
      return;
    }
    try {
      final url = ApiConfig.audioUrl(mp3Path);
      AppLogger.info('AudioService.play');
      final file = await _AudioCacheManager().getSingleFile(url);
      await _player.play(DeviceFileSource(file.path));
    } catch (e, st) {
      AppLogger.error('AudioService.play failed', e, st);
      rethrow;
    }
  }

  // Sonraki ayetin ses dosyasını arka planda cache'e indirir.
  void prefetch(String mp3Path) {
    if (mp3Path.isEmpty) return;
    final url = ApiConfig.audioUrl(mp3Path);
    _AudioCacheManager().downloadFile(url).ignore();
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.resume();
  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}
