import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Open the phone/browser's small saved storage.
    final prefs = await SharedPreferences.getInstance();
    //await prefs.setString('auth_token', 'fake-token');

    // Look for a saved token. It is null if nothing was saved.
    final token = prefs.getString('auth_token');

    // If this screen was already closed while we waited, stop here.
    if (!mounted) return;

    // Token found -> temporary home page (will be replaced by listings page).
    // No token -> welcome page.
    final Widget nextScreen = (token != null && token.isNotEmpty)
        ? const TempHomeScreen()
        : const WelcomeScreen();

    // pushReplacement removes the splash screen, so Back can't return to it.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
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
