// Widget tests for SCRUM-37: the "Request for Rent" button.
// Uses a fake API, so the backend does NOT need to be running.
// Run with:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/rental_request_api.dart';
import 'package:frontend/request_rent_button.dart';
import 'package:frontend/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRequestApi extends RentalRequestApi {
  RequestStatus status;
  Exception? sendError;
  int sendCalls = 0;

  FakeRequestApi({
    bool isOwner = false,
    bool alreadyRequested = false,
    bool available = true,
    this.sendError,
  }) : status = RequestStatus(
          isOwner: isOwner,
          alreadyRequested: alreadyRequested,
          listingAvailable: available,
        );

  @override
  Future<RequestStatus> getStatus({required String token, required int listingId}) async => status;

  @override
  Future<String> sendRequest({required String token, required int listingId}) async {
    sendCalls++;
    if (sendError != null) throw sendError!;
    status = RequestStatus(isOwner: false, alreadyRequested: true, listingAvailable: true);
    return 'Request sent! The owner will see it on their dashboard';
  }
}

Future<void> pumpButton(WidgetTester tester, FakeRequestApi api) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: RequestRentButton(listingId: 1, api: api)),
  ));
  await tester.pumpAndSettle();
}

ElevatedButton button(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(const Key('request_rent_button')));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'auth_token': 'tok'}));

  testWidgets('shows REQUEST FOR RENT and sends a request on tap', (tester) async {
    final api = FakeRequestApi();
    await pumpButton(tester, api);
    expect(find.text('REQUEST FOR RENT'), findsOneWidget);

    await tester.tap(find.byKey(const Key('request_rent_button')));
    await tester.pumpAndSettle();

    expect(api.sendCalls, 1);
    expect(find.text('Request sent! The owner will see it on their dashboard'), findsOneWidget);
    expect(find.text('REQUESTED'), findsOneWidget);
    expect(button(tester).onPressed, isNull); // can't send twice
  });

  testWidgets('already requested: shows REQUESTED, disabled', (tester) async {
    await pumpButton(tester, FakeRequestApi(alreadyRequested: true));
    expect(find.text('REQUESTED'), findsOneWidget);
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('FR-3.2: own listing shows a note instead of a button', (tester) async {
    await pumpButton(tester, FakeRequestApi(isOwner: true));
    expect(find.text('This is your listing'), findsOneWidget);
    expect(find.byKey(const Key('request_rent_button')), findsNothing);
  });

  testWidgets('rented out: shows NOT AVAILABLE, disabled', (tester) async {
    await pumpButton(tester, FakeRequestApi(available: false));
    expect(find.text('NOT AVAILABLE'), findsOneWidget);
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('backend error is shown to the user', (tester) async {
    final api = FakeRequestApi(sendError: AuthException('This item is no longer available'));
    await pumpButton(tester, api);
    await tester.tap(find.byKey(const Key('request_rent_button')));
    await tester.pumpAndSettle();
    expect(find.text('This item is no longer available'), findsOneWidget);
  });

  testWidgets('expired login goes back to Welcome', (tester) async {
    final api = FakeRequestApi(sendError: SessionExpiredException('Session expired. Please log in again'));
    await pumpButton(tester, api);
    await tester.tap(find.byKey(const Key('request_rent_button')));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
