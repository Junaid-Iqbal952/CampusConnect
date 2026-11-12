import 'package:flutter/material.dart';

import 'signup_screen.dart';
import 'login_screen.dart';
import 'styles.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. The Logo
              Image.asset('assets/logo.png', height: 400),

              const SizedBox(height: 25), // Gap before buttons
              // 3. Buttons in a single line (Row)
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Centers the buttons
                children: [
                  // Login Button
                  SizedBox(
                    width: 120, // Small fixed width
                    height: 45,
                    child: ElevatedButton(
                      style: AppStyles.primaryButtonStyle,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Login",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 60,
                  ), // Horizontal space between the two buttons
                  // Sign Up Button
                  SizedBox(
                    width: 120, // Matches the login button
                    height: 45,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppStyles.primaryColor,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
