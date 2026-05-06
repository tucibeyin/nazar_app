import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/config/api_config.dart';

// Testlerde baseUrl çevre değişkeni enjekte edilmediği için
// varsayılan 'https://nazar.aracabak.com' kullanılır.
const _base = 'https://nazar.aracabak.com';

void main() {
  group('ApiConfig parametreli endpoint\'ler', () {
    test('nazarEndpoint hash içerir', () {
      expect(ApiConfig.nazarEndpoint(42), '$_base/api/v1/nazar/42');
    });

    test('nazarEndpoint sıfır hash için çalışır', () {
      expect(ApiConfig.nazarEndpoint(0), '$_base/api/v1/nazar/0');
    });

    test('hatimEndpoint index içerir', () {
      expect(ApiConfig.hatimEndpoint(100), '$_base/api/v1/hatim/100');
    });

    test('packageDetailEndpoint id içerir', () {
      expect(ApiConfig.packageDetailEndpoint('insira'),
          '$_base/api/v1/packages/insira');
    });

    test('prayerTimesEndpoint lat ve lng içerir', () {
      final url = ApiConfig.prayerTimesEndpoint(41.0, 29.0);
      expect(url, contains('lat=41.0'));
      expect(url, contains('lng=29.0'));
      expect(url, startsWith(_base));
    });

    test('hatimHalkasiRoomEndpoint oda kodu içerir', () {
      expect(ApiConfig.hatimHalkasiRoomEndpoint('ABC123'),
          '$_base/api/v1/hatim-halkasi/ABC123');
    });

    test('hatimHalkasiJuzEndpoint kod ve cüz numarası içerir', () {
      expect(ApiConfig.hatimHalkasiJuzEndpoint('XYZ', 15),
          '$_base/api/v1/hatim-halkasi/XYZ/juz/15');
    });

    test('audioUrl path\'i baseUrl\'e ekler', () {
      expect(
        ApiConfig.audioUrl('/media/audio/001001.mp3'),
        '$_base/media/audio/001001.mp3',
      );
    });
  });

  group('ApiConfig getter endpoint\'ler', () {
    test('packagesEndpoint doğru URL döner', () {
      expect(ApiConfig.packagesEndpoint, '$_base/api/v1/packages');
    });

    test('esmaulHusnaEndpoint doğru URL döner', () {
      expect(ApiConfig.esmaulHusnaEndpoint, '$_base/api/v1/esmaul-husna');
    });

    test('hatimHalkasiCreateEndpoint doğru URL döner', () {
      expect(ApiConfig.hatimHalkasiCreateEndpoint,
          '$_base/api/v1/hatim-halkasi/create');
    });
  });
}
