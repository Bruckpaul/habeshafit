// Renders the coaching screens with real fonts and saves PNGs to
// build/shots/. Not part of the normal test suite. Run with:
//   flutter test tool/screenshots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habeshafit/data/coaching_backend.dart';
import 'package:habeshafit/data/repository.dart';
import 'package:habeshafit/logic/templates.dart';
import 'package:habeshafit/models/coaching.dart';
import 'package:habeshafit/models/exercise.dart';
import 'package:habeshafit/models/routine.dart';
import 'package:habeshafit/router.dart';
import 'package:habeshafit/state/app_state.dart';
import 'package:habeshafit/state/coaching_state.dart';
import 'package:habeshafit/theme.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';

const _lib = [
  Exercise(id: 'Barbell_Bench_Press_-_Medium_Grip', name: 'Barbell Bench Press', primaryMuscles: ['chest'], equipment: 'barbell'),
  Exercise(id: 'Barbell_Squat', name: 'Barbell Squat', primaryMuscles: ['quadriceps'], equipment: 'barbell'),
  Exercise(id: 'Pullups', name: 'Pullups', primaryMuscles: ['lats'], equipment: 'body only'),
];

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String f) async => ByteData.sublistView(await File('$dir/$f').readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']) {
    roboto.addFont(bytes(f));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'));
  await icons.load();
}

