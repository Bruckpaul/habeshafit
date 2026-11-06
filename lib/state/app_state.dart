import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/repository.dart';
import '../logic/schedule.dart';
import '../logic/stats.dart';
import '../models/exercise.dart';
import '../models/profile.dart';
import '../models/routine.dart';
import '../models/workout.dart';
import '../util/ids.dart';

/// Single source of truth for the UI. Every change is written to the local
/// database before listeners are notified, so nothing is lost on app kill.
class AppState extends ChangeNotifier {
  final Repository repo;
  AppState(this.repo);

  bool loaded = false;
  UserProfile profile = UserProfile();
  List<Exercise> library = [];
  final Map<String, Exercise> _exerciseById = {};
  List<Routine> routines = [];

  /// Finished sessions, newest first.
  List<WorkoutSession> sessions = [];
  List<Measurement> measurements = [];

  /// The workout in progress, if any. Persisted on every change.
  WorkoutSession? active;

  /// Rest timer for the active workout (memory only).
  DateTime? restEndsAt;
  int restTotalSeconds = 0;

  /// Overridable clock for tests.
  DateTime Function() clock = DateTime.now;

  static Future<List<Exercise>> loadLibraryAsset() async {
    final raw = await rootBundle.loadString('assets/exercises.json');
    return (jsonDecode(raw) as List)
        .map((e) => Exercise.fromJson(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  Future<void> load({List<Exercise>? libraryOverride}) async {
    final lib = libraryOverride ?? await loadLibraryAsset();
    final custom = await repo.loadCustomExercises();
    library = [...custom, ...lib]..sort((a, b) => a.name.compareTo(b.name));
    _exerciseById
      ..clear()
      ..addEntries(library.map((e) => MapEntry(e.id, e)));
    profile = await repo.loadProfile() ?? UserProfile();
    routines = await repo.loadRoutines()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    sessions = await repo.loadSessions();
    measurements = await repo.loadMeasurements();
    active = await repo.loadActiveSession();
    loaded = true;
    notifyListeners();
  }

  // ---- lookups ---------------------------------------------------------------

  Exercise exercise(String id) =>
      _exerciseById[id] ?? Exercise(id: id, name: id.replaceAll('_', ' '));

  Routine? routineById(String? id) {
    for (final r in routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Routines the phone owner trains with (own + assigned by their coach).
  List<Routine> get myRoutines => routines.where((r) => r.isMine).toList();

  Routine? get activeRoutine {
    final r = routineById(profile.activeRoutineId);
    return (r == null || r.archived) ? null : r;
  }

  WorkoutSession? sessionById(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  TodayPlan get today => planToday(
        routine: activeRoutine,
        history: sessions,
        now: clock(),
        override: profile.dayOverrides[dayKey(clock())],
      );

  int get streakWeeks => weeklyStreak(sessions, profile.weeklyTarget, clock());

  List<SetEntry> previousFor(String exerciseId) =>
      previousSets(exerciseId, sessions, excludeSessionId: active?.id);

  /// Exercises the user logged most recently, newest first.
  List<String> get recentExerciseIds {
    final seen = <String>{};
    for (final s in sessions) {
      for (final e in s.exercises) {
        seen.add(e.exerciseId);
      }
      if (seen.length >= 20) break;
    }
    return seen.toList();
  }

  // ---- profile ---------------------------------------------------------------

  Future<void> updateProfile(void Function(UserProfile p) change) async {
    change(profile);
    // Drop overrides from past days.
    final todayKey = dayKey(clock());
    profile.dayOverrides.removeWhere((k, _) => k.compareTo(todayKey) < 0);
    await repo.saveProfile(profile);
    notifyListeners();
  }

  Future<void> setTodayOverride(String? dayIdOrRest) => updateProfile((p) {
        final k = dayKey(clock());
        if (dayIdOrRest == null) {
          p.dayOverrides.remove(k);
        } else {
          p.dayOverrides[k] = dayIdOrRest;
        }
      });

  // ---- routines --------------------------------------------------------------

  Future<void> saveRoutine(Routine r, {bool makeActive = false}) async {
    r.updatedAt = clock();
    final i = routines.indexWhere((x) => x.id == r.id);
    if (i == -1) {
      routines.add(r);
    } else {
      routines[i] = r;
    }
    await repo.saveRoutine(r);
    if (makeActive ||
        (r.isMine && (profile.activeRoutineId == null || routineById(profile.activeRoutineId) == null))) {
      profile.activeRoutineId = r.id;
      await repo.saveProfile(profile);
    }
    notifyListeners();
  }

  Future<void> setActiveRoutine(String? id) => updateProfile((p) => p.activeRoutineId = id);

  Future<void> deleteRoutine(String id) async {
    routines.removeWhere((r) => r.id == id);
    await repo.deleteRoutine(id);
    if (profile.activeRoutineId == id) {
      profile.activeRoutineId = routines.where((r) => !r.archived && r.isMine).firstOrNull?.id;
      await repo.saveProfile(profile);
    }
    notifyListeners();
  }

  Future<Routine> duplicateRoutine(Routine r) async {
    // A copy is always the owner's own, editable routine.
    final json = r.toJson()
      ..remove('id')
      ..['coachId'] = null
      ..['coachName'] = null
      ..['clientId'] = null
      ..['name'] = '${r.name} (copy)'
      ..['createdAt'] = clock().toIso8601String()
      ..['updatedAt'] = clock().toIso8601String();
    final copy = Routine.fromJson({...json, 'id': newId('routine')});
    await saveRoutine(copy);
    return copy;
  }

  Future<void> setArchived(Routine r, bool archived) async {
    r.archived = archived;
    await saveRoutine(r);
    if (archived && profile.activeRoutineId == r.id) {
      await setActiveRoutine(routines.where((x) => !x.archived && x.isMine).firstOrNull?.id);
    }
  }

  // ---- custom exercises -----------------------------------------------------

  Future<Exercise> addCustomExercise({
    required String name,
    required String muscle,
    required String equipment,
  }) async {
    final e = Exercise(
      id: newId('custom'),
      name: name,
      equipment: equipment,
      primaryMuscles: [muscle],
      isCustom: true,
    );
    await repo.saveCustomExercise(e);
    library = [e, ...library]..sort((a, b) => a.name.compareTo(b.name));
    _exerciseById[e.id] = e;
    notifyListeners();
    return e;
  }

  // ---- active workout -------------------------------------------------------

  ExerciseEntry _entryFor(String exerciseId, {PlannedExercise? plan}) {
    final prev = previousSets(exerciseId, sessions).where((s) => s.kind != SetKind.warmup).toList();
    final count = plan?.sets ?? (prev.isEmpty ? 3 : prev.length);
    return ExerciseEntry(
      exerciseId: exerciseId,
      restSeconds: plan?.restSeconds ?? profile.defaultRestSeconds,
      repMin: plan?.repMin,
      repMax: plan?.repMax,
      notes: plan?.notes ?? '',
      sets: List.generate(count, (_) => SetEntry()),
    );
  }

  Future<void> startRoutineWorkout(Routine routine, RoutineDay day, {int? slotIndex}) async {
    if (active != null) return;
    active = WorkoutSession(
      name: day.name,
      routineId: routine.id,
      dayId: day.id,
      slotIndex: slotIndex,
      start: clock(),
      exercises: [for (final p in day.exercises) _entryFor(p.exerciseId, plan: p)],
    );
    await _saveActive();
  }

  Future<void> startEmptyWorkout() async {
    if (active != null) return;
    final h = clock().hour;
    final part = h < 11 ? 'Morning' : (h < 17 ? 'Afternoon' : 'Evening');
    active = WorkoutSession(name: '$part workout', start: clock());
    await _saveActive();
  }

  Future<void> _saveActive() async {
    await repo.saveActiveSession(active);
    notifyListeners();
  }

  /// Apply [change] to the active session and persist it.
  Future<void> editActive(void Function(WorkoutSession s) change) async {
    final s = active;
    if (s == null) return;
    change(s);
    await _saveActive();
  }

  Future<void> addExercisesToActive(List<String> ids) =>
      editActive((s) => s.exercises.addAll(ids.map((id) => _entryFor(id))));

  /// Marks a set done/undone. Filling an empty set copies the previous
  /// session's values (the grey hint) and starts the rest timer.
  Future<void> toggleSetDone(ExerciseEntry entry, int index) async {
    final set = entry.sets[index];
    if (!set.done) {
      if (set.weight == null || set.reps == null) {
        final prev = previousFor(entry.exerciseId);
        final hint = index < prev.length ? prev[index] : (prev.isNotEmpty ? prev.last : null);
        set.weight ??= hint?.weight ?? (index > 0 ? entry.sets[index - 1].weight : null) ?? 0;
        set.reps ??= hint?.reps ?? (index > 0 ? entry.sets[index - 1].reps : null) ?? entry.repMax ?? entry.repMin;
      }
      if ((set.reps ?? 0) <= 0) return; // nothing to log
      set.done = true;
      startRest(entry.restSeconds);
    } else {
      set.done = false;
    }
    await _saveActive();
  }

  void startRest(int seconds) {
    if (seconds <= 0) return;
    restTotalSeconds = seconds;
    restEndsAt = clock().add(Duration(seconds: seconds));
    notifyListeners();
  }

  void adjustRest(int deltaSeconds) {
    final end = restEndsAt;
    if (end == null) return;
    restEndsAt = end.add(Duration(seconds: deltaSeconds));
    restTotalSeconds = (restTotalSeconds + deltaSeconds).clamp(1, 3600);
    if (!restEndsAt!.isAfter(clock())) restEndsAt = null;
    notifyListeners();
  }

  void stopRest() {
    restEndsAt = null;
    notifyListeners();
  }

  Future<void> discardActive() async {
    active = null;
    restEndsAt = null;
    await repo.saveActiveSession(null);
    notifyListeners();
  }

  /// Saves the active workout. Unfinished sets are dropped, as are exercises
  /// left with no completed sets. Returns the saved session, or null when
  /// nothing was logged.
  Future<WorkoutSession?> finishActive() async {
    final s = active;
    if (s == null) return null;
    for (final e in s.exercises) {
      e.sets.removeWhere((x) => !x.done);
    }
    s.exercises.removeWhere((e) => e.sets.isEmpty);
    active = null;
    restEndsAt = null;
    await repo.saveActiveSession(null);
    if (s.exercises.isEmpty) {
      notifyListeners();
      return null;
    }
    s.end = clock();
    s.records = detectRecords(s, sessions);
    sessions.insert(0, s);
    await repo.saveSession(s);
    // Today's swap/skip is used up once the workout is done.
    profile.dayOverrides.remove(dayKey(clock()));
    await repo.saveProfile(profile);
    notifyListeners();
    return s;
  }

  // ---- history ---------------------------------------------------------------

  Future<void> saveSession(WorkoutSession s) async {
    final i = sessions.indexWhere((x) => x.id == s.id);
    if (i == -1) {
      sessions.add(s);
    } else {
      sessions[i] = s;
    }
    sessions.sort((a, b) => b.start.compareTo(a.start));
    await repo.saveSession(s);
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    sessions.removeWhere((s) => s.id == id);
    await repo.deleteSession(id);
    notifyListeners();
  }

  /// Turns a finished (usually empty) workout into a routine.
  Future<Routine> routineFromSession(WorkoutSession s, String name) async {
    final day = RoutineDay(name: name, exercises: [
      for (final e in s.exercises)
        PlannedExercise(
          exerciseId: e.exerciseId,
          sets: e.sets.where((x) => x.kind != SetKind.warmup).length.clamp(1, 10),
          repMin: e.repMin ?? 8,
          repMax: e.repMax ?? 12,
          restSeconds: e.restSeconds,
        ),
    ]);
    final r = Routine(name: name, mode: ScheduleMode.rotation, days: [day], rotation: [day.id]);
    await saveRoutine(r);
    return r;
  }

  // ---- measurements ----------------------------------------------------------

  Future<void> addMeasurement(String type, double value, {DateTime? date}) async {
    final m = Measurement(id: newId('m'), date: date ?? clock(), type: type, value: value);
    measurements.insert(0, m);
    measurements.sort((a, b) => b.date.compareTo(a.date));
    await repo.saveMeasurement(m);
    notifyListeners();
  }

  Future<void> deleteMeasurement(String id) async {
    measurements.removeWhere((m) => m.id == id);
    await repo.deleteMeasurement(id);
    notifyListeners();
  }

  // ---- backup ----------------------------------------------------------------

  Future<String> exportData() => repo.exportJson();

  Future<void> importData(String json) async {
    await repo.importJson(json);
    await load(libraryOverride: library.where((e) => !e.isCustom).toList());
  }

  Future<void> resetAll() async {
    await repo.wipe();
    await load(libraryOverride: library.where((e) => !e.isCustom).toList());
  }
}
