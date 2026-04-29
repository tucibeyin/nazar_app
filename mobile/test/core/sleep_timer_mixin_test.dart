import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/core/sleep_timer_mixin.dart';

class _TestWidget extends StatefulWidget {
  const _TestWidget();
  @override
  _TestWidgetState createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget>
    with SleepTimerMixin<_TestWidget> {
  @override
  void dispose() {
    disposeSleepTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('SleepTimerMixin', () {
    testWidgets('başlangıçta sleepEnd null', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestWidget()));
      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
      expect(state.sleepEnd, isNull);
    });

    testWidgets('setSleepTimer sleepEnd\'i ayarlar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestWidget()));
      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));

      state.setSleepTimer(5, () {});
      expect(state.sleepEnd, isNotNull);
      expect(
        state.sleepEnd!.difference(DateTime.now()).inMinutes,
        greaterThanOrEqualTo(4),
      );
    });

    testWidgets('setSleepTimer(0) zamanlayıcıyı iptal eder', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestWidget()));
      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));

      state.setSleepTimer(5, () {});
      expect(state.sleepEnd, isNotNull);

      state.setSleepTimer(0, () {});
      expect(state.sleepEnd, isNull);
    });

    testWidgets('cancelSleepTimer sleepEnd\'i sıfırlar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestWidget()));
      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));

      state.setSleepTimer(3, () {});
      state.cancelSleepTimer();
      expect(state.sleepEnd, isNull);
    });

    testWidgets('süre dolunca onExpired çağrılır ve sleepEnd sıfırlanır',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestWidget()));
      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));

      var fired = false;
      state.setSleepTimer(1, () => fired = true);
      expect(state.sleepEnd, isNotNull);

      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(fired, isTrue);
      expect(state.sleepEnd, isNull);
    });
  });
}
