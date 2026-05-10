import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class RoutineListScreen extends StatelessWidget {
  const RoutineListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(title: const Text('Routines'), actions: [
        IconButton(
            icon: const Icon(Icons.history), onPressed: () {}), // placeholder
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRoutineDialog(context),
        child: const Icon(Icons.add, color: AppColors.primaryBackground),
      ),
      body: provider.routines.isEmpty
          ? const Center(child: Text('No routines yet. Create one!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.routines.length,
              itemBuilder: (_, i) {
                final routine = provider.routines[i];
                return Dismissible(
                  key: ValueKey(routine.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    provider.routines.removeAt(i);
                    provider.notifyListeners();
                  },
                  child: GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () => context.push('/workout/${routine.id}'),
                    child: Row(
                      children: [
                        Icon(Icons.fitness_center, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(routine.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text('${routine.days.length} days • Last: today',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showCreateRoutineDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('New Routine'),
        content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Routine name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                context.read<DataProvider>().addRoutine(nameCtrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
