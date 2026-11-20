import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'change_OR_reset_pw.dart';
import 'styles.dart';

// Use http://10.0.2.2:8000 for Android Emulator, or http://127.0.0.1:8000 for Windows/Web/iOS Simulator
const String _kBaseUrl = 'http://127.0.0.1:8000';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  Timer? _cooldownTimer;
  int _secondsRemaining = 0;
  bool _isSending = false;
  bool _codeSent = false;
  String? _statusMessage;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _secondsRemaining = seconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  int? _extractWaitSeconds(String detail) {
    final match = RegExp(r'Wait\s+(\d+)\s+seconds').firstMatch(detail);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _error = null;
      _statusMessage = null;
      _isSending = true;
    });

    try {
      final uri = Uri.parse('$_kBaseUrl/auth/request-reset').replace(
        queryParameters: {'email': email},
      );
      final response = await http.post(
        uri,
        headers: {'accept': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String message = 'Verification code sent (valid for 5 minutes).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['test_code'] != null) {
            // Helpful while testing before email delivery is wired up
            message = 'Code sent (dev code: ${decoded['test_code']}). Valid 5 min.';
          }
        } catch (_) {}

        setState(() {
          _codeSent = true;
          _statusMessage = message;
        });
        _startCooldown(60);
      } else {
        String detail = 'Could not send code (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            detail = decoded['detail'].toString();
          }
        } catch (_) {}

        final retryAfter = _extractWaitSeconds(detail);
        if (response.statusCode == 429 && retryAfter != null) {
          _startCooldown(retryAfter);
        }
        setState(() => _error = detail);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach server. Check if backend is running.');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _continueToReset() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address');
      return;
    }
    if (code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit verification code');
      return;
    }

    setState(() => _error = null);
    final didReset = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          isChangePassword: false,
          email: email,
          code: code,
        ),
      ),
    );

    if (!mounted) return;
    if (didReset == true) {
      Navigator.pop(context, true);
    }
  }

  InputDecoration _pillDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      contentPadding: const EdgeInsets.symmetric(vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(color: AppStyles.primaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCoolingDown = _secondsRemaining > 0;

    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppStyles.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppStyles.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Forgot password', style: AppStyles.headingText),
                const SizedBox(height: 12),
                const Text(
                  'Enter your campus email to receive a 6-digit reset code.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _pillDecoration(
                    hint: 'Email address',
                    icon: Icons.email,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (_isSending || isCoolingDown) ? null : _requestCode,
                  style: AppStyles.primaryButtonStyle,
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isCoolingDown
                              ? 'RESEND IN ${_secondsRemaining}S'
                              : (_codeSent ? 'RESEND CODE' : 'SEND CODE'),
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: _pillDecoration(
                      hint: '6-digit verification code',
                      icon: Icons.verified_user,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _continueToReset,
                    style: AppStyles.primaryButtonStyle,
                    child: const Text(
                      'VERIFY & SET PASSWORD',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.green),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}