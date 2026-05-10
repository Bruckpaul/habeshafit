import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/data_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../models/models.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String routineId;
  final String dayId;

  const ActiveWorkoutScreen(
      {super.key, required this.routineId, required this.dayId});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late PageController _pageController;
  int _currentExerciseIndex = 0;
  bool _restTimerActive = false;
  int _restSeconds = 60;
  Timer? _timer;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    final provider = context.read<DataProvider>();
    final routine =
        provider.routines.firstWhere((r) => r.id == widget.routineId);
    final day = routine.days.firstWhere((d) => d.id == widget.dayId);
    provider.startWorkout(routine, day);
  }

  void _startRestTimer() {
    setState(() => _restTimerActive = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restSeconds == 0) {
        t.cancel();
        setState(() {
          _restTimerActive = false;
          _restSeconds = 60;
        });
        return;
      }
      setState(() => _restSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final session = provider.activeSession;
    if (session == null)
      return const Scaffold(body: Center(child: Text('No active session')));
    final day = session.day;
    final exercises = day.exercises;
    final currentExercise = exercises[_currentExerciseIndex];
    final libExercise = provider.exerciseLibrary.firstWhere(
      (e) => e.id == currentExercise.exerciseId,
      orElse: () => provider.exerciseLibrary[0],
    );
    final loggedSets = session.exerciseLogs[currentExercise.exerciseId] ?? [];

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: exercises.length,
              onPageChanged: (i) => setState(() => _currentExerciseIndex = i),
              itemBuilder: (_, i) {
                final exInDay = exercises[i];
                final exLib = provider.exerciseLibrary.firstWhere(
                    (e) => e.id == exInDay.exerciseId,
                    orElse: () => provider.exerciseLibrary[0]);
                return _ExerciseView(
                  exercise: exLib,
                  targetSets: exInDay.targetSets,
                  loggedSets: loggedSets,
                  onLogSet: (weight, reps, type) {
                    provider.logSet(exInDay.exerciseId,
                        SetLog(weight: weight, reps: reps, type: type));
                  },
                );
              },
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: _restTimerActive
                    ? AppColors.secondaryAccent
                    : AppColors.accent,
                onPressed: () {
                  if (!_restTimerActive) {
                    _startRestTimer();
                  }
                },
                child: _restTimerActive
                    ? SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          value: 1 - (_restSeconds / 60),
                          strokeWidth: 3,
                          color: AppColors.primaryBackground,
                        ),
                      )
                    : const Icon(Icons.timer,
                        color: AppColors.primaryBackground),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accent)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Finish Exercise'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      provider.finishWorkout();
                      _confettiController.play();
                      Future.delayed(const Duration(seconds: 3),
                          () => Navigator.pop(context));
                    },
                    child: const Text('Finish Workout'),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                colors: [
                  AppColors.accent,
                  AppColors.secondaryAccent,
                  AppColors.success
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseView extends StatefulWidget {
  final ExerciseLibraryItem exercise;
  final int targetSets;
  final List<SetLog> loggedSets;
  final Function(double weight, int reps, SetType type) onLogSet;

  const _ExerciseView({
    required this.exercise,
    required this.targetSets,
    required this.loggedSets,
    required this.onLogSet,
  });

  @override
  State<_ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<_ExerciseView> {
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
  SetType _selectedType = SetType.normal;

  @override
  Widget build(BuildContext context) {
    final currentSet = widget.loggedSets.length + 1;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.exercise.name,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Set $currentSet of ${widget.targetSets}',
              style: TextStyle(fontSize: 18, color: AppColors.accent)),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Previous Performance',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Last session: 80 kg × 8 reps',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: SetType.values.map((type) {
              final isSelected = _selectedType == type;
              return FilterChip(
                label: Text(type.name.toUpperCase()),
                selected: isSelected,
                onSelected: (v) => setState(() => _selectedType = type),
                selectedColor: AppColors.accent.withOpacity(0.3),
                checkmarkColor: AppColors.accent,
                backgroundColor: AppColors.surface,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final weight = double.tryParse(_weightCtrl.text) ?? 0;
                final reps = int.tryParse(_repsCtrl.text) ?? 0;
                if (weight > 0 && reps > 0) {
                  widget.onLogSet(weight, reps, _selectedType);
                  _weightCtrl.clear();
                  _repsCtrl.clear();
                  setState(() {}); // rebuild logged sets
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Log Set'),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.loggedSets.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: widget.loggedSets.length,
                itemBuilder: (_, i) {
                  final set = widget.loggedSets[i];
                  return Dismissible(
                    key: ValueKey(i),
                    onDismissed: (_) {
                      widget.loggedSets.removeAt(i);
                      setState(() {});
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.accent.withOpacity(0.2),
                        child: Text('${i + 1}'),
                      ),
                      title: Text('${set.weight} kg × ${set.reps} reps'),
                      subtitle: Text(set.type.name,
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
