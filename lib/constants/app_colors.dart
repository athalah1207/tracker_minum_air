import 'package:flutter/material.dart';

/// Palet warna HydroTracker.
/// Warna netral berubah mengikuti pilihan Light Mode / Dark Mode.
class AppColors {
  static bool isDarkMode = false;

  // Warna aksen utama tetap sama pada kedua tema.
  static const Color primary = Color(0xFF087FB4);
  static const Color accent = Color(0xFF25BDE5);
  static const Color aqua = Color(0xFF18B8C8);

  static Color get primaryDark => isDarkMode
      ? const Color(0xFF6CC8EA)
      : const Color(0xFF075B82);

  static Color get lightBlue => isDarkMode
      ? const Color(0xFF101E29)
      : const Color(0xFFE1F5FD);

  static Color get softBlue => isDarkMode
      ? const Color(0xFF203A49)
      : const Color(0xFFCCEFFB);

  static Color get borderBlue => isDarkMode
      ? const Color(0xFF315263)
      : const Color(0xFFC5E7F4);

  static Color get cardBg => isDarkMode
      ? const Color(0xFF192D3A)
      : const Color(0xFFFFFFFF);

  static Color get textDark => isDarkMode
      ? const Color(0xFFE7F2F7)
      : const Color(0xFF123244);

  static Color get textMuted => isDarkMode
      ? const Color(0xFFA8C0CC)
      : const Color(0xFF587789);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF087FB4), Color(0xFF25BDE5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
