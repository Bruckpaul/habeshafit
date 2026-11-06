import '../models/routine.dart';
import '../models/workout.dart';
import '../util/ids.dart';

enum PlanStatus {
  /// No active routine selected.
  noRoutine,

  /// Active routine has no days yet.
  emptyRoutine,

  /// A workout is due today.
  workout,

  /// Today is a rest day.
  rest,

  /// A workout from the active routine was already finished today.
  done,
}

/// One calendar day in the forecast.
class PlannedDate {
  final DateTime date;
  final RoutineDay? day; // null = rest
  const PlannedDate(this.date, this.day);
}

class TodayPlan {
  final PlanStatus status;
  final Routine? routine;

  /// The workout due today ([PlanStatus.workout]).
  final RoutineDay? day;

  /// Rotation slot of [day], stored on the session so the cycle can advance.
  final int? slotIndex;

  /// Today's finished session ([PlanStatus.done]).
  final WorkoutSession? doneSession;

  /// Next planned workout after today.
  final RoutineDay? nextDay;
  final DateTime? nextDate;

  /// True when the user skipped or swapped today's workout.
  final bool overridden;

  /// Today plus the following six days.
  final List<PlannedDate> week;

  const TodayPlan({
    required this.status,
    this.routine,
    this.day,
    this.slotIndex,
    this.doneSession,
    this.nextDay,
    this.nextDate,
    this.overridden = false,
    this.week = const [],
  });
}

/// Works out what the user should train today.
///
/// * Weekdays mode: the day pinned to today's weekday; unpinned weekdays are
///   rest. Missed days are not carried forward. If no day has a weekday
///   pinned, the routine falls back to rotation behaviour.
/// * Rotation mode: the slot after the last finished one. Rest slots use up
///   calendar days; workout slots wait until they are done.
///
/// [override] is today's entry from `UserProfile.dayOverrides`: a day id to
/// swap in, or `'rest'` to skip.
TodayPlan planToday({
  required Routine? routine,
  required List<WorkoutSession> history,
  required DateTime now,
  String? override,
}) {
  if (routine == null) return const TodayPlan(status: PlanStatus.noRoutine);
  if (routine.days.isEmpty || routine.days.every((d) => d.exercises.isEmpty)) {
    return TodayPlan(status: PlanStatus.emptyRoutine, routine: routine);
  }

  final today = dateOnly(now);
  final finished = history
      .where((s) => s.routineId == routine.id && s.end != null)
      .toList()
    ..sort((a, b) => b.start.compareTo(a.start));
  WorkoutSession? doneToday;
  for (final s in finished) {
    if (sameDay(s.start, today)) {
      doneToday = s;
      break;
    }
  }

  final useWeekdays = routine.mode == ScheduleMode.weekdays &&
      routine.days.any((d) => d.weekdays.isNotEmpty);

  // Raw schedule for today and the forecast, before done/override handling.
  final List<PlannedDate> week;
  RoutineDay? scheduledToday;
  int? todaySlot;

  if (useWeekdays) {
    RoutineDay? dayFor(DateTime d) {
      for (final day in routine.days) {
        if (day.weekdays.contains(d.weekday)) return day;
      }
      return null;
    }

    week = [
      for (var i = 0; i < 7; i++)
        PlannedDate(today.add(Duration(days: i)), dayFor(today.add(Duration(days: i))))
    ];
    scheduledToday = week.first.day;
  } else {
    final slots = routine.effectiveRotation;
    final n = slots.length;
    final previous = finished.where((s) => !sameDay(s.start, today)).toList();

    int cursor; // slot index for `date`
    DateTime date;
    if (previous.isEmpty) {
      cursor = 0;
      date = today;
    } else {
      final last = previous.first;
      cursor = (_slotOf(last, slots) + 1) % n;
      date = dateOnly(last.start).add(const Duration(days: 1));
    }
    // Rest slots in the past are used up; workout slots wait.
    var guard = 0;
    while (slots[cursor] == null && date.isBefore(today) && guard++ < 1000) {
      cursor = (cursor + 1) % n;
      date = date.add(const Duration(days: 1));
    }

    int tomorrowCursor;
    if (doneToday != null) {
      final doneSlot = _slotOf(doneToday, slots);
      todaySlot = doneSlot >= 0 ? doneSlot : cursor;
      tomorrowCursor = (todaySlot + 1) % n;
    } else {
      todaySlot = cursor;
      tomorrowCursor = (cursor + 1) % n;
    }
    scheduledToday = routine.dayById(slots[todaySlot]);
    week = [
      PlannedDate(today, scheduledToday),
      for (var i = 1; i < 7; i++)
        PlannedDate(today.add(Duration(days: i)),
            routine.dayById(slots[(tomorrowCursor + i - 1) % n])),
    ];
  }

  PlannedDate? next;
  for (final p in week.skip(1)) {
    if (p.day != null) {
      next = p;
      break;
    }
  }

  if (doneToday != null) {
    return TodayPlan(
      status: PlanStatus.done,
      routine: routine,
      day: routine.dayById(doneToday.dayId),
      doneSession: doneToday,
      nextDay: next?.day,
      nextDate: next?.date,
      week: week,
    );
  }

  if (override != null) {
    if (override == 'rest') {
      return TodayPlan(
        status: PlanStatus.rest,
        routine: routine,
        nextDay: next?.day ?? scheduledToday,
        nextDate: next?.date ?? today.add(const Duration(days: 1)),
        overridden: true,
        week: week,
      );
    }
    final swapped = routine.dayById(override);
    if (swapped != null) {
      int? slot;
      if (!useWeekdays) {
        final slots = routine.effectiveRotation;
        // Nearest slot holding this day, starting from the expected one.
        for (var i = 0; i < slots.length; i++) {
          final idx = ((todaySlot ?? 0) + i) % slots.length;
          if (slots[idx] == swapped.id) {
            slot = idx;
            break;
          }
        }
      }
      return TodayPlan(
        status: PlanStatus.workout,
        routine: routine,
        day: swapped,
        slotIndex: slot,
        nextDay: next?.day,
        nextDate: next?.date,
        overridden: true,
        week: week,
      );
    }
  }

  if (scheduledToday == null) {
    return TodayPlan(
      status: PlanStatus.rest,
      routine: routine,
      nextDay: next?.day,
      nextDate: next?.date,
      week: week,
    );
  }
  return TodayPlan(
    status: PlanStatus.workout,
    routine: routine,
    day: scheduledToday,
    slotIndex: useWeekdays ? null : todaySlot,
    nextDay: next?.day,
    nextDate: next?.date,
    week: week,
  );
}

/// Slot a finished session filled; -1 when it no longer matches the rotation.
int _slotOf(WorkoutSession s, List<String?> slots) {
  final i = s.slotIndex;
  if (i != null && i >= 0 && i < slots.length && slots[i] == s.dayId) return i;
  return slots.indexOf(s.dayId);
}
