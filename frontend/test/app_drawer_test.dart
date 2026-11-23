// Widget tests for SCRUM-26: hamburger menu.
// Run with:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app_drawer.dart';
import 'package:frontend/change_OR_reset_pw.dart';
import 'package:frontend/coming_soon_screen.dart';
import 'package:frontend/listings_screen.dart';
import 'package:frontend/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const menuItems = [
  'My Profile',
  'My Dashboard',
  'Post a New Listing',
  'Change Password',
  'Logout',
];

final scaffoldKey = GlobalKey<ScaffoldState>();

/// A simple page with the menu attached, then opens the menu.
Future<void> openMenu(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      key: scaffoldKey,
      drawer: const AppDrawer(),
      appBar: AppBar(),
      body: const Text('page under the menu'),
    ),
  ));
  scaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'auth_token': 'some-token',
        'user_name': 'Aliza',
      }));

  testWidgets('shows header, logged-in user and all items in wireframe order',
      (tester) async {
    await openMenu(tester);

    expect(find.text('Campus Connect'), findsOneWidget);
    expect(find.byKey(const Key('drawer_close')), findsOneWidget);
    expect(find.text('Aliza'), findsOneWidget);
    expect(find.text('Campus member'), findsOneWidget);

    double lastY = -1;
    for (final label in menuItems) {
      expect(find.text(label), findsOneWidget, reason: label);
      final y = tester.getTopLeft(find.text(label)).dy;
      expect(y, greaterThan(lastY), reason: '$label is out of order');
      lastY = y;
    }
  });

  testWidgets('Close button closes the menu', (tester) async {
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('drawer_close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_drawer')), findsNothing);
    expect(find.text('page under the menu'), findsOneWidget);
  });

  testWidgets('Change Password opens the change password screen; Back returns',
      (tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget); // screen title

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new)); // the screen's back arrow
    await tester.pumpAndSettle();
    expect(find.text('page under the menu'), findsOneWidget);
    expect(find.byKey(const Key('app_drawer')), findsNothing); // menu closed
  });

  for (final label in ['My Profile', 'My Dashboard', 'Post a New Listing']) {
    testWidgets('$label opens its (coming soon) page', (tester) async {
      await openMenu(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.byType(ComingSoonScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, label), findsOneWidget);
    });
  }

  testWidgets('Logout clears the saved login and goes to Welcome', (tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('user_name'), isNull);
  });

  testWidgets('falls back to "Student" when no name is saved', (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'some-token'});
    await openMenu(tester);
    expect(find.text('Student'), findsOneWidget);
  });

  testWidgets('menu button on the Listings page opens the menu', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: ListingsScreen()));
    // Listings tries to load from the backend (not running in tests), so use
    // fixed pumps instead of pumpAndSettle in case its spinner keeps spinning.
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const Key('menu_button')));
    await tester.pump(const Duration(seconds: 1)); // drawer slide-in animation

    expect(find.byKey(const Key('app_drawer')), findsOneWidget);
    expect(find.text('My Dashboard'), findsOneWidget);
  });
}
