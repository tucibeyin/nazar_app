import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_times.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Bildirim kanalı
  static const _kChannelId = 'ezan_vakitleri';
  static const _kChannelName = 'Ezan Vakitleri';
  static const _kChannelDesc = 'Namaz vakti ezan bildirimleri';

  // Vakit → bildirim ID eşlemesi (10–15 arası: ev içi namaz bildirimleri)
  static const Map<String, int> _kIds = {
    'İmsak': 10,
    'Güneş': 11,
    'Öğle': 12,
    'İkindi': 13,
    'Akşam': 14,
    'Yatsı': 15,
  };

  static const String _kPref = 'notif_';

  // ── Başlatma ───────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  // ── İzin İsteme ────────────────────────────────────────────────────────────

  Future<void> requestPermissions() async {
    if (!_initialized) await initialize();

    // Android 13+ POST_NOTIFICATIONS
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
      return;
    }

    // iOS
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ── Günlük Vakitler için Alarm Kurma ───────────────────────────────────────

  Future<void> schedulePrayerTimeAlarms(PrayerTimesData data) async {
    if (!_initialized) await initialize();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    for (final (name, time) in data.vakitler) {
      final enabled = prefs.getBool('$_kPref$name') ?? true;
      if (!enabled || !time.isAfter(now)) continue;

      final id = _kIds[name];
      if (id == null) continue;

      await _schedule(
        id: id,
        title: '🕌 $name Vakti Girdi',
        body: _body(name),
        scheduledTime: time,
      );
    }
  }

  // Tek bir vakit için alarm kur (toggle açıldığında çağrılır)
  Future<void> scheduleSingleAlarm(String vakit, PrayerTimesData data) async {
    if (!_initialized) await initialize();
    final now = DateTime.now();

    for (final (name, time) in data.vakitler) {
      if (name != vakit) continue;
      if (!time.isAfter(now)) return;

      final id = _kIds[name];
      if (id == null) return;

      await _schedule(
        id: id,
        title: '🕌 $name Vakti Girdi',
        body: _body(name),
        scheduledTime: time,
      );
      return;
    }
  }

  Future<void> cancelAlarm(String vakit) async {
    final id = _kIds[vakit];
    if (id != null) await _plugin.cancel(id);
  }

  Future<void> cancelAllAlarms() async {
    for (final id in _kIds.values) {
      await _plugin.cancel(id);
    }
  }

  // ── Dahili ─────────────────────────────────────────────────────────────────

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    // Dart DateTime'ı UTC tabanlı TZDateTime'a çevir.
    // scheduledTime yerel saattir; .toUtc() ile UTC eşdeğerini alır,
    // notification engine bunu cihazın saatine göre doğru tetikler.
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.UTC);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Tam zamanlı alarm izni yoksa sessizce geç
    }
  }

  String _body(String name) {
    switch (name) {
      case 'İmsak':
        return 'İmsak vakti girdi. Oruç niyetini yenile.';
      case 'Güneş':
        return 'Güneş doğdu. İşrak namazı için fırsat.';
      case 'Öğle':
        return 'Öğle vakti girdi. Allah kabul etsin.';
      case 'İkindi':
        return 'İkindi vakti girdi. Allah kabul etsin.';
      case 'Akşam':
        return 'Akşam vakti girdi. İftar vakti.';
      case 'Yatsı':
        return 'Yatsı vakti girdi. Günün son namazı.';
      default:
        return '$name vakti girdi.';
    }
  }
}
