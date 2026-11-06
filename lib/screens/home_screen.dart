import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic/schedule.dart';
import '../models/routine.dart';
import '../models/workout.dart';
import '../models/coaching.dart';
import '../state/app_state.dart';
import '../state/coaching_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/ids.dart';
import '../widgets/coaching_widgets.dart';
import '../widgets/common.dart';
import 'workout_actions.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.today;
    final now = state.clock();
    final p = context.palette;
    final h = now.hour;
    final greeting = h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
    final name = state.profile.name.isEmpty ? '' : ', ${state.profile.name.split(' ').first}';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(DateFormat('EEEE, MMM d').format(now).toUpperCase(),
                      style: TextStyle(color: p.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text('$greeting$name', style: context.text.headlineSmall),
                ]),
              ),
              _StreakChip(weeks: state.streakWeeks),
              const InboxButton(audience: Audience.client),
            ]),
            const SizedBox(height: 18),
            _TodayCard(plan: plan),
            const _CoachReminders(),
            const SizedBox(height: 12),
            _QuickActions(),
            const SizedBox(height: 24),
            if (plan.week.isNotEmpty) ...[
              const SectionHeader('This week'),
              _WeekStrip(plan: plan),
              const SizedBox(height: 24),
            ],
            _MonthlyActivity(),
            const SizedBox(height: 24),
            _RecentWorkouts(),
          ],
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  final int weeks;
  const _StreakChip({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final target = context.select<AppState, int>((s) => s.profile.weeklyTarget);
    return Tooltip(
      message: 'Weeks in a row with at least $target training days',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.accent2.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_fire_department, color: p.accent2, size: 20),
          const SizedBox(width: 4),
          Text('$weeks wk', style: TextStyle(color: p.accent2, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final TodayPlan plan;
  const _TodayCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final active = state.active;

    if (active != null) {
      return _shell(
        context,
        label: 'IN PROGRESS',
        title: active.name,
        subtitle: '${active.doneSets} of ${active.totalSets} sets done · started ${DateFormat.jm().format(active.start)}',
        primary: FilledButton.icon(
          onPressed: () => context.push('/workout'),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Resume workout'),
        ),
      );
    }

    switch (plan.status) {
      case PlanStatus.noRoutine:
        return _shell(
          context,
          label: 'TODAY',
          title: 'No active plan',
          subtitle: 'Create a routine or pick a starter plan, and the app will tell you what to train each day.',
          primary: FilledButton(onPressed: () => context.go('/routines'), child: const Text('Set up a plan')),
        );
      case PlanStatus.emptyRoutine:
        return _shell(
          context,
          label: 'TODAY',
          title: plan.routine!.name,
          subtitle: 'Add days and exercises to this routine to see today\'s workout here.',
          primary: FilledButton(
              onPressed: () => context.push('/routine/${plan.routine!.id}'), child: const Text('Edit routine')),
        );
      case PlanStatus.done:
        final s = plan.doneSession!;
        return _shell(
          context,
          label: 'TODAY · DONE',
          labelColor: p.success,
          title: s.name,
          subtitle: [
            fmtDuration(s.duration),
            fmtVolume(s.volume, state.profile.unit),
            if (s.records.isNotEmpty) '${s.records.length} PR${s.records.length == 1 ? '' : 's'}',
          ].join(' · '),
          footer: plan.nextDay == null ? null : 'Next: ${plan.nextDay!.name} · ${relativeDay(plan.nextDate!, state.clock())}',
          primary: OutlinedButton(onPressed: () => context.push('/session/${s.id}'), child: const Text('View summary')),
        );
      case PlanStatus.rest:
        final next = plan.nextDay;
        return _shell(
          context,
          label: plan.overridden ? 'TODAY · SKIPPED' : 'TODAY · REST DAY',
          labelColor: p.accent2,
          title: 'Recover and come back stronger',
          subtitle: next == null
              ? 'No workout planned this week.'
              : 'Next: ${next.name} · ${relativeDay(plan.nextDate!, state.clock())}',
          primary: next == null
              ? null
              : OutlinedButton(
                  onPressed: () => startRoutineDay(context, plan.routine!, next),
                  child: Text('Train ${next.name} anyway'),
                ),
          menu: plan.overridden ? _menu(context, plan) : null,
        );
      case PlanStatus.workout:
        final day = plan.day!;
        final exercises = day.exercises.map((e) => state.exercise(e.exerciseId)).toList();
        final muscles = <String>{for (final e in exercises) e.primaryMuscle}.take(4);
        final last = state.sessions.where((s) => s.dayId == day.id).firstOrNull;
        return _shell(
          context,
          label: plan.overridden ? 'TODAY · SWAPPED' : 'TODAY',
          title: day.name,
          subtitle:
              '${plan.routine!.name} · ${plural(day.exercises.length, 'exercise')} · ${plural(day.totalSets, 'set')} · ~${fmtDuration(day.estimatedDuration)}',
          tags: muscles.map((m) => capitalize(m)).toList(),
          body: Column(children: [
            for (final (i, pe) in day.exercises.take(4).indexed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  ExerciseThumb(exercises[i], size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Text(exercises[i].name, overflow: TextOverflow.ellipsis)),
                  Text('${pe.sets} × ${pe.repLabel}', style: TextStyle(color: p.textSecondary)),
                ]),
              ),
            if (day.exercises.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('+ ${day.exercises.length - 4} more', style: TextStyle(color: p.textSecondary)),
                ),
              ),
          ]),
          footer: last == null ? 'First time doing this day' : 'Last done ${relativeDay(last.start, state.clock()).toLowerCase()}',
          primary: FilledButton.icon(
            onPressed: () => startRoutineDay(context, plan.routine!, day, slotIndex: plan.slotIndex),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start workout'),
          ),
          menu: _menu(context, plan),
        );
    }
  }

  Widget _menu(BuildContext context, TodayPlan plan) {
    final state = context.read<AppState>();
    final routine = plan.routine!;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: context.palette.textSecondary),
      onSelected: (v) async {
        if (v == 'skip') {
          await state.setTodayOverride('rest');
        } else if (v == 'reset') {
          await state.setTodayOverride(null);
        } else if (v == 'swap' && context.mounted) {
          final picked = await showModalBottomSheet<RoutineDay>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Train a different day', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                ),
                for (final d in routine.days.where((d) => d.exercises.isNotEmpty))
                  ListTile(
                    title: Text(d.name),
                    subtitle: Text(plural(d.exercises.length, 'exercise')),
                    trailing: d.id == plan.day?.id ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(ctx, d),
                  ),
                const SizedBox(height: 8),
              ]),
            ),
          );
          if (picked != null) await state.setTodayOverride(picked.id);
        }
      },
      itemBuilder: (_) => [
        if (plan.status == PlanStatus.workout) const PopupMenuItem(value: 'swap', child: Text('Swap to another day')),
        if (plan.status == PlanStatus.workout) const PopupMenuItem(value: 'skip', child: Text('Skip today (rest)')),
        if (plan.overridden) const PopupMenuItem(value: 'reset', child: Text('Back to the plan')),
      ],
    );
  }

  Widget _shell(
    BuildContext context, {
    required String label,
    Color? labelColor,
    required String title,
    required String subtitle,
    List<String> tags = const [],
    Widget? body,
    String? footer,
    Widget? primary,
    Widget? menu,
  }) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.accent.withValues(alpha: 0.14), p.surface, p.surface],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: labelColor ?? p.accent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
          ),
          if (menu != null) menu else const SizedBox(height: 40),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.text.headlineSmall),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: p.textSecondary, height: 1.35)),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags) Tag(t, color: p.accent)]),
            ],
            if (body != null) ...[const SizedBox(height: 6), body],
            if (footer != null) ...[
              const SizedBox(height: 12),
              Text(footer, style: TextStyle(color: p.textSecondary, fontSize: 13)),
            ],
            if (primary != null) ...[
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: primary),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget action(IconData icon, String label, VoidCallback onTap, Color color) => Expanded(
          child: AppCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
        );
    return Row(children: [
      action(Icons.add_circle_outline, 'Empty workout', () => startEmpty(context), p.accent),
      const SizedBox(width: 12),
      action(Icons.search, 'Exercises', () => context.push('/exercises/pick?single=1'), p.accent2),
    ]);
  }
}

