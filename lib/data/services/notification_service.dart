import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/platform/platform_support.dart';

/// One reminder to schedule (computed by planReminders from real data).
class ScheduledAlert {
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final DateTimeComponents? repeat;
  const ScheduledAlert(this.id, this.when, this.title, this.body, {this.repeat});
}

/// Local notifications on the device (no server needed): lecture, deadline,
/// exam, project and study reminders plus daily / weekly summaries.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _exact = false;

  Future<void> init() async {
    if (_ready) return;
    if (!_desktopNotificationsAvailable) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(_guessLocation());
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
          // iOS: permission is asked from Settings → Notifications (requestPermissions).
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          // Desktop (Windows toasts / Linux libnotify).
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
          windows: WindowsInitializationSettings(
            appName: 'CMD Uni',
            appUserModelId: 'MohammadNidal.UniPlanner',
            guid: '8a3f1c2e-4b6d-4e9a-b7c5-1d2e3f4a5b6c',
          ),
        ),
      );
      _ready = true;
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      _exact = await android?.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  static tz.Location _guessLocation() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    tz.Location? byOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      final z = loc.currentTimeZone;
      if (z.offset == offset) {
        if (z.abbreviation == now.timeZoneName) return loc;
        byOffset ??= loc;
      }
    }
    if (offset == const Duration(hours: 3)) return tz.getLocation('Asia/Aden');
    return byOffset ?? tz.UTC;
  }

  /// Desktop note: Windows shows scheduled toasts but does not repeat them, so
  /// a repeating reminder is scheduled as its next occurrence (the app
  /// re-plans reminders every time it starts). Linux has no scheduled
  /// notifications at all, so only immediate ones are shown there.
  static DateTime nextOccurrence(DateTime when, DateTimeComponents? repeat, DateTime now) {
    if (repeat == null || when.isAfter(now)) return when;
    var at = when;
    switch (repeat) {
      case DateTimeComponents.time:
        at = DateTime(now.year, now.month, now.day, when.hour, when.minute, when.second);
        if (!at.isAfter(now)) at = DateTime(now.year, now.month, now.day + 1, when.hour, when.minute, when.second);
      case DateTimeComponents.dayOfWeekAndTime:
        at = DateTime(now.year, now.month, now.day, when.hour, when.minute, when.second);
        while (at.weekday != when.weekday || !at.isAfter(now)) {
          at = DateTime(at.year, at.month, at.day + 1, when.hour, when.minute, when.second);
        }
      case DateTimeComponents.dayOfMonthAndTime:
        var m = now.month;
        var y = now.year;
        for (var i = 0; i < 24; i++) {
          final c = DateTime(y, m, when.day, when.hour, when.minute, when.second);
          if (c.month == ((m - 1) % 12) + 1 && c.isAfter(now)) return c;
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }
      case DateTimeComponents.dateAndTime:
        at = DateTime(now.year, when.month, when.day, when.hour, when.minute, when.second);
        if (!at.isAfter(now)) at = DateTime(now.year + 1, when.month, when.day, when.hour, when.minute, when.second);
    }
    return at;
  }

  /// Linux desktop notifications need a D-Bus session (any normal desktop has
  /// one). Without it (e.g. a headless/remote session) notifications are
  /// skipped instead of throwing.
  static bool get _desktopNotificationsAvailable {
    if (!PlatformSupport.isLinux) return true;
    final env = Platform.environment;
    if ((env['DBUS_SESSION_BUS_ADDRESS'] ?? '').isNotEmpty) return true;
    final runtime = env['XDG_RUNTIME_DIR'];
    return runtime != null && File('$runtime/bus').existsSync();
  }

  Future<bool> requestPermissions() async {
    await init();
    if (!_ready) return false;
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final granted = await android.requestNotificationsPermission() ?? false;
      try {
        _exact = await android.canScheduleExactNotifications() ?? false;
      } catch (_) {}
      return granted;
    } catch (e) {
      debugPrint('permission request failed: $e');
      return false;
    }
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      'uni_reminders',
      'University reminders / تذكيرات جامعية',
      channelDescription: 'Lectures, deadlines, exams and study reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> showNow(int id, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: _details);
    } catch (e) {
      debugPrint('show failed: $e');
    }
  }

  /// Replaces every scheduled reminder with [alerts].
  Future<void> reschedule(List<ScheduledAlert> alerts) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      if (!PlatformSupport.scheduledNotifications) return; // Linux: immediate alerts only
      for (final a in alerts) {
        if (a.repeat == null && !a.when.isAfter(now)) continue;
        final osRepeats = PlatformSupport.repeatingNotifications;
        final when = osRepeats ? a.when : nextOccurrence(a.when, a.repeat, now);
        await _plugin.zonedSchedule(
          id: a.id,
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          notificationDetails: _details,
          androidScheduleMode: _exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          title: a.title,
          body: a.body,
          matchDateTimeComponents: osRepeats ? a.repeat : null,
        );
      }
    } catch (e) {
      debugPrint('reschedule failed: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
