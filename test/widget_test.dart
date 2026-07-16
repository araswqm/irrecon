import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrecon/app/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: IRreconApp(),
      ),
    );
    await tester.pump();

    // Verify the home screen title is present
    expect(find.text('IRrecon'), findsOneWidget);
    expect(find.text('Find Your Remote'), findsOneWidget);
    expect(find.text('Camera Search'), findsOneWidget);
    expect(find.text('Browse Database'), findsOneWidget);
  });
}
