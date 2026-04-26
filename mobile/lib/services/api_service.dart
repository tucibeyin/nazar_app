import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/app_constants.dart';
import '../core/logger.dart';
import '../models/ayet.dart';
import '../models/hatim_ayet.dart';
import '../models/paket.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final http.Client _client;
  static final _rng = math.Random();

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Belirtilen hash için ayet getirir.
  /// Ağ hatasında [kMaxRetries] kez exponential + jitter backoff ile tekrar dener.
  Future<Ayet> fetchAyet(int hashInt) async {
    final uri = Uri.parse(ApiConfig.nazarEndpoint(hashInt));
    final headers = <String, String>{
      'Accept': 'application/json',
      if (ApiConfig.apiKey.isNotEmpty) 'X-API-Key': ApiConfig.apiKey,
    };
    Exception? lastError;

    for (int attempt = 1; attempt <= kMaxRetries; attempt++) {
      try {
        AppLogger.info('fetchAyet attempt $attempt');
        final response = await _client.get(uri, headers: headers).timeout(kApiTimeout);

        if (response.statusCode == 200) {
          return Ayet.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        }

        if (response.statusCode == 429) {
          throw const ApiException('Çok fazla istek gönderildi. Lütfen bekleyin.', statusCode: 429);
        }

        if (response.statusCode == 401) {
          throw const ApiException('Yetkilendirme hatası.', statusCode: 401);
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw ApiException('İstemci hatası.', statusCode: response.statusCode);
        }

        // 5xx — geçici sunucu hatası, retry edilebilir
        lastError = ApiException('Sunucu hatası.', statusCode: response.statusCode);
      } on ApiException {
        rethrow;
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
        AppLogger.error('fetchAyet unexpected error', e, st);
        lastError = ApiException('Beklenmedik hata: $e');
      }

      if (attempt < kMaxRetries) {
        final jitter = Duration(milliseconds: _rng.nextInt(500));
        final delay = kRetryBackoff * attempt + jitter;
        AppLogger.warning('fetchAyet retry in ${delay.inMilliseconds}ms (attempt $attempt)');
        await Future<void>.delayed(delay);
      }
    }

    throw lastError ?? const ApiException('Bilinmeyen ağ hatası.');
  }

  /// Verilen index'teki hatim ayetini getirir. Tek deneme, retry yok.
  Future<HatimAyet> fetchHatimAyet(int index) async {
    final uri = Uri.parse(ApiConfig.hatimEndpoint(index));
    final headers = <String, String>{
      'Accept': 'application/json',
      if (ApiConfig.apiKey.isNotEmpty) 'X-API-Key': ApiConfig.apiKey,
    };
    try {
      AppLogger.info('fetchHatimAyet index=$index');
      final response = await _client.get(uri, headers: headers).timeout(kApiTimeout);
      if (response.statusCode == 200) {
        return HatimAyet.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw ApiException('Hatim API hatası', statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('İnternet bağlantısı bulunamadı.');
    } on TimeoutException {
      throw const ApiException('Sunucu yanıt vermedi.');
    } catch (e, st) {
      AppLogger.error('fetchHatimAyet unexpected error', e, st);
      throw ApiException('Beklenmedik hata: $e');
    }
  }

  /// Tüm terapi paketlerini getirir.
  Future<List<Paket>> fetchPackages() async {
    final uri = Uri.parse(ApiConfig.packagesEndpoint());
    final headers = <String, String>{
      'Accept': 'application/json',
      if (ApiConfig.apiKey.isNotEmpty) 'X-API-Key': ApiConfig.apiKey,
    };
    try {
      AppLogger.info('fetchPackages');
      final response = await _client.get(uri, headers: headers).timeout(kApiTimeout);
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((e) => Paket.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException('Paket listesi alınamadı.', statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('İnternet bağlantısı bulunamadı.');
    } on TimeoutException {
      throw const ApiException('Sunucu yanıt vermedi.');
    } catch (e, st) {
      AppLogger.error('fetchPackages unexpected error', e, st);
      throw ApiException('Beklenmedik hata: $e');
    }
  }

  /// Bir paketin detaylı ayet listesini getirir.
  Future<PaketDetay> fetchPackageDetail(String id) async {
    final uri = Uri.parse(ApiConfig.packageDetailEndpoint(id));
    final headers = <String, String>{
      'Accept': 'application/json',
      if (ApiConfig.apiKey.isNotEmpty) 'X-API-Key': ApiConfig.apiKey,
    };
    try {
      AppLogger.info('fetchPackageDetail id=$id');
      final response = await _client.get(uri, headers: headers).timeout(kApiTimeout);
      if (response.statusCode == 200) {
        return PaketDetay.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw ApiException('Paket detayı alınamadı.', statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('İnternet bağlantısı bulunamadı.');
    } on TimeoutException {
      throw const ApiException('Sunucu yanıt vermedi.');
    } catch (e, st) {
      AppLogger.error('fetchPackageDetail unexpected error', e, st);
      throw ApiException('Beklenmedik hata: $e');
    }
  }

  void dispose() => _client.close();
}
