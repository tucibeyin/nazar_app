import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/models/hatim_room.dart';

void main() {
  group('JuzDurum', () {
    test('values.byName geçerli isimleri parse eder', () {
      expect(JuzDurum.values.byName('bos'), JuzDurum.bos);
      expect(JuzDurum.values.byName('alindi'), JuzDurum.alindi);
      expect(JuzDurum.values.byName('okundu'), JuzDurum.okundu);
    });

    test('name getter enum değerini string yapar', () {
      expect(JuzDurum.bos.name, 'bos');
      expect(JuzDurum.alindi.name, 'alindi');
      expect(JuzDurum.okundu.name, 'okundu');
    });

    test('geçersiz isimde ArgumentError fırlatır', () {
      expect(() => JuzDurum.values.byName('gecersiz'), throwsArgumentError);
    });
  });

  group('JuzItem.fromJson', () {
    test('tam veriyi doğru parse eder', () {
      final item = JuzItem.fromJson({'juz_num': 5, 'durum': 'alindi'});
      expect(item.juzNum, 5);
      expect(item.durum, JuzDurum.alindi);
    });

    test('juz_num double olarak gelirse int\'e çevirir', () {
      final item = JuzItem.fromJson({'juz_num': 15.0, 'durum': 'bos'});
      expect(item.juzNum, 15);
    });

    test('okundu durumunu doğru parse eder', () {
      final item = JuzItem.fromJson({'juz_num': 30, 'durum': 'okundu'});
      expect(item.durum, JuzDurum.okundu);
    });
  });

  group('JuzItem.copyWith', () {
    test('durum değiştirir, juzNum sabit kalır', () {
      const item = JuzItem(juzNum: 7, durum: JuzDurum.bos);
      final updated = item.copyWith(durum: JuzDurum.alindi);
      expect(updated.juzNum, 7);
      expect(updated.durum, JuzDurum.alindi);
    });

    test('null geçilirse mevcut değeri korur', () {
      const item = JuzItem(juzNum: 3, durum: JuzDurum.okundu);
      final same = item.copyWith();
      expect(same.juzNum, 3);
      expect(same.durum, JuzDurum.okundu);
    });
  });

  group('HatimRoom.fromJson', () {
    test('tam veriyi doğru parse eder', () {
      final json = {
        'code': 'XYZ789',
        'created_at': '2026-05-01T12:00:00',
        'juzler': [
          {'juz_num': 1, 'durum': 'okundu'},
          {'juz_num': 2, 'durum': 'alindi'},
          {'juz_num': 3, 'durum': 'bos'},
        ],
      };
      final room = HatimRoom.fromJson(json);
      expect(room.code, 'XYZ789');
      expect(room.createdAt, '2026-05-01T12:00:00');
      expect(room.juzler.length, 3);
      expect(room.juzler[0].durum, JuzDurum.okundu);
      expect(room.juzler[1].durum, JuzDurum.alindi);
      expect(room.juzler[2].durum, JuzDurum.bos);
    });

    test('boş juzler listesini işler', () {
      final room = HatimRoom.fromJson({
        'code': 'A',
        'created_at': '',
        'juzler': <dynamic>[],
      });
      expect(room.juzler, isEmpty);
    });
  });
}
