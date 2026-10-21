import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/profile_storage_service.dart';
import 'create_profile_view.dart';
import 'main_navigation_wrapper.dart';

class AccountSelectionView extends StatefulWidget {
  const AccountSelectionView({super.key});

  @override
  State<AccountSelectionView> createState() => _AccountSelectionViewState();
}

class _AccountSelectionViewState extends State<AccountSelectionView> {
  final ProfileStorageService _profileStorage = ProfileStorageService();
  List<UserProfile> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _profileStorage.loadProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _isLoading = false;
    });
  }

  void _openProfile(UserProfile profile) {
    final navigator = Navigator.of(context);
    navigator.pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => MainNavigationWrapper(
          profile: profile,
          onLogout: () {
            navigator.pushAndRemoveUntil<void>(
              MaterialPageRoute<void>(
                builder: (_) => const AccountSelectionView(),
              ),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _createProfile() async {
    final profile = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute<UserProfile>(
        builder: (_) => const CreateProfileView(),
      ),
    );
    if (!mounted || profile == null) return;

    await _loadProfiles();
    if (mounted) _openProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBlue,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.water_drop_rounded,
                            color: AppColors.primary,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'HydroTracker',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Siapa yang akan menggunakan aplikasi hari ini?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                      ),
                      const SizedBox(height: 30),
                      if (_profiles.isNotEmpty) ...[
                        const Text(
                          'Pilih Profil',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._profiles.map(_buildProfileTile),
                        const SizedBox(height: 10),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.person_add_alt_1, size: 36, color: AppColors.primary),
                              SizedBox(height: 10),
                              Text(
                                'Belum ada profil',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Buat profil dengan nama dan berat badan untuk mulai mencatat minum.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _createProfile,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Buat Profil Baru'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Profil disimpan di perangkat ini. Fitur ini belum menggunakan akun online atau kata sandi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileTile(UserProfile profile) {
    final initial = profile.name.trim().isEmpty
        ? '?'
        : profile.name.trim().substring(0, 1).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.lightBlue,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        title: Text(profile.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        subtitle: Text('${profile.weightKg.toStringAsFixed(0)} kg  •  Target ${profile.dailyGoalMl} ml'),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        onTap: () => _openProfile(profile),
      ),
    );
  }
}
