import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/main.dart';

void main() {
  testWidgets('NazarApp başlatılabilir', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NazarApp()),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    // Drain splash timers
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
  });
}
