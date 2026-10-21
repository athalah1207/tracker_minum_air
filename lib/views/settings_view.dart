import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../controllers/water_controller.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/profile_storage_service.dart';

class SettingsView extends StatefulWidget {
  final WaterController waterController;
  final UserProfile profile;
  final VoidCallback onLogout;

  const SettingsView({
    super.key,
    required this.waterController,
    required this.profile,
    required this.onLogout,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _nameController;
  late final TextEditingController _goalController;
  double _weightKg = 60.0;
  bool _autoGoalFromWeight = false;
  bool _isNotificationEnabled = false;
  int _intervalHours = 2;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  bool _isSaving = false;

  String get _autoGoalKey => 'profile_${widget.profile.id}_auto_goal_from_weight';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _weightKg = widget.profile.weightKg.clamp(30.0, 150.0).toDouble();
    _goalController = TextEditingController(
      text: widget.waterController.dailyGoalMl.toString(),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _nameController.text = widget.profile.name;
      _weightKg = widget.profile.weightKg.clamp(30.0, 150.0).toDouble();
      _autoGoalFromWeight = prefs.getBool(_autoGoalKey) ?? false;
      _isNotificationEnabled = prefs.getBool('alarm_active') ?? false;
      _intervalHours = prefs.getInt('alarm_interval') ?? 2;
      if (![1, 2, 3, 4].contains(_intervalHours)) _intervalHours = 2;
      _startTime = TimeOfDay(
        hour: prefs.getInt('alarm_start_hour') ?? 8,
        minute: prefs.getInt('alarm_start_min') ?? 0,
      );
      _endTime = TimeOfDay(
        hour: prefs.getInt('alarm_end_hour') ?? 22,
        minute: prefs.getInt('alarm_end_min') ?? 0,
      );
      _goalController.text = _autoGoalFromWeight
          ? UserProfile.calculateGoal(_weightKg).toString()
          : widget.waterController.dailyGoalMl.toString();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Nama pengguna harus diisi.', isError: true);
      return;
    }

    final parsedGoal = int.tryParse(_goalController.text.trim());
    final newGoal = _autoGoalFromWeight
        ? UserProfile.calculateGoal(_weightKg)
        : parsedGoal;
    if (newGoal == null || newGoal <= 0 || newGoal > 100000) {
      _showMessage('Masukkan target minum yang valid dalam ml.', isError: true);
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (_isNotificationEnabled && endMinutes <= startMinutes) {
      _showMessage('Jam selesai harus setelah jam mulai.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      widget.profile
        ..name = name
        ..weightKg = _weightKg
        ..dailyGoalMl = newGoal;

      await ProfileStorageService().saveProfile(widget.profile);
      await prefs.setBool(_autoGoalKey, _autoGoalFromWeight);
      // Pengingat menggunakan notifikasi lokal perangkat, sehingga tidak perlu database online.
      await prefs.setBool('alarm_active', _isNotificationEnabled);
      await prefs.setInt('alarm_interval', _intervalHours);
      await prefs.setInt('alarm_start_hour', _startTime.hour);
      await prefs.setInt('alarm_start_min', _startTime.minute);
      await prefs.setInt('alarm_end_hour', _endTime.hour);
      await prefs.setInt('alarm_end_min', _endTime.minute);
      await widget.waterController.updateDailyGoal(newGoal);

      final notificationService = NotificationService();
      if (_isNotificationEnabled) {
        final granted = await notificationService.requestPermissions();
        await notificationService.scheduleWaterReminders(
          intervalHours: _intervalHours,
          startTime: _startTime,
          endTime: _endTime,
        );
        _showMessage(granted
            ? 'Profil, target, dan alarm berhasil disimpan.'
            : 'Profil tersimpan. Izinkan notifikasi melalui pengaturan Android.');
      } else {
        await notificationService.cancelAllNotifications();
        _showMessage('Profil dan target tersimpan. Alarm dimatikan.');
      }
      _goalController.text = newGoal.toString();
    } catch (error) {
      _showMessage('Pengaturan tersimpan sebagian. Periksa alarm: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ganti Profil?'),
        content: Text('Keluar dari profil ${widget.profile.name} dan kembali ke pilihan profil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (shouldLogout == true && mounted) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBlue,
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.lightBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Profil Pengguna'),
            const SizedBox(height: 12),
            _buildProfileCard(),
            const SizedBox(height: 28),
            _buildSectionHeader('Pengingat Minum'),
            const SizedBox(height: 12),
            _buildNotificationCard(),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Akun di Perangkat Ini'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Keluar tidak menghapus profil atau riwayat minum. Kamu bisa memilih profil lain dari halaman awal.', style: TextStyle(color: AppColors.textMuted, height: 1.4)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Keluar / Ganti Profil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
      );

  Widget _buildProfileCard() {
    final initial = widget.profile.name.trim().isEmpty
        ? '?'
        : widget.profile.name.trim().substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.lightBlue,
              child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Nama', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Masukkan nama kamu',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Berat Badan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
              Text('${_weightKg.toStringAsFixed(0)} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
            ],
          ),
          Slider(
            value: _weightKg,
            min: 30,
            max: 150,
            divisions: 120,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.lightBlue,
            onChanged: (value) => setState(() {
              _weightKg = value;
              if (_autoGoalFromWeight) _goalController.text = UserProfile.calculateGoal(value).toString();
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hitung target dari berat badan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: const Text('Estimasi awal: berat badan × 35 ml', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            value: _autoGoalFromWeight,
            activeThumbColor: AppColors.primary,
            onChanged: (value) => setState(() {
              _autoGoalFromWeight = value;
              if (value) _goalController.text = UserProfile.calculateGoal(_weightKg).toString();
            }),
          ),
          const Divider(height: 24),
          const Text('Target Harian', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextField(
            controller: _goalController,
            enabled: !_autoGoalFromWeight,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixText: 'ml',
              helperText: _autoGoalFromWeight ? 'Dihitung otomatis dari berat badan.' : 'Masukkan target harian dalam mililiter.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktifkan Alarm', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: const Text('Pengingat melalui notifikasi secara berkala', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            value: _isNotificationEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: (value) => setState(() => _isNotificationEnabled = value),
          ),
          if (_isNotificationEnabled) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Interval Pengingat', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                DropdownButton<int>(
                  value: _intervalHours,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Setiap 1 Jam')),
                    DropdownMenuItem(value: 2, child: Text('Setiap 2 Jam')),
                    DropdownMenuItem(value: 3, child: Text('Setiap 3 Jam')),
                    DropdownMenuItem(value: 4, child: Text('Setiap 4 Jam')),
                  ],
                  onChanged: (value) { if (value != null) setState(() => _intervalHours = value); },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(true),
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text('Mulai: ${_startTime.format(context)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(false),
                    icon: const Icon(Icons.access_time_filled, size: 18),
                    label: Text('Selesai: ${_endTime.format(context)}'),
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
