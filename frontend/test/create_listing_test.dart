// Widget test for the "post a listing" form. No backend needed.
// Run with:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

import 'package:frontend/create_listing_screen.dart';
import 'package:frontend/listing_api.dart';
import 'package:frontend/listing_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers what the form sent to updateListing, instead of calling the backend.
class FakeEditApi extends ListingApi {
  int? editedId;
  String? sentTitle;
  String? sentRate;
  Uint8List? sentPhoto;
  bool called = false;

  @override
  Future<void> updateListing({
    required String token,
    required int listingId,
    required String title,
    required String description,
    required String hourlyRate,
    required String condition,
    required String maxDuration,
    required bool negotiable,
    required String campus,
    Uint8List? photoBytes,
    String photoName = 'photo.jpg',
  }) async {
    called = true;
    editedId = listingId;
    sentTitle = title;
    sentRate = hourlyRate;
    sentPhoto = photoBytes;
  }
}

final existing = Listing(
  id: 7,
  name: 'Casio calculator',
  description: 'Works great',
  hourlyRate: 20,
  campus: 'City',
  negotiable: true,
  imageUrl: '', // no network image in tests
  ownerUsername: 'Ali Khan',
  condition: 'Good',
  maxDuration: 3,
  postedAt: '2026-11-27',
);

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

  testWidgets('edit mode fills the form and changes the title and button',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: CreateListingScreen(listing: existing)));

    expect(find.text('Edit Listing'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Casio calculator'), findsOneWidget);
    expect(find.text('Works great'), findsOneWidget);
    expect(find.text('20'), findsOneWidget); // 20.0 shows as "20"
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('City Campus'), findsOneWidget);
  });

  testWidgets('saving an edit sends the changes and keeps the old photo',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auth_token': 'my-token'});

    final api = FakeEditApi();
    await tester.pumpWidget(
        MaterialApp(home: CreateListingScreen(api: api, listing: existing)));

    await tester.enterText(find.widgetWithText(TextFormField, '20'), '35');
    await tester.ensureVisible(find.byKey(const Key('post_button')));
    await tester.tap(find.byKey(const Key('post_button')));
    await tester.pumpAndSettle();

    expect(api.called, isTrue);
    expect(api.editedId, 7);
    expect(api.sentTitle, 'Casio calculator');
    expect(api.sentRate, '35');
    expect(api.sentPhoto, isNull); // no new photo picked = keep the old one
    expect(find.byKey(const Key('photo_error')), findsNothing);
  });
}