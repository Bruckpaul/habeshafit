import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/models.dart';

class DataProvider extends ChangeNotifier {
  // Exercise library loaded from assets
  List<ExerciseLibraryItem> exerciseLibrary = [];

  // User
  UserProfile user = UserProfile(
    name: 'Fit User',
    email: 'fit@habeshafit.com',
    memberSince: DateTime(2024, 6, 1),
    streak: 12,
    totalWorkouts: 47,
    onboardingComplete: false,
  );

  // Routines
  List<Routine> routines = [];

  // Workout logs
  List<WorkoutLog> workoutLogs = [];

  // Measurements
  List<Measurement> measurements = [];

  // Challenges
  List<Challenge> challenges = [];

  // Active session (during a workout)
  ActiveSession? activeSession;

  DataProvider({required List<ExerciseLibraryItem> mockExercises}) {
    exerciseLibrary = mockExercises;
    _initMockData();
  }

  static Future<List<ExerciseLibraryItem>> loadExercisesFromAssets() async {
    final jsonString = await rootBundle.loadString('assets/exercises.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .map((e) => ExerciseLibraryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _initMockData() {
    // Create some routines
    final pushDay = Day(
      id: 'd1',
      name: 'Push Day',
      exercises: [
        ExerciseInDay(exerciseId: 'ex1', targetSets: 4), // Bench Press
        ExerciseInDay(exerciseId: 'ex2', targetSets: 4),
        ExerciseInDay(exerciseId: 'ex3', targetSets: 3),
        ExerciseInDay(exerciseId: 'ex10', targetSets: 4), // OHP
        ExerciseInDay(exerciseId: 'ex16', targetSets: 3), // Skull Crusher
      ],
    );
    final pullDay = Day(
      id: 'd2',
      name: 'Pull Day',
      exercises: [
        ExerciseInDay(exerciseId: 'ex4', targetSets: 4), // Pull-up
        ExerciseInDay(exerciseId: 'ex5', targetSets: 4),
        ExerciseInDay(exerciseId: 'ex6', targetSets: 3),
        ExerciseInDay(exerciseId: 'ex13', targetSets: 3),
        ExerciseInDay(exerciseId: 'ex14', targetSets: 3),
      ],
    );
    final legDay = Day(
      id: 'd3',
      name: 'Leg Day',
      exercises: [
        ExerciseInDay(exerciseId: 'ex8', targetSets: 5),
        ExerciseInDay(exerciseId: 'ex7', targetSets: 3),
        ExerciseInDay(exerciseId: 'ex9', targetSets: 4),
        ExerciseInDay(exerciseId: 'ex21', targetSets: 4),
        ExerciseInDay(exerciseId: 'ex22', targetSets: 3),
      ],
    );

    routines = [
      Routine(
          id: 'r1', name: 'Push Pull Legs', days: [pushDay, pullDay, legDay]),
      Routine(
        id: 'r2',
        name: 'Upper Lower Split',
        days: [
          Day(id: 'd4', name: 'Upper', exercises: [
            ExerciseInDay(exerciseId: 'ex1', targetSets: 3),
            ExerciseInDay(exerciseId: 'ex5', targetSets: 3),
            ExerciseInDay(exerciseId: 'ex10', targetSets: 3),
            ExerciseInDay(exerciseId: 'ex13', targetSets: 3),
          ]),
          Day(id: 'd5', name: 'Lower', exercises: [
            ExerciseInDay(exerciseId: 'ex8', targetSets: 4),
            ExerciseInDay(exerciseId: 'ex9', targetSets: 4),
            ExerciseInDay(exerciseId: 'ex21', targetSets: 3),
          ]),
        ],
      ),
    ];

    // Generate some workout logs
    final now = DateTime.now();
    for (int i = 0; i < 14; i++) {
      final date = now.subtract(Duration(days: i));
      final routine = routines[i % routines.length];
      final day = routine.days[i % routine.days.length];
      final exerciseLogs = day.exercises.map((e) {
        return ExerciseLog(
          exerciseId: e.exerciseId,
          sets: List.generate(
            e.targetSets,
            (j) => SetLog(
              weight: 50.0 + (i * 2.5) + j * 5,
              reps: 8 + (j % 3),
              type: SetType.values[j % SetType.values.length],
            ),
          ),
        );
      }).toList();
      workoutLogs.add(WorkoutLog(
        id: 'log_$i',
        date: date,
        routineId: routine.id,
        dayId: day.id,
        exercises: exerciseLogs,
      ));
    }

    // Measurements
    final parts = ['Biceps', 'Chest', 'Waist', 'Thighs'];
    for (int i = 0; i < 6; i++) {
      for (final part in parts) {
        measurements.add(Measurement(
          id: 'm_${part}_$i',
          date: now.subtract(Duration(days: i * 7)),
          bodyPart: part,
          value: 30.0 + i + (part == 'Biceps' ? 2 : 0),
          isMetric: true,
        ));
      }
    }

    // Challenges
    challenges = [
      Challenge(
        id: 'c1',
        name: '100 Push-Ups',
        description: '100 push-ups a day for 30 days',
        target: 100,
        progress: 82,
        daysLeft: 12,
      ),
      Challenge(
        id: 'c2',
        name: '10K Steps Daily',
        description: 'Walk 10,000 steps every day',
        target: 10000,
        progress: 8500,
        daysLeft: 20,
      ),
    ];
  }

  // User onboarding
  void completeOnboarding() {
    user = user.copyWith(onboardingComplete: true);
    notifyListeners();
  }

  // Add routine
  void addRoutine(String name) {
    final newId = 'r${routines.length + 1}';
    routines.add(Routine(id: newId, name: name, days: []));
    notifyListeners();
  }

  // Add day to routine
  void addDayToRoutine(String routineId, String dayName) {
    final routineIndex = routines.indexWhere((r) => r.id == routineId);
    if (routineIndex == -1) return;
    final routine = routines[routineIndex];
    final newDay = Day(
      id: 'd${routine.days.length + 1}_$routineId',
      name: dayName,
      exercises: [],
    );
    routines[routineIndex] = routine.copyWith(days: [...routine.days, newDay]);
    notifyListeners();
  }

  // Add exercise to day
  void addExerciseToDay(String routineId, String dayId, String exerciseId) {
    final routineIndex = routines.indexWhere((r) => r.id == routineId);
    if (routineIndex == -1) return;
    final routine = routines[routineIndex];
    final dayIndex = routine.days.indexWhere((d) => d.id == dayId);
    if (dayIndex == -1) return;
    final day = routine.days[dayIndex];
    final updatedExercises = [
      ...day.exercises,
      ExerciseInDay(exerciseId: exerciseId, targetSets: 3),
    ];
    routines[routineIndex] = routine.copyWith(
      days: [
        for (int i = 0; i < routine.days.length; i++)
          if (i == dayIndex)
            day.copyWith(exercises: updatedExercises)
          else
            routine.days[i],
      ],
    );
    notifyListeners();
  }

  // Start an active workout session
  void startWorkout(Routine routine, Day day) {
    activeSession = ActiveSession(
      routine: routine,
      day: day,
      startTime: DateTime.now(),
      exerciseLogs: {},
    );
    notifyListeners();
  }

  // Log a set during active workout
  void logSet(String exerciseId, SetLog setLog) {
    if (activeSession == null) return;
    final logs = Map<String, List<SetLog>>.from(activeSession!.exerciseLogs);
    logs.putIfAbsent(exerciseId, () => []).add(setLog);
    activeSession = activeSession!.copyWith(exerciseLogs: logs);
    notifyListeners();
  }

  // Finish workout
  void finishWorkout() {
    if (activeSession == null) return;
    final session = activeSession!;
    final exerciseLogList = session.exerciseLogs.entries.map((e) {
      return ExerciseLog(exerciseId: e.key, sets: e.value);
    }).toList();
    final log = WorkoutLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      date: session.startTime,
      routineId: session.routine.id,
      dayId: session.day.id,
      exercises: exerciseLogList,
    );
    workoutLogs.insert(0, log);
    user = user.copyWith(
      totalWorkouts: user.totalWorkouts + 1,
      streak: user.streak + 1,
    );
    activeSession = null;
    notifyListeners();
  }

  // Add a measurement
  void addMeasurement(Measurement measurement) {
    measurements.insert(0, measurement);
    notifyListeners();
  }

  // Join challenge
  void joinChallenge(Challenge challenge) {
    challenges.add(challenge);
    notifyListeners();
  }
}

// Active session state
class ActiveSession {
  final Routine routine;
  final Day day;
  final DateTime startTime;
  final Map<String, List<SetLog>>
      exerciseLogs; // exerciseId -> list of logged sets

  const ActiveSession({
    required this.routine,
    required this.day,
    required this.startTime,
    required this.exerciseLogs,
  });

  ActiveSession copyWith({
    Routine? routine,
    Day? day,
    DateTime? startTime,
    Map<String, List<SetLog>>? exerciseLogs,
  }) {
    return ActiveSession(
      routine: routine ?? this.routine,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      exerciseLogs: exerciseLogs ?? this.exerciseLogs,
    );
  }
}
