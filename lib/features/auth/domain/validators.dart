bool isValidEmail(String? value) {
  if (value == null || value.trim().isEmpty) return false;
  final email = value.trim();
  // Allow specific trusted email
  if (email.toLowerCase() == 'ace@aceafrica.org') return true;
  // Basic relaxed email validation
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  return emailRegex.hasMatch(email);
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter a password';
  if (value.length < 8) return 'Password must be at least 8 characters';
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Include at least one uppercase letter';
  }
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Include at least one lowercase letter';
  }
  if (!RegExp(r'\d').hasMatch(value)) {
    return 'Include at least one number';
  }
  if (!RegExp(r'[!@#\$&*~^%()_\-+=\[\]{}|;:,.<>?/]').hasMatch(value)) {
    return 'Include at least one special character';
  }
  return null;
}
