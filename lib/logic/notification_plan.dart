import '../models/coaching.dart';
import '../models/profile.dart';
import '../util/format.dart';
import 'schedule.dart';

/// A notification the phone should have scheduled.
class PlannedNotification {
  /// Stable within one plan; the scheduler replaces the whole set on change.
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final NotificationKind kind;

  /// Repeat every week at the same weekday and time.
  final bool weekly;

  const PlannedNotification({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
    this.weekly = false,
  });

  String get signature => '$id|${at.toIso8601String()}|$title|$body|$weekly';
}

enum NotificationKind { rest, workout, coach }

/// Id reserved for the rest-timer alert.
const int kRestNotificationId = 1;

/// Works out every reminder to schedule from now on:
/// * a "today's workout" reminder at [UserProfile.dailyReminderMinutes] for
///   each planned training day in the coming week (skipped once today's
///   workout is done or the time has passed);
/// * the coach's reminders for the phone owner, weekly or one-off.
List<PlannedNotification> planNotifications({
  required UserProfile profile,
  required TodayPlan plan,
  required List<Reminder> coachReminders,
  String? coachName,
  required DateTime now,
}) {
  final out = <PlannedNotification>[];
  var nextId = 100;

  final minutes = profile.dailyReminderMinutes;
  if (minutes != null) {
    for (final (i, p) in plan.week.indexed) {
      final day = p.day;
      if (day == null || day.exercises.isEmpty) continue;
      if (i == 0 && plan.status != PlanStatus.workout) continue;
      final at = DateTime(p.date.year, p.date.month, p.date.day).add(Duration(minutes: minutes));
      if (!at.isAfter(now)) continue;
      out.add(PlannedNotification(
        id: nextId++,
        at: at,
        title: 'Today: ${day.name}',
        body: '${plural(day.exercises.length, 'exercise')} · ~${fmtDuration(day.estimatedDuration)}. Tap to start.',
        kind: NotificationKind.workout,
      ));
    }
  }

  nextId = 500;
  final from = coachName ?? 'Your coach';
  for (final r in coachReminders.where((r) => r.active)) {
    final parts = r.time.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0;
    final title = '${r.type.label} · $from';
    if (r.weekdays.isEmpty) {
      final d = r.date;
      if (d == null) continue;
      final at = DateTime(d.year, d.month, d.day, h, m);
      if (at.isAfter(now)) {
        out.add(PlannedNotification(id: nextId++, at: at, title: title, body: r.text, kind: NotificationKind.coach));
      }
      continue;
    }
    for (final w in r.weekdays) {
      // Next date on weekday [w] at h:m, strictly after now.
      var at = DateTime(now.year, now.month, now.day, h, m).add(Duration(days: (w - now.weekday) % 7));
      if (!at.isAfter(now)) at = at.add(const Duration(days: 7));
      out.add(PlannedNotification(
        id: nextId++,
        at: at,
        title: title,
        body: r.text,
        kind: NotificationKind.coach,
        weekly: true,
      ));
    }
  }
  return out;
}
