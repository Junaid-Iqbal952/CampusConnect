// Client-side checks for the auth screens (SCRUM-7, SCRUM-9).
// Messages match the SRS (Deliverable 3) and the backend (backend/auth.py).
// The backend repeats every check, these just give instant feedback.

class AuthMessages {
  static const wrongCredentials = 'Wrong username or password';
  static const fillAllFields = 'Please fill in all fields';
  static const nameRequired = 'Please enter your full name';
  static const badErp = 'ERP must be exactly 5 digits';
  static const badEmail = 'Please enter your IBA email';
  static const shortPassword = 'Password must be at least 8 characters';
  static const passwordsDontMatch = "Passwords don't match";
  static const serverUnreachable =
      'Could not reach the server. Check your connection and try again.';
}

class AuthValidators {
  static const ibaDomain = '@khi.iba.edu.pk';
  static const minPasswordLength = 8;

  /// Returns an error message, or null if the value is OK.
  static String? name(String value) =>
      value.trim().isEmpty ? AuthMessages.nameRequired : null;

  static String? erp(String value) =>
      RegExp(r'^\d{5}$').hasMatch(value.trim()) ? null : AuthMessages.badErp;

  static String? ibaEmail(String value) {
    final email = value.trim().toLowerCase();
    if (email.length <= ibaDomain.length || !email.endsWith(ibaDomain)) {
      return AuthMessages.badEmail;
    }
    return null;
  }

  static String? password(String value) =>
      value.length < minPasswordLength ? AuthMessages.shortPassword : null;

  static String? confirmPassword(String password, String confirm) =>
      password == confirm ? null : AuthMessages.passwordsDontMatch;
}
