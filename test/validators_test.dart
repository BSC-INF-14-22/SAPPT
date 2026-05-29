import 'package:flutter_test/flutter_test.dart';
import 'package:smart_agri_price_tracker/features/auth/domain/validators.dart';

void main() {
  group('Email validator', () {
    test('accepts ace@aceafrica.org', () {
      expect(isValidEmail('ace@aceafrica.org'), isTrue);
    });

    test('rejects invalid email', () {
      expect(isValidEmail('not-an-email'), isFalse);
    });

    test('accepts normal valid email', () {
      expect(isValidEmail('user@example.com'), isTrue);
    });
  });

  group('Password validator', () {
    test('rejects short password', () {
      expect(validatePassword('Ab1!'), isNotNull);
    });

    test('rejects missing uppercase', () {
      expect(validatePassword('abcd1234!'), contains('uppercase'));
    });

    test('accepts strong password', () {
      expect(validatePassword('Abcd1234!'), isNull);
    });
  });
}
