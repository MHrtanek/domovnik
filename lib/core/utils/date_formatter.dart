import 'package:intl/intl.dart';

abstract class DateFormatter {
  static final _dateFormat = DateFormat('d. M. yyyy', 'sk');
  static final _dateTimeFormat = DateFormat('d. M. yyyy HH:mm', 'sk');
  static final _timeFormat = DateFormat('HH:mm', 'sk');

  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime.toLocal());
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime.toLocal());
  }

  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime.toLocal());
  }

  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime.toLocal());

    if (diff.inMinutes < 1) return 'Práve teraz';
    if (diff.inMinutes < 60) return 'Pred ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Pred ${diff.inHours} hod';
    if (diff.inDays < 7) return 'Pred ${diff.inDays} dňami';
    return _dateFormat.format(dateTime.toLocal());
  }

  static String formatExpiry(DateTime? expiresAt) {
    if (expiresAt == null) return 'Bez obmedzenia';
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return 'Skončené';
    final daysLeft = expiresAt.difference(now).inDays;
    if (daysLeft == 0) return 'Končí dnes';
    if (daysLeft == 1) return 'Zostáva 1 deň';
    if (daysLeft < 5) return 'Zostávajú $daysLeft dni';
    return 'Zostáva $daysLeft dní';
  }
}
