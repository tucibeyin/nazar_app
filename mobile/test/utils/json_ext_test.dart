import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/utils/json_ext.dart';

void main() {
  group('JsonExt.intOf', () {
    test('geçerli int döndürür', () {
      expect({'x': 5}.intOf('x'), 5);
    });

    test('double değeri int\'e dönüştürür', () {
      expect({'x': 3.7}.intOf('x'), 3);
    });

    test('eksik key için 0 döndürür', () {
      expect(<String, dynamic>{}.intOf('x'), 0);
    });

    test('özel default değerini döndürür', () {
      expect(<String, dynamic>{}.intOf('x', 42), 42);
    });

    test('String tip için default döndürür', () {
      expect({'x': 'abc'}.intOf('x'), 0);
    });

    test('null değer için default döndürür', () {
      expect({'x': null}.intOf('x'), 0);
    });

    test('negatif sayıyı doğru taşır', () {
      expect({'x': -3}.intOf('x'), -3);
    });
  });

  group('JsonExt.strOf', () {
    test('geçerli string döndürür', () {
      expect({'x': 'merhaba'}.strOf('x'), 'merhaba');
    });

    test('boş string döndürür', () {
      expect({'x': ''}.strOf('x'), '');
    });

    test('eksik key için boş string döndürür', () {
      expect(<String, dynamic>{}.strOf('x'), '');
    });

    test('özel default değerini döndürür', () {
      expect(<String, dynamic>{}.strOf('x', 'fallback'), 'fallback');
    });

    test('int tip için default döndürür', () {
      expect({'x': 42}.strOf('x'), '');
    });

    test('null değer için default döndürür', () {
      expect({'x': null}.strOf('x'), '');
    });
  });
}
