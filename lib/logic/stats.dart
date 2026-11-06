import 'dart:math' as math;

import '../models/workout.dart';
import '../util/ids.dart';

/// Epley estimate of a one-rep max.
double estimateOneRepMax(double weight, int reps) {
  if (reps <= 0 || weight <= 0) return 0;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}

/// The sets logged for [exerciseId] in the most recent finished session,
/// ignoring [excludeSessionId]. Empty when the exercise was never done.
List<SetEntry> previousSets(
  String exerciseId,
  List<WorkoutSession> history, {
  String? excludeSessionId,
}) {
  WorkoutSession? best;
  for (final s in history) {
    if (s.end == null || s.id == excludeSessionId) continue;
    if (!s.exercises.any((e) => e.exerciseId == exerciseId && e.doneSets > 0)) continue;
    if (best == null || s.start.isAfter(best.start)) best = s;
  }
  if (best == null) return const [];
  return best.exercises
      .where((e) => e.exerciseId == exerciseId)
      .expand((e) => e.sets)
      .where((s) => s.done)
      .toList();
}

class ExerciseBests {
  final double maxWeight;
  final double bestE1rm;
  final double bestSetVolume;
  const ExerciseBests(this.maxWeight, this.bestE1rm, this.bestSetVolume);
  static const zero = ExerciseBests(0, 0, 0);
}

ExerciseBests bestsFor(String exerciseId, Iterable<WorkoutSession> sessions) {
  var w = 0.0, e = 0.0, v = 0.0;
  for (final s in sessions) {
    for (final ex in s.exercises.where((x) => x.exerciseId == exerciseId)) {
      for (final set in ex.sets.where((x) => x.countsForStats)) {
        final weight = set.weight ?? 0;
        final reps = set.reps ?? 0;
        w = math.max(w, weight);
        e = math.max(e, estimateOneRepMax(weight, reps));
        v = math.max(v, weight * reps);
      }
    }
  }
  return ExerciseBests(w, e, v);
}

/// Records [session] beats compared to all earlier finished sessions.
/// An exercise needs at least one earlier session to count as a record.
List<PersonalRecord> detectRecords(WorkoutSession session, List<WorkoutSession> history) {
  final earlier = history
      .where((s) => s.id != session.id && s.end != null && s.start.isBefore(session.start))
      .toList();
  final records = <PersonalRecord>[];
  final seen = <String>{};
  for (final ex in session.exercises) {
    if (!seen.add(ex.exerciseId)) continue;
    final hadBefore = earlier.any((s) => s.exercises.any((e) => e.exerciseId == ex.exerciseId && e.doneSets > 0));
    if (!hadBefore) continue;
    final before = bestsFor(ex.exerciseId, earlier);
    final now = bestsFor(ex.exerciseId, [session]);
    if (now.maxWeight > before.maxWeight) {
      records.add(PersonalRecord(ex.exerciseId, 'weight', now.maxWeight));
    }
    if (now.bestE1rm > before.bestE1rm + 0.01) {
      records.add(PersonalRecord(ex.exerciseId, 'e1rm', now.bestE1rm));
    }
    if (now.bestSetVolume > before.bestSetVolume) {
      records.add(PersonalRecord(ex.exerciseId, 'volume', now.bestSetVolume));
    }
  }
  return records;
}

DateTime weekStart(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - DateTime.monday));

/// Consecutive Monday-based weeks in which the user trained at least
/// [weeklyTarget] distinct days. The current week counts once the target is
/// met; until then the streak is carried from previous weeks.
int weeklyStreak(List<WorkoutSession> sessions, int weeklyTarget, DateTime now) {
  if (weeklyTarget <= 0) return 0;
  final daysByWeek = <DateTime, Set<String>>{};
  for (final s in sessions.where((s) => s.end != null)) {
    daysByWeek.putIfAbsent(weekStart(s.start), () => {}).add(dayKey(s.start));
  }
  bool met(DateTime w) => (daysByWeek[w]?.length ?? 0) >= weeklyTarget;

  var week = weekStart(now);
  var streak = 0;
  if (met(week)) streak++;
  week = week.subtract(const Duration(days: 7));
  while (met(week)) {
    streak++;
    week = week.subtract(const Duration(days: 7));
  }
  return streak;
}

/// Sets per primary muscle for sessions in [from, to).
Map<String, int> setsPerMuscle(
  List<WorkoutSession> sessions,
  String Function(String exerciseId) muscleOf,
  DateTime from,
  DateTime to,
) {
  final out = <String, int>{};
  for (final s in sessions) {
    if (s.end == null || s.start.isBefore(from) || !s.start.isBefore(to)) continue;
    for (final e in s.exercises) {
      final n = e.doneSets;
      if (n == 0) continue;
      final m = muscleOf(e.exerciseId);
      out[m] = (out[m] ?? 0) + n;
    }
  }
  return out;
}

/// True when every working set hit the top of the rep range last time, so the
/// user should add weight.
bool shouldProgress(List<SetEntry> previous, int? repMax) {
  if (repMax == null) return false;
  final working = previous.where((s) => s.countsForStats).toList();
  return working.isNotEmpty && working.every((s) => (s.reps ?? 0) >= repMax);
}
