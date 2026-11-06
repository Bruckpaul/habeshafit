import 'package:flutter_test/flutter_test.dart';
import 'package:habeshafit/data/coaching_backend.dart';
import 'package:habeshafit/data/repository.dart';
import 'package:habeshafit/models/coaching.dart';
import 'package:habeshafit/models/exercise.dart';
import 'package:habeshafit/models/routine.dart';
import 'package:habeshafit/state/app_state.dart';
import 'package:habeshafit/state/coaching_state.dart';
import 'package:sembast/sembast_memory.dart';

const lib = [Exercise(id: 'bench', name: 'Bench', primaryMuscles: ['chest'])];

Future<(AppState, CoachingState)> fresh() async {
  final db = await newDatabaseFactoryMemory().openDatabase('c.db');
  final app = AppState(Repository(db));
  await app.load(libraryOverride: lib);
  await app.updateProfile((p) => p.name = 'Bruck');
  final coaching = CoachingState(LocalCoachingBackend(db), app);
  await coaching.load();
  return (app, coaching);
}

Future<void> becomeApprovedCoach(CoachingState c) async {
  final center = TrainingCenter(name: 'Iron Gym', contact: 'x@y.z');
  await c.applyAsCoach(center: center, profile: CoachProfile(name: 'Coach B', centerId: center.id));
  await c.reviewCenter(c.myCenter!, approve: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sample coaches are seeded once and labelled', () async {
    final (_, c) = await fresh();
    expect(c.coaches.where((x) => x.isSample).length, 2);
    await c.load();
    expect(c.coaches.where((x) => x.isSample).length, 2);
  });

  test('coach account is locked until the center is approved, then trial starts', () async {
    final (_, c) = await fresh();
    final center = TrainingCenter(name: 'Iron Gym', contact: '0911');
    await c.applyAsCoach(center: center, profile: CoachProfile(name: 'Coach B', centerId: center.id));
    expect(c.isCoach, isTrue);
    expect(c.canCoach, isFalse);
    expect(c.pendingCenters.single.id, center.id);

    await c.reviewCenter(c.myCenter!, approve: true);
    expect(c.canCoach, isTrue);
    expect(c.trialDaysLeft, inInclusiveRange(kTrialDays - 1, kTrialDays));
    expect(c.inbox(Audience.coach).first.title, 'Coach account approved');
  });

  test('program for myself becomes my active plan and notifies me', () async {
    final (app, c) = await fresh();
    await becomeApprovedCoach(c);
    final me = await c.addClient(name: 'Bruck', isMe: true);
    expect(c.myCoach?.id, c.myCoachId);

    final r = c.newProgram(me)
      ..days.add(RoutineDay(name: 'Upper', exercises: [PlannedExercise(exerciseId: 'bench', repMin: 6, repMax: 8)]));
    await c.saveProgram(r);
    expect(app.activeRoutine?.id, r.id);
    expect(app.myRoutines.any((x) => x.id == r.id), isTrue);
    expect(c.inbox(Audience.client).map((n) => n.title), contains('New program from your coach'));
  });

  test('programs for other clients stay out of my Workouts list', () async {
    final (app, c) = await fresh();
    await becomeApprovedCoach(c);
    final other = await c.addClient(name: 'Abel');
    await c.saveProgram(c.newProgram(other)..days.add(RoutineDay(name: 'A')));
    expect(app.myRoutines, isEmpty);
    expect(c.programsFor(other.id, c.myCoachId!).length, 1);
    expect(c.inbox(Audience.client).where((n) => n.title.contains('program')), isEmpty);
  });

  test('finishing a workout notifies the coach and completes lift goals', () async {
    final (app, c) = await fresh();
    await becomeApprovedCoach(c);
    await c.addClient(name: 'Bruck', isMe: true);
    await c.saveGoal(Goal(
      clientId: kMeClientId,
      coachId: c.myCoachId!,
      type: GoalType.lift,
      title: 'Bench 100',
      ref: 'bench',
      start: 80,
      target: 100,
    ));

    await app.startEmptyWorkout();
    await app.addExercisesToActive(['bench']);
    final e = app.active!.exercises.single;
    e.sets[0]
      ..weight = 100
      ..reps = 3;
    await app.toggleSetDone(e, 0);
    final saved = await app.finishActive();
    await c.onWorkoutFinished(saved!);

    expect(c.goals.single.achieved, isTrue);
    expect(c.inbox(Audience.coach).map((n) => n.title), contains('Bruck finished ${saved.name}'));
    expect(c.inbox(Audience.client).map((n) => n.title), contains('Goal reached'));
  });

  test('body-weight goal going down uses progress toward a lower target', () async {
    final (app, c) = await fresh();
    await becomeApprovedCoach(c);
    await c.addClient(name: 'Bruck', isMe: true);
    final g = Goal(clientId: kMeClientId, coachId: c.myCoachId!, type: GoalType.bodyweight, title: 'Cut', start: 90, target: 80);
    await c.saveGoal(g);
    await app.addMeasurement('bodyweight', 85);
    expect(c.goalProgress(g), closeTo(0.5, 0.001));
  });

  test('request to my own coach profile can be accepted', () async {
    final (_, c) = await fresh();
    await becomeApprovedCoach(c);
    await c.sendRequest(c.myCoachProfile!, goal: 'Get strong');
    expect(c.incomingRequests.single.fromName, 'Bruck');
    await c.answerRequest(c.incomingRequests.single, accept: true);
    expect(c.myLink?.coachId, c.myCoachId);
    expect(c.incomingRequests, isEmpty);
  });

  test('comments notify the other side; meal ticks count toward adherence', () async {
    final (app, c) = await fresh();
    await becomeApprovedCoach(c);
    await c.addClient(name: 'Bruck', isMe: true);
    await app.startEmptyWorkout();
    await app.addExercisesToActive(['bench']);
    final e = app.active!.exercises.single;
    e.sets[0]
      ..weight = 60
      ..reps = 8;
    await app.toggleSetDone(e, 0);
    final s = (await app.finishActive())!;

    await c.addComment(session: s, clientId: kMeClientId, fromCoach: true, text: 'Great depth');
    expect(c.inbox(Audience.client).first.body, 'Great depth');
    await c.addComment(session: s, clientId: kMeClientId, fromCoach: false, text: 'Thanks!');
    expect(c.inbox(Audience.coach).first.body, 'Thanks!');
    expect(c.commentsFor(s.id).length, 2);

    final plan = MealPlan(clientId: kMeClientId, coachId: c.myCoachId!, meals: [Meal(time: '08:00', name: 'Breakfast')]);
    await c.saveMealPlan(plan);
    await c.toggleMealEaten(plan, plan.meals.single);
    expect(c.mealAdherence(plan), closeTo(1 / 7, 0.001));
  });

  test('reminders fire on chosen weekdays only', () {
    final r = Reminder(clientId: kMeClientId, coachId: 'c', type: ReminderType.training, text: 'Legs', time: '18:00', weekdays: [1, 3]);
    expect(r.firesOn(DateTime(2026, 11, 2)), isTrue); // Monday
    expect(r.firesOn(DateTime(2026, 11, 3)), isFalse);
  });
}
