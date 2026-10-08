import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/water_log.dart';

class WaterController extends ChangeNotifier {
  static const String _keyDailyGoal = 'daily_goal_ml';
  static const String _keyCurrentAmount = 'current_amount_ml';
  static const String _keyStreak = 'streak_days';
  static const String _keyLastDate = 'last_date';
  static const String _keyLogs = 'water_logs';

  int _dailyGoalMl = 2000;
  int _currentAmountMl = 0;
  int _streakDays = 0;
  List<WaterLog> _logs = [];
  bool _isLoading = true;

  int get dailyGoalMl => _dailyGoalMl;
  int get currentAmountMl => _currentAmountMl;
  int get streakDays => _streakDays;
  List<WaterLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;

  WaterController() {
    loadData();
  }

  // 1. Memuat data dari SharedPreferences
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    _dailyGoalMl = prefs.getInt(_keyDailyGoal) ?? 2000;
    _streakDays = prefs.getInt(_keyStreak) ?? 0;

    final String? lastDateStr = prefs.getString(_keyLastDate);
    final String todayStr = _formatDate(DateTime.now());

    // Cek apakah data ini milik hari ini atau hari sebelumnya
    if (lastDateStr == todayStr) {
      _currentAmountMl = prefs.getInt(_keyCurrentAmount) ?? 0;

      final List<String>? logsJson = prefs.getStringList(_keyLogs);
      if (logsJson != null) {
        _logs = logsJson.map((item) => WaterLog.fromJson(item)).toList();
      }
    } else {
      // Jika berganti hari, cek apakah target kemarin tercapai untuk kalkulasi streak
      if (lastDateStr != null) {
        final int previousAmount = prefs.getInt(_keyCurrentAmount) ?? 0;
        if (previousAmount >= _dailyGoalMl) {
          _streakDays += 1;
        } else {
          _streakDays = 0; // Streak terputus jika target tidak tercapai
        }
        await prefs.setInt(_keyStreak, _streakDays);
      }

      // Reset hitungan harian untuk hari yang baru
      _currentAmountMl = 0;
      _logs = [];
      await prefs.setString(_keyLastDate, todayStr);
      await prefs.setInt(_keyCurrentAmount, 0);
      await prefs.setStringList(_keyLogs, []);
    }

    _isLoading = false;
    notifyListeners();
  }

  // 2. Menambah air minum
  Future<void> addWater(int amountMl, {String drinkType = 'Air Putih'}) async {
    final newLog = WaterLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amountMl: amountMl,
      timestamp: DateTime.now(),
      drinkType: drinkType,
    );

    _currentAmountMl += amountMl;
    _logs.insert(0, newLog);

    notifyListeners();
    await _saveToPrefs();
  }

  // 3. Menghapus salah satu catatan minum (Undo/Delete)
  Future<void> deleteLog(String id) async {
    final index = _logs.indexWhere((log) => log.id == id);
    if (index != -1) {
      _currentAmountMl = (_currentAmountMl - _logs[index].amountMl).clamp(0, double.infinity).toInt();
      _logs.removeAt(index);

      notifyListeners();
      await _saveToPrefs();
    }
  }

  // 4. Mengubah target harian (misal dari halaman Settings atau Onboarding)
  Future<void> updateDailyGoal(int newGoalMl) async {
    _dailyGoalMl = newGoalMl;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyGoal, newGoalMl);
  }

  // Helper untuk menyimpan perubahan ke SharedPreferences
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_keyCurrentAmount, _currentAmountMl);
    await prefs.setString(_keyLastDate, _formatDate(DateTime.now()));

    final List<String> logsJson = _logs.map((log) => log.toJson()).toList();
    await prefs.setStringList(_keyLogs, logsJson);
  }

  // Helper format tanggal sederhana (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}