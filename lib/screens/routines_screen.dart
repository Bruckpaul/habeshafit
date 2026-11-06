import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/templates.dart';
import '../models/routine.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'workout_actions.dart';

const kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String scheduleSummary(Routine r) {
  if (r.mode == ScheduleMode.rotation || !r.days.any((d) => d.weekdays.isNotEmpty)) {
    final slots = r.effectiveRotation;
    final rests = slots.where((s) => s == null).length;
    return 'Rotation · ${slots.length - rests} workouts${rests > 0 ? ', $rests rest' : ''} per cycle';
  }
  final days = <int>{for (final d in r.days) ...d.weekdays}.toList()..sort();
  return days.map((d) => kWeekdayShort[d - 1]).join(', ');
}

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final active = state.myRoutines.where((r) => !r.archived).toList();
    final archived = state.myRoutines.where((r) => r.archived).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          IconButton(tooltip: 'History', onPressed: () => context.push('/history'), icon: const Icon(Icons.history)),
          IconButton(
              tooltip: 'Exercise library',
              onPressed: () => context.push('/exercises/pick?single=1'),
              icon: const Icon(Icons.menu_book_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newRoutine(context),
        icon: const Icon(Icons.add),
        label: const Text('New routine'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          AppCard(
            onTap: () => startEmpty(context),
            color: p.accent.withValues(alpha: 0.10),
            borderColor: p.accent.withValues(alpha: 0.4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.bolt, color: p.onAccent),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Start empty workout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  SizedBox(height: 2),
                  Text('Add exercises as you go. Save it as a routine after.'),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 24),
          const SectionHeader('My routines'),
          if (active.isEmpty)
            AppCard(
              child: Column(children: [
                Text('No routines yet. Build one, or start from a proven split.',
                    style: TextStyle(color: p.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => _newRoutine(context), child: const Text('Create routine')),
              ]),
            ),
          for (final r in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoutineCard(routine: r, isActive: state.profile.activeRoutineId == r.id),
            ),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _showArchived = !_showArchived),
              icon: Icon(_showArchived ? Icons.expand_less : Icons.expand_more),
              label: Text('Archived (${archived.length})'),
            ),
            if (_showArchived)
              for (final r in archived)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoutineCard(routine: r, isActive: false),
                ),
          ],
        ],
      ),
    );
  }

  Future<void> _newRoutine(BuildContext context) async {
    final state = context.read<AppState>();
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Blank routine'),
            subtitle: const Text('Build it day by day'),
            onTap: () => Navigator.pop(ctx, -1),
          ),
          const Divider(),
          for (final (i, t) in kRoutineTemplates.indexed)
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: Text(t.name),
              subtitle: Text(t.description),
              onTap: () => Navigator.pop(ctx, i),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == -1) {
      context.push('/routine/new');
    } else {
      final r = kRoutineTemplates[choice].build();
      await state.saveRoutine(r);
      if (context.mounted) context.push('/routine/${r.id}');
    }
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final bool isActive;
  const _RoutineCard({required this.routine, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.read<AppState>();
    return AppCard(
      onTap: () => context.push('/routine/${routine.id}'),
      borderColor: isActive ? p.accent.withValues(alpha: 0.6) : null,
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(routine.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ),
          if (routine.isCoachAssigned) Padding(padding: const EdgeInsets.only(right: 6), child: Tag('COACH', color: p.accent2)),
          if (isActive) Tag('ACTIVE', color: p.accent),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'active':
                  await state.setActiveRoutine(routine.id);
                case 'duplicate':
                  await state.duplicateRoutine(routine);
                case 'archive':
                  await state.setArchived(routine, !routine.archived);
                case 'delete':
                  if (await confirm(context,
                      title: 'Delete "${routine.name}"?',
                      message: 'Your workout history is kept; only the plan is removed.',
                      confirmLabel: 'Delete',
                      destructive: true)) {
                    await state.deleteRoutine(routine.id);
                  }
              }
            },
            itemBuilder: (_) => [
              if (!isActive && !routine.archived) const PopupMenuItem(value: 'active', child: Text('Set as active plan')),
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem(value: 'archive', child: Text(routine.archived ? 'Restore' : 'Archive')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ]),
        Text(scheduleSummary(routine), style: TextStyle(color: p.textSecondary)),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final d in routine.days)
              ActionChip(
                avatar: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text('${d.name} · ${d.exercises.length}'),
                onPressed: d.exercises.isEmpty ? null : () => startRoutineDay(context, routine, d),
              ),
            if (routine.days.isEmpty) Text('No days yet', style: TextStyle(color: p.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}
