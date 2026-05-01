import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/app_constants.dart';
import '../core/logger.dart';
import '../models/ayet.dart';
import '../models/esma.dart';
import '../models/hatim_ayet.dart';
import '../models/hatim_room.dart';
import '../models/paket.dart';
import '../models/prayer_times.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final http.Client _client;
  // Testlerde gecikmeyi sıfıra indirmek için enjekte edilebilir; null = üretim değeri.
  final Duration Function(int attempt)? _retryDelay;
  static final _rng = math.Random();

  ApiService({http.Client? client, Duration Function(int attempt)? retryDelay})
      : _client = client ?? http.Client(),
        _retryDelay = retryDelay;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (ApiConfig.apiKey.isNotEmpty) 'X-API-Key': ApiConfig.apiKey,
      };

  // Tüm endpointler için ortak retry mantığı.
  // 4xx → anında fırlatır (retry edilmez). 5xx / ağ → kMaxRetries'e kadar dener.
  Future<T> _withRetry<T>(String tag, Future<T> Function() fn) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= kMaxRetries; attempt++) {
      try {
        AppLogger.info('$tag attempt $attempt');
        return await fn();
      } on ApiException catch (e) {
        // 4xx → anında fırlat (client hatası, retry fayda sağlamaz)
        if (e.statusCode != null && e.statusCode! < 500) rethrow;
        lastError = e;
      } on SocketException {
        lastError = const ApiException('İnternet bağlantısı bulunamadı.');
      } on TlsException {
        lastError = const ApiException('Güvenli bağlantı kurulamadı.');
      } on HttpException {
        lastError = const ApiException('Sunucuya ulaşılamadı.');
      } on FormatException {
        lastError = const ApiException('Sunucu yanıtı okunamadı.');
      } on TimeoutException {
        lastError = const ApiException('Sunucu yanıt vermedi. Lütfen tekrar deneyin.');
      } catch (e, st) {
        AppLogger.error('$tag unexpected error', e, st);
        lastError = ApiException('Beklenmedik hata: $e');
      }
      if (attempt < kMaxRetries) {
        final delay = _retryDelay != null
            ? _retryDelay(attempt)
            : kRetryBackoff * attempt + Duration(milliseconds: _rng.nextInt(500));
        AppLogger.warning('$tag retry in ${delay.inMilliseconds}ms (attempt $attempt)');
        await Future<void>.delayed(delay);
      }
    }
    throw lastError ?? const ApiException('Bilinmeyen ağ hatası.');
  }

  ApiException _fromStatus(int code, String fallback) {
    if (code == 429) return const ApiException('Çok fazla istek gönderildi. Lütfen bekleyin.', statusCode: 429);
    if (code == 401) return const ApiException('Yetkilendirme hatası.', statusCode: 401);
    return ApiException(fallback, statusCode: code);
  }

  Future<Ayet> fetchAyet(int hashInt) => _withRetry('fetchAyet', () async {
        final resp = await _client
            .get(Uri.parse(ApiConfig.nazarEndpoint(hashInt)), headers: _headers)
            .timeout(kApiTimeout);
        if (resp.statusCode == 200) {
          return Ayet.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        }
        throw _fromStatus(resp.statusCode, 'İstemci hatası.');
      });

  Future<HatimAyet> fetchHatimAyet(int index) => _withRetry('fetchHatimAyet', () async {
        final resp = await _client
            .get(Uri.parse(ApiConfig.hatimEndpoint(index)), headers: _headers)
            .timeout(kApiTimeout);
        if (resp.statusCode == 200) {
          return HatimAyet.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        }
        throw _fromStatus(resp.statusCode, 'Hatim API hatası.');
      });

  static const _kPackagesCacheKey = 'packages_cache';

  Future<List<Paket>> fetchPackages() async {
    try {
      return await _withRetry('fetchPackages', () async {
        final resp = await _client
            .get(Uri.parse(ApiConfig.packagesEndpoint()), headers: _headers)
            .timeout(kApiTimeout);
        if (resp.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kPackagesCacheKey, resp.body);
          return (jsonDecode(resp.body) as List<dynamic>)
              .map((e) => Paket.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw _fromStatus(resp.statusCode, 'Paket listesi alınamadı.');
      });
    } on ApiException catch (e) {
      // statusCode == null → ağ katmanı hatası (SocketException, TlsException vb.)
      if (e.statusCode == null) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_kPackagesCacheKey);
        if (cached != null) {
          AppLogger.warning('fetchPackages: ağ hatası, önbellekten yükleniyor');
          return (jsonDecode(cached) as List<dynamic>)
              .map((e) => Paket.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      rethrow;
    }
  }

  Future<PaketDetay> fetchPackageDetail(String id) => _withRetry('fetchPackageDetail', () async {
        final resp = await _client
            .get(Uri.parse(ApiConfig.packageDetailEndpoint(id)), headers: _headers)
            .timeout(kApiTimeout);
        if (resp.statusCode == 200) {
          return PaketDetay.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        }
        throw _fromStatus(resp.statusCode, 'Paket detayı alınamadı.');
      });

  Future<PrayerTimesData> fetchPrayerTimes(double lat, double lng) =>
      _withRetry('fetchPrayerTimes', () async {
        final resp = await _client
            .get(Uri.parse(ApiConfig.prayerTimesEndpoint(lat, lng)), headers: _headers)
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          return PrayerTimesData.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>,
            lat: lat,
            lng: lng,
          );
        }
        throw _fromStatus(resp.statusCode, 'Namaz vakitleri alınamadı.');
      });

  Future<List<Esma>> fetchEsmaulHusna() => _withRetry('fetchEsmaulHusna', () async {
        final resp = await _client
            .get(Uri.parse(ApiConfig.esmaulHusnaEndpoint()), headers: _headers)
            .timeout(kApiTimeout);
        if (resp.statusCode == 200) {
          return (jsonDecode(resp.body) as List<dynamic>)
              .map((e) => Esma.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw _fromStatus(resp.statusCode, 'Esmaül Hüsna listesi alınamadı.');
      });

  // ── Hatim Halkası — POST / GET / PATCH direkt (retry yok, idempotent değil) ─

  Future<HatimRoom> createHatimRoom() async {
    try {
      final resp = await _client
          .post(
            Uri.parse(ApiConfig.hatimHalkasiCreateEndpoint()),
            headers: {..._headers, 'Content-Type': 'application/json'},
          )
          .timeout(kApiTimeout);
      if (resp.statusCode == 201) {
        return HatimRoom.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      }
      throw _fromStatus(resp.statusCode, 'Oda oluşturulamadı.');
    } on SocketException {
      throw const ApiException('İnternet bağlantısı bulunamadı.');
    } on TlsException {
      throw const ApiException('Güvenli bağlantı kurulamadı.');
    } on TimeoutException {
      throw const ApiException('Sunucu yanıt vermedi. Lütfen tekrar deneyin.');
    } on FormatException {
      throw const ApiException('Sunucu yanıtı okunamadı.');
    }
  }

  Future<HatimRoom> getHatimRoom(String code) async {
    try {
      final resp = await _client
          .get(
            Uri.parse(ApiConfig.hatimHalkasiRoomEndpoint(code)),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return HatimRoom.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      }
      if (resp.statusCode == 404) {
        throw const ApiException('Oda bulunamadı.', statusCode: 404);
      }
      throw _fromStatus(resp.statusCode, 'Oda bilgisi alınamadı.');
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('İnternet bağlantısı bulunamadı.');
    } on TlsException {
      throw const ApiException('Güvenli bağlantı kurulamadı.');
    } on TimeoutException {
      throw const ApiException('Bağlantı zaman aşımına uğradı.');
    } on FormatException {
      throw const ApiException('Sunucu yanıtı okunamadı.');
    }
  }

  Future<void> updateHatimJuz(String code, int juzNum, String durum) async {
    try {
      final resp = await _client
          .patch(
            Uri.parse(ApiConfig.hatimHalkasiJuzEndpoint(code, juzNum)),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'durum': durum}),
          )
          .timeout(kApiTimeout);
      if (resp.statusCode == 200) return;
      if (resp.statusCode == 404) {
        throw const ApiException('Cüz bulunamadı.', statusCode: 404);
      }
      throw _fromStatus(resp.statusCode, 'Cüz güncellenemedi.');
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('İnternet bağlantısı bulunamadı.');
    } on TlsException {
      throw const ApiException('Güvenli bağlantı kurulamadı.');
    } on TimeoutException {
      throw const ApiException('Bağlantı zaman aşımına uğradı.');
    } on FormatException {
      throw const ApiException('Sunucu yanıtı okunamadı.');
    }
  }

  void dispose() => _client.close();
}
