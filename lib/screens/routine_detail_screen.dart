import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class RoutineDetailScreen extends StatelessWidget {
  final String routineId;
  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final routine = provider.routines.firstWhere((r) => r.id == routineId);
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(title: Text(routine.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDayDialog(context),
        child: const Icon(Icons.add, color: AppColors.primaryBackground),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: routine.days.length,
        onReorder: (oldIndex, newIndex) {
          final days = [...routine.days];
          final moved = days.removeAt(oldIndex);
          days.insert(newIndex, moved);
          final updatedRoutine = routine.copyWith(days: days);
          final index = provider.routines.indexWhere((r) => r.id == routineId);
          provider.routines[index] = updatedRoutine;
          provider.notifyListeners();
        },
        itemBuilder: (_, i) {
          final day = routine.days[i];
          return GlassCard(
            key: ValueKey(day.id),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(day.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: day.exercises.isEmpty
                  ? const Text('No exercises')
                  : Wrap(
                      spacing: 4,
                      children: day.exercises.take(3).map((e) {
                        final ex = provider.exerciseLibrary.firstWhere(
                            (lib) => lib.id == e.exerciseId,
                            orElse: () => provider.exerciseLibrary[0]);
                        return Chip(
                          label: Text(ex.name,
                              style: const TextStyle(fontSize: 10)),
                          backgroundColor: AppColors.accent.withOpacity(0.15),
                          shape: StadiumBorder(side: BorderSide.none),
                        );
                      }).toList(),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/workout/$routineId/day/${day.id}/start'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.accent),
                  ),
                  const Icon(Icons.drag_handle, color: AppColors.textSecondary),
                ],
              ),
              onTap: () => context.push('/workout/$routineId/day/${day.id}'),
            ),
          );
        },
      ),
    );
  }

  void _showAddDayDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Day'),
        content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Day name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                context
                    .read<DataProvider>()
                    .addDayToRoutine(routineId, nameCtrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
