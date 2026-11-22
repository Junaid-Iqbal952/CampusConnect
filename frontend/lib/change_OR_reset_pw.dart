import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_session.dart';

// Use http://10.0.2.2:8000 for Android Emulator, or http://127.0.0.1:8000 for Windows/Web/iOS Simulator
const String _kBaseUrl = 'http://127.0.0.1:8000';

class ResetPasswordScreen extends StatefulWidget {
  final bool isChangePassword;
  final String? email;
  final String? code;

  const ResetPasswordScreen({
    super.key,
    this.isChangePassword = false,
    this.email,
    this.code,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _codeController;
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    _codeController = TextEditingController(text: widget.code ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPass = _newController.text;
    final confirmPass = _confirmController.text;

    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    if (newPass != confirmPass) {
      FocusScope.of(context).unfocus();
      _newController.clear();
      _confirmController.clear();
      setState(() => _error = "Passwords don't match");
      return;
    }

    if (!widget.isChangePassword) {
      if (_emailController.text.trim().isEmpty) {
        setState(() => _error = 'Please enter your email address');
        return;
      }
      if (_codeController.text.trim().isEmpty) {
        setState(() => _error = 'Please enter the 6-digit verification code');
        return;
      }
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      http.Response response;

            if (widget.isChangePassword) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';
        final uri = Uri.parse('$_kBaseUrl/auth/change-password');
        response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',     // proves who we are
          },
          body: jsonEncode({
            'current_password': _currentController.text,
            'new_password': newPass,
          }),
        );
      } else {
        final uri = Uri.parse('$_kBaseUrl/auth/reset-password').replace(
          queryParameters: {
            'email': _emailController.text.trim(),
            'code': _codeController.text.trim(),
            'new_password': newPass,
          },
        );
        response = await http.post(uri, headers: {'accept': 'application/json'});
      }

      if (!mounted) return;

            // 401 = token no longer valid (expired, or logged in on another device).
      if (response.statusCode == 401 && widget.isChangePassword) {
        var msg = 'Session expired. Please log in again';
        try {
          msg = jsonDecode(response.body)['detail'].toString();
        } catch (_) {}
        await clearSessionAndGoToWelcome(context, message: msg);
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
        Navigator.pop(context, true);
      } else {
        String message = 'Failed to update password (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            message = decoded['detail'].toString();
          }
        } catch (_) {}
        setState(() => _error = message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach server. Check if backend is running.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool hidden,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: hidden,
      enableSuggestions: false,   // stops the browser's suggestions popup
      autocorrect: false,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: const BorderSide(color: AppStyles.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _infoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: const BorderSide(color: AppStyles.primaryColor, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showResetFields =
        !widget.isChangePassword && (widget.email == null || widget.code == null);

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
                Text(
                  widget.isChangePassword
                      ? 'Change password'
                      : 'Reset password',
                  style: AppStyles.headingText,
                ),
                const SizedBox(height: 40),
                if (widget.isChangePassword) ...[
                  _passwordField(
                    label: 'Current password',
                    controller: _currentController,
                    hidden: _hideCurrent,
                    onToggle: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                  ),
                  const SizedBox(height: 20),
                ] else if (showResetFields) ...[
                  _infoField(
                    label: 'Email address',
                    controller: _emailController,
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _infoField(
                    label: '6-digit code',
                    controller: _codeController,
                    icon: Icons.verified_user,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                ],
                _passwordField(
                  label: 'New password',
                  controller: _newController,
                  hidden: _hideNew,
                  onToggle: () => setState(() => _hideNew = !_hideNew),
                ),
                const SizedBox(height: 20),
                _passwordField(
                  label: 'Confirm password',
                  controller: _confirmController,
                  hidden: _hideConfirm,
                  onToggle: () =>
                      setState(() => _hideConfirm = !_hideConfirm),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: AppStyles.primaryButtonStyle,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'SAVE PASSWORD',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}