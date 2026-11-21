// Widget tests for the Login and Sign-up screens (SCRUM-7, 8, 9).
// They use a FakeAuthApi, so the backend does NOT need to be running.
// Run with:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/auth_validators.dart';
import 'package:frontend/login_screen.dart';
import 'package:frontend/signup_screen.dart';
import 'package:frontend/temp_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pretends to be the backend. Only "12345" / "secret123" logs in.
class FakeAuthApi extends AuthApi {
  int loginCalls = 0;
  int signupCalls = 0;
  final _ok = AuthResult(
    token: 'fake-token',
    user: {'userid': 1, 'erp': '12345', 'name': 'Ali Khan'},
  );

  @override
  Future<AuthResult> login({required String identifier, required String password}) async {
    loginCalls++;
    if (identifier == '12345' && password == 'secret123') return _ok;
    throw AuthException(AuthMessages.wrongCredentials);
  }

  @override
  Future<AuthResult> signup({
    required String name,
    required String erp,
    required String email,
    required String password,
  }) async {
    signupCalls++;
    if (erp == '11111') throw AuthException('An account with this ERP already exists');
    return _ok;
  }
}

Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400); // tall enough for the whole form
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Login screen', () {
    testWidgets('empty fields show an error and do not call the API', (tester) async {
      final api = FakeAuthApi();
      await pumpScreen(tester, LoginScreen(api: api));

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();

      expect(find.text(AuthMessages.fillAllFields), findsOneWidget);
      expect(api.loginCalls, 0);
    });

    testWidgets('TC_AUTH_NEG_01: wrong password shows error and clears both fields',
        (tester) async {
      await pumpScreen(tester, LoginScreen(api: FakeAuthApi()));

      await tester.enterText(find.byKey(const Key('login_identifier')), '12345');
      await tester.enterText(find.byKey(const Key('login_password')), 'wrongpass');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      expect(find.text(AuthMessages.wrongCredentials), findsOneWidget);
      expect(textOf(tester, 'login_identifier'), isEmpty);
      expect(textOf(tester, 'login_password'), isEmpty);
      expect(find.byType(TempHomeScreen), findsNothing);
    });

    testWidgets('TC_AUTH_POS_03: correct ERP + password saves token and goes home',
        (tester) async {
      await pumpScreen(tester, LoginScreen(api: FakeAuthApi()));

      await tester.enterText(find.byKey(const Key('login_identifier')), '12345');
      await tester.enterText(find.byKey(const Key('login_password')), 'secret123');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      expect(find.byType(TempHomeScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), 'fake-token');
    });
  });

  group('Sign-up screen', () {
    Future<void> fillForm(
      WidgetTester tester, {
      String name = 'Ali Khan',
      String erp = '12345',
      String email = 'ali@khi.iba.edu.pk',
      String password = 'secret123',
      String? confirm,
    }) async {
      await tester.enterText(find.byKey(const Key('signup_fullName')), name);
      await tester.enterText(find.byKey(const Key('signup_erp')), erp);
      await tester.enterText(find.byKey(const Key('signup_email')), email);
      await tester.enterText(find.byKey(const Key('signup_password')), password);
      await tester.enterText(
          find.byKey(const Key('signup_confirmPassword')), confirm ?? password);
      await tester.tap(find.byKey(const Key('signup_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('TC_AUTH_NEG_02: non-IBA email shows error and clears email',
        (tester) async {
      final api = FakeAuthApi();
      await pumpScreen(tester, SignupScreen(api: api));
      await fillForm(tester, email: 'student@gmail.com');

      expect(find.text(AuthMessages.badEmail), findsOneWidget);
      expect(textOf(tester, 'signup_email'), isEmpty);
      expect(api.signupCalls, 0);
    });

    testWidgets('TC_AUTH_NEG_03: 4-digit ERP is rejected', (tester) async {
      final api = FakeAuthApi();
      await pumpScreen(tester, SignupScreen(api: api));
      await fillForm(tester, erp: '1234');

      expect(find.text(AuthMessages.badErp), findsOneWidget);
      expect(api.signupCalls, 0);
    });

    testWidgets('SCRUM-7: short password is rejected', (tester) async {
      final api = FakeAuthApi();
      await pumpScreen(tester, SignupScreen(api: api));
      await fillForm(tester, password: 'short');

      expect(find.text(AuthMessages.shortPassword), findsOneWidget);
      expect(api.signupCalls, 0);
    });

    testWidgets("SCRUM-7: mismatched passwords show error and clear both",
        (tester) async {
      final api = FakeAuthApi();
      await pumpScreen(tester, SignupScreen(api: api));
      await fillForm(tester, password: 'secret123', confirm: 'secret124');

      expect(find.text(AuthMessages.passwordsDontMatch), findsOneWidget);
      expect(textOf(tester, 'signup_password'), isEmpty);
      expect(textOf(tester, 'signup_confirmPassword'), isEmpty);
      expect(api.signupCalls, 0);
    });

    testWidgets('server error (duplicate ERP) is shown to the user', (tester) async {
      await pumpScreen(tester, SignupScreen(api: FakeAuthApi()));
      await fillForm(tester, erp: '11111');

      expect(find.text('An account with this ERP already exists'), findsOneWidget);
    });

    testWidgets('valid details create the account and go home', (tester) async {
      await pumpScreen(tester, SignupScreen(api: FakeAuthApi()));
      await fillForm(tester);

      expect(find.byType(TempHomeScreen), findsOneWidget);
    });
  });
}
