import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'styles.dart';
import 'welcome_screen.dart';

// TEMPORARY page for in place of listings page. needed for token.
// will be deleted when the real listings page is built
class TempHomeScreen extends StatelessWidget {
  const TempHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("You are logged in (temporary page)"),
            const SizedBox(height: 20),
            ElevatedButton(
              style: AppStyles.primaryButtonStyle,
              onPressed: () async {
                // Delete the saved token.
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('auth_token');

                if (!context.mounted) return;

                // Go to Welcome and clear all old screens from history.
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              child: const Text("LOGOUT"),
            ),
          ],
        ),
      ),
    );
  }
}