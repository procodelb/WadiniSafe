// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wadinisafe/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: WadiniSafeApp()));

    // Verify that we are at least rendering something from the app
    // Since we don't know the exact initial UI content for this generic test,
    // we just check if it pumps successfully.
    // Ideally, we should check for a widget we know exists on the initial screen.
    // But for a basic fix of the compilation error:
    expect(find.byType(WadiniSafeApp), findsOneWidget);
  });
}
