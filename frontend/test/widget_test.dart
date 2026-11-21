// Smoke test for app start-up. (Replaces Flutter's default counter test,
// which always failed because this app has no counter.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('not logged in -> splash then welcome screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());

    await tester.pump(const Duration(seconds: 3)); // splash waits 2 seconds
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
