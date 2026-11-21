import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'temp_home_screen.dart';

/// After a successful login/sign-up: save the token (the splash screen reads
/// 'auth_token' to keep you logged in, SCRUM-12) and go to the home page,
/// clearing history so Back can't return to the login screen (FR-1.8).
Future<void> saveSessionAndGoHome(BuildContext context, AuthResult result) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', result.token);
  await prefs.setString('user_erp', result.user['erp']?.toString() ?? '');
  await prefs.setString('user_name', result.user['name']?.toString() ?? '');

  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const TempHomeScreen()),
    (route) => false,
  );
}

/// Red error text shown above the main button on auth screens.
class AuthErrorText extends StatelessWidget {
  final String? message;
  const AuthErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return SizedBox(
      width: 400,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          message!,
          key: const Key('auth_error_text'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
