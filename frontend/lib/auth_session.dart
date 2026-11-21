import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'temp_home_screen.dart';
import 'welcome_screen.dart';

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

/// Wipes the saved login and goes to Welcome (back can't return).
/// [message] is shown as a small bar, e.g. "You were logged in on another device".
Future<void> clearSessionAndGoToWelcome(BuildContext context, {String? message}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_token');
  await prefs.remove('user_erp');
  await prefs.remove('user_name');

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);   // grab it BEFORE leaving this screen
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    (route) => false,
  );
  if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// The normal logout button: tell the server, then wipe the phone.
Future<void> logoutAndGoToWelcome(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  if (token != null) await AuthApi().logout(token);
  if (!context.mounted) return;
  await clearSessionAndGoToWelcome(context);
}