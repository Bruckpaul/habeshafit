import '../models/routine.dart';

/// Starter programs offered during onboarding and in the routine list.
class RoutineTemplate {
  final String name;
  final String description;
  final Routine Function() build;
  const RoutineTemplate(this.name, this.description, this.build);
}

PlannedExercise _p(String id, int sets, int min, int max, {int rest = 90}) =>
    PlannedExercise(exerciseId: id, sets: sets, repMin: min, repMax: max, restSeconds: rest);

final List<RoutineTemplate> kRoutineTemplates = [
  RoutineTemplate('Upper / Lower', '4 days · Mon, Tue, Thu, Fri', () {
    final upperA = RoutineDay(name: 'Upper A', weekdays: [1], exercises: [
      _p('Barbell_Bench_Press_-_Medium_Grip', 4, 6, 8, rest: 150),
      _p('Bent_Over_Barbell_Row', 4, 6, 8, rest: 150),
      _p('Seated_Dumbbell_Press', 3, 8, 10),
      _p('Wide-Grip_Lat_Pulldown', 3, 10, 12),
      _p('Barbell_Curl', 3, 10, 12, rest: 60),
      _p('Triceps_Pushdown', 3, 10, 12, rest: 60),
    ]);
    final lowerA = RoutineDay(name: 'Lower A', weekdays: [2], exercises: [
      _p('Barbell_Squat', 4, 5, 8, rest: 180),
      _p('Romanian_Deadlift', 3, 8, 10, rest: 120),
      _p('Leg_Press', 3, 10, 12),
      _p('Lying_Leg_Curls', 3, 10, 12, rest: 60),
      _p('Standing_Calf_Raises', 4, 12, 15, rest: 60),
    ]);
    final upperB = RoutineDay(name: 'Upper B', weekdays: [4], exercises: [
      _p('Incline_Dumbbell_Press', 4, 8, 10, rest: 120),
      _p('Pullups', 4, 6, 10, rest: 120),
      _p('Standing_Military_Press', 3, 6, 8, rest: 120),
      _p('Seated_Cable_Rows', 3, 10, 12),
      _p('Side_Lateral_Raise', 3, 12, 15, rest: 60),
      _p('Hammer_Curls', 3, 10, 12, rest: 60),
    ]);
    final lowerB = RoutineDay(name: 'Lower B', weekdays: [5], exercises: [
      _p('Barbell_Deadlift', 3, 4, 6, rest: 180),
      _p('Dumbbell_Lunges', 3, 10, 12),
      _p('Leg_Extensions', 3, 12, 15, rest: 60),
      _p('Barbell_Hip_Thrust', 3, 8, 12),
      _p('Hanging_Leg_Raise', 3, 10, 15, rest: 60),
    ]);
    return Routine(name: 'Upper / Lower', days: [upperA, lowerA, upperB, lowerB]);
  }),
  RoutineTemplate('Push / Pull / Legs', '6-slot rotation with a rest day', () {
    final push = RoutineDay(name: 'Push', exercises: [
      _p('Barbell_Bench_Press_-_Medium_Grip', 4, 6, 8, rest: 150),
      _p('Seated_Dumbbell_Press', 3, 8, 10),
      _p('Incline_Dumbbell_Press', 3, 8, 12),
      _p('Side_Lateral_Raise', 3, 12, 15, rest: 60),
      _p('Triceps_Pushdown', 3, 10, 12, rest: 60),
    ]);
    final pull = RoutineDay(name: 'Pull', exercises: [
      _p('Pullups', 4, 6, 10, rest: 120),
      _p('Bent_Over_Barbell_Row', 3, 8, 10, rest: 120),
      _p('Seated_Cable_Rows', 3, 10, 12),
      _p('Face_Pull', 3, 12, 15, rest: 60),
      _p('Barbell_Curl', 3, 10, 12, rest: 60),
    ]);
    final legs = RoutineDay(name: 'Legs', exercises: [
      _p('Barbell_Squat', 4, 5, 8, rest: 180),
      _p('Romanian_Deadlift', 3, 8, 10, rest: 120),
      _p('Leg_Press', 3, 10, 12),
      _p('Lying_Leg_Curls', 3, 10, 12, rest: 60),
      _p('Standing_Calf_Raises', 4, 12, 15, rest: 60),
    ]);
    return Routine(
      name: 'Push / Pull / Legs',
      mode: ScheduleMode.rotation,
      days: [push, pull, legs],
      rotation: [push.id, pull.id, legs.id, push.id, pull.id, legs.id, null],
    );
  }),
  RoutineTemplate('Full body', '3 days · Mon, Wed, Fri', () {
    final day = RoutineDay(name: 'Full body', weekdays: [1, 3, 5], exercises: [
      _p('Barbell_Squat', 3, 6, 8, rest: 150),
      _p('Barbell_Bench_Press_-_Medium_Grip', 3, 6, 8, rest: 150),
      _p('Bent_Over_Barbell_Row', 3, 8, 10, rest: 120),
      _p('Standing_Military_Press', 2, 8, 10),
      _p('Romanian_Deadlift', 2, 8, 10),
      _p('Plank', 3, 30, 60, rest: 60),
    ]);
    return Routine(name: 'Full body', days: [day]);
  }),
];
