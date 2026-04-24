import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/app_constants.dart';
import '../core/logger.dart';
import '../models/ayet.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Belirtilen hash için ayet getirir.
  /// Ağ hatasında [kMaxRetries] kez tekrar dener.
  Future<Ayet> fetchAyet(int hashInt) async {
    final uri = Uri.parse(ApiConfig.nazarEndpoint(hashInt));
    Exception? lastError;

    for (int attempt = 1; attempt <= kMaxRetries; attempt++) {
      try {
        AppLogger.info('fetchAyet attempt $attempt', uri.toString());
        final response = await _client.get(uri).timeout(kApiTimeout);

        if (response.statusCode == 200) {
          return Ayet.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        }

        if (response.statusCode == 429) {
          throw const ApiException('Çok fazla istek gönderildi. Lütfen bekleyin.', statusCode: 429);
        }

        throw ApiException('Sunucu hatası.', statusCode: response.statusCode);
      } on ApiException {
        rethrow;
      } on SocketException {
        lastError = const ApiException('İnternet bağlantısı bulunamadı.');
      } on HttpException {
        lastError = const ApiException('Sunucuya ulaşılamadı.');
      } on FormatException {
        lastError = const ApiException('Sunucu yanıtı okunamadı.');
      } catch (e, st) {
        AppLogger.error('fetchAyet unexpected error', e, st);
        lastError = ApiException('Beklenmedik hata: $e');
      }

      if (attempt < kMaxRetries) {
        AppLogger.warning('fetchAyet retry in ${kRetryBackoff.inSeconds}s');
        await Future<void>.delayed(kRetryBackoff * attempt);
      }
    }

    throw lastError ?? const ApiException('Bilinmeyen ağ hatası.');
  }

  void dispose() => _client.close();
}
