import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/water_log.dart';

class WaterController extends ChangeNotifier {
  final String profileId;
  final int initialGoalMl;

  int _dailyGoalMl = 2000;
  int _currentAmountMl = 0;
  int _streakDays = 0;
  int _bottleCapacityMl = 500;
  List<WaterLog> _logs = [];
  List<WaterLog> _historyLogs = [];
  bool _isLoading = true;

  WaterController({this.profileId = 'default', this.initialGoalMl = 2000}) {
    loadData();
  }

  String get _prefix => 'hydrotracker_profile_${profileId}_';
  String get _keyDailyGoal => '${_prefix}daily_goal_ml';
  String get _keyCurrentAmount => '${_prefix}current_amount_ml';
  String get _keyStreak => '${_prefix}streak_days';
  String get _keyLastDate => '${_prefix}last_date';
  String get _keyLogs => '${_prefix}water_logs';
  String get _keyHistoryLogs => '${_prefix}water_logs_history';
  String get _keyBottleCapacity => '${_prefix}bottle_capacity_ml';

  int get dailyGoalMl => _dailyGoalMl;
  int get currentAmountMl => _currentAmountMl;
  int get streakDays => _streakDays;
  int get bottleCapacityMl => _bottleCapacityMl;
  List<WaterLog> get logs => List.unmodifiable(_logs);
  List<WaterLog> get historyLogs => List.unmodifiable(_historyLogs);
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateOldWaterDataIfNeeded(prefs);

      final savedGoal = prefs.getInt(_keyDailyGoal) ?? initialGoalMl;
      _dailyGoalMl = savedGoal > 0 ? savedGoal : 2000;

      final savedBottleCapacity = prefs.getInt(_keyBottleCapacity) ?? 500;
      _bottleCapacityMl = savedBottleCapacity >= 50 && savedBottleCapacity <= 5000
          ? savedBottleCapacity
          : 500;
      if (_bottleCapacityMl != savedBottleCapacity) {
        await prefs.setInt(_keyBottleCapacity, _bottleCapacityMl);
      }

      _streakDays = prefs.getInt(_keyStreak) ?? 0;

      final String? lastDateStr = prefs.getString(_keyLastDate);
      final String todayStr = _formatDate(DateTime.now());
      final List<String> currentLogsJson = prefs.getStringList(_keyLogs) ?? [];
      final List<String>? historyLogsJson = prefs.getStringList(_keyHistoryLogs);

      _historyLogs = _decodeLogs(historyLogsJson ?? []);
      _mergeIntoHistory(_decodeLogs(currentLogsJson));

      if (lastDateStr == todayStr) {
        _currentAmountMl = prefs.getInt(_keyCurrentAmount) ?? 0;
        _logs = _decodeLogs(currentLogsJson);
      } else {
        if (lastDateStr != null) {
          final previousAmount = prefs.getInt(_keyCurrentAmount) ?? 0;
          _streakDays = previousAmount >= _dailyGoalMl ? _streakDays + 1 : 0;
          await prefs.setInt(_keyStreak, _streakDays);
        }

        _currentAmountMl = 0;
        _logs = [];
        await prefs.setString(_keyLastDate, todayStr);
        await prefs.setInt(_keyCurrentAmount, 0);
        await prefs.setStringList(_keyLogs, []);
      }

      await prefs.setInt(_keyDailyGoal, _dailyGoalMl);
      await prefs.setStringList(
        _keyHistoryLogs,
        _historyLogs.map((log) => log.toJson()).toList(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Salin data dari penyimpanan versi lama hanya sekali ke profil pertama.
  Future<void> _migrateOldWaterDataIfNeeded(SharedPreferences prefs) async {
    const migrationFlag = 'hydrotracker_legacy_water_data_migrated';
    if (prefs.getBool(migrationFlag) ?? false) return;

    if (!prefs.containsKey(_keyDailyGoal) && prefs.containsKey('daily_goal_ml')) {
      await prefs.setInt(_keyDailyGoal, prefs.getInt('daily_goal_ml')!);
    }
    if (!prefs.containsKey(_keyCurrentAmount) &&
        prefs.containsKey('current_amount_ml')) {
      await prefs.setInt(_keyCurrentAmount, prefs.getInt('current_amount_ml')!);
    }
    if (!prefs.containsKey(_keyStreak) && prefs.containsKey('streak_days')) {
      await prefs.setInt(_keyStreak, prefs.getInt('streak_days')!);
    }
    if (!prefs.containsKey(_keyLastDate) && prefs.containsKey('last_date')) {
      await prefs.setString(_keyLastDate, prefs.getString('last_date')!);
    }
    if (!prefs.containsKey(_keyLogs) && prefs.containsKey('water_logs')) {
      await prefs.setStringList(
        _keyLogs,
        prefs.getStringList('water_logs') ?? [],
      );
    }
    if (!prefs.containsKey(_keyHistoryLogs) &&
        prefs.containsKey('water_logs_history')) {
      await prefs.setStringList(
        _keyHistoryLogs,
        prefs.getStringList('water_logs_history') ?? [],
      );
    }

    await prefs.setBool(migrationFlag, true);
  }

  List<WaterLog> _decodeLogs(List<String> jsonLogs) {
    final List<WaterLog> decoded = [];
    for (final item in jsonLogs) {
      try {
        decoded.add(WaterLog.fromJson(item));
      } catch (_) {
        // Abaikan catatan rusak agar data lain tetap bisa dimuat.
      }
    }
    return decoded;
  }

  void _mergeIntoHistory(Iterable<WaterLog> logsToMerge) {
    final ids = _historyLogs.map((log) => log.id).toSet();
    for (final log in logsToMerge) {
      if (ids.add(log.id)) _historyLogs.add(log);
    }
    _historyLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int totalForDate(DateTime date) {
    return _historyLogs.where((log) {
      final localDate = log.timestamp.toLocal();
      return localDate.year == date.year &&
          localDate.month == date.month &&
          localDate.day == date.day;
    }).fold<int>(0, (total, log) => total + log.amountMl);
  }

  Future<void> addWater(int amountMl, {String drinkType = 'Air Putih'}) async {
    if (amountMl <= 0) return;

    final now = DateTime.now();
    final newLog = WaterLog(
      id: now.microsecondsSinceEpoch.toString(),
      amountMl: amountMl,
      timestamp: now,
      drinkType: drinkType,
    );

    _currentAmountMl += amountMl;
    _logs.insert(0, newLog);
    _historyLogs.insert(0, newLog);
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> deleteLog(String id) async {
    final index = _logs.indexWhere((log) => log.id == id);
    if (index == -1) return;

    _currentAmountMl =
        (_currentAmountMl - _logs[index].amountMl).clamp(0, 1 << 31).toInt();
    _logs.removeAt(index);
    _historyLogs.removeWhere((log) => log.id == id);
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> updateDailyGoal(int newGoalMl) async {
    if (newGoalMl <= 0) return;

    _dailyGoalMl = newGoalMl;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyGoal, newGoalMl);
  }

  Future<void> updateBottleCapacity(int newCapacityMl) async {
    if (newCapacityMl < 50 || newCapacityMl > 5000) return;

    _bottleCapacityMl = newCapacityMl;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBottleCapacity, newCapacityMl);
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCurrentAmount, _currentAmountMl);
    await prefs.setString(_keyLastDate, _formatDate(DateTime.now()));
    await prefs.setStringList(
      _keyLogs,
      _logs.map((log) => log.toJson()).toList(),
    );
    await prefs.setStringList(
      _keyHistoryLogs,
      _historyLogs.map((log) => log.toJson()).toList(),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
