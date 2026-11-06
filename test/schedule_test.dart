import 'package:flutter_test/flutter_test.dart';
import 'package:habeshafit/logic/schedule.dart';
import 'package:habeshafit/models/routine.dart';
import 'package:habeshafit/models/workout.dart';

RoutineDay day(String id, {List<int> weekdays = const []}) => RoutineDay(
      id: id,
      name: id,
      weekdays: [...weekdays],
      exercises: [PlannedExercise(exerciseId: 'Squat')],
    );

WorkoutSession done(Routine r, String dayId, DateTime at, {int? slot}) => WorkoutSession(
      name: dayId,
      routineId: r.id,
      dayId: dayId,
      slotIndex: slot,
      start: at,
      end: at.add(const Duration(hours: 1)),
    );

void main() {
  // 2026-11-02 is a Monday.
  DateTime d(int day, [int hour = 9]) => DateTime(2026, 11, day, hour);

  group('weekdays mode', () {
    final r = Routine(id: 'ul', name: 'UL', days: [
      day('upper', weekdays: [1, 4]),
      day('lower', weekdays: [2, 5]),
    ]);

    test('picks the day pinned to today', () {
      expect(planToday(routine: r, history: [], now: d(2)).day?.id, 'upper'); // Mon
      expect(planToday(routine: r, history: [], now: d(3)).day?.id, 'lower'); // Tue
      expect(planToday(routine: r, history: [], now: d(5)).day?.id, 'upper'); // Thu
      expect(planToday(routine: r, history: [], now: d(6)).day?.id, 'lower'); // Fri
    });

    test('unpinned weekday is rest and points to the next workout', () {
      final p = planToday(routine: r, history: [], now: d(4)); // Wednesday
      expect(p.status, PlanStatus.rest);
      expect(p.nextDay?.id, 'upper');
      expect(p.nextDate, DateTime(2026, 11, 5));
    });

    test('finished today shows done', () {
      final p = planToday(routine: r, history: [done(r, 'upper', d(2, 7))], now: d(2, 20));
      expect(p.status, PlanStatus.done);
      expect(p.nextDay?.id, 'lower');
      expect(p.nextDate, DateTime(2026, 11, 3));
    });

    test('missed days are not carried forward', () {
      // Monday's upper was skipped; Tuesday is still lower.
      expect(planToday(routine: r, history: [], now: d(3)).day?.id, 'lower');
    });

    test('override swaps or skips today', () {
      expect(planToday(routine: r, history: [], now: d(2), override: 'lower').day?.id, 'lower');
      final rest = planToday(routine: r, history: [], now: d(2), override: 'rest');
      expect(rest.status, PlanStatus.rest);
      expect(rest.overridden, isTrue);
    });

    test('week forecast lists 7 days', () {
      final p = planToday(routine: r, history: [], now: d(2));
      expect(p.week.map((e) => e.day?.id).toList(),
          ['upper', 'lower', null, 'upper', 'lower', null, null]);
    });
  });

  group('rotation mode', () {
    final r = Routine(
      id: 'ppl',
      name: 'PPL',
      mode: ScheduleMode.rotation,
      days: [day('push'), day('pull'), day('legs')],
      rotation: ['push', 'pull', 'legs', null],
    );

    test('starts at the first slot with no history', () {
      expect(planToday(routine: r, history: [], now: d(2)).day?.id, 'push');
    });

    test('next slot after the last finished session', () {
      final p = planToday(routine: r, history: [done(r, 'push', d(2), slot: 0)], now: d(3));
      expect(p.day?.id, 'pull');
    });

    test('cycle waits when days are missed', () {
      final p = planToday(routine: r, history: [done(r, 'push', d(2), slot: 0)], now: d(7));
      expect(p.day?.id, 'pull');
    });

    test('rest slot falls on the day after the last workout of the cycle', () {
      final history = [done(r, 'legs', d(4), slot: 2)];
      final rest = planToday(routine: r, history: history, now: d(5));
      expect(rest.status, PlanStatus.rest);
      expect(rest.nextDay?.id, 'push');
      expect(rest.nextDate, DateTime(2026, 11, 6));
      // Rest day passed: back to push.
      expect(planToday(routine: r, history: history, now: d(6)).day?.id, 'push');
      // Rest days in the past are used up, workout waits.
      expect(planToday(routine: r, history: history, now: d(9)).day?.id, 'push');
    });

    test('done today forecasts from the following slot', () {
      final p = planToday(routine: r, history: [done(r, 'pull', d(3, 7), slot: 1)], now: d(3, 19));
      expect(p.status, PlanStatus.done);
      expect(p.week.map((e) => e.day?.id).take(4).toList(), ['pull', 'legs', null, 'push']);
      expect(p.nextDay?.id, 'legs');
    });

    test('repeated day ids use the stored slot index', () {
      final r2 = Routine(
        id: 'ul',
        name: 'UL',
        mode: ScheduleMode.rotation,
        days: [day('upper'), day('lower')],
        rotation: ['upper', 'lower', null, 'upper', 'lower', null, null],
      );
      final history = [done(r2, 'lower', d(6), slot: 4)];
      final p = planToday(routine: r2, history: history, now: d(7));
      expect(p.status, PlanStatus.rest);
      // Two rest slots (index 5, 6) then upper.
      expect(planToday(routine: r2, history: history, now: d(9)).day?.id, 'upper');
      expect(planToday(routine: r2, history: history, now: d(9)).slotIndex, 0);
    });

    test('weekdays routine with nothing pinned falls back to rotation', () {
      final r3 = Routine(id: 'x', name: 'x', days: [day('a'), day('b')]);
      expect(planToday(routine: r3, history: [done(r3, 'a', d(2))], now: d(3)).day?.id, 'b');
    });
  });

  test('no routine and empty routine', () {
    expect(planToday(routine: null, history: [], now: d(2)).status, PlanStatus.noRoutine);
    expect(planToday(routine: Routine(name: 'e'), history: [], now: d(2)).status,
        PlanStatus.emptyRoutine);
  });
}
