// Widget tests for My Dashboard (SCRUM-51). No backend needed: a fake API
// gives back whatever each test wants.
// Run with:  flutter test
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/listing_api.dart';
import 'package:frontend/listing_model.dart';
import 'package:frontend/create_listing_screen.dart';
import 'package:frontend/dashboard.dart';
import 'package:frontend/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pretends to be the backend. Either returns [items] or throws [error].
class FakeListingApi extends ListingApi {
  final List<Listing> items;
  final Exception? error;
  String? tokenUsed;
  int loadCount = 0; // how many times the dashboard asked for my listings

  FakeListingApi({this.items = const [], this.error});

  @override
  Future<List<Listing>> getMyListings(String token) async {
    tokenUsed = token;
    loadCount++;
    if (error != null) throw error!;
    return items;
  }

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
  }) async {} // pretend the save worked
}

Listing fakeListing(int id, String name) => Listing(
      id: id,
      name: name,
      description: 'desc',
      hourlyRate: 20,
      campus: 'Main',
      negotiable: false,
      imageUrl: '', // no network image in tests
      ownerUsername: 'Ali Khan',
      condition: 'Good',
      maxDuration: 3,
      postedAt: '2026-11-27',
    );

Future<void> openDashboard(WidgetTester tester, FakeListingApi api) async {
  await tester.pumpWidget(MaterialApp(home: MyDashboardScreen(api: api)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'auth_token': 'my-token'}));

  testWidgets('shows my listings with the saved token', (tester) async {
    final api = FakeListingApi(items: [
      fakeListing(1, 'Casio calculator'),
      fakeListing(2, 'Lab coat'),
    ]);
    await openDashboard(tester, api);

    expect(api.tokenUsed, 'my-token');
    expect(find.text('My Listings'), findsOneWidget);
    expect(find.text('Casio calculator'), findsOneWidget);
    expect(find.text('Lab coat'), findsOneWidget);
    expect(find.text('Rs 20 / hr'), findsNWidgets(2));
    expect(find.text('Available'), findsNWidgets(2));
  });

  testWidgets('shows a message when I have no listings', (tester) async {
    await openDashboard(tester, FakeListingApi());
    expect(find.byKey(const Key('my_listings_empty')), findsOneWidget);
  });

  testWidgets('shows the error and a Try again button', (tester) async {
    await openDashboard(
      tester,
      FakeListingApi(error: AuthException('Could not reach the server')),
    );
    expect(find.text('Could not reach the server'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('expired login goes back to Welcome', (tester) async {
    await openDashboard(
      tester,
      FakeListingApi(error: SessionExpiredException('Session expired')),
    );
    expect(find.byType(WelcomeScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
  });

  testWidgets('Edit opens the filled form, and saving reloads the list',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400); // tall enough for the form
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = FakeListingApi(items: [fakeListing(1, 'Casio calculator')]);
    await openDashboard(tester, api);
    expect(api.loadCount, 1);

    await tester.tap(find.byKey(const Key('edit_listing_1')));
    await tester.pumpAndSettle();
    expect(find.byType(CreateListingScreen), findsOneWidget);
    expect(find.text('Edit Listing'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('post_button')));
    await tester.tap(find.byKey(const Key('post_button')));
    await tester.pumpAndSettle();

    expect(find.byType(CreateListingScreen), findsNothing); // back on the dashboard
    expect(api.loadCount, 2); // list was loaded again
  });

  testWidgets('no Edit button on a listing that is not available',
      (tester) async {
    final rented = Listing(
      id: 2,
      name: 'Lab coat',
      description: 'desc',
      hourlyRate: 20,
      campus: 'Main',
      negotiable: false,
      imageUrl: '',
      ownerUsername: 'Ali Khan',
      condition: 'Good',
      maxDuration: 3,
      postedAt: '2026-11-27',
      status: 'rented',
    );
    await openDashboard(tester, FakeListingApi(items: [rented]));
    expect(find.byKey(const Key('edit_listing_2')), findsNothing);
  });
}