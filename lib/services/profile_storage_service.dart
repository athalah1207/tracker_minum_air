import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Menyimpan cache profil di perangkat agar aplikasi tetap bisa dipakai offline.
class ProfileStorageService {
  static const String _profilesKey = 'hydrotracker_profiles_v1';

  Future<List<UserProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(UserProfile.fromJson)
            .toList();
      } catch (_) {
        // Jika arsip profil rusak, jangan hentikan aplikasi; coba migrasi data lama.
      }
    }

    // Migrasikan profil tunggal dari versi aplikasi sebelumnya jika tersedia.
    final oldName = (prefs.getString('user_name') ?? '').trim();
    final oldWeight = prefs.getDouble('user_weight_kg');
    if (oldName.isNotEmpty || oldWeight != null) {
      final weight = (oldWeight ?? 60.0).clamp(30.0, 150.0).toDouble();
      final profile = UserProfile(
        id: 'legacy_${DateTime.now().microsecondsSinceEpoch}',
        name: oldName.isEmpty ? 'Profil Lama' : oldName,
        weightKg: weight,
        dailyGoalMl: prefs.getInt('daily_goal_ml') ?? UserProfile.calculateGoal(weight),
      );
      await saveProfile(profile);
      return [profile];
    }

    return [];
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await _readStoredProfiles(prefs);
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((item) => item.toJson()).toList()),
    );
  }

  /// Mengganti daftar profil lokal dengan profil yang dipulihkan dari cloud.
  Future<void> replaceProfiles(List<UserProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<UserProfile>> _readStoredProfiles(SharedPreferences prefs) async {
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(UserProfile.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
