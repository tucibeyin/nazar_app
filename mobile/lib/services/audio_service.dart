import 'package:audioplayers/audioplayers.dart';

import '../config/api_config.dart';
import '../core/logger.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;

  // onPlayerStateChanged.completed kullanıyoruz çünkü stop() çağrısı
  // PlayerState.stopped üretir; PlayerState.completed yalnızca doğal bitişte.
  late final Stream<void> completionStream = _player.onPlayerStateChanged
      .where((s) => s == PlayerState.completed)
      .map((_) {});

  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> playFromPath(String mp3Path) async {
    if (mp3Path.isEmpty) {
      AppLogger.warning('AudioService.play: mp3Path boş, atlanıyor');
      return;
    }
    try {
      final url = ApiConfig.audioUrl(mp3Path);
      AppLogger.info('AudioService.play');
      // stop() KASITLI olarak KALDIRILDI.
      // play() iOS'ta AVPlayer.replaceCurrentItem kullanır ve geçişi
      // kendi yönetir. Önceden stop() çağırmak PlayerState.completed
      // olayını spurious olarak tetikleyip cascade'e yol açıyordu.
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
