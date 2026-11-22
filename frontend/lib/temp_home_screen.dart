import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'change_OR_reset_pw.dart';
import 'styles.dart';

// TEMPORARY page in place of the listings page. Delete when the real one is built.
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ResetPasswordScreen(isChangePassword: true),
                ),
              ),
              child: const Text("CHANGE PASSWORD"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: AppStyles.primaryButtonStyle,
              onPressed: () => logoutAndGoToWelcome(context),
              child: const Text("LOGOUT"),
            ),
          ],
        ),
      ),
    );
  }
}