// Widget test for the "post a listing" form. No backend needed.
// Run with:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/create_listing_screen.dart';

void main() {
  testWidgets('empty form shows errors and is not sent', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400); // tall enough for the form
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CreateListingScreen()));

    await tester.ensureVisible(find.byKey(const Key('post_button')));
    await tester.tap(find.byKey(const Key('post_button')));
    await tester.pump();

    expect(find.text('Please enter a name'), findsOneWidget);
    expect(find.text('Please enter a description'), findsOneWidget);
    expect(find.text('Enter an hourly rate above 0'), findsOneWidget);
    expect(find.text('Please describe the condition'), findsOneWidget);
    expect(find.text('Enter a duration of at least 1 day'), findsOneWidget);
    expect(find.text('Please choose a campus'), findsOneWidget);
    expect(find.byKey(const Key('photo_error')), findsOneWidget);
  });
}