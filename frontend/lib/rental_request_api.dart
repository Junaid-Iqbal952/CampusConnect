import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'auth_validators.dart';

/// What the "Request for Rent" button needs to know (GET /listings/{id}/request-status).
class RequestStatus {
  final bool isOwner;
  final bool alreadyRequested;
  final bool listingAvailable;

  RequestStatus({
    required this.isOwner,
    required this.alreadyRequested,
    required this.listingAvailable,
  });
}

/// Talks to backend/rental_requests.py (SCRUM-37).
class RentalRequestApi {
  final http.Client _client;
  RentalRequestApi({http.Client? client}) : _client = client ?? http.Client();

  /// SCRUM-37: returns the success message to show the user.
  Future<String> sendRequest({required String token, required int listingId}) async {
    final res = await _call(() => _client.post(
          Uri.parse('$apiBaseUrl/listings/$listingId/request'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (res.statusCode == 201) {
      return _decode(res.body)['message']?.toString() ?? 'Request sent!';
    }
    throw _error(res);
  }

  Future<RequestStatus> getStatus({required String token, required int listingId}) async {
    final res = await _call(() => _client.get(
          Uri.parse('$apiBaseUrl/listings/$listingId/request-status'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (res.statusCode != 200) throw _error(res);
    final j = _decode(res.body);
    return RequestStatus(
      isOwner: j['is_owner'] == true,
      alreadyRequested: j['already_requested'] == true,
      listingAvailable: j['listing_available'] != false,
    );
  }

  // ---------- helpers ----------

  Future<http.Response> _call(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(AuthMessages.serverUnreachable);
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  AuthException _error(http.Response res) {
    final detail = _decode(res.body)['detail'];
    final message = detail is String ? detail : 'Something went wrong (${res.statusCode})';
    if (res.statusCode == 401) return SessionExpiredException(message);
    return AuthException(message);
  }
}
