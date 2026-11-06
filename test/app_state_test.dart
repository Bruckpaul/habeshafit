import 'package:flutter_test/flutter_test.dart';
import 'package:habeshafit/data/repository.dart';
import 'package:habeshafit/models/exercise.dart';
import 'package:habeshafit/state/app_state.dart';
import 'package:sembast/sembast_memory.dart';

const lib = [
  Exercise(id: 'bench', name: 'Bench', primaryMuscles: ['chest']),
  Exercise(id: 'squat', name: 'Squat', primaryMuscles: ['quadriceps']),
];

Future<(AppState, Repository)> fresh() async {
  final db = await newDatabaseFactoryMemory().openDatabase('t.db');
  final repo = Repository(db);
  final state = AppState(repo);
  await state.load(libraryOverride: lib);
  return (state, repo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty workout: add, log, finish, and it is persisted', () async {
    final (state, repo) = await fresh();
    await state.startEmptyWorkout();
    expect(state.active, isNotNull);
    await state.addExercisesToActive(['bench']);
    final entry = state.active!.exercises.single;
    expect(entry.sets.length, 3);

    // Active session survives a restart.
    final reloaded = AppState(repo);
    await reloaded.load(libraryOverride: lib);
    expect(reloaded.active?.exercises.single.exerciseId, 'bench');

    entry.sets[0]
      ..weight = 60
      ..reps = 10;
    await state.toggleSetDone(entry, 0);
    expect(state.restEndsAt, isNotNull);
    final saved = await state.finishActive();
    expect(saved, isNotNull);
    expect(saved!.exercises.single.sets.length, 1, reason: 'unfinished sets dropped');
    expect(state.active, isNull);

    final again = AppState(repo);
    await again.load(libraryOverride: lib);
    expect(again.sessions.single.id, saved.id);
    expect(again.active, isNull);
  });

  test('finishing with nothing logged saves nothing', () async {
    final (state, _) = await fresh();
    await state.startEmptyWorkout();
    await state.addExercisesToActive(['bench']);
    expect(await state.finishActive(), isNull);
    expect(state.sessions, isEmpty);
  });

  test('checking an empty set copies the previous session', () async {
    final (state, _) = await fresh();
    await state.startEmptyWorkout();
    await state.addExercisesToActive(['squat']);
    var e = state.active!.exercises.single;
    e.sets[0]
      ..weight = 100
      ..reps = 5;
    await state.toggleSetDone(e, 0);
    await state.finishActive();

    await state.startEmptyWorkout();
    await state.addExercisesToActive(['squat']);
    e = state.active!.exercises.single;
    expect(e.sets.length, 1, reason: 'set count follows last session');
    await state.toggleSetDone(e, 0);
    expect(e.sets[0].weight, 100);
    expect(e.sets[0].reps, 5);
  });

  test('backup round trip', () async {
    final (state, repo) = await fresh();
    await state.updateProfile((p) => p.name = 'Bruck');
    await state.addMeasurement('bodyweight', 80);
    final json = await state.exportData();
    await state.resetAll();
    expect(state.measurements, isEmpty);
    await state.importData(json);
    expect(state.profile.name, 'Bruck');
    expect(state.measurements.single.value, 80);
    expect(() => repo.importJson('{"x":1}'), throwsFormatException);
  });
}
