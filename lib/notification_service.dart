import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'habous_parser.dart';
import 'repository.dart';

/// إشعارات حقيقية (AlarmManager دقيق) — كتخدم حتى والتطبيق مسدود وبلا إنترنت
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channel = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayers', 'مواقيت الصلاة',
      channelDescription: 'تنبيه أوقات الصلوات',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  static tz.Location get _loc => tz.getLocation('Africa/Casablanca');

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_loc);
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await impl?.requestNotificationsPermission();      // Android 13+
    await impl?.requestExactAlarmsPermission();        // Android 12+
  }

  /// برمجة إشعارات الشهر كامل (كل صلاة × كل يوم). الإشعارات الفائتة تُتخطى.
  static Future<void> scheduleMonth(HabousData data) async {
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(_loc);
    const names = {
      'fajr': 'الفجر', 'chourouq': 'الشروق', 'dhuhr': 'الظهر',
      'asr': 'العصر', 'maghrib': 'المغرب', 'isha': 'العشاء',
    };
    int id = 0;
    for (final d in data.days) {
      final base = d.date; // السنة/الشهر من الجدول نفسه = دقة حتى عند تبدل الشهر
      for (final e in names.entries) {
        final hm = d.byKey(e.key);
        final h = int.parse(hm.substring(0, 2));
        final m = int.parse(hm.substring(3, 5));
        final when = tz.TZDateTime(_loc, base.year, base.month, base.day, h, m);
        if (!when.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id++,
          'حان الآن وقت صلاة ${e.value}',
          data.ville.isEmpty ? '🕌' : '🕌 ${data.ville}',
          when,
          _channel,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
             UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  /// يُستدعى بعد إعادة تشغيل الهاتف: يعيد برمجة الإشعارات من الكاش المحلي
  static Future<void> rescheduleFromCache() async {
    final c = await Repository.load();
    if (c != null) await scheduleMonth(c.data);
  }
}
