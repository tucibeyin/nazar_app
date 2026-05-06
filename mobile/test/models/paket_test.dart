import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/models/paket.dart';

const _json = {
  'id': 'fatiha',
  'isim': 'Fatiha Suresi',
  'aciklama': 'Kur\'an\'ın açılış suresi',
  'icon': 'book',
  'ayet_sayisi': 7,
};

void main() {
  group('Paket.fromJson', () {
    test('tam veriyi doğru parse eder', () {
      final p = Paket.fromJson(_json);
      expect(p.id, 'fatiha');
      expect(p.isim, 'Fatiha Suresi');
      expect(p.aciklama, 'Kur\'an\'ın açılış suresi');
      expect(p.icon, 'book');
      expect(p.ayetSayisi, 7);
    });

    test('eksik alanlar için varsayılan değerler döner', () {
      final p = Paket.fromJson({});
      expect(p.id, '');
      expect(p.isim, '');
      expect(p.ayetSayisi, 0);
    });
  });

  group('Paket ==', () {
    test('aynı id eşit kabul edilir', () {
      const p1 = Paket(id: 'x', isim: 'A', aciklama: '', icon: 'book', ayetSayisi: 1);
      const p2 = Paket(id: 'x', isim: 'B', aciklama: 'farklı', icon: 'star', ayetSayisi: 99);
      expect(p1, equals(p2));
    });

    test('farklı id eşit değildir', () {
      const p1 = Paket(id: 'a', isim: 'A', aciklama: '', icon: 'book', ayetSayisi: 1);
      const p2 = Paket(id: 'b', isim: 'A', aciklama: '', icon: 'book', ayetSayisi: 1);
      expect(p1, isNot(equals(p2)));
    });

    test('hashCode aynı id için eşittir', () {
      const p1 = Paket(id: 'y', isim: 'X', aciklama: '', icon: 'star', ayetSayisi: 3);
      const p2 = Paket(id: 'y', isim: 'Z', aciklama: '', icon: 'book', ayetSayisi: 0);
      expect(p1.hashCode, p2.hashCode);
    });
  });

  group('Paket.toJson', () {
    test('round-trip tutarlı', () {
      final original = Paket.fromJson(_json);
      final roundTrip = Paket.fromJson(original.toJson());
      expect(roundTrip.id, original.id);
      expect(roundTrip.isim, original.isim);
      expect(roundTrip.ayetSayisi, original.ayetSayisi);
    });
  });

  group('PaketDetay.fromJson', () {
    test('ayet listesini parse eder', () {
      final detail = PaketDetay.fromJson({
        'id': 'fatiha',
        'isim': 'Fatiha',
        'aciklama': '',
        'icon': 'book',
        'ayetler': [
          {
            'id': 1,
            'sure_isim': 'Al-Fatiha',
            'arapca': 'بسم',
            'meal': 'Bismillah',
            'mp3_url': '/a.mp3',
          }
        ],
      });
      expect(detail.id, 'fatiha');
      expect(detail.ayetler.length, 1);
      expect(detail.ayetler.first.id, 1);
    });

    test('null ayetler listesi boş liste döndürür', () {
      final detail = PaketDetay.fromJson({
        'id': 'x', 'isim': '', 'aciklama': '', 'icon': '', 'ayetler': null,
      });
      expect(detail.ayetler, isEmpty);
    });

    test('ayetler alanı yoksa boş liste döndürür', () {
      final detail = PaketDetay.fromJson(
          {'id': 'x', 'isim': '', 'aciklama': '', 'icon': ''});
      expect(detail.ayetler, isEmpty);
    });
  });
}
