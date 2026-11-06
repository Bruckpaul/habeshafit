import 'package:flutter_test/flutter_test.dart';
import 'package:habeshafit/logic/stats.dart';
import 'package:habeshafit/models/workout.dart';

WorkoutSession s(DateTime at, List<(double, int)> sets, {String ex = 'bench'}) => WorkoutSession(
      name: 'w',
      start: at,
      end: at.add(const Duration(hours: 1)),
      exercises: [
        ExerciseEntry(exerciseId: ex, sets: [
          for (final (w, r) in sets) SetEntry(weight: w, reps: r, done: true),
        ])
      ],
    );

void main() {
  test('Epley 1RM', () {
    expect(estimateOneRepMax(100, 1), 100);
    expect(estimateOneRepMax(100, 10), closeTo(133.3, 0.1));
    expect(estimateOneRepMax(0, 5), 0);
  });

  test('previous sets come from the latest session with the exercise', () {
    final a = s(DateTime(2026, 11, 1), [(60, 10)]);
    final b = s(DateTime(2026, 11, 3), [(65, 8), (65, 7)]);
    final other = s(DateTime(2026, 11, 4), [(20, 10)], ex: 'curl');
    final prev = previousSets('bench', [a, other, b]);
    expect(prev.map((e) => e.weight), [65, 65]);
    expect(previousSets('bench', [a, b], excludeSessionId: b.id).single.weight, 60);
  });

  test('records need an earlier session and must beat it', () {
    final first = s(DateTime(2026, 11, 1), [(60, 10)]);
    expect(detectRecords(first, []), isEmpty);
    final heavier = s(DateTime(2026, 11, 3), [(70, 5)]);
    final types = detectRecords(heavier, [first]).map((r) => r.type).toSet();
    expect(types, containsAll(['weight']));
    expect(types.contains('volume'), isFalse); // 350 < 600
    final same = s(DateTime(2026, 11, 5), [(60, 10)]);
    expect(detectRecords(same, [first]), isEmpty);
  });

  test('weekly streak counts weeks that hit the target', () {
    final now = DateTime(2026, 11, 5); // Thursday
    final sessions = [
      // this week: 1 day (target 2, not met yet)
      s(DateTime(2026, 11, 3), [(1, 1)]),
      // last week: 2 days
      s(DateTime(2026, 10, 27), [(1, 1)]),
      s(DateTime(2026, 10, 29), [(1, 1)]),
      // two weeks ago: 2 sessions on the same day (counts once)
      s(DateTime(2026, 10, 20, 8), [(1, 1)]),
      s(DateTime(2026, 10, 20, 18), [(1, 1)]),
    ];
    expect(weeklyStreak(sessions, 2, now), 1);
    expect(weeklyStreak(sessions, 1, now), 3);
  });

  test('assisted reps are saved but ignored by records and volume', () {
    final set = SetEntry(weight: 100, reps: 5, assisted: 1, done: true);
    final back = SetEntry.fromJson(set.toJson());
    expect(back.assisted, 1);
    expect(back.repsLabel, '5+1');
    expect(back.volume, 500);
    expect(SetEntry.fromJson({'weight': 50, 'reps': 3}).assisted, 0, reason: 'old data loads');

    final before = s(DateTime(2026, 11, 1), [(100, 5)]);
    final assisted = WorkoutSession(
      name: 'w',
      start: DateTime(2026, 11, 3),
      end: DateTime(2026, 11, 3, 1),
      exercises: [ExerciseEntry(exerciseId: 'bench', sets: [set])],
    );
    expect(detectRecords(assisted, [before]), isEmpty);
  });

  test('progress hint when all working sets hit the top of the range', () {
    final sets = [SetEntry(weight: 60, reps: 12, done: true), SetEntry(weight: 60, reps: 12, done: true)];
    expect(shouldProgress(sets, 12), isTrue);
    sets.add(SetEntry(weight: 60, reps: 10, done: true));
    expect(shouldProgress(sets, 12), isFalse);
  });
}
