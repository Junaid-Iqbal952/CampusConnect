// Widget tests for SCRUM-13: change password with ERP + current password.
// They use a fake http client, so the backend does NOT need to be running.
// Run with:  flutter test
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/auth_validators.dart';
import 'package:frontend/change_OR_reset_pw.dart';
import 'package:frontend/welcome_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pretends to be the backend. Only ERP 12345 + "secret123" is accepted.
/// The token "kicked-out" behaves like a login on another device (401).
class FakeBackend {
  int calls = 0;
  http.Request? lastRequest;

  late final MockClient client = MockClient((request) async {
    calls++;
    lastRequest = request;
    if (request.headers['Authorization'] == 'Bearer kicked-out') {
      return http.Response(
          jsonEncode({'detail': 'You were logged in on another device'}), 401);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (body['erp'] == '12345' && body['current_password'] == 'secret123') {
      return http.Response(jsonEncode({'message': 'Password updated successfully'}), 200);
    }
    return http.Response(jsonEncode({'detail': 'Wrong ERP or current password'}), 400);
  });
}

Finder field(String hint) => find.widgetWithText(TextField, hint);

String textOf(WidgetTester tester, String hint) =>
    tester.widget<TextField>(field(hint)).controller!.text;

/// Opens the change-password screen from a dummy page, so Navigator.pop works.
Future<void> openScreen(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ResetPasswordScreen(isChangePassword: true, client: backend.client),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> fillAndSave(
  WidgetTester tester, {
  String erp = '12345',
  String current = 'secret123',
  String newPass = 'newpass456',
  String? confirm,
}) async {
  await tester.enterText(field('ERP'), erp);
  await tester.enterText(field('Current password'), current);
  await tester.enterText(field('New password'), newPass);
  await tester.enterText(field('Confirm password'), confirm ?? newPass);
  await tester.tap(find.text('SAVE PASSWORD'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'auth_token': 'good-token'}));

  testWidgets('shows ERP and current password fields', (tester) async {
    await openScreen(tester, FakeBackend());
    expect(find.text('Change password'), findsOneWidget);
    expect(field('ERP'), findsOneWidget);
    expect(field('Current password'), findsOneWidget);
    expect(field('Email address'), findsNothing); // reset-only fields hidden
  });

  testWidgets('TC_AUTH_POS_05: success sends token + ERP, shows message, closes screen',
      (tester) async {
    final backend = FakeBackend();
    await openScreen(tester, backend);
    await fillAndSave(tester);

    expect(backend.calls, 1);
    expect(backend.lastRequest!.url.path, '/auth/change-password');
    expect(backend.lastRequest!.headers['Authorization'], 'Bearer good-token');
    final sent = jsonDecode(backend.lastRequest!.body);
    expect(sent['erp'], '12345');
    expect(sent['new_password'], 'newpass456');

    expect(find.text('Password updated successfully'), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
  });

  testWidgets('TC_AUTH_NEG_04: new password same as current is rejected', (tester) async {
    final backend = FakeBackend();
    await openScreen(tester, backend);
    await fillAndSave(tester, newPass: 'secret123');

    expect(find.text(AuthMessages.samePassword), findsOneWidget);
    expect(backend.calls, 0);
  });

  testWidgets('invalid ERP is rejected before calling the backend', (tester) async {
    final backend = FakeBackend();
    await openScreen(tester, backend);
    await fillAndSave(tester, erp: '123');

    expect(find.text(AuthMessages.badErp), findsOneWidget);
    expect(backend.calls, 0);
  });

  testWidgets('wrong current password shows error, clears that field, stays logged in',
      (tester) async {
    await openScreen(tester, FakeBackend());
    await fillAndSave(tester, current: 'wrongpass1');

    expect(find.text('Wrong ERP or current password'), findsOneWidget);
    expect(textOf(tester, 'Current password'), isEmpty);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'good-token');
  });

  testWidgets('logged in on another device -> back to Welcome with message',
      (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'kicked-out'});
    await openScreen(tester, FakeBackend());
    await fillAndSave(tester);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('You were logged in on another device'), findsOneWidget);
  });

  testWidgets('mismatched new passwords are rejected', (tester) async {
    final backend = FakeBackend();
    await openScreen(tester, backend);
    await fillAndSave(tester, confirm: 'different99');

    expect(find.text(AuthMessages.passwordsDontMatch), findsOneWidget);
    expect(backend.calls, 0);
  });
}
