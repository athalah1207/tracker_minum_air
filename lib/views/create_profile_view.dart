import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/profile_storage_service.dart';

class CreateProfileView extends StatefulWidget {
  const CreateProfileView({super.key});

  @override
  State<CreateProfileView> createState() => _CreateProfileViewState();
}

class _CreateProfileViewState extends State<CreateProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  double _weightKg = 60;
  bool _isSaving = false;

  int get _goalMl => UserProfile.calculateGoal(_weightKg);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);

    final profile = UserProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      weightKg: _weightKg,
      dailyGoalMl: _goalMl,
    );

    try {
      await ProfileStorageService().saveProfile(profile);
      // Simpan target awal pada ruang data profil ini sebelum controller dimuat.
      // Ini mencegah target lama dari instalasi sebelumnya menimpa target profil baru.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'hydrotracker_profile_${profile.id}_daily_goal_ml',
        profile.dailyGoalMl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil gagal disimpan: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBlue,
      appBar: AppBar(
        backgroundColor: AppColors.lightBlue,
        title: const Text('Buat Profil Baru', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.lightBlue,
                        child: Icon(Icons.person_add_alt_1_rounded, size: 38, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('Nama pengguna', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Athalah',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Nama harus diisi.';
                        if (value.trim().length > 40) return 'Nama maksimal 40 karakter.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Berat badan', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_weightKg.toStringAsFixed(0)} kg', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17)),
                      ],
                    ),
                    Slider(
                      value: _weightKg,
                      min: 30,
                      max: 150,
                      divisions: 120,
                      label: '${_weightKg.toStringAsFixed(0)} kg',
                      activeColor: AppColors.primary,
                      onChanged: (value) => setState(() => _weightKg = value),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Perkiraan target minum harian', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('$_goalMl ml / hari', style: const TextStyle(color: AppColors.textDark, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Estimasi awal: berat badan × 35 ml. Target dapat diubah nanti melalui Pengaturan.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan dan Mulai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
