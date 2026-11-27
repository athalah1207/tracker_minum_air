import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import 'main_navigation_wrapper.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController(text: '60');
  double _weightKg = 60.0;
  int _calculatedGoalMl = 2100;
  bool _isSaving = false;
  List<String> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _recalculateGoal(_weightKg);
    _loadSavedAccounts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // Memuat daftar akun yang pernah dibuat di HP ini
  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedAccounts = prefs.getStringList('saved_accounts') ?? [];
    });
  }

  // Hitung ulang target air berdasarkan BB (BB * 35 ml)
  void _recalculateGoal(double weight) {
    setState(() {
      _weightKg = weight;
      _calculatedGoalMl = UserProfile.calculateGoal(weight);
    });
  }

  // Pilih akun lama yang sudah tersimpan
  Future<void> _selectExistingAccount(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    // Set flag onboarding selesai
    await prefs.setInt('daily_goal_ml', _calculatedGoalMl);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainNavigationWrapper(
          profile: UserProfile(
            id: name,
            name: name,
            weightKg: prefs.getDouble('user_weight_kg') ?? _weightKg,
            dailyGoalMl: _calculatedGoalMl,
          ),
          onLogout: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => OnboardingView()),
          ),
        ),
      ),
    );
  }

  // Simpan profil baru dan masuk ke aplikasi
  Future<void> _submitOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silakan isi nama kamu terlebih dahulu!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setDouble('user_weight_kg', _weightKg);
    await prefs.setInt('daily_goal_ml', _calculatedGoalMl);

    // Simpan ke daftar riwayat akun lokal
    List<String> accounts = prefs.getStringList('saved_accounts') ?? [];
    if (!accounts.contains(name)) {
      accounts.add(name);
      await prefs.setStringList('saved_accounts', accounts);
    }

    if (!mounted) return;

    // Masuk ke Navigasi Utama (Home, Stats, Settings)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainNavigationWrapper(
          profile: UserProfile(
            id: name,
            name: name,
            weightKg: _weightKg,
            dailyGoalMl: _calculatedGoalMl,
          ),
          onLogout: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => OnboardingView()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 10),

              // 1. Hero Icon / Ilustrasi
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),

              SizedBox(height: 24),

              // 2. Judul & Subjudul
              Text(
                'Selamat Datang di HydroTracker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Buat profil baru atau pilih akun tersimpan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),

              SizedBox(height: 24),

              // 3. Opsi Pilih Akun Tersimpan (Jika Ada)
              if (_savedAccounts.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilih Akun Tersimpan:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _savedAccounts.length,
                    itemBuilder: (context, index) {
                      final name = _savedAccounts[index];
                      return Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          avatar: Icon(Icons.person, size: 18, color: AppColors.primary),
                          label: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.cardBg,
                          side: BorderSide(color: AppColors.primary),
                          onPressed: () => _selectExistingAccount(name),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('atau Buat Baru', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                SizedBox(height: 20),
              ],

              // 4. Form Input Nama
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama kamu...',
                    border: InputBorder.none,
                    icon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // 5. Card Input Berat Badan
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Berat Badan Saat Ini',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _weightKg.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'kg',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.lightBlue,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.12),
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
                      ),
                      child: Slider(
                        value: _weightKg,
                        min: 30.0,
                        max: 150.0,
                        divisions: 120,
                        onChanged: (value) => _recalculateGoal(value),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // 6. Card Hasil Kalkulasi Target Air Harian
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_drink_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekomendasi Target Harian',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '$_calculatedGoalMl ml / hari',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // 7. Tombol Mulai
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Mulai Lacak Minum',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}