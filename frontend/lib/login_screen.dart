import 'package:flutter/material.dart';

import 'api_service.dart';
import 'auth_session.dart';
import 'auth_validators.dart';
import 'signup_screen.dart';
import 'styles.dart';
import 'forgot_password_screen.dart';
class LoginScreen extends StatefulWidget {
  /// Tests pass a fake AuthApi; the real app uses the default one.
  final AuthApi? api;
  const LoginScreen({Key? key, this.api}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  late final AuthApi _api = widget.api ?? AuthApi();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // SCRUM-8: log in with ERP (or email) + password.
  // SCRUM-9: show the error and clear both fields if credentials are wrong.
  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = AuthMessages.fillAllFields);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _api.login(identifier: identifier, password: password);
      if (!mounted) return;
      await saveSessionAndGoHome(context, result);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        // FR-1.5: clear both fields on wrong credentials.
        if (e.message == AuthMessages.wrongCredentials) {
          _identifierController.clear();
          _passwordController.clear();
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //const Icon(Icons.school, size: 80, color: AppStyles.primaryColor),
              Image.asset('assets/logo.png', height: 300),
              const SizedBox(height: 10),
              const Text(
                "Welcome Back!",
                textAlign: TextAlign.center,
                style: AppStyles.headingText,
              ),
              const SizedBox(height: 40),

              // ERP or Email Field
              SizedBox(
                width: 400,
                child: TextField(
                  key: const Key('login_identifier'),
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText: "ERP or Email",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 15.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Password Field
              SizedBox(
                width: 400,
                child: TextField(
                  key: const Key('login_password'),
                  controller: _passwordController,
                  onSubmitted: (_) => _isLoading ? null : _login(),
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 15.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        30.0,
                      ), // This makes the corners round
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2.5),

              // Forgot Password
              SizedBox(
                width: 400,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final didReset = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                      if (!context.mounted) return;
                      if (didReset == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password reset complete. Log in with your new password.',
                            ),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: AppStyles.primaryColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              AuthErrorText(_errorMessage),

              // Login Button
              ElevatedButton(
                key: const Key('login_button'),
                style: AppStyles.primaryButtonStyle,
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("LOGIN", style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 10),

              // Sign Up Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Sign Up Now",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppStyles.primaryColor,
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
