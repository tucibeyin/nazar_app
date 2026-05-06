import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nazar_app/providers/kaza_provider.dart';

void main() {
  group('KazaEntry hesaplanan alanlar', () {
    test('progress: borç yoksa 0 döner', () {
      const e = KazaEntry(id: 'x', isim: 'X', borc: 0, kilinen: 5);
      expect(e.progress, 0.0);
    });

    test('progress: kilinen/borc oranı', () {
      const e = KazaEntry(id: 'x', isim: 'X', borc: 100, kilinen: 40);
      expect(e.progress, closeTo(0.4, 0.001));
    });

    test('progress: kilinen > borc ise 1.0\'a kısıtlanır', () {
      const e = KazaEntry(id: 'x', isim: 'X', borc: 10, kilinen: 15);
      expect(e.progress, 1.0);
    });

    test('kalan: borçtan kilinen çıkar', () {
      const e = KazaEntry(id: 'x', isim: 'X', borc: 50, kilinen: 20);
      expect(e.kalan, 30);
    });

    test('kalan: kilinen >= borc ise 0 döner', () {
      const e = KazaEntry(id: 'x', isim: 'X', borc: 10, kilinen: 10);
      expect(e.kalan, 0);
    });

    test('kalan: kilinen > borc ise 0 döner (aşım)', () {
      const e = KazaEntry(id: 'x', isim: 'X', borc: 5, kilinen: 8);
      expect(e.kalan, 0);
    });

    test('tamamlandi: borc > 0 ve kilinen >= borc', () {
      const done = KazaEntry(id: 'x', isim: 'X', borc: 5, kilinen: 5);
      const notYet = KazaEntry(id: 'x', isim: 'X', borc: 5, kilinen: 4);
      const noDebt = KazaEntry(id: 'x', isim: 'X', borc: 0, kilinen: 0);
      expect(done.tamamlandi, isTrue);
      expect(notYet.tamamlandi, isFalse);
      expect(noDebt.tamamlandi, isFalse);
    });

    test('copyWith sadece belirtilen alanı değiştirir', () {
      const e = KazaEntry(id: 'sabah', isim: 'Sabah', borc: 10, kilinen: 3);
      final updated = e.copyWith(kilinen: 7);
      expect(updated.borc, 10);
      expect(updated.kilinen, 7);
      expect(updated.id, 'sabah');
    });
  });

  group('KazaNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('başlangıçta 7 vakit vardır', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(n.state.length, 7);
    });

    test('başlangıçta tüm borçlar ve kilinen sıfır', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      for (final e in n.state) {
        expect(e.borc, 0, reason: '${e.id} borcu sıfır olmalı');
        expect(e.kilinen, 0, reason: '${e.id} kilineni sıfır olmalı');
      }
    });

    test('setBorc borcu ayarlar', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.setBorc('sabah', 30);
      final entry = n.state.firstWhere((e) => e.id == 'sabah');
      expect(entry.borc, 30);
    });

    test('setBorc 99999\'u aşan değeri kırpar', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.setBorc('sabah', 200000);
      final entry = n.state.firstWhere((e) => e.id == 'sabah');
      expect(entry.borc, 99999);
    });

    test('setBorc negatif değeri sıfıra kırpar', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.setBorc('sabah', -5);
      final entry = n.state.firstWhere((e) => e.id == 'sabah');
      expect(entry.borc, 0);
    });

    test('increment kilinen\'i bir artırır', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.increment('ogle');
      await n.increment('ogle');
      final entry = n.state.firstWhere((e) => e.id == 'ogle');
      expect(entry.kilinen, 2);
    });

    test('decrement kilinen\'i bir azaltır', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.increment('ikindi');
      await n.increment('ikindi');
      await n.decrement('ikindi');
      final entry = n.state.firstWhere((e) => e.id == 'ikindi');
      expect(entry.kilinen, 1);
    });

    test('decrement sıfırın altına inmez', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.decrement('aksam'); // kilinen zaten 0
      final entry = n.state.firstWhere((e) => e.id == 'aksam');
      expect(entry.kilinen, 0);
    });

    test('diğer vakitler etkilenmez', () async {
      final n = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.setBorc('sabah', 10);
      await n.increment('sabah');
      final ogle = n.state.firstWhere((e) => e.id == 'ogle');
      expect(ogle.borc, 0);
      expect(ogle.kilinen, 0);
    });

    test('SharedPreferences\'e yazar ve yeni notifier okur', () async {
      final n1 = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      await n1.setBorc('yatsi', 20);
      await n1.increment('yatsi');

      final n2 = KazaNotifier();
      await Future<void>.delayed(Duration.zero);
      final entry = n2.state.firstWhere((e) => e.id == 'yatsi');
      expect(entry.borc, 20);
      expect(entry.kilinen, 1);
    });
  });
}
