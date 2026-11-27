import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/cloud_auth_service.dart';
import '../services/cloud_backup_service.dart';
import '../services/profile_storage_service.dart';
import 'create_profile_view.dart';
import 'main_navigation_wrapper.dart';

class AccountSelectionView extends StatefulWidget {
  final bool restoreFromCloud;

  const AccountSelectionView({
    super.key,
    this.restoreFromCloud = true,
  });

  @override
  State<AccountSelectionView> createState() => _AccountSelectionViewState();
}

class _AccountSelectionViewState extends State<AccountSelectionView> {
  final ProfileStorageService _profileStorage = ProfileStorageService();
  final CloudAuthService _authService = CloudAuthService();
  final CloudBackupService _backupService = CloudBackupService();

  List<UserProfile> _profiles = [];
  bool _isLoading = true;
  bool _isSigningIn = false;
  bool _isSigningOut = false;

  static const String _cloudOwnerKey = 'hydrotracker_cloud_owner_uid';

  User? get _signedInUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfiles(syncCloud: widget.restoreFromCloud);
  }

  /// Saat akun sudah pernah login, ambil profil dari cloud.
  /// Jika akun baru belum punya profil cloud, profil lokal pertama kali
  /// diunggah agar data lama pengguna tidak hilang.
  Future<void> _loadProfiles({
    bool syncCloud = false,
    bool reportCloudError = false,
  }) async {
    if (mounted) setState(() => _isLoading = true);
    Object? cloudError;

    final user = _signedInUser;
    if (user != null && syncCloud) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final previousOwner = prefs.getString(_cloudOwnerKey);
        final accountChanged =
            previousOwner != null && previousOwner != user.uid;

        // Jangan pernah mengunggah cache akun Google sebelumnya ke akun baru.
        if (accountChanged) {
          await _profileStorage.replaceProfiles(<UserProfile>[]);
        }

        final restored = await _backupService.restoreProfiles(user.uid);
        if (!restored && !accountChanged) {
          final localProfiles = await _profileStorage.loadProfiles();
          for (final profile in localProfiles) {
            await _backupService.syncProfile(user.uid, profile);
          }
        }
        await prefs.setString(_cloudOwnerKey, user.uid);
      } catch (error) {
        cloudError = error;
      }
    }

    final profiles = await _profileStorage.loadProfiles();
    if (!mounted) return;

    setState(() {
      _profiles = profiles;
      _isLoading = false;
    });

    if (reportCloudError && cloudError != null) {
      throw Exception('Login berhasil, tetapi backup cloud gagal: $cloudError');
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      await _authService.signInWithGoogle();
      await _loadProfiles(syncCloud: true, reportCloudError: true);
      if (!mounted) return;
      _showMessage('Login Google berhasil. Akun sudah terhubung ke Firebase.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Login gagal: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signOutGoogle() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);

    try {
      await _authService.signOut();
      await _loadProfiles();
      if (!mounted) return;
      _showMessage('Akun Google sudah dikeluarkan. Profil lokal tetap tersimpan.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal keluar dari akun: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.primary,
      ),
    );
  }

  void _openProfile(UserProfile profile) {
    final navigator = Navigator.of(context);
    final cloudUid = _signedInUser?.uid;

    navigator.pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => MainNavigationWrapper(
          profile: profile,
          cloudUid: cloudUid,
          onLogout: () {
            navigator.pushAndRemoveUntil<void>(
              MaterialPageRoute<void>(
                builder: (_) => const AccountSelectionView(restoreFromCloud: false),
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

    final user = _signedInUser;
    if (user != null) {
      try {
        await _backupService.syncProfile(user.uid, profile);
      } catch (error) {
        _showMessage('Profil tersimpan di HP, tetapi backup cloud gagal: $error', isError: true);
      }
    }

    await _loadProfiles();
    if (mounted) _openProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    final user = _signedInUser;

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
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
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
                      Text(
                        'HydroTracker',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Siapa yang akan menggunakan aplikasi hari ini?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                      ),
                      const SizedBox(height: 22),
                      if (user == null)
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isSigningIn ? null : _signInWithGoogle,
                            icon: _isSigningIn
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              _isSigningIn ? 'Menghubungkan akun...' : 'Masuk dengan Google',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_done_rounded, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Akun Google terhubung',
                                      style: TextStyle(
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      user.email ?? user.displayName ?? 'Akun aktif',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _isSigningOut ? null : _signOutGoogle,
                                child: _isSigningOut
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Keluar'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 26),
                      if (_profiles.isNotEmpty) ...[
                        Text(
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
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
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
                      Text(
                        user == null
                            ? 'Masuk dengan Google untuk mencadangkan profil dan riwayat minum ke cloud. Kamu tetap bisa memakai profil lokal tanpa login.'
                            : 'Profil dan riwayat minum dicadangkan ke akun Google ini saat data berubah.',
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
        color: AppColors.cardBg,
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
        title: Text(profile.name, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        subtitle: Text('${profile.weightKg.toStringAsFixed(0)} kg  •  Target ${profile.dailyGoalMl} ml'),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        onTap: () => _openProfile(profile),
      ),
    );
  }
}
