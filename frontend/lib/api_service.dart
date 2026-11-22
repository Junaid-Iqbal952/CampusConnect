import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_validators.dart';
import 'device_id.dart';

/// Where the FastAPI backend runs.
/// - Flutter web / desktop on the same laptop: http://127.0.0.1:8000 (default)
/// - Android emulator: run with  --dart-define=API_URL=http://10.0.2.2:8000
const String apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

/// Thrown when the backend says no. [message] is safe to show the user.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the server says 401 (token no longer valid).
class SessionExpiredException extends AuthException {
  SessionExpiredException(super.message);
}

class AuthResult {
  final String token;
  final Map<String, dynamic> user;
  AuthResult({required this.token, required this.user});
}

/// Talks to backend/auth.py. Screens take an AuthApi so tests can pass a fake one.
class AuthApi {
  final http.Client _client;
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) {
    return _post('/auth/login', {
      'identifier': identifier.trim(),
      'password': password,
    });
  }

  Future<AuthResult> signup({
    required String name,
    required String erp,
    required String email,
    required String password,
  }) {
    return _post('/auth/signup', {
      'name': name.trim(),
      'erp': erp.trim(),
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AuthResult> _post(String path, Map<String, String> body) async {
    final http.Response res;
    final deviceId = await getDeviceId();
    try {
      res = await _client
          .post(
            Uri.parse('$apiBaseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({...body, 'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Backend not running, no internet, CORS blocked, timeout...
      throw AuthException(AuthMessages.serverUnreachable);
    }

    final data = _decode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return AuthResult(
        token: data['token'] as String,
        user: Map<String, dynamic>.from(data['user'] as Map),
      );
    }

    // FastAPI errors look like {"detail": "message"}.
    final detail = data['detail'];
    throw AuthException(
      detail is String ? detail : 'Something went wrong (${res.statusCode})',
    );
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

    /// Asks the server: is this saved token still valid?
  /// Returns normally if yes. Throws SessionExpiredException on 401.
  Future<void> checkSession(String token) async {
    final http.Response res;
    try {
      res = await _client
          .get(Uri.parse('$apiBaseUrl/auth/me'),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw AuthException(AuthMessages.serverUnreachable);
    }
    if (res.statusCode == 200) return;
    if (res.statusCode == 401) {
      final detail = _decode(res.body)['detail'];
      throw SessionExpiredException(
          detail is String ? detail : 'Session expired. Please log in again');
    }
    throw AuthException('Something went wrong (${res.statusCode})');
  }

  /// Tells the server we logged out. Errors are ignored on purpose.
  Future<void> logout(String token) async {
    try {
      await _client
          .post(Uri.parse('$apiBaseUrl/auth/logout'),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
