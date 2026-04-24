import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/utils/hash_util.dart';

void main() {
  group('HashUtil.fromBytes', () {
    test('aynı girdi her zaman aynı sonucu verir (determinizm)', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final h1 = HashUtil.fromBytes(bytes);
      final h2 = HashUtil.fromBytes(bytes);
      expect(h1, h2);
    });

    test('farklı girdi farklı sonuç üretir', () {
      final bytes1 = Uint8List.fromList([1, 2, 3]);
      final bytes2 = Uint8List.fromList([4, 5, 6]);
      expect(HashUtil.fromBytes(bytes1), isNot(HashUtil.fromBytes(bytes2)));
    });

    test('sonuç her zaman negatif olmayan bir tamsayıdır', () {
      for (int i = 0; i < 20; i++) {
        final bytes = Uint8List.fromList(List.generate(32, (j) => (i * j) % 256));
        final hash = HashUtil.fromBytes(bytes);
        expect(hash, greaterThanOrEqualTo(0));
      }
    });

    test('boş veriyi işler', () {
      final hash = HashUtil.fromBytes(Uint8List(0));
      expect(hash, isA<int>());
      expect(hash, greaterThanOrEqualTo(0));
    });
  });
}
