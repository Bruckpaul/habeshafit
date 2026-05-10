import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/data_provider.dart';
import 'router.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load exercises from JSON before creating the provider.
  final exercises = await DataProvider.loadExercisesFromAssets();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => DataProvider(mockExercises: exercises)),
      ],
      child: const HabeshaFitApp(),
    ),
  );
}

class HabeshaFitApp extends StatelessWidget {
  const HabeshaFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HabeshaFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
