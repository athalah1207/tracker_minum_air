import 'package:flutter/material.dart';

class AppColors {
  // Biru Elektrik Utama (Sangat tajam dan hidup)
  static const Color primary = Color(0xFF0066FF);
  
  // Biru Gelap untuk Teks/Header penting
  static const Color primaryDark = Color(0xFF003CB3);
  
  // Cyan Terang (Aksen segar untuk target/ikon)
  static const Color accent = Color(0xFF00E5FF);
  
  // Background Ice Blue yang cerah dan bersih (tidak pudar)
  static const Color lightBlue = Color(0xFFF0F5FF);
  
  // Warna Card Putih Bersih (Kontras maksimal dengan background)
  static const Color cardBg = Color(0xFFFFFFFF);
  
  // Teks Utama (Gelap pekat agar mudah dibaca)
  static const Color textDark = Color(0xFF090D16);
  
  // Teks Sekunder / Muted
  static const Color textMuted = Color(0xFF64748B);

  // Gradien Utama untuk Tombol / Header (Biar keliatan mahal & segar)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0066FF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}