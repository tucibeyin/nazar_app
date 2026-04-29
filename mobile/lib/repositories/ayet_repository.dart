import '../core/logger.dart';
import '../models/ayet.dart';
import '../services/api_service.dart';

/// API çağrılarını saran in-memory LRU cache katmanı.
/// Aynı hash için tekrar istek atmaz; max [_maxSize] girdi tutar.
class AyetRepository {
  final ApiService _api;
  final _cache = <int, Ayet>{};
  static const _maxSize = 50;

  AyetRepository(this._api);

  Future<Ayet> fetchAyet(int hashInt) async {
    if (_cache.containsKey(hashInt)) {
      AppLogger.info('AyetRepository cache hit');
      // LRU: erişilen key sona taşınır; _evictIfNeeded ilk key'i (en eskiyi) siler.
      final ayet = _cache.remove(hashInt)!;
      _cache[hashInt] = ayet;
      return ayet;
    }
    final ayet = await _api.fetchAyet(hashInt);
    _evictIfNeeded();
    _cache[hashInt] = ayet;
    return ayet;
  }

  void clearCache() => _cache.clear();

  int get cacheSize => _cache.length;

  void _evictIfNeeded() {
    if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  void dispose() {
    _cache.clear();
    // _api lifecycle'ı Provider tarafından yönetilir.
  }
}
