import 'package:flutter/material.dart';
import 'styles.dart';
// One screen used in 2 places: forgot password and change password.
// For Change Password (from the hamburger menu), pass isChangePassword: true.

class ResetPasswordScreen extends StatefulWidget {
  final bool isChangePassword;

  const ResetPasswordScreen({super.key, this.isChangePassword = false});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _save() {
    final newPass = _newController.text;
    final confirmPass = _confirmController.text;

    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    if (newPass != confirmPass) {
      _newController.clear();
      _confirmController.clear();
      setState(() => _error = "Passwords don't match");
      return;
    }

    setState(() => _error = null);

    // TODO: call the backend here to save the new password.
    // If isChangePassword is true, send _currentController.text too.
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

  @override
  Widget build(BuildContext context) {
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
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _save,
                  style: AppStyles.primaryButtonStyle,
                  child: const Text(
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