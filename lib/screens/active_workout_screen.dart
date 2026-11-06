import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/coaching_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/workout_editor.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});
  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  Timer? _tick;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    // A fresh empty workout goes straight to the exercise picker.
    final s = context.read<AppState>().active;
    if (s != null && s.exercises.isEmpty && DateTime.now().difference(s.start).inSeconds < 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addExercises());
    }
  }

  void _onTick() {
    if (!mounted) return;
    final state = context.read<AppState>();
    final end = state.restEndsAt;
    if (end != null && !end.isAfter(DateTime.now())) {
      state.stopRest();
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rest over. Next set!'), duration: Duration(seconds: 2)),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _addExercises() async {
    final ids = await context.push<List<String>>('/exercises/pick');
    if (ids != null && ids.isNotEmpty && mounted) {
      await context.read<AppState>().addExercisesToActive(ids);
    }
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    final s = state.active;
    if (s == null || _finishing) return;
    final done = s.doneSets;
    final pending = s.exercises.fold<int>(0, (a, e) => a + e.sets.where((x) => !x.done).length);
    if (done == 0) {
      final discard = await confirm(context,
          title: 'Nothing logged yet',
          message: 'Tick at least one set to save this workout. Discard it instead?',
          confirmLabel: 'Discard workout',
          destructive: true);
      if (discard) {
        await state.discardActive();
        if (mounted) context.pop();
      }
      return;
    }
    if (pending > 0 &&
        !await confirm(context,
            title: 'Finish workout?',
            message: '$pending unticked set${pending == 1 ? '' : 's'} will not be saved.',
            confirmLabel: 'Finish')) {
      return;
    }
    if (!mounted) return;
    _finishing = true;
    final coaching = context.read<CoachingState>();
    final saved = await state.finishActive();
    if (saved != null) await coaching.onWorkoutFinished(saved);
    if (!mounted) return;
    if (saved == null) {
      context.pop();
    } else {
      context.pushReplacement('/session/${saved.id}?summary=1');
    }
  }

  Future<void> _discard() async {
    final state = context.read<AppState>();
    if (await confirm(context,
        title: 'Discard workout?',
        message: 'All sets logged in this workout will be lost.',
        confirmLabel: 'Discard',
        destructive: true)) {
      await state.discardActive();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final s = state.active;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.check_circle_outline,
          title: 'No workout running',
          message: 'Start one from Home or Workouts.',
          action: 'Close',
          onAction: () => context.pop(),
        ),
      );
    }
    final unit = state.profile.unit;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Minimise',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: () async {
            final n = await promptText(context, title: 'Workout name', initial: s.name);
            if (n != null) await state.editActive((x) => x.name = n);
          },
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
            Text(fmtClock(s.duration), style: TextStyle(fontSize: 13, color: p.accent, fontWeight: FontWeight.w700)),
          ]),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
              onPressed: _finish,
              child: const Text('Finish'),
            ),
          ),
        ],
      ),
      body: WorkoutEditor(
        session: s,
        onChanged: () => state.editActive((_) {}),
        onToggleSet: state.toggleSetDone,
        onAddExercises: _addExercises,
        header: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(children: [
              Expanded(child: Stat(fmtClock(s.duration), 'Duration')),
              Expanded(child: Stat(fmtVolume(s.volume, unit), 'Volume')),
              Expanded(child: Stat('${s.doneSets}/${s.totalSets}', 'Sets')),
            ]),
          ),
        ],
        footer: [
          const SizedBox(height: 16),
          TextButton(
            onPressed: _discard,
            style: TextButton.styleFrom(foregroundColor: p.danger),
            child: const Text('Discard workout'),
          ),
        ],
      ),
      bottomNavigationBar: state.restEndsAt == null ? null : _RestBar(state: state),
    );
  }
}

class _RestBar extends StatelessWidget {
  final AppState state;
  const _RestBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final left = state.restEndsAt!.difference(DateTime.now());
    final secs = left.inSeconds.clamp(0, 3600);
    final frac = state.restTotalSeconds == 0 ? 0.0 : (secs / state.restTotalSeconds).clamp(0.0, 1.0);
    return Material(
      color: p.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: frac, minHeight: 4, color: p.accent, backgroundColor: p.surfaceAlt),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(children: [
              Icon(Icons.timer_outlined, color: p.accent),
              const SizedBox(width: 8),
              Text('Rest', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Text(fmtClock(Duration(seconds: secs)),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
              const Spacer(),
              TextButton(onPressed: () => state.adjustRest(-15), child: const Text('−15')),
              TextButton(onPressed: () => state.adjustRest(15), child: const Text('+15')),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: state.stopRest,
                child: const Text('Skip'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
