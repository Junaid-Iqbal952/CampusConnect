import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_session.dart';
import 'styles.dart';
import 'temp_home_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    // Open the browser's small saved storage and look for a saved token.
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    // If this screen was already closed while we waited, stop here.
    if (!mounted) return;

    // No saved token -> Welcome page.
    if (token == null || token.isEmpty) {
      _go(const WelcomeScreen());
      return;
    }

    // Saved token -> ask the server if it is still good.
    try {
      await AuthApi().checkSession(token);
    } on SessionExpiredException catch (e) {
      // Token expired, or another device logged in.
      // Wipe the saved login and show the reason on the Welcome page.
      if (!mounted) return;
      await clearSessionAndGoToWelcome(context, message: e.message);
      return;
    } catch (_) {
      // Server not reachable (no internet, backend off).
      // Stay logged in, because staying logged in shouldn't need internet.
    }

    if (!mounted) return;
    _go(const TempHomeScreen());
  }

  // pushReplacement removes the splash screen, so Back can't return to it.
  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      body: Center(child: Image.asset('assets/logo.png', height: 300)),
    );
  }
}