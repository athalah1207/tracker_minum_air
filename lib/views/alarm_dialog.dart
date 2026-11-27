import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../services/notification_service.dart';

class AlarmDialog extends StatefulWidget {
  const AlarmDialog({super.key});

  @override
  State<AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<AlarmDialog> {
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 22, minute: 0);
  int _intervalHours = 2;
  bool _isAlarmActive = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAlarmSettings();
  }

  Future<void> _loadAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _isAlarmActive = prefs.getBool('alarm_active') ?? false;
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
    });
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

  Future<void> _saveAlarm() async {
    if (_isSaving) return;

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (_isAlarmActive && endMinutes <= startMinutes) {
      _showMessage('Jam selesai harus setelah jam mulai.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_active', _isAlarmActive);
      await prefs.setInt('alarm_interval', _intervalHours);
      await prefs.setInt('alarm_start_hour', _startTime.hour);
      await prefs.setInt('alarm_start_min', _startTime.minute);
      await prefs.setInt('alarm_end_hour', _endTime.hour);
      await prefs.setInt('alarm_end_min', _endTime.minute);

      final service = NotificationService();
      var notificationsGranted = true;
      if (_isAlarmActive) {
        if (service.supportsScheduledReminders) {
          notificationsGranted = await service.requestPermissions();
          await service.scheduleWaterReminders(
            intervalHours: _intervalHours,
            startTime: _startTime,
            endTime: _endTime,
          );
        } else {
          notificationsGranted = false;
        }
      } else {
        await service.cancelAllNotifications();
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(!_isAlarmActive
              ? 'Alarm dimatikan.'
              : !service.supportsScheduledReminders
                  ? 'Pengaturan tersimpan, tetapi alarm terjadwal belum didukung di browser. Gunakan aplikasi Android.'
                  : notificationsGranted
                      ? 'Alarm aktif. Pengingat dijadwalkan setiap $_intervalHours jam.'
                      : 'Jadwal tersimpan, tetapi izin notifikasi Android belum diberikan.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      _showMessage('Alarm gagal disimpan: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.cardBg,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.alarm_add_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Atur Alarm Minum Air',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Aktifkan Alarm',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                value: _isAlarmActive,
                activeThumbColor: AppColors.primary,
                onChanged: (value) => setState(() => _isAlarmActive = value),
              ),
              if (_isAlarmActive) ...[
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.access_time_filled, color: AppColors.primary),
                  title: Text('Mulai Jam', style: TextStyle(color: AppColors.textDark)),
                  trailing: TextButton(
                    onPressed: () => _selectTime(true),
                    child: Text(
                      _startTime.format(context),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.timer_off_outlined, color: AppColors.primary),
                  title: Text('Selesai Jam', style: TextStyle(color: AppColors.textDark)),
                  trailing: TextButton(
                    onPressed: () => _selectTime(false),
                    child: Text(
                      _endTime.format(context),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_rounded, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Interval', style: TextStyle(color: AppColors.textDark)),
                      ],
                    ),
                    DropdownButton<int>(
                      value: _intervalHours,
                      underline: SizedBox(),
                      items: [
                        DropdownMenuItem(value: 1, child: Text('Setiap 1 Jam')),
                        DropdownMenuItem(value: 2, child: Text('Setiap 2 Jam')),
                        DropdownMenuItem(value: 3, child: Text('Setiap 3 Jam')),
                        DropdownMenuItem(value: 4, child: Text('Setiap 4 Jam')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _intervalHours = value);
                      },
                    ),
                  ],
                ),
              ],
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan Alarm',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
