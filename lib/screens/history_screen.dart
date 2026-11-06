import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final unit = state.profile.unit;
    final byMonth = <String, List<WorkoutSession>>{};
    for (final s in state.sessions) {
      byMonth.putIfAbsent(DateFormat('MMMM yyyy').format(s.start), () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: state.sessions.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No workouts yet',
              message: 'Finished workouts appear here with every set you logged.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                for (final entry in byMonth.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Row(children: [
                      Expanded(child: Text(entry.key, style: context.text.titleMedium)),
                      Text('${entry.value.length} workouts', style: TextStyle(color: p.textSecondary)),
                    ]),
                  ),
                  for (final s in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => context.push('/session/${s.id}'),
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 46,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                            child: Column(children: [
                              Text(DateFormat('E').format(s.start).toUpperCase(),
                                  style: TextStyle(fontSize: 10, color: p.textSecondary, fontWeight: FontWeight.w700)),
                              Text('${s.start.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                '${fmtDuration(s.duration)} · ${plural(s.exercises.length, 'exercise')} · ${fmtVolume(s.volume, unit)}',
                                style: TextStyle(color: p.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.exercises.map((e) => state.exercise(e.exerciseId).name).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.textSecondary, fontSize: 12),
                              ),
                            ]),
                          ),
                          if (s.records.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.emoji_events, size: 18, color: p.accent2),
                            Text('${s.records.length}', style: TextStyle(color: p.accent2, fontWeight: FontWeight.w700)),
                          ],
                        ]),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
