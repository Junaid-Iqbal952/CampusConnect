import 'package:flutter/material.dart';

import 'api_service.dart';
import 'auth_session.dart';
import 'auth_validators.dart';
import 'login_screen.dart';
import 'styles.dart';

class SignupScreen extends StatefulWidget {
  /// Tests pass a fake AuthApi; the real app uses the default one.
  final AuthApi? api;
  const SignupScreen({Key? key, this.api}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _erpController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  late final AuthApi _api = widget.api ?? AuthApi();

  @override
  void dispose() {
    _fullNameController.dispose();
    _erpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) => setState(() => _errorMessage = message);

  // Sign up with name, ERP, IBA email + password (SCRUM-7).
  Future<void> _createAccount() async {
    final name = _fullNameController.text;
    final erp = _erpController.text;
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    // Check the fields top to bottom and stop at the first problem.
    final nameError = AuthValidators.name(name);
    if (nameError != null) {
      _showError(nameError);
      return;
    }

    final erpError = AuthValidators.erp(erp);
    if (erpError != null) {
      _showError(erpError);
      return;
    }

    final emailError = AuthValidators.ibaEmail(email);
    if (emailError != null) {
      _emailController.clear(); // FR-1.1: clear the email field
      _showError(emailError);
      return;
    }

    final passwordError = AuthValidators.password(password);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }

    final confirmError = AuthValidators.confirmPassword(password, confirm);
    if (confirmError != null) {
      _passwordController.clear(); // FR-1.2: clear both password fields
      _confirmPasswordController.clear();
      _showError(confirmError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _api.signup(
        name: name,
        erp: erp,
        email: email,
        password: password,
      );
      if (!mounted) return;
      // TODO (SCRUM-6/10/11): go to the email-code screen here instead, once it exists.
      await saveSessionAndGoHome(context, result);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message); // e.g. "An account with this ERP already exists"
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
              // 2. Title
              const Text(
                "Enter Details",
                textAlign: TextAlign.center,
                style: AppStyles.headingText,
              ),
              const SizedBox(height: 30),

              // 3. Full Name Field
              SizedBox(
                width: 400,
                child: TextField(
                  key: const Key('signup_fullName'),
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 15.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 4. ERP Field
              SizedBox(
                width: 400,
                child: TextField(
                  key: const Key('signup_erp'),
                  controller: _erpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "ERP (5 digits)",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 15.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 5. IBA Email Field
              SizedBox(
                width: 400,
                child: TextField(
                  key: const Key('signup_email'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "IBA Email",
                    hintText: "e.g., student@khi.iba.edu.pk",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 15.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 6. Password Field
              SizedBox(
                width: 400,
                child: TextField(
                  key: const Key('signup_password'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 15.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
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
              const SizedBox(height: 30),

              // 7. Confirm Password Field
              SizedBox(
                width: 400,
                child: TextField(
                  key: const Key('signup_confirmPassword'),
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 15.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              AuthErrorText(_errorMessage),

              // 8. Create Account Button
              SizedBox(
                width: 200,
                height: 40,
                child: ElevatedButton(
                  key: const Key('signup_button'),
                  style: AppStyles.primaryButtonStyle,
                  onPressed: _isLoading ? null : _createAccount,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "CREATE ACCOUNT",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 15),

              // 9. Already a member? Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already a member?"),
                  TextButton(
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
