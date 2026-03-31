import 'package:flutter/material.dart';

abstract class AppColors {
  // Primary – Slovak blue
  static const Color primary = Color(0xFF1A3C6E);
  static const Color primaryLight = Color(0xFF2E5FA3);
  static const Color primaryDark = Color(0xFF0D2244);

  // Secondary – green
  static const Color secondary = Color(0xFF2E7D32);
  static const Color secondaryLight = Color(0xFF4CAF50);
  static const Color secondaryDark = Color(0xFF1B5E20);

  // Accent – orange
  static const Color accent = Color(0xFFF57C00);
  static const Color accentLight = Color(0xFFFFB74D);
  static const Color accentDark = Color(0xFFE65100);

  // Status colors
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // Ticket status
  static const Color statusPrijate = Color(0xFF1565C0);   // blue
  static const Color statusVRieseni = Color(0xFFF57C00);  // orange
  static const Color statusUkoncene = Color(0xFF2E7D32);  // green

  // Neutrals
  static const Color surface = Color(0xFFF5F7FA);
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFFBDBDBD);

  // Urgent announcement
  static const Color urgentBackground = Color(0xFFFFF3E0);
  static const Color urgentBorder = Color(0xFFF57C00);
}
