// Exercise library item from JSON
class ExerciseLibraryItem {
  final String id;
  final String name;
  final String muscleGroup;

  const ExerciseLibraryItem({
    required this.id,
    required this.name,
    required this.muscleGroup,
  });

  factory ExerciseLibraryItem.fromJson(Map<String, dynamic> json) {
    return ExerciseLibraryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      muscleGroup: json['muscleGroup'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
      };

  ExerciseLibraryItem copyWith(
      {String? id, String? name, String? muscleGroup}) {
    return ExerciseLibraryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
    );
  }
}

// An exercise with target sets inside a day
class ExerciseInDay {
  final String exerciseId;
  final int targetSets;

  const ExerciseInDay({required this.exerciseId, this.targetSets = 3});

  ExerciseInDay copyWith({String? exerciseId, int? targetSets}) {
    return ExerciseInDay(
      exerciseId: exerciseId ?? this.exerciseId,
      targetSets: targetSets ?? this.targetSets,
    );
  }

  Map<String, dynamic> toJson() =>
      {'exerciseId': exerciseId, 'targetSets': targetSets};
  factory ExerciseInDay.fromJson(Map<String, dynamic> json) {
    return ExerciseInDay(
      exerciseId: json['exerciseId'] as String,
      targetSets: (json['targetSets'] as num?)?.toInt() ?? 3,
    );
  }
}

class Day {
  final String id;
  final String name;
  final List<ExerciseInDay> exercises;

  const Day({required this.id, required this.name, required this.exercises});

  Day copyWith({String? id, String? name, List<ExerciseInDay>? exercises}) {
    return Day(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Day.fromJson(Map<String, dynamic> json) {
    return Day(
      id: json['id'] as String,
      name: json['name'] as String,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => ExerciseInDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Routine {
  final String id;
  final String name;
  final List<Day> days;

  const Routine({required this.id, required this.name, required this.days});

  Routine copyWith({String? id, String? name, List<Day>? days}) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      days: days ?? this.days,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      days: (json['days'] as List<dynamic>)
          .map((d) => Day.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Rep logging types
enum SetType { normal, negative, drop, forced }

class SetLog {
  final double weight; // kg
  final int reps;
  final SetType type;

  const SetLog(
      {required this.weight, required this.reps, this.type = SetType.normal});

  SetLog copyWith({double? weight, int? reps, SetType? type}) {
    return SetLog(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'type': type.index,
      };

  factory SetLog.fromJson(Map<String, dynamic> json) {
    return SetLog(
      weight: (json['weight'] as num).toDouble(),
      reps: (json['reps'] as num).toInt(),
      type: SetType.values[json['type'] as int? ?? 0],
    );
  }
}

class ExerciseLog {
  final String exerciseId;
  final List<SetLog> sets;

  const ExerciseLog({required this.exerciseId, this.sets = const []});

  ExerciseLog copyWith({String? exerciseId, List<SetLog>? sets}) {
    return ExerciseLog(
      exerciseId: exerciseId ?? this.exerciseId,
      sets: sets ?? this.sets,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    return ExerciseLog(
      exerciseId: json['exerciseId'] as String,
      sets: (json['sets'] as List<dynamic>)
          .map((s) => SetLog.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WorkoutLog {
  final String id;
  final DateTime date;
  final String routineId;
  final String dayId;
  final List<ExerciseLog> exercises;

  const WorkoutLog({
    required this.id,
    required this.date,
    required this.routineId,
    required this.dayId,
    this.exercises = const [],
  });

  WorkoutLog copyWith({
    String? id,
    DateTime? date,
    String? routineId,
    String? dayId,
    List<ExerciseLog>? exercises,
  }) {
    return WorkoutLog(
      id: id ?? this.id,
      date: date ?? this.date,
      routineId: routineId ?? this.routineId,
      dayId: dayId ?? this.dayId,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'routineId': routineId,
        'dayId': dayId,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      routineId: json['routineId'] as String,
      dayId: json['dayId'] as String,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Measurement {
  final String id;
  final DateTime date;
  final String bodyPart; // e.g., Biceps, Chest
  final double value; // in cm or inches
  final bool isMetric; // true = cm, false = inches

  const Measurement({
    required this.id,
    required this.date,
    required this.bodyPart,
    required this.value,
    this.isMetric = true,
  });

  Measurement copyWith({
    String? id,
    DateTime? date,
    String? bodyPart,
    double? value,
    bool? isMetric,
  }) {
    return Measurement(
      id: id ?? this.id,
      date: date ?? this.date,
      bodyPart: bodyPart ?? this.bodyPart,
      value: value ?? this.value,
      isMetric: isMetric ?? this.isMetric,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'bodyPart': bodyPart,
        'value': value,
        'isMetric': isMetric,
      };

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      bodyPart: json['bodyPart'] as String,
      value: (json['value'] as num).toDouble(),
      isMetric: json['isMetric'] as bool? ?? true,
    );
  }
}

class Challenge {
  final String id;
  final String name;
  final String description;
  final int target; // e.g. 100 push-ups
  final int progress;
  final int daysLeft;

  const Challenge({
    required this.id,
    required this.name,
    required this.description,
    required this.target,
    required this.progress,
    required this.daysLeft,
  });

  Challenge copyWith({
    String? id,
    String? name,
    String? description,
    int? target,
    int? progress,
    int? daysLeft,
  }) {
    return Challenge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      daysLeft: daysLeft ?? this.daysLeft,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'target': target,
        'progress': progress,
        'daysLeft': daysLeft,
      };

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      target: (json['target'] as num).toInt(),
      progress: (json['progress'] as num).toInt(),
      daysLeft: (json['daysLeft'] as num).toInt(),
    );
  }
}

class UserProfile {
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime memberSince;
  final int streak;
  final int totalWorkouts;
  final bool onboardingComplete;

  const UserProfile({
    required this.name,
    required this.email,
    this.photoUrl,
    required this.memberSince,
    this.streak = 0,
    this.totalWorkouts = 0,
    this.onboardingComplete = false,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
    DateTime? memberSince,
    int? streak,
    int? totalWorkouts,
    bool? onboardingComplete,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      memberSince: memberSince ?? this.memberSince,
      streak: streak ?? this.streak,
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'memberSince': memberSince.toIso8601String(),
        'streak': streak,
        'totalWorkouts': totalWorkouts,
        'onboardingComplete': onboardingComplete,
      };
}
