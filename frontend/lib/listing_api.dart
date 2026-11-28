import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'auth_validators.dart';
import 'listing_model.dart';
/// Talks to the listing endpoints in backend/listings.py.
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
    _addFields(request, token, title, description, hourlyRate, condition,
        maxDuration, negotiable, campus);
    request.files.add(
      http.MultipartFile.fromBytes('photo', photoBytes, filename: photoName),
    );
    await _sendForm(request, successCode: 201);
  }

  /// PUT /listings/{id}: edit one of my listings (SCRUM-24).
  /// photoBytes is optional: leave it null to keep the old photo.
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
    final request =
        http.MultipartRequest('PUT', Uri.parse('$apiBaseUrl/listings/$listingId'));
    _addFields(request, token, title, description, hourlyRate, condition,
        maxDuration, negotiable, campus);
    if (photoBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('photo', photoBytes, filename: photoName),
      );
    }
    await _sendForm(request, successCode: 200);
  }

  /// Puts the token and the text fields on the request (same for create and edit).
  void _addFields(
    http.MultipartRequest request,
    String token,
    String title,
    String description,
    String hourlyRate,
    String condition,
    String maxDuration,
    bool negotiable,
    String campus,
  ) {
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title.trim();
    request.fields['description'] = description.trim();
    request.fields['hourly_rate'] = hourlyRate.trim();
    request.fields['condition'] = condition.trim();
    request.fields['max_duration'] = maxDuration.trim();
    request.fields['negotiable'] = negotiable.toString(); // "true" or "false"
    request.fields['campus'] = campus;
  }

  /// Sends the form. Returns quietly on success, throws on any error.
  Future<void> _sendForm(http.MultipartRequest request,
      {required int successCode}) async {
    final http.Response res;
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      // Backend not running, no internet, timeout...
      throw AuthException(AuthMessages.serverUnreachable);
    }

    if (res.statusCode == successCode) return; // success

    // 400 / 403 / 404 / 409 all come with a message from the server in "detail".
    final detail = _detail(res.body);
    if (res.statusCode == 401) {
      throw SessionExpiredException(detail ?? 'Session expired. Please log in again');
    }
    throw AuthException(detail ?? 'Something went wrong (${res.statusCode})');
  }

  /// GET /listings/mine: every listing the logged-in user posted (My Dashboard).
  Future<List<Listing>> getMyListings(String token) async {
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse('$apiBaseUrl/listings/mine'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(AuthMessages.serverUnreachable);
    }

    if (res.statusCode == 200) {
      final items = jsonDecode(res.body)['data']['items'] as List;
      return items.map((json) => Listing.fromJson(json)).toList();
    }

    final detail = _detail(res.body);
    if (res.statusCode == 401) {
      throw SessionExpiredException(detail ?? 'Session expired. Please log in again');
    }
    throw AuthException(detail ?? 'Could not load your listings (${res.statusCode})');
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