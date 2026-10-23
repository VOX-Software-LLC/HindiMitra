import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// notificationService.ts — local scheduled notifications (no server).
/// Not available on web (same as the original: "Push notifications are available on mobile devices only").
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

const _dailyId = 1001; // 'daily-hindi-reminder'
const _streakId = 1002; // 'streak-warning'

Future<void> _init() async {
  if (_ready || kIsWeb) return;
  tzdata.initializeTimeZones();
  await _plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
  ));
  _ready = true;
}

Future<bool> requestNotificationPermissions() async {
  if (kIsWeb) return false;
  await _init();
  bool? granted;
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) granted = await android.requestNotificationsPermission();
  final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  if (ios != null) granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
  return granted ?? true;
}

NotificationDetails _details(String channelId, String channelName) => NotificationDetails(
      android: AndroidNotificationDetails(channelId, channelName, importance: Importance.high, priority: Priority.high,
          vibrationPattern: Int64List.fromList([0, 250, 250, 250])),
      iOS: const DarwinNotificationDetails(),
    );

/// Next occurrence of local hour:minute, expressed as a UTC instant (repeats daily at that UTC time-of-day).
tz.TZDateTime _nextDaily(int hour, int minute) {
  final now = DateTime.now();
  var t = DateTime(now.year, now.month, now.day, hour, minute);
  if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
  return tz.TZDateTime.from(t.toUtc(), tz.UTC);
}

Future<void> scheduleDailyReminder([int hour = 18, int minute = 0]) async {
  if (kIsWeb) return;
  await _init();
  await cancelDailyReminder();
  const messages = [
    ('हिन्दी सीखो! 📚', 'Time for your daily Hindi practice! Keep your streak going.'),
    ('अभ्यास का समय! ✍️', 'Your Hindi letters miss you! Come practice today.'),
    ('नमस्ते! 🙏', "Don't break your streak — a quick 5-minute lesson awaits!"),
    ('आज का अभ्यास 🌺', 'Master a new letter today! Your progress is waiting.'),
    ('Hindi time! 🎯', "Just one lesson keeps your streak alive. Let's go!"),
  ];
  final m = messages[Random().nextInt(messages.length)];
  await _plugin.zonedSchedule(_dailyId, m.$1, m.$2, _nextDaily(hour, minute), _details('daily-reminder', 'Daily Reminders'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, payload: 'daily-reminder');
}

Future<void> cancelDailyReminder() async { if (kIsWeb) return; await _init(); await _plugin.cancel(_dailyId); }

Future<void> scheduleStreakWarning() async {
  if (kIsWeb) return;
  await _init();
  await cancelStreakWarning();
  await _plugin.zonedSchedule(_streakId, '🔥 Streak in danger!',
      "You haven't practiced today. Open the app to keep your streak alive!", _nextDaily(20, 0), _details('streak-alert', 'Streak Alerts'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, payload: 'streak-warning');
}

Future<void> cancelStreakWarning() async { if (kIsWeb) return; await _init(); await _plugin.cancel(_streakId); }

Future<void> dismissTodayStreakWarning() async { await cancelStreakWarning(); await scheduleStreakWarning(); }

Future<void> sendMilestoneNotification(String milestone) async {
  if (kIsWeb) return;
  await _init();
  await _plugin.show(DateTime.now().millisecondsSinceEpoch % 100000, '🎉 Achievement Unlocked!', milestone, _details('daily-reminder', 'Daily Reminders'));
}

Future<void> cancelAllNotifications() async { if (kIsWeb) return; await _init(); await _plugin.cancelAll(); }
