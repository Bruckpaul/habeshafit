import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/notification_plan.dart';
import '../models/coaching.dart';
import '../state/app_state.dart';
import '../state/coaching_state.dart';
import 'notifications.dart';

/// Keeps the phone's scheduled notifications in line with the app's data:
/// reschedules reminders when the plan, settings or coach reminders change,
/// and mirrors the rest timer.
class NotificationScheduler {
  final AppState app;
  final CoachingState coaching;
  final Notifier notifier;

  NotificationScheduler(this.app, this.coaching, this.notifier);

  Timer? _debounce;
  String? _lastSignature;
  DateTime? _lastRest;

  void start() {
    app.addListener(_changed);
    coaching.addListener(_changed);
    _sync();
  }

  /// Recompute after time passes (app resumed on a new day).
  void resync() {
    _lastSignature = null;
    _sync();
  }

  void dispose() {
    app.removeListener(_changed);
    coaching.removeListener(_changed);
    _debounce?.cancel();
  }

  void _changed() {
    _syncRest();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _sync);
  }

  List<PlannedNotification> currentPlan() {
    final link = coaching.myLink;
    return planNotifications(
      profile: app.profile,
      plan: app.today,
      coachReminders: link == null ? const [] : coaching.remindersFor(kMeClientId, link.coachId),
      coachName: coaching.myCoach?.name,
      now: app.clock(),
    );
  }

  Future<void> _sync() async {
    final plan = currentPlan();
    final sig = plan.map((p) => p.signature).join('\n');
    if (sig == _lastSignature) return;
    _lastSignature = sig;
    try {
      await notifier.replaceScheduled(plan);
    } catch (e) {
      debugPrint('Scheduling notifications failed: $e');
    }
  }

  void _syncRest() {
    final at = app.profile.restAlerts ? app.restEndsAt : null;
    if (at == _lastRest) return;
    _lastRest = at;
    (at == null ? notifier.cancelRest() : notifier.scheduleRest(at)).catchError((Object e) {
      debugPrint('Rest notification failed: $e');
    });
  }

  /// Asks for notification permission once, at a moment it makes sense
  /// (starting a workout or turning a reminder on).
  Future<bool> ensurePermission({bool force = false}) async {
    if (app.profile.notificationsAsked && !force) return true;
    final ok = await notifier.requestPermission();
    await app.updateProfile((p) => p.notificationsAsked = true);
    return ok;
  }
}
