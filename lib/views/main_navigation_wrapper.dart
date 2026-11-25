import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../controllers/water_controller.dart';
import '../models/user_profile.dart';
import 'home_view.dart';
import 'settings_view.dart';
import 'stats_view.dart';

class MainNavigationWrapper extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onLogout;

  const MainNavigationWrapper({
    super.key,
    required this.profile,
    required this.onLogout,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  int _settingsPageVersion = 0;
  late final WaterController _waterController;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _waterController = WaterController(
      profileId: widget.profile.id,
      initialGoalMl: widget.profile.dailyGoalMl,
    );
    _pages = [
      HomeView(controller: _waterController),
      StatsView(waterController: _waterController),
      _createSettingsPage(),
    ];
  }

  Widget _createSettingsPage() => SettingsView(
        key: ValueKey(_settingsPageVersion),
        profile: widget.profile,
        waterController: _waterController,
        onLogout: widget.onLogout,
      );

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          height: 74,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
              if (index == 2) {
                _settingsPageVersion++;
                _pages[2] = _createSettingsPage();
              }
            });
          },
          backgroundColor: AppColors.cardBg,
          indicatorColor: AppColors.softBlue,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.water_drop_outlined),
              selectedIcon: Icon(Icons.water_drop_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Statistik',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
