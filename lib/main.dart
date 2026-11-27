import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'constants/app_colors.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'views/account_selection_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService().init();
  await ThemeService.instance.load();
  runApp(const HydroTrackerApp());
}

class HydroTrackerApp extends StatelessWidget {
  const HydroTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'HydroTracker',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(dark: false),
          darkTheme: _buildTheme(dark: true),
          themeMode: ThemeService.instance.themeMode,
          home: const AccountSelectionView(),
        );
      },
    );
  }

  ThemeData _buildTheme({required bool dark}) {
    final scaffold = dark
        ? const Color(0xFF101E29)
        : const Color(0xFFE1F5FD);
    final surface = dark
        ? const Color(0xFF192D3A)
        : const Color(0xFFFFFFFF);
    final text = dark
        ? const Color(0xFFE7F2F7)
        : const Color(0xFF123244);
    final muted = dark
        ? const Color(0xFFA8C0CC)
        : const Color(0xFF587789);
    final border = dark
        ? const Color(0xFF315263)
        : const Color(0xFFC5E7F4);
    final soft = dark
        ? const Color(0xFF203A49)
        : const Color(0xFFCCEFFB);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.aqua,
      onSecondary: dark ? Colors.white : const Color(0xFF075B82),
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? const Color(0xFF6CC8EA) : AppColors.primary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? const Color(0xFF6CC8EA) : AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
        ),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark
            ? const Color(0xFF25485B)
            : const Color(0xFF075B82),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: soft,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: soft,
        thumbColor: AppColors.primary,
        overlayColor: const Color(0x22087FB4),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      listTileTheme: ListTileThemeData(
        textColor: text,
        iconColor: dark ? const Color(0xFF6CC8EA) : AppColors.primary,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: soft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