class _WeekStrip extends StatelessWidget {
  final TodayPlan plan;
  const _WeekStrip({required this.plan});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final now = state.clock();
    final monday = dateOnly(now).subtract(Duration(days: now.weekday - 1));
    final doneDays = {
      for (final s in state.sessions)
        if (!s.start.isBefore(monday)) dayKey(s.start)
    };
    // Planned days come from the forecast (today onward).
    final planned = {for (final d in plan.week) dayKey(d.date): d.day};

    return Row(children: [
      for (var i = 0; i < 7; i++)
        Builder(builder: (context) {
          final date = monday.add(Duration(days: i));
          final key = dayKey(date);
          final isToday = sameDay(date, now);
          final done = doneDays.contains(key);
          final plannedDay = planned[key];
          final past = date.isBefore(dateOnly(now));
          final bg = done ? p.accent : (isToday ? p.accent.withValues(alpha: 0.14) : p.surface);
          final fg = done ? p.onAccent : (isToday ? p.accent : p.textPrimary);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Tooltip(
                message: done ? 'Trained' : (plannedDay?.name ?? (past ? 'No workout' : 'Rest')),
                child: Container(
                  height: 74,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isToday ? p.accent : p.border, width: isToday ? 1.5 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(DateFormat('E').format(date).substring(0, 2),
                        style: TextStyle(color: done ? p.onAccent : p.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${date.day}', style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    if (done)
                      Icon(Icons.check, size: 14, color: p.onAccent)
                    else if (plannedDay != null)
                      Text(_abbr(plannedDay.name),
                          style: TextStyle(color: p.textSecondary, fontSize: 10, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.clip,
                          maxLines: 1)
                    else
                      const SizedBox(height: 14),
                  ]),
                ),
              ),
            ),
          );
        }),
    ]);
  }

  static String _abbr(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return name.length <= 4 ? name : name.substring(0, 3);
    return words.map((w) => w[0].toUpperCase()).join().substring(0, words.length.clamp(1, 3));
  }
}

