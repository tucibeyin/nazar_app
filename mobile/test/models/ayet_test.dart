import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/models/ayet.dart';

void main() {
  group('Ayet.fromJson', () {
    test('tam veriyi doğru parse eder', () {
      final json = {
        'id': 1,
        'sure_isim': 'Al-Fatiha',
        'arapca': 'بِسْمِ اللَّهِ',
        'meal': 'Allah adıyla',
        'mp3_url': '/audio/001001.mp3',
      };
      final ayet = Ayet.fromJson(json);
      expect(ayet.id, 1);
      expect(ayet.sureIsim, 'Al-Fatiha');
      expect(ayet.arapca, 'بِسْمِ اللَّهِ');
      expect(ayet.meal, 'Allah adıyla');
      expect(ayet.mp3Url, '/audio/001001.mp3');
    });

    test('null değerleri varsayılanlarla doldurur', () {
      final ayet = Ayet.fromJson({});
      expect(ayet.id, 0);
      expect(ayet.sureIsim, '');
      expect(ayet.arapca, '');
      expect(ayet.meal, '');
      expect(ayet.mp3Url, '');
    });

    test('id olarak double kabul eder (backend dönüşümü)', () {
      final ayet = Ayet.fromJson({'id': 42.0});
      expect(ayet.id, 42);
    });

    test('null id\'yi 0 olarak döndürür', () {
      final ayet = Ayet.fromJson({'id': null});
      expect(ayet.id, 0);
    });

    test('beklenmedik tip olduğunda çökmez', () {
      final ayet = Ayet.fromJson({'id': 'invalid', 'sure_isim': 123});
      expect(ayet.id, 0);
      expect(ayet.sureIsim, '');
    });
  });
}