void main() {
  testWidgets('coaching flow screenshots', (tester) async {
    AppTheme.useGoogleFonts = false;
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(390 * 2, 1000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    late AppState app;
    late CoachingState coaching;
    await tester.runAsync(() async {
      final db = await newDatabaseFactoryMemory().openDatabase('shots.db');
      app = AppState(Repository(db));
      await app.load(libraryOverride: _lib);
      await app.updateProfile((p) {
        p.name = 'Bruck';
        p.onboardingComplete = true;
        p.themeMode = ThemeMode.dark;
      });
      await app.saveRoutine(kRoutineTemplates.first.build(), makeActive: true);
      coaching = CoachingState(LocalCoachingBackend(db), app);
      await coaching.load();
    });

    final router = buildRouter(app);
    final appKey = GlobalKey();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider.value(value: coaching),
      ],
      child: RepaintBoundary(
        key: appKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          routerConfig: router,
        ),
      ),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> real(Future<void> Function() f) async {
      await tester.runAsync(f);
      await settle();
    }

    var n = 0;
    Future<void> shot(String name) async {
      await settle();
      n++;
      await expectLater(find.byKey(appKey),
          matchesGoldenFile('../../build/shots/${n.toString().padLeft(2, '0')}_$name.png'));
    }

    Future<void> tapText(String text) async {
      final f = find.text(text).last;
      await tester.ensureVisible(f);
      await settle();
      await tester.tap(f);
      await settle();
    }

    Future<void> type(String label, String value) async {
      final f = find.widgetWithText(TextField, label).first;
      await tester.ensureVisible(f);
      await tester.enterText(f, value);
      await tester.pump();
    }

    // 1. Client landing
    router.go('/coach');
    await shot('client_landing');

    // 2. Apply as coach via the real form
    await tapText('Are you a coach?');
    await shot('apply_form');
    await type('Gym / center name *', 'Iron Addis Gym');
    await type('City', 'Addis Ababa');
    await type('Phone or email *', '0911 000000');
    await type('Bio: how you coach, who you help', 'Strength and physique coach. 8 years helping beginners build muscle.');
    await tapText('Bodybuilding');
    await tapText('Strength');
    await type('Years coaching', '8');
    await tapText('Submit application');
    await shot('application_sent_dialog');
    await tapText('OK');
    router.go('/coach');
    await shot('pending_review');

    // 3. Owner approves
    router.push('/admin');
    await shot('owner_tools');
    await tapText('Approve');
    router.go('/coach');
    await shot('dashboard_empty');

    // 4. Add myself as a client through the sheet
    await tapText('Add client');
    await shot('add_client_sheet');
    await tester.tap(find.widgetWithText(FilledButton, 'Add client').last);
    await settle();
    await shot('client_program_tab_empty');

    // 5. Program editor for the client
    await tapText('Write a new program');
    await shot('program_editor');
    router.pop();
    await settle();
    final me = coaching.clientOf(kMeClientId)!;
    await real(() async {
      final r = coaching.newProgram(me)
        ..name = 'Hypertrophy block 1'
        ..days = [
          RoutineDay(name: 'Upper', weekdays: [1, 4], exercises: [
            PlannedExercise(exerciseId: 'Barbell_Bench_Press_-_Medium_Grip', sets: 4, repMin: 6, repMax: 8, notes: 'Pause 1s on chest'),
            PlannedExercise(exerciseId: 'Pullups', sets: 3, repMin: 8, repMax: 10),
          ]),
          RoutineDay(name: 'Lower', weekdays: [2, 5], exercises: [
            PlannedExercise(exerciseId: 'Barbell_Squat', sets: 4, repMin: 5, repMax: 8, restSeconds: 180),
          ]),
        ];
      await coaching.saveProgram(r);
    });
    await shot('client_program_tab');

    // 6. Goals, meals, reminders
    await real(() async {
      await coaching.saveGoal(Goal(clientId: kMeClientId, coachId: me.coachId, type: GoalType.lift, title: 'Bench 100 kg',
          ref: 'Barbell_Bench_Press_-_Medium_Grip', start: 70, target: 100, deadline: DateTime(2027, 2, 1)));
      await coaching.saveGoal(Goal(clientId: kMeClientId, coachId: me.coachId, type: GoalType.habit, title: 'Train 4 days a week', target: 4));
      await app.addMeasurement('bodyweight', 86);
      await coaching.saveGoal(Goal(clientId: kMeClientId, coachId: me.coachId, type: GoalType.bodyweight, title: 'Cut to 80 kg', start: 90, target: 80));
    });
    await tapText('Goals');
    await shot('client_goals_tab');
    await tapText('Meals');
    await tapText('Create meal plan');
    await shot('meal_plan_editor');
    await tapText('Send to client');
    await shot('client_meals_tab');
    await tapText('Reminders');
    await real(() async {
      await coaching.saveReminder(Reminder(clientId: kMeClientId, coachId: me.coachId, type: ReminderType.training,
          text: 'Upper day: bring your belt', time: '18:00', weekdays: [1, 2, 3, 4, 5, 6, 7]));
      await coaching.saveReminder(Reminder(clientId: kMeClientId, coachId: me.coachId, type: ReminderType.water,
          text: 'Drink 500 ml of water', time: '10:00', weekdays: [1, 2, 3, 4, 5, 6, 7]));
    });
    await shot('client_reminders_tab');

    // 7. A workout with coach feedback
    late String sessionId;
    await real(() async {
      await app.startEmptyWorkout();
      await app.addExercisesToActive(['Barbell_Bench_Press_-_Medium_Grip']);
      final e = app.active!.exercises.single;
      e.sets[0]
        ..weight = 80
        ..reps = 6
        ..assisted = 1;
      await app.toggleSetDone(e, 0);
      app.stopRest();
      final s = (await app.finishActive())!;
      sessionId = s.id;
      await coaching.onWorkoutFinished(s);
      await coaching.addComment(session: s, clientId: kMeClientId, fromCoach: true, text: 'Good bar path. Next week aim for 6 without the spot.');
    });
    router.push('/session/$sessionId');
    await shot('session_with_feedback');
    router.pop();
    await settle();

    // 8. Client side
    await real(() => coaching.setView(CoachView.client));
    router.go('/coach');
    await shot('my_training_top');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await shot('my_training_bottom');

    router.push('/notifications?for=client');
    await shot('client_inbox');
    router.pop();
    await settle();

    router.push('/coach/directory');
    await shot('directory');
    router.push('/coach/profile/${coaching.myCoachId}');
    await shot('coach_profile');
    router.go('/home');
    await shot('home_with_coach');

    router.push('/routine/${coaching.programsFor(kMeClientId, me.coachId).first.id}');
    await shot('program_from_my_training');
    router.pop();
    await settle();

    // Pending timers (rest timer, etc.) shouldn't leak.
    await tester.pumpWidget(const SizedBox());
    expect(GoRouter.of, isNotNull);
  });
}
