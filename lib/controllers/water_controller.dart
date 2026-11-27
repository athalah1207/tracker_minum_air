import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/water_log.dart';
import '../services/cloud_backup_service.dart';

class WaterController extends ChangeNotifier {
  final String profileId;
  final int initialGoalMl;
  final String? cloudUid;

  int _dailyGoalMl = 2000;
  int _currentAmountMl = 0;
  int _bottleCapacityMl = 500;
  List<WaterLog> _logs = [];
  List<WaterLog> _historyLogs = [];
  Map<String, int> _dailyGoalByDate = {};
  Set<String> _unlockedBadgeIds = {};
  bool _isLoading = true;

  WaterController({
    this.profileId = 'default',
    this.initialGoalMl = 2000,
    this.cloudUid,
  }) {
    loadData();
  }

  String get _prefix => 'hydrotracker_profile_${profileId}_';
  String get _keyDailyGoal => '${_prefix}daily_goal_ml';
  String get _keyDailyGoalHistory => '${_prefix}daily_goal_history';
  String get _keyUnlockedBadges => '${_prefix}unlocked_badges';
  String get _keyCurrentAmount => '${_prefix}current_amount_ml';
  String get _keyLastDate => '${_prefix}last_date';
  String get _keyLogs => '${_prefix}water_logs';
  String get _keyHistoryLogs => '${_prefix}water_logs_history';
  String get _keyBottleCapacity => '${_prefix}bottle_capacity_ml';

  int get dailyGoalMl => _dailyGoalMl;
  int get currentAmountMl => _currentAmountMl;
  Set<String> get unlockedBadgeIds => Set.unmodifiable(_unlockedBadgeIds);

  /// Streak aktif dihitung dari hari-hari yang benar-benar mencapai target.
  /// Hari ini ikut dihitung jika target sudah tercapai; jika belum, streak
  /// tetap aktif berdasarkan pencapaian kemarin sampai hari ini berakhir.
  int get streakDays {
    final totals = _dailyTotals;
    final today = _dateOnly(DateTime.now());
    var currentDate = _isGoalReached(today, totals[today] ?? 0)
        ? today
        : today.subtract(const Duration(days: 1));

    if (!_isGoalReached(currentDate, totals[currentDate] ?? 0)) return 0;

    var streak = 0;
    while (_isGoalReached(currentDate, totals[currentDate] ?? 0)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Jumlah hari dalam riwayat yang memenuhi target pada tanggal tersebut.
  int get totalGoalDays => _dailyTotals.entries
      .where((entry) => _isGoalReached(entry.key, entry.value))
      .length;

  /// Streak terpanjang yang pernah tercatat di dalam riwayat.
  int get longestStreakDays {
    final dates = _dailyTotals.entries
        .where((entry) => _isGoalReached(entry.key, entry.value))
        .map((entry) => entry.key)
        .toList()
      ..sort();

    var longest = 0;
    var current = 0;
    DateTime? previousDate;

    for (final date in dates) {
      if (previousDate != null && date.difference(previousDate).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      previousDate = date;
    }
    return longest;
  }

  /// Total seluruh air yang tercatat di riwayat.
  int get totalWaterMl =>
      _historyLogs.fold<int>(0, (total, log) => total + log.amountMl);

  Map<DateTime, int> get _dailyTotals {
    final totals = <DateTime, int>{};
    for (final log in _historyLogs) {
      final date = _dateOnly(log.timestamp.toLocal());
      totals[date] = (totals[date] ?? 0) + log.amountMl;
    }
    return totals;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isGoalReached(DateTime date, int total) {
    final goalForDate = _dailyGoalByDate[_formatDate(date)] ?? _dailyGoalMl;
    return total >= goalForDate;
  }

  List<String> _encodeDailyGoalHistory() => _dailyGoalByDate.entries
      .map((entry) => '${entry.key}|${entry.value}')
      .toList();

  void _collectUnlockedBadges() {
    if (totalGoalDays >= 1) _unlockedBadgeIds.add('first_goal');
    if (longestStreakDays >= 3) _unlockedBadgeIds.add('streak_3');
    if (longestStreakDays >= 7) _unlockedBadgeIds.add('streak_7');
    if (totalGoalDays >= 30) _unlockedBadgeIds.add('goal_30');
    if (totalWaterMl >= 100000) _unlockedBadgeIds.add('water_100_liters');
  }

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

      final String? lastDateStr = prefs.getString(_keyLastDate);
      final String todayStr = _formatDate(DateTime.now());
      _dailyGoalByDate = {};
      for (final entry in prefs.getStringList(_keyDailyGoalHistory) ?? []) {
        final separator = entry.lastIndexOf('|');
        if (separator <= 0) continue;
        final goal = int.tryParse(entry.substring(separator + 1));
        if (goal != null && goal > 0) {
          _dailyGoalByDate[entry.substring(0, separator)] = goal;
        }
      }
      _dailyGoalByDate.putIfAbsent(todayStr, () => _dailyGoalMl);
      _unlockedBadgeIds =
          (prefs.getStringList(_keyUnlockedBadges) ?? []).toSet();

      final List<String> currentLogsJson = prefs.getStringList(_keyLogs) ?? [];
      final List<String>? historyLogsJson = prefs.getStringList(_keyHistoryLogs);

      _historyLogs = _decodeLogs(historyLogsJson ?? []);
      _mergeIntoHistory(_decodeLogs(currentLogsJson));

      if (lastDateStr == todayStr) {
        _currentAmountMl = prefs.getInt(_keyCurrentAmount) ?? 0;
        _logs = _decodeLogs(currentLogsJson);
      } else {
        _currentAmountMl = 0;
        _logs = [];
        await prefs.setString(_keyLastDate, todayStr);
        await prefs.setInt(_keyCurrentAmount, 0);
        await prefs.setStringList(_keyLogs, []);
      }

      _collectUnlockedBadges();
      await prefs.setInt(_keyDailyGoal, _dailyGoalMl);
      await prefs.setStringList(
        _keyDailyGoalHistory,
        _encodeDailyGoalHistory(),
      );
      await prefs.setStringList(_keyUnlockedBadges, _unlockedBadgeIds.toList());
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
    _collectUnlockedBadges();
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
    _dailyGoalByDate[_formatDate(DateTime.now())] = newGoalMl;
    _collectUnlockedBadges();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyGoal, newGoalMl);
    await prefs.setStringList(
      _keyDailyGoalHistory,
      _encodeDailyGoalHistory(),
    );
    await prefs.setStringList(_keyUnlockedBadges, _unlockedBadgeIds.toList());
    await _syncToCloud();
  }

  Future<void> updateBottleCapacity(int newCapacityMl) async {
    if (newCapacityMl < 50 || newCapacityMl > 5000) return;

    _bottleCapacityMl = newCapacityMl;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBottleCapacity, newCapacityMl);
    await _syncToCloud();
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
    await prefs.setStringList(_keyUnlockedBadges, _unlockedBadgeIds.toList());
    await _syncToCloud();
  }

  Future<void> _syncToCloud() async {
    final uid = cloudUid;
    if (uid == null || uid.isEmpty) return;
    try {
      await CloudBackupService().syncWaterData(uid, profileId);
    } catch (error) {
      // Perubahan tetap tersimpan lokal jika internet/database sedang gagal.
      debugPrint('HydroTracker cloud sync error: $error');
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
