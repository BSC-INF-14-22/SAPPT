const testAdminEmail = 'admin@gmail.com';

bool isTestAdminEmail(String? value) =>
    value != null && value.trim().toLowerCase() == testAdminEmail;

bool isValidEmail(String? value) {
  if (value == null || value.trim().isEmpty) return false;
  final email = value.trim().toLowerCase();
  // Temporary test-only admin account.
  if (email == testAdminEmail) return true;
  // Allow specific trusted email.
  if (email == 'ace@aceafrica.org') return true;
  if (email.length > 254) return false;

  final emailRegex = RegExp(
    r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$",
  );
  if (!emailRegex.hasMatch(email)) return false;

  final parts = email.split('@');
  if (parts.length != 2) return false;

  final local = parts.first;
  final domain = parts.last;
  if (local.startsWith('.') || local.endsWith('.') || local.contains('..')) {
    return false;
  }
  if (domain.startsWith('.') || domain.endsWith('.') || domain.contains('..')) {
    return false;
  }

  final blockedDomains = {
    'example.com',
    'example.org',
    'example.net',
    'test.com',
    'mailinator.com',
    'tempmail.com',
    'temp-mail.org',
    '10minutemail.com',
    'guerrillamail.com',
    'yopmail.com',
    'fakeemail.com',
    'trashmail.com',
    'dispostable.com',
  };
  if (blockedDomains.contains(domain)) return false;

  final tld = domain.split('.').last;
  return tld.length >= 2 && RegExp(r'^[a-z]+$').hasMatch(tld);
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
