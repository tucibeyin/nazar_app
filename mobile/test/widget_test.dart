import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazar_app/main.dart';

void main() {
  testWidgets('NazarApp kamera listesi boşken başlatılabilir', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NazarApp(cameras: []),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
