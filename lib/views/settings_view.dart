import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../controllers/water_controller.dart';
import '../models/user_profile.dart';
import '../services/cloud_backup_service.dart';
import '../services/notification_service.dart';
import '../services/profile_storage_service.dart';
import '../services/theme_service.dart';

class SettingsView extends StatefulWidget {
  final WaterController waterController;
  final UserProfile profile;
  final String? cloudUid;
  final VoidCallback onLogout;

  const SettingsView({
    super.key,
    required this.waterController,
    required this.profile,
    this.cloudUid,
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
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 22, minute: 0);
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
      if (widget.cloudUid != null) {
        await CloudBackupService().syncProfile(widget.cloudUid!, widget.profile);
      }

      final notificationService = NotificationService();
      try {
        if (_isNotificationEnabled) {
          if (!notificationService.supportsScheduledReminders) {
            _showMessage(
              'Profil dan target tersimpan. Alarm terjadwal belum didukung di browser; gunakan aplikasi Android.',
              isError: true,
            );
          } else {
            final granted = await notificationService.requestPermissions();
            await notificationService.scheduleWaterReminders(
              intervalHours: _intervalHours,
              startTime: _startTime,
              endTime: _endTime,
            );
            _showMessage(granted
                ? 'Profil, target, dan alarm berhasil disimpan.'
                : 'Profil tersimpan. Izinkan notifikasi melalui pengaturan Android.');
          }
        } else {
          await notificationService.cancelAllNotifications();
          _showMessage('Profil dan target tersimpan. Alarm dimatikan.');
        }
      } catch (alarmError) {
        _showMessage(
          'Profil dan target tersimpan, tetapi alarm gagal diatur: $alarmError',
          isError: true,
        );
      }

      _goalController.text = newGoal.toString();
    } catch (error) {
      _showMessage('Pengaturan gagal disimpan: $error', isError: true);
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
        title: Text('Ganti Profil?'),
        content: Text('Keluar dari profil ${widget.profile.name} dan kembali ke pilihan profil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: Icon(Icons.logout_rounded),
            label: Text('Keluar'),
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
        title: Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.lightBlue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Tampilan'),
            SizedBox(height: 12),
            _buildAppearanceCard(),
            SizedBox(height: 24),
            _buildSectionHeader('Profil Pengguna'),
            SizedBox(height: 12),
            _buildProfileCard(),
            SizedBox(height: 28),
            _buildSectionHeader('Pengingat Minum'),
            SizedBox(height: 12),
            _buildNotificationCard(),
            SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            SizedBox(height: 24),
            _buildSectionHeader('Akun di Perangkat Ini'),
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Keluar tidak menghapus profil atau riwayat minum. Kamu bisa memilih profil lain dari halaman awal.', style: TextStyle(color: AppColors.textMuted, height: 1.4)),
                  SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmLogout,
                      icon: Icon(Icons.logout_rounded),
                      label: Text('Keluar / Ganti Profil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
      );

  Widget _buildAppearanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(Icons.dark_mode_outlined, color: AppColors.primary),
        title: Text(
          'Dark Mode',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
        ),
        subtitle: Text(
          'Gunakan tampilan gelap di seluruh aplikasi',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        value: ThemeService.instance.isDarkMode,
        activeThumbColor: AppColors.primary,
        onChanged: (value) async {
          await ThemeService.instance.setDarkMode(value);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _buildProfileCard() {
    final initial = widget.profile.name.trim().isEmpty
        ? '?'
        : widget.profile.name.trim().substring(0, 1).toUpperCase();
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.lightBlue,
              child: Text(initial, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),
          SizedBox(height: 16),
          Text('Nama', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
          SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Masukkan nama kamu',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Berat Badan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
              Text('${_weightKg.toStringAsFixed(0)} kg', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
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
            title: Text('Hitung target dari berat badan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: Text('Estimasi awal: berat badan × 35 ml', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            value: _autoGoalFromWeight,
            activeThumbColor: AppColors.primary,
            onChanged: (value) => setState(() {
              _autoGoalFromWeight = value;
              if (value) _goalController.text = UserProfile.calculateGoal(_weightKg).toString();
            }),
          ),
          Divider(height: 24),
          Text('Target Harian', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
          SizedBox(height: 8),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Aktifkan Alarm', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: Text('Pengingat melalui notifikasi secara berkala', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            value: _isNotificationEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: (value) => setState(() => _isNotificationEnabled = value),
          ),
          if (_isNotificationEnabled) ...[
            Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Interval Pengingat', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                DropdownButton<int>(
                  value: _intervalHours,
                  underline: SizedBox(),
                  items: [
                    DropdownMenuItem(value: 1, child: Text('Setiap 1 Jam')),
                    DropdownMenuItem(value: 2, child: Text('Setiap 2 Jam')),
                    DropdownMenuItem(value: 3, child: Text('Setiap 3 Jam')),
                    DropdownMenuItem(value: 4, child: Text('Setiap 4 Jam')),
                  ],
                  onChanged: (value) { if (value != null) setState(() => _intervalHours = value); },
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(true),
                    icon: Icon(Icons.access_time, size: 18),
                    label: Text('Mulai: ${_startTime.format(context)}'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(false),
                    icon: Icon(Icons.access_time_filled, size: 18),
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
