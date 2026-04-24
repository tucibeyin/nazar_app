import 'package:audioplayers/audioplayers.dart';

import '../config/api_config.dart';
import '../core/logger.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;
  Stream<void> get completionStream => _player.onPlayerComplete;

  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> playFromPath(String mp3Path) async {
    try {
      final url = ApiConfig.audioUrl(mp3Path);
      AppLogger.info('AudioService.play', url);
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e, st) {
      AppLogger.error('AudioService.play failed', e, st);
      rethrow;
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.resume();
  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}
