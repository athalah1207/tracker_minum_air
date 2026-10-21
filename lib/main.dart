import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'services/notification_service.dart';
import 'views/account_selection_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const HydroTrackerApp());
}

class HydroTrackerApp extends StatelessWidget {
  const HydroTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.lightBlue,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightBlue,
          foregroundColor: AppColors.textDark,
          elevation: 0,
        ),
      ),
      home: const AccountSelectionView(),
    );
  }
}
