import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../controllers/water_controller.dart';
import '../models/user_profile.dart';

class SettingsView extends StatefulWidget {
  final WaterController waterController;

  const SettingsView({
    super.key,
    required this.waterController,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _goalController;
  double _weightKg = 60.0;
  bool _isNotificationEnabled = true;
  int _intervalHours = 2;
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(
      text: widget.waterController.dailyGoalMl.toString(),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  // Memuat pengaturan notifikasi & profil dari SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _weightKg = prefs.getDouble('user_weight_kg') ?? 60.0;
      _isNotificationEnabled = prefs.getBool('notif_enabled') ?? true;
      _intervalHours = prefs.getInt('notif_interval') ?? 2;
      
      final startHour = prefs.getInt('notif_start_hour') ?? 7;
      final startMin = prefs.getInt('notif_start_min') ?? 0;
      _startTime = TimeOfDay(hour: startHour, minute: startMin);

      final endHour = prefs.getInt('notif_end_hour') ?? 21;
      final endMin = prefs.getInt('notif_end_min') ?? 0;
      _endTime = TimeOfDay(hour: endHour, minute: endMin);
    });
  }

  // Menyimpan perubahan pengaturan
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_weight_kg', _weightKg);
    await prefs.setBool('notif_enabled', _isNotificationEnabled);
    await prefs.setInt('notif_interval', _intervalHours);
    await prefs.setInt('notif_start_hour', _startTime.hour);
    await prefs.setInt('notif_start_min', _startTime.minute);
    await prefs.setInt('notif_end_hour', _endTime.hour);
    await prefs.setInt('notif_end_min', _endTime.minute);

    final newGoal = int.tryParse(_goalController.text) ?? widget.waterController.dailyGoalMl;
    await widget.waterController.updateDailyGoal(newGoal);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan berhasil disimpan!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Picker Waktu
  Future<void> _selectTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBlue,
      appBar: AppBar(
        title: const Text(
          'Pengaturan & Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Seksi Profil & Target Air
            _buildSectionHeader('Profil & Target Air'),
            const SizedBox(height: 12),
            _buildProfileCard(),

            const SizedBox(height: 28),

            // 2. Seksi Notifikasi Pengingat
            _buildSectionHeader('Pengingat Minum'),
            const SizedBox(height: 12),
            _buildNotificationCard(),

            const SizedBox(height: 36),

            // 3. Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_rounded, color: Colors.white),
                label: const Text(
                  'Simpan Perubahan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Slider BB
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Berat Badan',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              Text(
                '${_weightKg.toStringAsFixed(0)} kg',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Slider(
            value: _weightKg,
            min: 30,
            max: 150,
            divisions: 120,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.lightBlue,
            onChanged: (val) {
              setState(() {
                _weightKg = val;
                // Hitung ulang otomatis untuk saran di TextField Target
                final autoGoal = UserProfile.calculateGoal(val);
                _goalController.text = autoGoal.toString();
              });
            },
          ),
          const Divider(height: 24),

          // Input Manual Target Harian
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Target Harian (ml)',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _goalController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixText: 'ml',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Toggle Notifikasi
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Aktifkan Notifikasi',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
            subtitle: const Text(
              'Ingatkan saya untuk minum secara teratur',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            value: _isNotificationEnabled,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _isNotificationEnabled = val);
            },
          ),

          if (_isNotificationEnabled) ...[
            const Divider(height: 20),

            // Dropdown Interval
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Interval Pengingat',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                DropdownButton<int>(
                  value: _intervalHours,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Setiap 1 Jam')),
                    DropdownMenuItem(value: 2, child: Text('Setiap 2 Jam')),
                    DropdownMenuItem(value: 3, child: Text('Setiap 3 Jam')),
                    DropdownMenuItem(value: 4, child: Text('Setiap 4 Jam')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _intervalHours = val);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Jadwal Jam Mulai & Selesai
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(true),
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text('Mulai: ${_startTime.format(context)}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(false),
                    icon: const Icon(Icons.access_time_filled, size: 18),
                    label: Text('Selesai: ${_endTime.format(context)}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}