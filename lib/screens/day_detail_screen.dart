import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../models/models.dart';

class DayDetailScreen extends StatelessWidget {
  final String routineId;
  final String dayId;

  const DayDetailScreen(
      {super.key, required this.routineId, required this.dayId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final routine = provider.routines.firstWhere((r) => r.id == routineId);
    final day = routine.days.firstWhere((d) => d.id == dayId);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(title: Text(day.name)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: day.exercises.length,
        itemBuilder: (_, i) {
          final exerciseInDay = day.exercises[i];
          final libExercise = provider.exerciseLibrary.firstWhere(
            (e) => e.id == exerciseInDay.exerciseId,
            orElse: () => provider.exerciseLibrary[0],
          );
          // Find last logged data
          final lastLog = provider.workoutLogs
              .where((l) => l.routineId == routineId && l.dayId == dayId)
              .expand((l) => l.exercises)
              .firstWhere((el) => el.exerciseId == exerciseInDay.exerciseId,
                  orElse: () => const ExerciseLog(exerciseId: ''));
          final lastSet = lastLog.sets.isNotEmpty ? lastLog.sets.last : null;
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(libExercise.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        lastSet != null
                            ? 'Last: ${lastSet.weight} kg × ${lastSet.reps} reps'
                            : 'No data',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.error),
                  onPressed: () {
                    final updatedExercises = [...day.exercises];
                    updatedExercises.removeAt(i);
                    final updatedDay =
                        day.copyWith(exercises: updatedExercises);
                    final routineIndex =
                        provider.routines.indexWhere((r) => r.id == routineId);
                    final days = [...routine.days];
                    days[days.indexWhere((d) => d.id == dayId)] = updatedDay;
                    provider.routines[routineIndex] =
                        routine.copyWith(days: days);
                    provider.notifyListeners();
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExerciseBottomSheet(context),
        child: const Icon(Icons.add, color: AppColors.primaryBackground),
      ),
    );
  }

  void _showAddExerciseBottomSheet(BuildContext context) {
    final provider = context.read<DataProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => ExercisePicker(
        exercises: provider.exerciseLibrary,
        onSelect: (exerciseId) {
          provider.addExerciseToDay(routineId, dayId, exerciseId);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class ExercisePicker extends StatelessWidget {
  final List<ExerciseLibraryItem> exercises;
  final Function(String exerciseId) onSelect;

  const ExercisePicker(
      {super.key, required this.exercises, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final searchCtrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add Exercise',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          TextField(
            controller: searchCtrl,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Search exercise'),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: exercises
                  .where((e) => e.name
                      .toLowerCase()
                      .contains(searchCtrl.text.toLowerCase()))
                  .map((e) => ListTile(
                        title: Text(e.name),
                        subtitle: Text(e.muscleGroup,
                            style: TextStyle(color: AppColors.textSecondary)),
                        onTap: () => onSelect(e.id),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
