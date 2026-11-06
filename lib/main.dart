import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/coaching_backend.dart';
import 'data/repository.dart';
import 'router.dart';
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
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: coaching),
    ],
    child: HabeshaFitApp(state: state),
  ));
}

class HabeshaFitApp extends StatefulWidget {
  final AppState state;
  const HabeshaFitApp({super.key, required this.state});

  @override
  State<HabeshaFitApp> createState() => _HabeshaFitAppState();
}

class _HabeshaFitAppState extends State<HabeshaFitApp> {
  late final router = buildRouter(widget.state);

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((s) => s.profile.themeMode);
    return MaterialApp.router(
      title: 'HabeshaFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      routerConfig: router,
    );
  }
}
