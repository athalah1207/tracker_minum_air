import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'profile_storage_service.dart';

/// Backup dan pemulihan profil serta riwayat HydroTracker ke Cloud Firestore.
/// Struktur cloud:
/// users/{uid}
///   profiles/{profileId}
///     state/main
///     logs/{logId}
class CloudBackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _profiles(String uid) =>
      _firestore.collection('users').doc(uid).collection('profiles');

  Future<void> syncProfile(String uid, UserProfile profile) async {
    await _profiles(uid).doc(profile.id).set(
      <String, dynamic>{
        ...profile.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await syncWaterData(uid, profile.id);
  }

  /// Dipanggil setiap data minum/target berubah.
  Future<void> syncWaterData(String uid, String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'hydrotracker_profile_${profileId}_';
    final profileRef = _profiles(uid).doc(profileId);

    final state = <String, dynamic>{
      'dailyGoalMl': prefs.getInt('${prefix}daily_goal_ml') ?? 2000,
      'dailyGoalHistory': prefs.getStringList(
            '${prefix}daily_goal_history',
          ) ??
          <String>[],
      'unlockedBadges': prefs.getStringList(
            '${prefix}unlocked_badges',
          ) ??
          <String>[],
      'currentAmountMl': prefs.getInt('${prefix}current_amount_ml') ?? 0,
      'lastDate': prefs.getString('${prefix}last_date') ?? _todayKey(),
      'bottleCapacityMl': prefs.getInt('${prefix}bottle_capacity_ml') ?? 500,
      'autoGoalFromWeight':
          prefs.getBool('profile_${profileId}_auto_goal_from_weight') ?? false,
      'alarmActive': prefs.getBool('alarm_active') ?? false,
      'alarmInterval': prefs.getInt('alarm_interval') ?? 2,
      'alarmStartHour': prefs.getInt('alarm_start_hour') ?? 8,
      'alarmStartMin': prefs.getInt('alarm_start_min') ?? 0,
      'alarmEndHour': prefs.getInt('alarm_end_hour') ?? 22,
      'alarmEndMin': prefs.getInt('alarm_end_min') ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await profileRef.collection('state').doc('main').set(
      state,
      SetOptions(merge: true),
    );

    final rawLogs = prefs.getStringList('${prefix}water_logs_history') ??
        prefs.getStringList('${prefix}water_logs') ??
        <String>[];
    final localLogs = <String, Map<String, dynamic>>{};

    for (final raw in rawLogs) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final id = map['id']?.toString();
          if (id != null && id.isNotEmpty) localLogs[id] = map;
        }
      } catch (_) {
        // Abaikan satu catatan rusak; catatan lain tetap dicadangkan.
      }
    }

    final logsRef = profileRef.collection('logs');
    final cloudLogs = await logsRef.get();
    final cloudById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in cloudLogs.docs) doc.id: doc,
    };

    var batch = _firestore.batch();
    var operationCount = 0;

    Future<void> commitBatch() async {
      if (operationCount == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      operationCount = 0;
    }

    for (final entry in localLogs.entries) {
      final oldData = cloudById[entry.key]?.data();
      final newData = entry.value;
      final isUnchanged = oldData != null &&
          oldData['amountMl'] == newData['amountMl'] &&
          oldData['timestamp'] == newData['timestamp'] &&
          oldData['drinkType'] == newData['drinkType'];

      if (!isUnchanged) {
        batch.set(logsRef.doc(entry.key), newData, SetOptions(merge: true));
        operationCount++;
      }

      if (operationCount >= 400) await commitBatch();
    }

    for (final cloudEntry in cloudById.entries) {
      if (!localLogs.containsKey(cloudEntry.key)) {
        batch.delete(cloudEntry.value.reference);
        operationCount++;
      }
      if (operationCount >= 400) await commitBatch();
    }

    await commitBatch();
  }

  /// Mengembalikan semua profil milik akun. Mengembalikan false jika akun
  /// belum memiliki profil cloud, supaya profil lokal pertama bisa diunggah.
  Future<bool> restoreProfiles(String uid) async {
    final snapshot = await _profiles(uid).get();
    if (snapshot.docs.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final restoredProfiles = <UserProfile>[];

    for (final profileDoc in snapshot.docs) {
      final profileData = profileDoc.data();
      final profile = UserProfile.fromJson({
        ...profileData,
        'id': profileDoc.id,
      });
      restoredProfiles.add(profile);

      final stateSnapshot = await profileDoc.reference
          .collection('state')
          .doc('main')
          .get();
      final state = stateSnapshot.data() ?? <String, dynamic>{};

      final logsSnapshot = await profileDoc.reference
          .collection('logs')
          .get();
      final logs = logsSnapshot.docs.map((doc) => doc.data()).toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

      await _restoreOneProfile(prefs, profile, state, logs);
    }

    await ProfileStorageService().replaceProfiles(restoredProfiles);
    return true;
  }

  Future<void> _restoreOneProfile(
    SharedPreferences prefs,
    UserProfile profile,
    Map<String, dynamic> state,
    List<Map<String, dynamic>> logs,
  ) async {
    final prefix = 'hydrotracker_profile_${profile.id}_';
    final today = _todayKey();
    final lastDate = state['lastDate']?.toString() ?? today;
    final logJson = logs.map(jsonEncode).toList();
    final currentLogJson = logs.where((log) {
      final timestamp = DateTime.tryParse(log['timestamp']?.toString() ?? '');
      if (timestamp == null) return false;
      return _dateKey(timestamp.toLocal()) == lastDate;
    }).map(jsonEncode).toList();

    await prefs.setInt(
      '${prefix}daily_goal_ml',
      (state['dailyGoalMl'] as num?)?.toInt() ?? profile.dailyGoalMl,
    );
    await prefs.setStringList(
      '${prefix}daily_goal_history',
      _stringList(state['dailyGoalHistory']),
    );
    await prefs.setStringList(
      '${prefix}unlocked_badges',
      _stringList(state['unlockedBadges']),
    );
    await prefs.setInt(
      '${prefix}current_amount_ml',
      (state['currentAmountMl'] as num?)?.toInt() ?? 0,
    );
    await prefs.setString('${prefix}last_date', lastDate);
    await prefs.setInt(
      '${prefix}bottle_capacity_ml',
      (state['bottleCapacityMl'] as num?)?.toInt() ?? 500,
    );
    await prefs.setStringList('${prefix}water_logs_history', logJson);
    await prefs.setStringList('${prefix}water_logs', currentLogJson);

    await prefs.setBool(
      'profile_${profile.id}_auto_goal_from_weight',
      state['autoGoalFromWeight'] == true,
    );
    await prefs.setBool('alarm_active', state['alarmActive'] == true);
    await prefs.setInt(
      'alarm_interval',
      (state['alarmInterval'] as num?)?.toInt() ?? 2,
    );
    await prefs.setInt(
      'alarm_start_hour',
      (state['alarmStartHour'] as num?)?.toInt() ?? 8,
    );
    await prefs.setInt(
      'alarm_start_min',
      (state['alarmStartMin'] as num?)?.toInt() ?? 0,
    );
    await prefs.setInt(
      'alarm_end_hour',
      (state['alarmEndHour'] as num?)?.toInt() ?? 22,
    );
    await prefs.setInt(
      'alarm_end_min',
      (state['alarmEndMin'] as num?)?.toInt() ?? 0,
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value.map((item) => item.toString()).toList();
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
