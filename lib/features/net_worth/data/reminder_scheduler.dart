import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/monthly_entry.dart';

/// Wraps `FlutterLocalNotificationsPlugin` for the "log this month" nudge.
/// [init] must be called once at startup (see `main.dart`); everything else
/// is safe to call any number of times.
class ReminderScheduler {
  ReminderScheduler._();
  static final instance = ReminderScheduler._();

  static const _reminderId = 1001;
  static const _channelId = 'month_end_reminder';
  static const _channelName = 'Month-end reminder';

  /// How close to month-end the reminder should fire — a nudge near the
  /// deadline, not a nag from day one of the month.
  static const _daysBeforeMonthEnd = 5;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // This app is Philippines-only throughout (₱ / en_PH formatting) —
    // hardcoding the zone avoids a separate device-timezone-detection
    // package for a reminder that's already inexact by design.
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const settings = InitializationSettings(android: androidSettings);
    // This is startup-critical: `main.dart` awaits `init()` before `runApp()`,
    // so any uncaught exception here (e.g. a plugin/platform hiccup like a
    // missing notification icon resource) would otherwise take down the
    // entire app before it ever renders a frame. The reminder is a
    // nice-to-have — losing it silently beats a blank-screen crash.
    try {
      await _plugin.initialize(settings: settings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (error, stackTrace) {
      // debugPrint is throttled, not stripped, in release builds — guard it
      // like every other log site so release logcat stays silent.
      if (kDebugMode) {
        debugPrint('ReminderScheduler.init failed, continuing without reminders: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// Pure and testable: true when [now]'s month has no logged entry yet and
  /// we're within [_daysBeforeMonthEnd] days of month-end.
  bool shouldRemind(List<MonthlyEntry> entries, DateTime now) {
    final currentMonthId =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final alreadyLogged = entries.any((e) => e.id == currentMonthId);
    if (alreadyLogged) return false;

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day;
    return daysRemaining <= _daysBeforeMonthEnd;
  }

  /// Schedules (or cancels, if not currently applicable) the month-end
  /// reminder based on the latest known entries. Safe to call repeatedly,
  /// e.g. on every app launch.
  Future<void> scheduleMonthEndReminder(List<MonthlyEntry> entries, {DateTime? now}) async {
    final current = now ?? DateTime.now();
    if (!shouldRemind(entries, current)) {
      await cancelReminder();
      return;
    }

    final daysInMonth = DateTime(current.year, current.month + 1, 0).day;
    var fireAt = tz.TZDateTime(tz.local, current.year, current.month, daysInMonth, 18);
    final nowTz = tz.TZDateTime.now(tz.local);
    if (fireAt.isBefore(nowTz)) {
      fireAt = nowTz.add(const Duration(minutes: 1));
    }

    await _plugin.zonedSchedule(
      id: _reminderId,
      title: 'Log this month',
      body: "You haven't logged your balances for this month yet.",
      scheduledDate: fireAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> cancelReminder() => _plugin.cancel(id: _reminderId);
}
