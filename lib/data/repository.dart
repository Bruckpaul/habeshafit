import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../models/exercise.dart';
import '../models/profile.dart';
import '../models/routine.dart';
import '../models/workout.dart';
import 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';

typedef Json = Map<String, Object?>;

/// Local, offline-first storage. Every record is a JSON document keyed by id.
class Repository {
  final Database db;
  Repository(this.db);

  static const _dbName = 'habeshafit.db';
  static const schemaVersion = 1;

  static Future<Repository> open() async => Repository(await openAppDatabase(_dbName));

  final _routines = stringMapStoreFactory.store('routines');
  final _sessions = stringMapStoreFactory.store('sessions');
  final _measurements = stringMapStoreFactory.store('measurements');
  final _customExercises = stringMapStoreFactory.store('custom_exercises');
  final _meta = stringMapStoreFactory.store('meta');

  static Json _copy(Object? v) => Map<String, Object?>.from(
      jsonDecode(jsonEncode(v)) as Map); // deep, mutable copy

  // ---- profile & active session --------------------------------------------

  Future<UserProfile?> loadProfile() async {
    final v = await _meta.record('profile').get(db);
    return v == null ? null : UserProfile.fromJson(_copy(v));
  }

  Future<void> saveProfile(UserProfile p) =>
      _meta.record('profile').put(db, p.toJson());

  Future<WorkoutSession?> loadActiveSession() async {
    final v = await _meta.record('active_session').get(db);
    return v == null ? null : WorkoutSession.fromJson(_copy(v));
  }

  Future<void> saveActiveSession(WorkoutSession? s) => s == null
      ? _meta.record('active_session').delete(db)
      : _meta.record('active_session').put(db, s.toJson());

  // ---- routines ------------------------------------------------------------

  Future<List<Routine>> loadRoutines() async => (await _routines.find(db))
      .map((r) => Routine.fromJson(_copy(r.value)))
      .toList();

  Future<void> saveRoutine(Routine r) => _routines.record(r.id).put(db, r.toJson());
  Future<void> deleteRoutine(String id) => _routines.record(id).delete(db);

  // ---- sessions ------------------------------------------------------------

  Future<List<WorkoutSession>> loadSessions() async => (await _sessions.find(db,
          finder: Finder(sortOrders: [SortOrder('start', false)])))
      .map((r) => WorkoutSession.fromJson(_copy(r.value)))
      .toList();

  Future<void> saveSession(WorkoutSession s) =>
      _sessions.record(s.id).put(db, s.toJson());
  Future<void> deleteSession(String id) => _sessions.record(id).delete(db);

  // ---- measurements --------------------------------------------------------

  Future<List<Measurement>> loadMeasurements() async =>
      (await _measurements.find(db, finder: Finder(sortOrders: [SortOrder('date', false)])))
          .map((r) => Measurement.fromJson(_copy(r.value)))
          .toList();

  Future<void> saveMeasurement(Measurement m) =>
      _measurements.record(m.id).put(db, m.toJson());
  Future<void> deleteMeasurement(String id) => _measurements.record(id).delete(db);

  // ---- custom exercises ----------------------------------------------------

  Future<List<Exercise>> loadCustomExercises() async =>
      (await _customExercises.find(db))
          .map((r) => Exercise.fromJson(_copy(r.value)))
          .toList();

  Future<void> saveCustomExercise(Exercise e) =>
      _customExercises.record(e.id).put(db, e.toJson());

  // ---- backup --------------------------------------------------------------

  Future<String> exportJson() async {
    final data = {
      'app': 'habeshafit',
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': (await _meta.record('profile').get(db)),
      'routines': (await _routines.find(db)).map((r) => r.value).toList(),
      'sessions': (await _sessions.find(db)).map((r) => r.value).toList(),
      'measurements': (await _measurements.find(db)).map((r) => r.value).toList(),
      'customExercises': (await _customExercises.find(db)).map((r) => r.value).toList(),
    };
    return const JsonEncoder.withIndent(' ').convert(data);
  }

  /// Replaces all data with the contents of a backup. Throws [FormatException]
  /// when the text is not a HabeshaFit backup.
  Future<void> importJson(String text) async {
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['app'] != 'habeshafit') {
      throw const FormatException('Not a HabeshaFit backup');
    }
    // Parse everything first so a bad file changes nothing.
    final routines = ((decoded['routines'] as List?) ?? const [])
        .map((e) => Routine.fromJson(_copy(e)))
        .toList();
    final sessions = ((decoded['sessions'] as List?) ?? const [])
        .map((e) => WorkoutSession.fromJson(_copy(e)))
        .toList();
    final measurements = ((decoded['measurements'] as List?) ?? const [])
        .map((e) => Measurement.fromJson(_copy(e)))
        .toList();
    final custom = ((decoded['customExercises'] as List?) ?? const [])
        .map((e) => Exercise.fromJson(_copy(e)))
        .toList();
    final profile = decoded['profile'] == null
        ? null
        : UserProfile.fromJson(_copy(decoded['profile']));

    await db.transaction((txn) async {
      for (final store in [_routines, _sessions, _measurements, _customExercises, _meta]) {
        await store.delete(txn);
      }
      for (final r in routines) {
        await _routines.record(r.id).put(txn, r.toJson());
      }
      for (final s in sessions) {
        await _sessions.record(s.id).put(txn, s.toJson());
      }
      for (final m in measurements) {
        await _measurements.record(m.id).put(txn, m.toJson());
      }
      for (final e in custom) {
        await _customExercises.record(e.id).put(txn, e.toJson());
      }
      if (profile != null) await _meta.record('profile').put(txn, profile.toJson());
    });
  }

  Future<void> wipe() async {
    await db.transaction((txn) async {
      for (final store in [_routines, _sessions, _measurements, _customExercises, _meta]) {
        await store.delete(txn);
      }
    });
  }
}
