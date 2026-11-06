import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/coaching_backend.dart';
import 'data/repository.dart';
import 'router.dart';
import 'services/notification_scheduler.dart';
import 'services/notifications.dart';
import 'state/app_state.dart';
import 'state/coaching_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await Repository.open();
  final state = AppState(repo);
  await state.load();
  // Local for now; swap in a cloud backend for real coach ↔ client sync.
  final coaching = CoachingState(LocalCoachingBackend(repo.db), state);
  await coaching.load();

  final router = buildRouter(state);
  final notifier = createNotifier();
  try {
    await notifier.init(onOpen: router.go);
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }
  final scheduler = NotificationScheduler(state, coaching, notifier)..start();
  final launch = await notifier.launchRoute();
  if (launch != null && state.profile.onboardingComplete) router.go(launch);

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: coaching),
      Provider.value(value: scheduler),
    ],
    child: HabeshaFitApp(router: router, scheduler: scheduler),
  ));
}

class HabeshaFitApp extends StatefulWidget {
  final GoRouter router;
  final NotificationScheduler scheduler;
  const HabeshaFitApp({super.key, required this.router, required this.scheduler});

  @override
  State<HabeshaFitApp> createState() => _HabeshaFitAppState();
}

class _HabeshaFitAppState extends State<HabeshaFitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app (e.g. the next morning): refresh the plan and
  /// the reminders scheduled from it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) widget.scheduler.resync();
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((s) => s.profile.themeMode);
    return MaterialApp.router(
      title: 'HabeshaFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      routerConfig: widget.router,
    );
  }
}
