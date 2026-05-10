import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/home_screen.dart';
import 'screens/routine_list_screen.dart';
import 'screens/routine_detail_screen.dart';
import 'screens/day_detail_screen.dart';
import 'screens/active_workout_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/workout',
            builder: (_, __) => const RoutineListScreen(),
            routes: [
              GoRoute(
                path: ':routineId',
                builder: (_, state) => RoutineDetailScreen(
                  routineId: state.pathParameters['routineId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'day/:dayId',
                    builder: (_, state) => DayDetailScreen(
                      routineId: state.pathParameters['routineId']!,
                      dayId: state.pathParameters['dayId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'start',
                        pageBuilder: (_, state) => CustomTransitionPage(
                          fullscreenDialog: true,
                          child: ActiveWorkoutScreen(
                            routineId: state.pathParameters['routineId']!,
                            dayId: state.pathParameters['dayId']!,
                          ),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
              path: '/progress', builder: (_, __) => const ProgressScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
}
