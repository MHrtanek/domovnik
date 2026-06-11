import 'package:flutter_test/flutter_test.dart';
import 'package:domovnik/features/auth/presentation/utils/auth_error_mapper.dart';

void main() {
  group('mapAuthError', () {
    test('maps the invalid_credentials error code', () {
      expect(
        mapAuthError('AuthApiException(message: invalid_credentials)'),
        'Nesprávny email alebo heslo.',
      );
    });

    test('maps the "Invalid login credentials" message', () {
      expect(
        mapAuthError('Invalid login credentials'),
        'Nesprávny email alebo heslo.',
      );
    });

    test('maps the email_not_confirmed code', () {
      expect(
        mapAuthError('email_not_confirmed'),
        'Email nebol potvrdený. Skontrolujte svoju schránku.',
      );
    });

    test('maps the "Email not confirmed" message', () {
      expect(
        mapAuthError('Email not confirmed'),
        'Email nebol potvrdený. Skontrolujte svoju schránku.',
      );
    });

    test('maps the too_many_requests code', () {
      expect(
        mapAuthError('too_many_requests'),
        'Príliš veľa pokusov. Skúste neskôr.',
      );
    });

    test('falls back to a generic message for unknown errors', () {
      expect(
        mapAuthError('SocketException: failed host lookup'),
        'Prihlásenie zlyhalo. Skúste to znova.',
      );
    });
  });
}
