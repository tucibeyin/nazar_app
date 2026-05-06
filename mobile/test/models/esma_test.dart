import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/models/esma.dart';

void main() {
  group('Esma.fromJson', () {
    test('tam veriyi doğru parse eder', () {
      final esma = Esma.fromJson({
        'id': 1,
        'isim': 'Er-Rahman',
        'arapca': 'الرَّحْمَٰنُ',
        'anlam': 'Çok merhametli',
        'fazilet': 'Rahmet kapılarını açar',
        'ebced_degeri': 298,
      });
      expect(esma.id, 1);
      expect(esma.isim, 'Er-Rahman');
      expect(esma.arapca, 'الرَّحْمَٰنُ');
      expect(esma.anlam, 'Çok merhametli');
      expect(esma.fazilet, 'Rahmet kapılarını açar');
      expect(esma.ebcedDegeri, 298);
    });

    test('null string alanları boş string döndürür', () {
      final esma = Esma.fromJson({'id': 2});
      expect(esma.isim, '');
      expect(esma.arapca, '');
      expect(esma.anlam, '');
      expect(esma.fazilet, '');
      expect(esma.ebcedDegeri, 0);
    });

    test('id double olarak gelirse int\'e çevirir', () {
      final esma = Esma.fromJson({'id': 7.0});
      expect(esma.id, 7);
    });

    test('ebced_degeri double olarak gelirse int\'e çevirir', () {
      final esma = Esma.fromJson({'id': 1, 'ebced_degeri': 100.0});
      expect(esma.ebcedDegeri, 100);
    });

    test('null ebced_degeri için 0 döndürür', () {
      final esma = Esma.fromJson({'id': 1, 'ebced_degeri': null});
      expect(esma.ebcedDegeri, 0);
    });
  });
}
