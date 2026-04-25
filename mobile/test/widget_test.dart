import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/main.dart';

void main() {
  testWidgets('NazarApp kamera listesi boşken başlatılabilir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: NazarApp(camerasFuture: Future.value([])),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    // Drain splash timers (220ms entrance + 1900ms min-time + exit delays)
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
  });
}
