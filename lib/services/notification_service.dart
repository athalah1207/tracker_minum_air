import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initialization;

  /// Pengingat terjadwal dari plugin ini hanya dijalankan pada aplikasi native.
  /// Browser tidak mendukung notifikasi terjadwal/berulang melalui API ini.
  bool get supportsScheduledReminders => !kIsWeb;

  Future<void> init() {
    // Jangan menyentuh instance plugin native saat aplikasi berjalan di browser.
    // Ini mencegah LateInitializationError pada implementasi platform yang tidak
    // tersedia di build web.
    if (kIsWeb) {
      _initialized = true;
      return Future<void>.value();
    }

    if (_initialized) return Future<void>.value();

    // Gunakan satu Future agar beberapa pemanggilan init bersamaan tidak
    // menginisialisasi plugin dua kali.
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      tz_data.initializeTimeZones();
      // Aplikasi ini menggunakan waktu Indonesia Barat (WIB).
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(settings);
      _initialized = true;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  /// Meminta izin notifikasi dan izin alarm presisi jika Android mendukungnya.
  /// Nilai kembali menunjukkan apakah izin notifikasi diberikan.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (!_initialized) await init();

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) {
      return true;
    }

    final notificationsGranted =
        await androidImplementation.requestNotificationsPermission();
    await androidImplementation.requestExactAlarmsPermission();
    return notificationsGranted ?? true;
  }

  Future<void> scheduleWaterReminders({
    required int intervalHours,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    if (intervalHours < 1) {
      throw ArgumentError.value(intervalHours, 'intervalHours', 'Harus minimal 1 jam.');
    }

    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    if (endMinutes <= startMinutes) {
      throw ArgumentError('Jam selesai harus setelah jam mulai.');
    }

    await cancelAllNotifications();

    final now = tz.TZDateTime.now(tz.local);
    var notificationId = 1;

    // Jadwalkan semua slot di antara jam mulai dan selesai. Setiap slot
    // berulang setiap hari pada jam yang sama. Jika slot hari ini sudah lewat,
    // jadwal pertama dibuat untuk besok agar slot tersebut tetap berulang harian.
    for (var minutes = startMinutes;
        minutes <= endMinutes;
        minutes += intervalHours * 60) {
      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (!scheduledDate.isAfter(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _scheduleNotification(
        id: notificationId,
        title: 'Waktunya Minum Air! 💧',
        body: 'Yuk, minum air putih sekarang agar tubuhmu tetap terhidrasi.',
        scheduledDate: scheduledDate,
      );
      notificationId++;
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'water_reminder_channel',
      'Pengingat Minum Air',
      channelDescription: 'Notifikasi berkala pengingat minum air putih',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on PlatformException {
      // Jika izin alarm presisi tidak tersedia, tetap coba jadwalkan dengan mode
      // inexact supaya pengingat masih mungkin muncul walaupun tidak tepat menitnya.
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    await _notificationsPlugin.cancelAll();
  }
}
