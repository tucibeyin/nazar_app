import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nazar_app/models/ayet.dart';
import 'package:nazar_app/repositories/ayet_repository.dart';
import 'package:nazar_app/services/api_service.dart';

const _validJson = {
  'id': 7,
  'sure_isim': 'Al-Fatiha 7',
  'arapca': 'صِرَاطَ الَّذِينَ',
  'meal': 'Nimet verdiklerin yolu',
  'mp3_url': '/audio/001007.mp3',
};

http.Client _mockClient(Map<String, dynamic> body) =>
    MockClient((_) async => http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        ));

void main() {
  group('AyetRepository', () {
    test('cache olmayan hash API çağrısı yapar', () async {
      final repo = AyetRepository(ApiService(client: _mockClient(_validJson)));
      final ayet = await repo.fetchAyet(42);
      expect(ayet.id, 7);
      expect(repo.cacheSize, 1);
    });

    test('aynı hash ikinci çağrıda cache\'den döner', () async {
      int callCount = 0;
      final client = MockClient((_) async {
        callCount++;
        return http.Response(
          jsonEncode(_validJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = AyetRepository(ApiService(client: client));

      await repo.fetchAyet(42);
      await repo.fetchAyet(42);

      expect(callCount, 1, reason: 'İkinci çağrı cache\'den gelmeli');
    });

    test('farklı hash\'ler ayrı cache girdileri oluşturur', () async {
      final repo = AyetRepository(ApiService(client: _mockClient(_validJson)));
      await repo.fetchAyet(1);
      await repo.fetchAyet(2);
      expect(repo.cacheSize, 2);
    });

    test('clearCache cache\'i temizler', () async {
      final repo = AyetRepository(ApiService(client: _mockClient(_validJson)));
      await repo.fetchAyet(1);
      repo.clearCache();
      expect(repo.cacheSize, 0);
    });

    test('ApiException repository\'den geçer', () async {
      final client = MockClient((_) async =>
          http.Response('{"detail":"rate limit"}', 429));
      final repo = AyetRepository(ApiService(client: client));
      expect(() => repo.fetchAyet(1), throwsA(isA<ApiException>()));
    });

    test('farklı Ayet nesneleri == ile karşılaştırılabilir', () {
      const a = Ayet(id: 1, sureIsim: 'X', arapca: 'Y', meal: 'Z', mp3Url: '/a.mp3');
      const b = Ayet(id: 1, sureIsim: 'Different', arapca: 'D', meal: 'D', mp3Url: '/b.mp3');
      expect(a, equals(b), reason: 'Aynı id = aynı ayet');
    });

    test('copyWith orijinali değiştirmez', () {
      const original = Ayet(id: 1, sureIsim: 'X', arapca: 'Y', meal: 'Z', mp3Url: '/a.mp3');
      final copy = original.copyWith(sureIsim: 'Updated');
      expect(original.sureIsim, 'X');
      expect(copy.sureIsim, 'Updated');
    });
  });
}
