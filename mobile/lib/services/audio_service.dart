import 'package:audioplayers/audioplayers.dart';

import '../config/api_config.dart';
import '../core/logger.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  // Kasıtlı stop() sırasında gelen onPlayerComplete eventlerini filtrele.
  // Aksi hâlde playFromPath içindeki stop() çağrısı, dinleyicilerde
  // _advancePlayback → playFromPath → stop() kısır döngüsünü başlatır.
  bool _intentionalStop = false;

  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;

  late final Stream<void> completionStream =
      _player.onPlayerComplete.where((_) => !_intentionalStop);

  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> playFromPath(String mp3Path) async {
    if (mp3Path.isEmpty) {
      AppLogger.warning('AudioService.play: mp3Path boş, atlanıyor');
      return;
    }
    try {
      final url = ApiConfig.audioUrl(mp3Path);
      AppLogger.info('AudioService.play');
      _intentionalStop = true;
      await _player.stop();
      _intentionalStop = false;
      await _player.play(UrlSource(url));
    } catch (e, st) {
      _intentionalStop = false;
      AppLogger.error('AudioService.play failed', e, st);
      rethrow;
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.resume();

  Future<void> stop() async {
    _intentionalStop = true;
    await _player.stop();
    _intentionalStop = false;
  }

  void dispose() => _player.dispose();
}
