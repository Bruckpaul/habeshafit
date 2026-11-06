import '../util/ids.dart';

enum SetKind { warmup, normal, drop, failure }

extension SetKindLabel on SetKind {
  /// Short label shown in the set column (W, D, F); normal sets show a number.
  String get short => switch (this) {
        SetKind.warmup => 'W',
        SetKind.drop => 'D',
        SetKind.failure => 'F',
        SetKind.normal => '',
      };

  String get label => switch (this) {
        SetKind.warmup => 'Warm-up',
        SetKind.drop => 'Drop set',
        SetKind.failure => 'Failure',
        SetKind.normal => 'Working set',
      };
}

class SetEntry {
  /// Weight in kg. Null until the user enters or confirms a value.
  double? weight;
  /// Reps done on your own.
  int? reps;

  /// Extra reps done with a spotter's help (forced reps). Not counted in
  /// records, 1RM estimates or volume, so those stay honest.
  int assisted;
  SetKind kind;
  bool done;

  SetEntry({this.weight, this.reps, this.assisted = 0, this.kind = SetKind.normal, this.done = false});

  bool get countsForStats => done && kind != SetKind.warmup && (reps ?? 0) > 0;
  double get volume => countsForStats ? (weight ?? 0) * (reps ?? 0) : 0;

  /// `5` or `5+1` when assisted reps were added.
  String get repsLabel => assisted > 0 ? '${reps ?? 0}+$assisted' : '${reps ?? 0}';

  factory SetEntry.fromJson(Map<String, Object?> j) => SetEntry(
        weight: (j['weight'] as num?)?.toDouble(),
        reps: (j['reps'] as num?)?.toInt(),
        assisted: (j['assisted'] as num?)?.toInt() ?? 0,
        kind: SetKind.values.byName((j['kind'] as String?) ?? 'normal'),
        done: (j['done'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() =>
      {'weight': weight, 'reps': reps, 'assisted': assisted, 'kind': kind.name, 'done': done};
}

class ExerciseEntry {
  final String id;
  String exerciseId;
  List<SetEntry> sets;
  int restSeconds;
  int? repMin;
  int? repMax;
  String notes;

  ExerciseEntry({
    String? id,
    required this.exerciseId,
    List<SetEntry>? sets,
    this.restSeconds = 90,
    this.repMin,
    this.repMax,
    this.notes = '',
  })  : id = id ?? newId('ex'),
        sets = sets ?? [];

  String? get repTarget => repMin == null
      ? null
      : (repMin == repMax || repMax == null ? '$repMin' : '$repMin–$repMax');

  int get doneSets => sets.where((s) => s.countsForStats).length;
  double get volume => sets.fold(0.0, (s, e) => s + e.volume);

  factory ExerciseEntry.fromJson(Map<String, Object?> j) => ExerciseEntry(
        id: j['id'] as String?,
        exerciseId: j['exerciseId'] as String,
        sets: ((j['sets'] as List?) ?? const [])
            .map((e) => SetEntry.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
        restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 90,
        repMin: (j['repMin'] as num?)?.toInt(),
        repMax: (j['repMax'] as num?)?.toInt(),
        notes: (j['notes'] as String?) ?? '',
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'sets': sets.map((s) => s.toJson()).toList(),
        'restSeconds': restSeconds,
        'repMin': repMin,
        'repMax': repMax,
        'notes': notes,
      };
}

/// A personal record achieved in a session.
class PersonalRecord {
  final String exerciseId;
  final String type; // 'weight' | 'e1rm' | 'volume'
  final double value;
  const PersonalRecord(this.exerciseId, this.type, this.value);

  String get label => switch (type) {
        'weight' => 'Heaviest weight',
        'e1rm' => 'Best est. 1RM',
        _ => 'Best set volume',
      };

  factory PersonalRecord.fromJson(Map<String, Object?> j) => PersonalRecord(
      j['exerciseId'] as String, j['type'] as String, (j['value'] as num).toDouble());
  Map<String, Object?> toJson() =>
      {'exerciseId': exerciseId, 'type': type, 'value': value};
}

class WorkoutSession {
  final String id;
  String name;
  String? routineId;
  String? dayId;

  /// Index of the rotation slot this session filled (rotation routines only).
  int? slotIndex;
  DateTime start;
  DateTime? end;
  List<ExerciseEntry> exercises;
  String notes;
  List<PersonalRecord> records;

  WorkoutSession({
    String? id,
    required this.name,
    this.routineId,
    this.dayId,
    this.slotIndex,
    DateTime? start,
    this.end,
    List<ExerciseEntry>? exercises,
    this.notes = '',
    List<PersonalRecord>? records,
  })  : id = id ?? newId('session'),
        start = start ?? DateTime.now(),
        exercises = exercises ?? [],
        records = records ?? [];

  bool get isFromRoutine => routineId != null;
  Duration get duration => (end ?? DateTime.now()).difference(start);
  double get volume => exercises.fold(0.0, (s, e) => s + e.volume);
  int get doneSets => exercises.fold(0, (s, e) => s + e.doneSets);
  int get totalSets => exercises.fold(0, (s, e) => s + e.sets.length);

  WorkoutSession copy() => WorkoutSession.fromJson(toJson());

  factory WorkoutSession.fromJson(Map<String, Object?> j) => WorkoutSession(
        id: j['id'] as String,
        name: j['name'] as String,
        routineId: j['routineId'] as String?,
        dayId: j['dayId'] as String?,
        slotIndex: (j['slotIndex'] as num?)?.toInt(),
        start: DateTime.parse(j['start'] as String),
        end: j['end'] == null ? null : DateTime.parse(j['end'] as String),
        exercises: ((j['exercises'] as List?) ?? const [])
            .map((e) => ExerciseEntry.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
        notes: (j['notes'] as String?) ?? '',
        records: ((j['records'] as List?) ?? const [])
            .map((e) => PersonalRecord.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'routineId': routineId,
        'dayId': dayId,
        'slotIndex': slotIndex,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'notes': notes,
        'records': records.map((r) => r.toJson()).toList(),
      };
}
