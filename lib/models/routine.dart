import '../util/ids.dart';

/// How a routine decides which day is due.
enum ScheduleMode {
  /// Each day is pinned to weekdays (Mon = Upper, Tue = Lower...).
  weekdays,

  /// Days run in a cycle with optional rest slots; the cycle waits for you.
  rotation,
}

class PlannedExercise {
  String exerciseId;
  int sets;
  int repMin;
  int repMax;

  /// Target weight in kg, optional.
  double? targetWeight;
  int restSeconds;
  String notes;

  PlannedExercise({
    required this.exerciseId,
    this.sets = 3,
    this.repMin = 8,
    this.repMax = 12,
    this.targetWeight,
    this.restSeconds = 90,
    this.notes = '',
  });

  String get repLabel => repMin == repMax ? '$repMin' : '$repMin–$repMax';

  factory PlannedExercise.fromJson(Map<String, Object?> j) => PlannedExercise(
        exerciseId: j['exerciseId'] as String,
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        repMin: (j['repMin'] as num?)?.toInt() ?? 8,
        repMax: (j['repMax'] as num?)?.toInt() ?? 12,
        targetWeight: (j['targetWeight'] as num?)?.toDouble(),
        restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 90,
        notes: (j['notes'] as String?) ?? '',
      );

  Map<String, Object?> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'repMin': repMin,
        'repMax': repMax,
        'targetWeight': targetWeight,
        'restSeconds': restSeconds,
        'notes': notes,
      };
}

class RoutineDay {
  final String id;
  String name;
  List<PlannedExercise> exercises;

  /// ISO weekdays (1 = Monday ... 7 = Sunday) used in [ScheduleMode.weekdays].
  List<int> weekdays;

  RoutineDay({
    String? id,
    required this.name,
    List<PlannedExercise>? exercises,
    List<int>? weekdays,
  })  : id = id ?? newId('day'),
        exercises = exercises ?? [],
        weekdays = weekdays ?? [];

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets);

  /// Rough duration: ~45 s per set plus the planned rest.
  Duration get estimatedDuration => Duration(
        seconds: exercises.fold(
            0, (s, e) => s + e.sets * (45 + e.restSeconds)),
      );

  factory RoutineDay.fromJson(Map<String, Object?> j) => RoutineDay(
        id: j['id'] as String,
        name: j['name'] as String,
        exercises: ((j['exercises'] as List?) ?? const [])
            .map((e) => PlannedExercise.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
        weekdays: ((j['weekdays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'weekdays': weekdays,
      };
}

class Routine {
  final String id;
  String name;
  ScheduleMode mode;
  List<RoutineDay> days;

  /// Rotation slots: a day id, or `null` for a rest slot.
  List<String?> rotation;
  bool archived;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Set when a coach built this program. Clients can log it but not edit it.
  String? coachId;
  String? coachName;

  /// Whose program this is: null = the phone owner's own routine, otherwise a
  /// coach's client id (`me` = the phone owner as a client).
  String? clientId;

  bool get isCoachAssigned => coachId != null;

  /// Shown in the owner's Workouts tab.
  bool get isMine => clientId == null || clientId == 'me';

  Routine({
    String? id,
    required this.name,
    this.mode = ScheduleMode.weekdays,
    List<RoutineDay>? days,
    List<String?>? rotation,
    this.archived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.coachId,
    this.coachName,
    this.clientId,
  })  : id = id ?? newId('routine'),
        days = days ?? [],
        rotation = rotation ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  RoutineDay? dayById(String? id) {
    for (final d in days) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Rotation with deleted days removed; falls back to days in order.
  List<String?> get effectiveRotation {
    final ids = days.map((d) => d.id).toSet();
    final cleaned = rotation.where((s) => s == null || ids.contains(s)).toList();
    if (cleaned.every((s) => s == null)) return days.map((d) => d.id).toList();
    return cleaned;
  }

  Routine copy() => Routine.fromJson(toJson());

  factory Routine.fromJson(Map<String, Object?> j) => Routine(
        id: j['id'] as String,
        name: j['name'] as String,
        mode: ScheduleMode.values.byName((j['mode'] as String?) ?? 'weekdays'),
        days: ((j['days'] as List?) ?? const [])
            .map((e) => RoutineDay.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
        rotation: ((j['rotation'] as List?) ?? const [])
            .map((e) => e as String?)
            .toList(),
        archived: (j['archived'] as bool?) ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        coachId: j['coachId'] as String?,
        coachName: j['coachName'] as String?,
        clientId: j['clientId'] as String?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'mode': mode.name,
        'days': days.map((d) => d.toJson()).toList(),
        'rotation': rotation,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'coachId': coachId,
        'coachName': coachName,
        'clientId': clientId,
      };
}
