import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_session.dart';
import 'rental_request_api.dart';
import 'styles.dart';

/// SCRUM-37: the "Request for Rent" button on the listing detail page.
///
/// Asks the backend first, then shows one of:
///   - your own listing  -> a note instead of a button (FR-3.2)
///   - already requested -> "REQUESTED" (disabled)
///   - already rented    -> "NOT AVAILABLE" (disabled)
///   - otherwise         -> "REQUEST FOR RENT"
class RequestRentButton extends StatefulWidget {
  final int listingId;

  /// Tests pass a fake API; the real app uses the default one.
  final RentalRequestApi? api;

  const RequestRentButton({super.key, required this.listingId, this.api});

  @override
  State<RequestRentButton> createState() => _RequestRentButtonState();
}

class _RequestRentButtonState extends State<RequestRentButton> {
  late final RentalRequestApi _api = widget.api ?? RentalRequestApi();

  bool _loading = true;
  bool _sending = false;
  RequestStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<String> _token() async =>
      (await SharedPreferences.getInstance()).getString('auth_token') ?? '';

  Future<void> _loadStatus() async {
    try {
      final status = await _api.getStatus(token: await _token(), listingId: widget.listingId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } on SessionExpiredException catch (e) {
      if (!mounted) return;
      await clearSessionAndGoToWelcome(context, message: e.message);
    } on AuthException {
      // Couldn't check: still show the normal button; the backend re-checks on tap.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await _api.sendRequest(token: await _token(), listingId: widget.listingId);
      if (!mounted) return;
      setState(() => _status = RequestStatus(
            isOwner: false,
            alreadyRequested: true,
            listingAvailable: true,
          ));
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on SessionExpiredException catch (e) {
      if (!mounted) return;
      await clearSessionAndGoToWelcome(context, message: e.message);
    } on AuthException catch (e) {
      // e.g. "You have already requested this item", "This item is no longer available"
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      _loadStatus(); // refresh the button to match the server
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final status = _status;
    if (status != null && status.isOwner) {
      return const SizedBox(
        width: double.infinity,
        child: Text(
          'This is your listing',
          key: Key('own_listing_note'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
      );
    }

    String label = 'REQUEST FOR RENT';
    VoidCallback? onPressed = _sending ? null : _send;
    if (status != null && status.alreadyRequested) {
      label = 'REQUESTED';
      onPressed = null;
    } else if (status != null && !status.listingAvailable) {
      label = 'NOT AVAILABLE';
      onPressed = null;
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        key: const Key('request_rent_button'),
        style: AppStyles.primaryButtonStyle,
        onPressed: onPressed,
        child: _sending
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
