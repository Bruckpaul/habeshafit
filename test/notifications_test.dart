import 'package:flutter_test/flutter_test.dart';
import 'package:habeshafit/data/coaching_backend.dart';
import 'package:habeshafit/data/repository.dart';
import 'package:habeshafit/logic/notification_plan.dart';
import 'package:habeshafit/logic/schedule.dart';
import 'package:habeshafit/models/coaching.dart';
import 'package:habeshafit/models/exercise.dart';
import 'package:habeshafit/models/profile.dart';
import 'package:habeshafit/models/routine.dart';
import 'package:habeshafit/services/notification_scheduler.dart';
import 'package:habeshafit/services/notifications.dart';
import 'package:habeshafit/state/app_state.dart';
import 'package:habeshafit/state/coaching_state.dart';
import 'package:sembast/sembast_memory.dart';

// 2026-11-02 is a Monday.
DateTime d(int day, [int h = 6, int m = 0]) => DateTime(2026, 11, day, h, m);

Routine upperLower() => Routine(id: 'ul', name: 'UL', days: [
      RoutineDay(id: 'u', name: 'Upper', weekdays: [1, 4], exercises: [PlannedExercise(exerciseId: 'bench')]),
      RoutineDay(id: 'l', name: 'Lower', weekdays: [2, 5], exercises: [PlannedExercise(exerciseId: 'squat')]),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('planNotifications', () {
    test('daily reminder on planned days only, from now on', () {
      final r = upperLower();
      final plan = planToday(routine: r, history: [], now: d(2));
      final list = planNotifications(
        profile: UserProfile(dailyReminderMinutes: 7 * 60),
        plan: plan,
        coachReminders: const [],
        now: d(2, 6),
      );
      expect(list.map((n) => (n.at, n.title)).toList(), [
        (d(2, 7), 'Today: Upper'),
        (d(3, 7), 'Today: Lower'),
        (d(5, 7), 'Today: Upper'),
        (d(6, 7), 'Today: Lower'),
      ]);
      expect(list.first.body, contains('1 exercise'));
    });

    test('no reminder for today once the time passed or the workout is done', () {
      final r = upperLower();
      final late = planNotifications(
        profile: UserProfile(dailyReminderMinutes: 7 * 60),
        plan: planToday(routine: r, history: [], now: d(2, 9)),
        coachReminders: const [],
        now: d(2, 9),
      );
      expect(late.first.at, d(3, 7));
    });

    test('off when no reminder time is set', () {
      final list = planNotifications(
        profile: UserProfile(),
        plan: planToday(routine: upperLower(), history: [], now: d(2)),
        coachReminders: const [],
        now: d(2),
      );
      expect(list, isEmpty);
    });

    test('coach reminders: weekly per weekday and one-off', () {
      final list = planNotifications(
        profile: UserProfile(),
        plan: const TodayPlan(status: PlanStatus.noRoutine),
        coachReminders: [
          Reminder(clientId: kMeClientId, coachId: 'c', type: ReminderType.water, text: 'Drink', time: '10:00', weekdays: [1, 3]),
          Reminder(clientId: kMeClientId, coachId: 'c', type: ReminderType.checkIn, text: 'Photo', time: '20:30', date: d(4)),
          Reminder(clientId: kMeClientId, coachId: 'c', type: ReminderType.sleep, text: 'Off', time: '22:00', weekdays: [1], active: false),
        ],
        coachName: 'Coach B',
        now: d(2, 11), // Monday 11:00, after Monday's 10:00
      );
      expect(list.map((n) => (n.at, n.weekly)).toList(), [
        (d(9, 10), true), // next Monday
        (d(4, 10), true), // Wednesday
        (d(4, 20, 30), false),
      ]);
      expect(list.first.title, 'Water · Coach B');
    });
  });

  test('scheduler mirrors the rest timer and reschedules on changes', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('n.db');
    final app = AppState(Repository(db));
    await app.load(libraryOverride: const [Exercise(id: 'bench', name: 'Bench')]);
    final coaching = CoachingState(LocalCoachingBackend(db), app);
    await coaching.load();
    final noop = NoopNotifier();
    final s = NotificationScheduler(app, coaching, noop)..start();

    app.startRest(90);
    expect(noop.restAt, app.restEndsAt);
    app.stopRest();
    expect(noop.restAt, isNull);

    await app.updateProfile((p) => p.restAlerts = false);
    app.startRest(60);
    expect(noop.restAt, isNull, reason: 'rest alerts turned off');

    await app.saveRoutine(upperLower(), makeActive: true);
    await app.updateProfile((p) => p.dailyReminderMinutes = 23 * 60 + 59);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(noop.scheduled, isNotEmpty);
    s.dispose();
  });

  test('backup includes coaching data', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('b.db');
    final app = AppState(Repository(db));
    await app.load(libraryOverride: const []);
    final coaching = CoachingState(LocalCoachingBackend(db), app);
    await coaching.load();
    final center = TrainingCenter(name: 'Gym', contact: 'x');
    await coaching.applyAsCoach(center: center, profile: CoachProfile(name: 'B', centerId: center.id));
    await coaching.reviewCenter(coaching.myCenter!, approve: true);
    await coaching.addClient(name: 'Me', isMe: true);

    final json = await app.exportData();
    await coaching.resetAll();
    expect(coaching.myCoachProfile, isNull);
    await app.importData(json);
    await coaching.load();
    expect(coaching.myCoachProfile?.name, 'B');
    expect(coaching.myLink, isNotNull);
    expect(coaching.coaches.where((c) => c.isSample).length, 2, reason: 'samples not duplicated');
  });
}
