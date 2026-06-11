/// Maps a raw authentication error string (as thrown by Supabase / GoTrue)
/// to a user-facing Slovak message.
///
/// Pure function with no dependencies so it can be unit-tested in isolation
/// (see test/auth/auth_error_mapper_test.dart).
String mapAuthError(String error) {
  if (error.contains('invalid_credentials') ||
      error.contains('Invalid login credentials')) {
    return 'Nesprávny email alebo heslo.';
  }
  if (error.contains('email_not_confirmed') ||
      error.contains('Email not confirmed')) {
    return 'Email nebol potvrdený. Skontrolujte svoju schránku.';
  }
  if (error.contains('too_many_requests') ||
      error.contains('Too many requests')) {
    return 'Príliš veľa pokusov. Skúste neskôr.';
  }
  return 'Prihlásenie zlyhalo. Skúste to znova.';
}
