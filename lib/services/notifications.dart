import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/notification_plan.dart';

/// Shows and schedules phone notifications. [NoopNotifier] is used on web
/// and in tests.
abstract class Notifier {
  Future<void> init({void Function(String route)? onOpen});

  /// Asks the OS for permission. Returns whether notifications are allowed.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder (not the rest alert) with [list].
  Future<void> replaceScheduled(List<PlannedNotification> list);

  Future<void> scheduleRest(DateTime at);
  Future<void> cancelRest();

  /// Route to open if the app was launched from a notification.
  Future<String?> launchRoute();
}

class NoopNotifier implements Notifier {
  final List<PlannedNotification> scheduled = [];
  DateTime? restAt;

  @override
  Future<void> init({void Function(String route)? onOpen}) async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> replaceScheduled(List<PlannedNotification> list) async => scheduled
    ..clear()
    ..addAll(list);
  @override
  Future<void> scheduleRest(DateTime at) async => restAt = at;
  @override
  Future<void> cancelRest() async => restAt = null;
  @override
  Future<String?> launchRoute() async => null;
}

class LocalNotifier implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _rest = AndroidNotificationDetails(
    'rest_timer',
    'Rest timer',
    channelDescription: 'Alerts when your rest between sets is over',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
  );
  static const _workout = AndroidNotificationDetails(
    'workout_reminder',
    'Workout reminders',
    channelDescription: 'Today\'s planned workout',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _coach = AndroidNotificationDetails(
    'coach_reminders',
    'Coach reminders',
    channelDescription: 'Training times, meals, water and check-ins from your coach',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _darwin = DarwinNotificationDetails();

  NotificationDetails _details(NotificationKind k) => NotificationDetails(
        android: switch (k) {
          NotificationKind.rest => _rest,
          NotificationKind.workout => _workout,
          NotificationKind.coach => _coach,
        },
        iOS: _darwin,
      );

  static String _route(NotificationKind k) => switch (k) {
        NotificationKind.rest => '/workout',
        NotificationKind.workout => '/home',
        NotificationKind.coach => '/coach',
      };

  @override
  Future<void> init({void Function(String route)? onOpen}) async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone name: fall back to UTC offsets; times may be off by DST.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Ask for permission in context (first workout), not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final route = r.payload;
        if (route != null && route.isNotEmpty) onOpen?.call(route);
      },
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<AndroidScheduleMode> _mode() async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> replaceScheduled(List<PlannedNotification> list) async {
    if (!_ready) return;
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id != kRestNotificationId) await _plugin.cancel(id: p.id);
    }
    final mode = await _mode();
    for (final n in list) {
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: _details(n.kind),
        androidScheduleMode: mode,
        title: n.title,
        body: n.body,
        payload: _route(n.kind),
        matchDateTimeComponents: n.weekly ? DateTimeComponents.dayOfWeekAndTime : null,
      );
    }
  }

  @override
  Future<void> scheduleRest(DateTime at) async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      id: kRestNotificationId,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details(NotificationKind.rest),
      androidScheduleMode: await _mode(),
      title: 'Rest over',
      body: 'Time for your next set.',
      payload: '/workout',
    );
  }

  @override
  Future<void> cancelRest() async {
    if (_ready) await _plugin.cancel(id: kRestNotificationId);
  }

  @override
  Future<String?> launchRoute() async {
    if (!_ready) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp != true) return null;
    return d!.notificationResponse?.payload;
  }
}

/// Phone notifications on Android/iOS; nothing on web/desktop.
Notifier createNotifier() =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
        ? LocalNotifier()
        : NoopNotifier();
