import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nazar_app/models/paket.dart';
import 'package:nazar_app/providers/cevsen_provider.dart';

const _p1 = Paket(
    id: 'fatiha', isim: 'Fatiha', aciklama: '', icon: 'book', ayetSayisi: 7);
const _p2 = Paket(
    id: 'kursi', isim: 'Ayetel Kürsi', aciklama: '', icon: 'throne', ayetSayisi: 1);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CevsenNotifier', () {
    test('başlangıçta boş', () async {
      final n = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(n.state, isEmpty);
    });

    test('add paket ekler', () async {
      final n = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.add(_p1);
      expect(n.state, contains(_p1));
    });

    test('aynı paketi iki kez eklemez', () async {
      final n = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.add(_p1);
      await n.add(_p1);
      expect(n.state.length, 1);
    });

    test('remove paketi çıkarır', () async {
      final n = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.add(_p1);
      await n.remove(_p1.id);
      expect(n.state, isEmpty);
    });

    test('contains doğru sonuç döndürür', () async {
      final n = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.add(_p1);
      expect(n.contains(_p1.id), isTrue);
      expect(n.contains(_p2.id), isFalse);
    });

    test('reorder sıralamayı günceller', () async {
      final n = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.add(_p1);
      await n.add(_p2);
      await n.reorder([_p2, _p1]);
      expect(n.state.first.id, _p2.id);
    });

    test('clear listeyi boşaltır', () async {
      final n = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.add(_p1);
      await n.clear();
      expect(n.state, isEmpty);
    });

    test('SharedPreferences\'e yazar ve yeni notifier okur', () async {
      final n1 = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      await n1.add(_p1);

      final n2 = CevsenNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(n2.state.map((p) => p.id), contains(_p1.id));
    });
  });
}
