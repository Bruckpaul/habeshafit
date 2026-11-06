import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/coaching.dart';
import 'screens/active_workout_screen.dart';
import 'screens/coaching/admin_screen.dart';
import 'screens/coaching/client_detail_screen.dart';
import 'screens/coaching/coach_apply_screen.dart';
import 'screens/coaching/coach_profile_screen.dart';
import 'screens/coaching/coach_tab_screen.dart';
import 'screens/coaching/directory_screen.dart';
import 'screens/coaching/notifications_screen.dart';
import 'screens/exercise_detail_screen.dart';
import 'screens/exercise_picker_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/routine_editor_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/shell_screen.dart';
import 'state/app_state.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AppState state) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: _OnboardingListenable(state),
    redirect: (context, s) {
      final onboarded = state.profile.onboardingComplete;
      final atOnboarding = s.matchedLocation == '/onboarding';
      if (!onboarded && !atOnboarding) return '/onboarding';
      if (onboarded && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellScreen(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/routines', builder: (_, __) => const RoutinesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/coach', builder: (_, __) => const CoachTabScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/routine/:id',
        builder: (_, s) => RoutineEditorScreen(
          routineId: s.pathParameters['id']!,
          forClientId: s.uri.queryParameters['client'],
        ),
      ),
      GoRoute(
        path: '/exercises/pick',
        pageBuilder: (_, s) => MaterialPage(
          fullscreenDialog: true,
          child: ExercisePickerScreen(single: s.uri.queryParameters['single'] == '1'),
        ),
      ),
      GoRoute(
        path: '/exercise/:id',
        builder: (_, s) => ExerciseDetailScreen(exerciseId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/workout',
        pageBuilder: (_, __) => const MaterialPage(fullscreenDialog: true, child: ActiveWorkoutScreen()),
      ),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(
        path: '/session/:id',
        builder: (_, s) => SessionDetailScreen(sessionId: s.pathParameters['id']!),
      ),
      // Coaching
      GoRoute(path: '/coach/apply', builder: (_, __) => const CoachApplyScreen()),
      GoRoute(path: '/coach/edit', builder: (_, __) => const CoachApplyScreen(editing: true)),
      GoRoute(path: '/coach/directory', builder: (_, __) => const DirectoryScreen()),
      GoRoute(
        path: '/coach/profile/:id',
        builder: (_, s) => CoachProfileScreen(coachId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/coach/client/:id',
        builder: (_, s) => ClientDetailScreen(clientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, s) => NotificationsScreen(
          audience: s.uri.queryParameters['for'] == 'coach' ? Audience.coach : Audience.client,
        ),
      ),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );
}

/// Re-runs the redirect only when onboarding status changes.
class _OnboardingListenable extends ChangeNotifier {
  final AppState state;
  bool _last;
  _OnboardingListenable(this.state) : _last = state.profile.onboardingComplete {
    state.addListener(() {
      if (state.profile.onboardingComplete != _last) {
        _last = state.profile.onboardingComplete;
        notifyListeners();
      }
    });
  }
}
