import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/routine.dart';
import '../../state/app_state.dart';
import '../../state/coaching_state.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/coaching_widgets.dart';
import '../../widgets/common.dart';
import '../routines_screen.dart' show scheduleSummary;

class ClientDetailScreen extends StatelessWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final c = coaching.clientOf(clientId);
    if (c == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.person_off, title: 'Client not found', message: ''));
    }
    final compliance = coaching.weeklyCompliance(c);
    final locked = !coaching.canCoach;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(c.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'notes') {
                  final n = await promptText(context, title: 'Private notes', initial: c.notes, hint: 'Injuries, schedule, preferences…');
                  if (n != null) {
                    c.notes = n;
                    await coaching.updateClient(c);
                  }
                } else if (v == 'end') {
                  if (await confirm(context,
                      title: 'End coaching with ${c.name}?',
                      message: 'They keep their history and programs.',
                      confirmLabel: 'End',
                      destructive: true)) {
                    await coaching.endLink(c);
                    if (context.mounted) context.pop();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'notes', child: Text('Private notes')),
                PopupMenuItem(value: 'end', child: Text('End coaching')),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: p.accent,
            labelColor: p.textPrimary,
            unselectedLabelColor: p.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            dividerColor: p.border,
            tabs: const [
              Tab(text: 'Program'),
              Tab(text: 'Workouts'),
              Tab(text: 'Goals'),
              Tab(text: 'Meals'),
              Tab(text: 'Reminders'),
            ],
          ),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  [
                    if (c.goal.isNotEmpty) 'Goal: ${c.goal}',
                    'Since ${DateFormat('MMM d, yyyy').format(c.since)}',
                    if (compliance != null) 'This week ${(compliance * 100).round()}%',
                  ].join(' · '),
                  style: TextStyle(color: p.textSecondary, fontSize: 13),
                ),
              ),
            ]),
          ),
          if (c.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(alignment: Alignment.centerLeft, child: Text(c.notes, style: TextStyle(color: p.accent2, fontSize: 13))),
            ),
          if (locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Read-only: your coach account is not active.', style: TextStyle(color: p.danger, fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: AbsorbPointer(
              absorbing: locked,
              child: TabBarView(children: [
                _ProgramTab(clientId: c.id),
                _WorkoutsTab(clientId: c.id),
                _pad(GoalBoard(clientId: c.id, coachId: c.coachId, editable: true)),
                _pad(MealPlanView(clientId: c.id, coachId: c.coachId, editable: true)),
                _pad(ReminderList(clientId: c.id, coachId: c.coachId, editable: true)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  static Widget _pad(Widget child) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [child]);
}

class _ProgramTab extends StatelessWidget {
  final String clientId;
  const _ProgramTab({required this.clientId});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final app = context.read<AppState>();
    final p = context.palette;
    final c = coaching.clientOf(clientId)!;
    final programs = coaching.programsFor(c.id, c.coachId);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      if (programs.isEmpty)
        AppCard(
          child: Text('Write ${c.name.split(' ').first}\'s program: days, exercises, sets, rep ranges, rest and notes. '
              'They can log it but not change it.', style: TextStyle(color: p.textSecondary)),
        ),
      for (final r in programs)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => context.push('/routine/${r.id}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                if (c.isMe && app.profile.activeRoutineId == r.id) Tag('ACTIVE', color: p.accent),
              ]),
              Text('${scheduleSummary(r)} · updated ${relativeDay(r.updatedAt, coaching.now).toLowerCase()}',
                  style: TextStyle(color: p.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              for (final d in r.days)
                Text('• ${d.name}: ${plural(d.exercises.length, 'exercise')}, ${plural(d.totalSets, 'set')}',
                    style: const TextStyle(fontSize: 13, height: 1.5)),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () => context.push('/routine/new?client=${c.id}'),
        icon: const Icon(Icons.add),
        label: const Text('Write a new program'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _copyFromMine(context),
        icon: const Icon(Icons.copy_all_outlined),
        label: const Text('Start from one of my routines'),
      ),
    ]);
  }

  Future<void> _copyFromMine(BuildContext context) async {
    final coaching = context.read<CoachingState>();
    final app = context.read<AppState>();
    final c = coaching.clientOf(clientId)!;
    final mine = app.routines.where((r) => r.clientId == null && !r.archived).toList();
    if (mine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have no routines of your own to copy yet.')));
      return;
    }
    final picked = await showModalBottomSheet<Routine>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final r in mine)
            ListTile(
              title: Text(r.name),
              subtitle: Text(scheduleSummary(r)),
              onTap: () => Navigator.pop(ctx, r),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    final r = await coaching.assignCopy(picked, c);
    if (context.mounted) context.push('/routine/${r.id}');
  }
}

class _WorkoutsTab extends StatelessWidget {
  final String clientId;
  const _WorkoutsTab({required this.clientId});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final c = coaching.clientOf(clientId)!;
    final sessions = coaching.sessionsOf(c);
    if (sessions.isEmpty) {
      return EmptyState(
        icon: Icons.history,
        title: 'No workouts yet',
        message: c.isMe
            ? 'Finish a workout on this phone and it shows up here with every set.'
            : 'Workouts appear here once ${c.name.split(' ').first} logs them. This needs cloud sync, which isn\'t connected yet.',
      );
    }
    final unit = context.read<AppState>().profile.unit;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = sessions[i];
        final n = coaching.commentsFor(s.id).length;
        return AppCard(
          onTap: () => context.push('/session/${s.id}'),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${DateFormat('EEE, MMM d').format(s.start)} · ${s.doneSets} sets · ${fmtVolume(s.volume, unit)}',
                    style: TextStyle(color: p.textSecondary, fontSize: 13)),
              ]),
            ),
            if (s.records.isNotEmpty) ...[Icon(Icons.emoji_events, size: 18, color: p.accent2), const SizedBox(width: 8)],
            Icon(n == 0 ? Icons.add_comment_outlined : Icons.comment, size: 20, color: n == 0 ? p.textSecondary : p.accent),
            if (n > 0) Text(' $n', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
  }
}
