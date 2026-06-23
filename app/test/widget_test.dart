import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raai/main.dart';

void main() {
  testWidgets('app boots to the splash loader', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RaaiApp()));
    // Session starts "unknown" → the splash shows a progress indicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
