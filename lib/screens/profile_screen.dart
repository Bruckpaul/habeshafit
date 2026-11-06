import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import '../state/coaching_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final prof = state.profile;
    final name = prof.name.isEmpty ? 'Athlete' : prof.name;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          AppCard(
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: p.accent.withValues(alpha: 0.16),
                child: Text(name.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: p.accent, fontSize: 26, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: context.text.titleLarge),
                  Text('${prof.goal.label} · ${capitalize(prof.experience)}', style: TextStyle(color: p.textSecondary)),
                  Text('Member since ${DateFormat('MMM yyyy').format(prof.memberSince)}',
                      style: TextStyle(color: p.textSecondary, fontSize: 12)),
                ]),
              ),
              IconButton(
                tooltip: 'Edit name',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final n = await promptText(context, title: 'Your name', initial: prof.name);
                  if (n != null) await state.updateProfile((x) => x.name = n);
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(children: [
              Expanded(child: Stat('${state.sessions.length}', 'Workouts')),
              Expanded(child: Stat('${state.streakWeeks} wk', 'Streak')),
              Expanded(
                child: Stat(
                  fmtDuration(state.sessions.fold(Duration.zero, (a, s) => a + s.duration)),
                  'Time trained',
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Training'),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Goal'),
              trailing: DropdownButton<TrainingGoal>(
                value: prof.goal,
                underline: const SizedBox(),
                items: [for (final g in TrainingGoal.values) DropdownMenuItem(value: g, child: Text(g.label))],
                onChanged: (v) => state.updateProfile((x) => x.goal = v!),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Weekly target'),
              subtitle: const Text('Training days for the streak'),
              trailing: DropdownButton<int>(
                value: prof.weeklyTarget,
                underline: const SizedBox(),
                items: [for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text('$d days'))],
                onChanged: (v) => state.updateProfile((x) => x.weeklyTarget = v!),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Default rest timer'),
              subtitle: const Text('For exercises added on the fly'),
              trailing: DropdownButton<int>(
                value: prof.defaultRestSeconds,
                underline: const SizedBox(),
                items: [for (final s in [30, 60, 90, 120, 180, 240]) DropdownMenuItem(value: s, child: Text(fmtRest(s)))],
                onChanged: (v) => state.updateProfile((x) => x.defaultRestSeconds = v!),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('Active plan'),
              subtitle: Text(state.activeRoutine?.name ?? 'None'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/routines'),
            ),
          ]),
          const SizedBox(height: 24),
          const SectionHeader('App'),
          _Group(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Icon(Icons.straighten, color: p.textSecondary),
                const SizedBox(width: 16),
                const Expanded(child: Text('Units', style: TextStyle(fontSize: 16))),
                SegmentedButton<WeightUnit>(
                  segments: const [
                    ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                    ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                  ],
                  selected: {prof.unit},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => state.updateProfile((x) => x.unit = v.first),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                Icon(Icons.dark_mode_outlined, color: p.textSecondary),
                const SizedBox(width: 16),
                const Expanded(child: Text('Theme', style: TextStyle(fontSize: 16))),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                  ],
                  selected: {prof.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => state.updateProfile((x) => x.themeMode = v.first),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 24),
          const SectionHeader('Your data'),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Export backup'),
              subtitle: const Text('Copies all your data as JSON'),
              onTap: () async {
                final json = await state.exportData();
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Backup copied (${(json.length / 1024).toStringAsFixed(0)} KB). Paste it somewhere safe.'),
                  ));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Restore backup'),
              subtitle: const Text('Replaces all data on this device'),
              onTap: () => _restore(context),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: p.danger),
              title: Text('Erase all data', style: TextStyle(color: p.danger)),
              onTap: () async {
                if (await confirm(context,
                    title: 'Erase everything?',
                    message: 'Routines, workouts, measurements and settings will be deleted from this device. Export a backup first if you might need them.',
                    confirmLabel: 'Erase',
                    destructive: true)) {
                  await state.resetAll();
                  if (context.mounted) await context.read<CoachingState>().resetAll();
                }
              },
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'HabeshaFit 1.0 · data stored on this device\nExercise data: free-exercise-db (public domain)',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textSecondary, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup'),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Paste the backup JSON here'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Restore')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    try {
      await context.read<AppState>().importData(text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That isn\'t a valid HabeshaFit backup')));
      }
    }
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const Divider(indent: 56),
          c,
        ],
      ]),
    );
  }
}
