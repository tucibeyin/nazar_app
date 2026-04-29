import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nazar_app/providers/service_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HatimProgressNotifier', () {
    test('başlangıçta sıfır', () async {
      final n = HatimProgressNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(n.state, 0);
    });

    test('advance bir artırır', () async {
      final n = HatimProgressNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.advance(6236);
      expect(n.state, 1);
    });

    test('advance total\'da modulo alır', () async {
      final n = HatimProgressNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.advance(3); // 0 → 1
      await n.advance(3); // 1 → 2
      await n.advance(3); // 2 → 0
      expect(n.state, 0);
    });

    test('reset sıfıra döner', () async {
      final n = HatimProgressNotifier();
      await Future<void>.delayed(Duration.zero);
      await n.advance(6236);
      await n.reset();
      expect(n.state, 0);
    });

    test('SharedPreferences\'e yazar ve yeni notifier okur', () async {
      final n1 = HatimProgressNotifier();
      await Future<void>.delayed(Duration.zero);
      await n1.advance(6236);

      final n2 = HatimProgressNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(n2.state, 1);
    });
  });
}