class _MonthlyActivity extends StatefulWidget {
  @override
  State<_MonthlyActivity> createState() => _MonthlyActivityState();
}

class _MonthlyActivityState extends State<_MonthlyActivity> {
  int _offset = 0; // months back from now

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final now = state.clock();
    final month = DateTime(now.year, now.month - _offset);
    final prev = DateTime(month.year, month.month - 1);
    final days = DateTime(month.year, month.month + 1, 0).day;

    final byDay = <int, List<WorkoutSession>>{};
    var prevCount = 0;
    for (final s in state.sessions) {
      if (s.start.year == month.year && s.start.month == month.month) {
        byDay.putIfAbsent(s.start.day, () => []).add(s);
      } else if (s.start.year == prev.year && s.start.month == prev.month) {
        prevCount++;
      }
    }
    final count = byDay.values.fold(0, (a, l) => a + l.length);
    final maxVolume = byDay.values
        .map((l) => l.fold(0.0, (a, s) => a + s.volume))
        .fold(0.0, (a, b) => a > b ? a : b);
    final leading = DateTime(month.year, month.month, 1).weekday - 1;

    String compare() {
      if (prevCount == 0) return count == 0 ? 'No workouts yet' : 'First month on record';
      final diff = count - prevCount;
      if (diff == 0) return 'Same as last month';
      return '${diff > 0 ? '+' : ''}$diff vs last month';
    }

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Monthly activity', style: context.text.titleMedium)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _offset++),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
          ),
          Text(DateFormat('MMM yyyy').format(month), style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _offset == 0 ? null : () => setState(() => _offset--),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(child: Center(child: Text(d, style: TextStyle(color: p.textSecondary, fontSize: 11)))),
        ]),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++)
              Builder(builder: (_) {
                final list = byDay[d];
                final vol = list?.fold(0.0, (a, s) => a + s.volume) ?? 0;
                final intensity = list == null ? 0.0 : (maxVolume == 0 ? 1.0 : 0.35 + 0.65 * (vol / maxVolume));
                final isToday = _offset == 0 && d == now.day;
                return Tooltip(
                  message: list == null ? DateFormat('MMM d').format(DateTime(month.year, month.month, d)) : list.map((s) => s.name).join(', '),
                  child: Container(
                    decoration: BoxDecoration(
                      color: list == null ? p.surfaceAlt : p.accent.withValues(alpha: intensity),
                      borderRadius: BorderRadius.circular(7),
                      border: isToday ? Border.all(color: p.accent, width: 1.5) : null,
                    ),
                    alignment: Alignment.center,
                    child: Text('$d',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: list != null && intensity > 0.6 ? p.onAccent : p.textSecondary,
                        )),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [
          Text('$count workout${count == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('  ·  ${compare()}', style: TextStyle(color: p.textSecondary)),
        ]),
      ]),
    );
  }
}

class _RecentWorkouts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final logs = state.sessions.take(6).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Recent workouts', action: logs.isEmpty ? null : 'See all', onAction: () => context.push('/history')),
      if (logs.isEmpty)
        AppCard(
          child: Row(children: [
            Icon(Icons.history, color: p.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text('Finished workouts show up here.', style: TextStyle(color: p.textSecondary))),
          ]),
        )
      else
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final s = logs[i];
              return SizedBox(
                width: 168,
                child: AppCard(
                  onTap: () => context.push('/session/${s.id}'),
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(relativeDay(s.start, state.clock()), style: TextStyle(color: p.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(s.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text('${fmtDuration(s.duration)} · ${s.exercises.length} ex',
                        style: TextStyle(color: p.textSecondary, fontSize: 12)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(fmtVolume(s.volume, state.profile.unit),
                          style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                      if (s.records.isNotEmpty) ...[
                        const Spacer(),
                        Icon(Icons.emoji_events, size: 16, color: p.accent2),
                        Text('${s.records.length}', style: TextStyle(color: p.accent2, fontWeight: FontWeight.w700)),
                      ],
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
    ]);
  }
}


/// Today's reminders from the phone owner's coach.
class _CoachReminders extends StatelessWidget {
  const _CoachReminders();

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final list = coaching.myRemindersToday;
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        onTap: () => context.go('/coach'),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FROM ${(coaching.myCoach?.name ?? 'YOUR COACH').toUpperCase()}',
              style: TextStyle(color: p.accent2, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          for (final r in list)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(reminderIcon(r.type), size: 18, color: p.accent2),
                const SizedBox(width: 10),
                Expanded(child: Text(r.text)),
                Text(r.time, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      ),
    );
  }
}
