import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nazar_app/models/ayet.dart';
import 'package:nazar_app/services/api_service.dart';

http.Client _mockClient(int status, Map<String, dynamic> body) => MockClient((_) async =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'}));

const _validJson = {
  'id': 1,
  'sure_isim': 'Al-Fatiha',
  'arapca': 'بسم',
  'meal': 'Bismillah',
  'mp3_url': '/audio/001.mp3',
};

void main() {
  group('ApiService.fetchAyet', () {
    test('başarılı yanıt Ayet döndürür', () async {
      final service = ApiService(client: _mockClient(200, _validJson));
      final ayet = await service.fetchAyet(1);
      expect(ayet, isA<Ayet>());
      expect(ayet.id, 1);
      expect(ayet.sureIsim, 'Al-Fatiha');
    });

    test('429 hata ApiException(statusCode:429) fırlatır', () async {
      final service = ApiService(
        client: _mockClient(429, {'detail': 'rate limit'}),
      );
      expect(
        () => service.fetchAyet(1),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });

    test('500 hata ApiException fırlatır', () async {
      final service = ApiService(
        client: _mockClient(500, {'detail': 'server error'}),
      );
      expect(() => service.fetchAyet(1), throwsA(isA<ApiException>()));
    });
  });
}
