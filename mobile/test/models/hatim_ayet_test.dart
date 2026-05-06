import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/models/hatim_ayet.dart';

const _base = {
  'id': 1,
  'sure_isim': 'Al-Fatiha',
  'arapca': 'بِسْمِ اللَّهِ',
  'meal': 'Allah adıyla',
  'mp3_url': '/audio/001001.mp3',
};

void main() {
  group('HatimAyet.fromJson', () {
    test('tüm alanları doğru parse eder', () {
      final ha = HatimAyet.fromJson({..._base, 'index': 42, 'total': 6236});
      expect(ha.ayet.id, 1);
      expect(ha.ayet.sureIsim, 'Al-Fatiha');
      expect(ha.index, 42);
      expect(ha.total, 6236);
    });

    test('index eksikse 0 döner', () {
      final ha = HatimAyet.fromJson(_base);
      expect(ha.index, 0);
    });

    test('total eksikse varsayılan 6236 döner', () {
      final ha = HatimAyet.fromJson(_base);
      expect(ha.total, 6236);
    });

    test('total sıfır verilirse sıfır döner', () {
      final ha = HatimAyet.fromJson({..._base, 'total': 0});
      expect(ha.total, 0);
    });

    test('Ayet verisi doğru aktarılır', () {
      final ha = HatimAyet.fromJson({..._base, 'index': 7, 'total': 100});
      expect(ha.ayet.mp3Url, '/audio/001001.mp3');
    });
  });
}
