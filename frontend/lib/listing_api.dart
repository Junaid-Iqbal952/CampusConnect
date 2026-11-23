import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'auth_validators.dart';

/// Talks to POST /listings in backend/listings.py.
class ListingApi {
  final http.Client _client;
  ListingApi({http.Client? client}) : _client = client ?? http.Client();

  Future<void> createListing({
    required String token,
    required String title,
    required String description,
    required String hourlyRate,
    required String condition,
    required String maxDuration,
    required bool negotiable,
    required String campus,
    required Uint8List photoBytes,
    required String photoName,
  }) async {
    // A "multipart" request can carry text fields AND a file together.
    final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/listings'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title.trim();
    request.fields['description'] = description.trim();
    request.fields['hourly_rate'] = hourlyRate.trim();
    request.fields['condition'] = condition.trim();
    request.fields['max_duration'] = maxDuration.trim();
    request.fields['negotiable'] = negotiable.toString(); // "true" or "false"
    request.fields['campus'] = campus;
    request.files.add(
      http.MultipartFile.fromBytes('photo', photoBytes, filename: photoName),
    );

    final http.Response res;
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      // Backend not running, no internet, timeout...
      throw AuthException(AuthMessages.serverUnreachable);
    }

    if (res.statusCode == 201) return; // success

    final detail = _detail(res.body);
    if (res.statusCode == 401) {
      throw SessionExpiredException(detail ?? 'Session expired. Please log in again');
    }
    throw AuthException(detail ?? 'Something went wrong (${res.statusCode})');
  }

  /// FastAPI errors look like {"detail": "message"}. Returns the message, or null.
  String? _detail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {}
    return null;
  }
}