import 'package:flutter/material.dart';

/// Palet warna HydroTracker: biru air yang cerah, bersih, dan tetap nyaman
/// dilihat dalam penggunaan sehari-hari.
class AppColors {
  // Biru air utama. Cukup pekat agar teks putih pada tombol tetap terbaca.
  static const Color primary = Color(0xFF087FB4);

  // Biru lebih dalam untuk judul/aksen yang membutuhkan kontras tambahan.
  static const Color primaryDark = Color(0xFF075B82);

  // Cyan cerah untuk indikator hidrasi, ikon, dan progres.
  static const Color accent = Color(0xFF25BDE5);
  static const Color aqua = Color(0xFF18B8C8);

  // Latar biru air yang lebih terasa dibanding warna ice-blue sebelumnya.
  static const Color lightBlue = Color(0xFFE1F5FD);
  static const Color softBlue = Color(0xFFCCEFFB);
  static const Color borderBlue = Color(0xFFC5E7F4);

  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF123244);
  static const Color textMuted = Color(0xFF587789);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF087FB4), Color(0xFF25BDE5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
