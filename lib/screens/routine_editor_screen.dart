import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/routine.dart';
import '../models/coaching.dart';
import '../state/app_state.dart';
import '../state/coaching_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import 'routines_screen.dart' show kWeekdayShort;

class RoutineEditorScreen extends StatefulWidget {
  /// Routine id, or `new`.
  final String routineId;

  /// When set (and [routineId] is `new`), a coach writes a program for this client.
  final String? forClientId;
  const RoutineEditorScreen({super.key, required this.routineId, this.forClientId});

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late Routine _draft;
  late final TextEditingController _name;
  bool _dirty = false;
  bool _isNew = false;

  /// A coach's program opened by the client: view and train only.
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<AppState>().routineById(widget.routineId);
    final coaching = context.read<CoachingState>();
    _isNew = existing == null;
    final client = widget.forClientId == null ? null : coaching.clientOf(widget.forClientId!);
    _draft = existing?.copy() ?? (client != null ? coaching.newProgram(client) : Routine(name: ''));
    _locked = _draft.isCoachAssigned && _draft.coachId != coaching.myCoachId;
    _name = TextEditingController(text: _draft.name);
  }

  void _touch(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  bool get _canSave => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    _draft.name = _name.text.trim();
    // Keep the rotation in sync with the days.
    if (_draft.rotation.isEmpty) _draft.rotation = _draft.days.map((d) => d.id).toList();
    _draft.rotation = _draft.rotation.where((s) => s == null || _draft.dayById(s) != null).toList();
    final coaching = context.read<CoachingState>();
    if (_draft.coachId != null && _draft.coachId == coaching.myCoachId) {
      await coaching.saveProgram(_draft);
    } else {
      await context.read<AppState>().saveRoutine(_draft);
    }
    _dirty = false;
    if (mounted) context.pop();
  }

  Future<void> _addDay() async {
    final name = await promptText(context,
        title: 'New day', hint: 'e.g. Upper A, Push, Leg day', initial: 'Day ${_draft.days.length + 1}', action: 'Add');
    if (name == null) return;
    final day = RoutineDay(name: name);
    _touch(() {
      _draft.days.add(day);
      _draft.rotation.add(day.id);
    });
    if (mounted) _openDay(day);
  }

  Future<void> _openDay(RoutineDay day) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayEditorScreen(day: day)));
    _touch(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_locked) return _LockedRoutineView(routine: _draft);
    final forClient = _draft.clientId != null && _draft.coachId != null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context,
            title: 'Discard changes?', message: 'Your edits to this routine will be lost.', confirmLabel: 'Discard', destructive: true);
        if (leave && context.mounted) {
          _dirty = false;
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(forClient ? (_isNew ? 'New client program' : 'Client program') : (_isNew ? 'New routine' : 'Edit routine')),
          actions: [
            TextButton(onPressed: _canSave ? _save : null, child: const Text('Save')),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            TextField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: 'Routine name, e.g. Upper / Lower'),
              onChanged: (_) => _touch(() {}),
            ),
            const SizedBox(height: 20),
            Text('Schedule', style: context.text.titleMedium),
            const SizedBox(height: 4),
            Text(
              _draft.mode == ScheduleMode.weekdays
                  ? 'Each day is pinned to weekdays. Days without a workout are rest days.'
                  : 'Days run in order. If you miss a day, the next workout waits for you.',
              style: TextStyle(color: p.textSecondary),
            ),
            const SizedBox(height: 10),
            SegmentedButton<ScheduleMode>(
              segments: const [
                ButtonSegment(value: ScheduleMode.weekdays, icon: Icon(Icons.calendar_month), label: Text('Fixed weekdays')),
                ButtonSegment(value: ScheduleMode.rotation, icon: Icon(Icons.loop), label: Text('Rotation')),
              ],
              selected: {_draft.mode},
              onSelectionChanged: (v) => _touch(() => _draft.mode = v.first),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: Text('Days', style: context.text.titleMedium)),
              TextButton.icon(onPressed: _addDay, icon: const Icon(Icons.add), label: const Text('Add day')),
            ]),
            if (_draft.days.isEmpty)
              AppCard(
                child: Text('Add your first training day, like "Upper" or "Push".',
                    style: TextStyle(color: p.textSecondary)),
              ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (a, b) => _touch(() {
                if (b > a) b--;
                _draft.days.insert(b, _draft.days.removeAt(a));
              }),
              children: [
                for (final (i, d) in _draft.days.indexed)
                  Padding(
                    key: ValueKey(d.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DayCard(
                      index: i,
                      day: d,
                      showWeekdays: _draft.mode == ScheduleMode.weekdays,
                      onTap: () => _openDay(d),
                      onToggleWeekday: (w) => _touch(() {
                        if (d.weekdays.contains(w)) {
                          d.weekdays.remove(w);
                        } else {
                          for (final other in _draft.days) {
                            other.weekdays.remove(w);
                          }
                          d.weekdays.add(w);
                          d.weekdays.sort();
                        }
                      }),
                      onDelete: () async {
                        if (await confirm(context,
                            title: 'Remove ${d.name}?', message: 'Its exercises will be removed from this routine.', confirmLabel: 'Remove', destructive: true)) {
                          _touch(() {
                            _draft.days.remove(d);
                            _draft.rotation.removeWhere((s) => s == d.id);
                          });
                        }
                      },
                      onRename: () async {
                        final n = await promptText(context, title: 'Rename day', initial: d.name);
                        if (n != null) _touch(() => d.name = n);
                      },
                    ),
                  ),
              ],
            ),
            if (_draft.mode == ScheduleMode.rotation && _draft.days.isNotEmpty) ...[
              const SizedBox(height: 16),
              _RotationEditor(
                routine: _draft,
                onChanged: () => _touch(() {}),
              ),
            ],
            if (_draft.mode == ScheduleMode.weekdays &&
                _draft.days.isNotEmpty &&
                !_draft.days.any((d) => d.weekdays.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Tip: tap the weekday letters on each day to pin it. Until then the days run in order.',
                    style: TextStyle(color: p.accent2)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(forClient ? (_draft.clientId == kMeClientId ? 'Save & send to me' : 'Save & send to client') : 'Save routine'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final int index;
  final RoutineDay day;
  final bool showWeekdays;
  final VoidCallback onTap;
  final ValueChanged<int> onToggleWeekday;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _DayCard({
    required this.index,
    required this.day,
    required this.showWeekdays,
    required this.onTap,
    required this.onToggleWeekday,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.read<AppState>();
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.drag_indicator, color: p.textSecondary),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(day.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                day.exercises.isEmpty
                    ? 'No exercises yet · tap to add'
                    : '${plural(day.exercises.length, 'exercise')} · ${plural(day.totalSets, 'set')} · ~${fmtDuration(day.estimatedDuration)}',
                style: TextStyle(color: p.textSecondary, fontSize: 13),
              ),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Remove day')),
            ],
          ),
        ]),
        if (day.exercises.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(children: [
              for (final pe in day.exercises.take(6))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ExerciseThumb(state.exercise(pe.exerciseId), size: 34),
                ),
              if (day.exercises.length > 6)
                Text('+${day.exercises.length - 6}', style: TextStyle(color: p.textSecondary)),
            ]),
          ),
        if (showWeekdays)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(children: [
              for (var w = 1; w <= 7; w++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onToggleWeekday(w),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: day.weekdays.contains(w) ? p.accent : p.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          kWeekdayShort[w - 1].substring(0, 2),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: day.weekdays.contains(w) ? p.onAccent : p.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _RotationEditor extends StatelessWidget {
  final Routine routine;
  final VoidCallback onChanged;
  const _RotationEditor({required this.routine, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (routine.rotation.isEmpty) routine.rotation = routine.days.map((d) => d.id).toList();
    final slots = routine.rotation;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cycle order', style: context.text.titleSmall),
        const SizedBox(height: 4),
        Text('The app suggests the next slot after your last workout. Rest slots use up a calendar day.',
            style: TextStyle(color: p.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 8, children: [
          for (final (i, s) in slots.indexed)
            InputChip(
              avatar: CircleAvatar(
                backgroundColor: s == null ? p.surfaceAlt : p.accent,
                child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: s == null ? p.textSecondary : p.onAccent)),
              ),
              label: Text(s == null ? 'Rest' : (routine.dayById(s)?.name ?? '?')),
              onDeleted: slots.length <= 1
                  ? null
                  : () {
                      slots.removeAt(i);
                      onChanged();
                    },
            ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          PopupMenuButton<String>(
            onSelected: (id) {
              slots.add(id);
              onChanged();
            },
            itemBuilder: (_) => [for (final d in routine.days) PopupMenuItem(value: d.id, child: Text(d.name))],
            child: const Chip(avatar: Icon(Icons.add, size: 18), label: Text('Add day')),
          ),
          ActionChip(
            avatar: const Icon(Icons.hotel, size: 18),
            label: const Text('Add rest'),
            onPressed: () {
              slots.add(null);
              onChanged();
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset'),
            onPressed: () {
              routine.rotation = routine.days.map((d) => d.id).toList();
              onChanged();
            },
          ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------

/// Edits one day's exercises in place. Changes are kept when the routine is
/// saved.
class DayEditorScreen extends StatefulWidget {
  final RoutineDay day;
  const DayEditorScreen({super.key, required this.day});
  @override
  State<DayEditorScreen> createState() => _DayEditorScreenState();
}

class _DayEditorScreenState extends State<DayEditorScreen> {
  RoutineDay get day => widget.day;

  Future<void> _add() async {
    final ids = await context.push<List<String>>('/exercises/pick');
    if (ids == null || ids.isEmpty || !mounted) return;
    final rest = context.read<AppState>().profile.defaultRestSeconds;
    setState(() => day.exercises.addAll(ids.map((id) => PlannedExercise(exerciseId: id, restSeconds: rest))));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final unit = state.profile.unit;
    return Scaffold(
      appBar: AppBar(
        title: Text(day.name),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final n = await promptText(context, title: 'Rename day', initial: day.name);
              if (n != null) setState(() => day.name = n);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add exercises'),
      ),
      body: day.exercises.isEmpty
          ? EmptyState(
              icon: Icons.fitness_center,
              title: 'No exercises yet',
              message: 'Search 870+ exercises with demos and instructions.',
              action: 'Add exercises',
              onAction: _add,
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              buildDefaultDragHandles: false,
              itemCount: day.exercises.length,
              onReorder: (a, b) => setState(() {
                if (b > a) b--;
                day.exercises.insert(b, day.exercises.removeAt(a));
              }),
              itemBuilder: (_, i) {
                final pe = day.exercises[i];
                final e = state.exercise(pe.exerciseId);
                return Dismissible(
                  key: ValueKey('${pe.exerciseId}_$i${pe.hashCode}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: p.danger, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => setState(() => day.exercises.removeAt(i)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _PlannedExerciseSheet(planned: pe, name: e.name),
                        );
                        setState(() {});
                      },
                      padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
                      child: Row(children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.drag_indicator, color: p.textSecondary),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/exercise/${Uri.encodeComponent(e.id)}'),
                          child: ExerciseThumb(e, size: 52),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                '${pe.sets} × ${pe.repLabel} reps',
                                if (pe.targetWeight != null) fmtWeight(pe.targetWeight!, unit),
                                'rest ${fmtRest(pe.restSeconds)}',
                              ].join(' · '),
                              style: TextStyle(color: p.textSecondary, fontSize: 13),
                            ),
                            if (pe.notes.isNotEmpty)
                              Text(pe.notes,
                                  style: TextStyle(color: p.accent2, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        Icon(Icons.tune, color: p.textSecondary, size: 20),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PlannedExerciseSheet extends StatefulWidget {
  final PlannedExercise planned;
  final String name;
  const _PlannedExerciseSheet({required this.planned, required this.name});
  @override
  State<_PlannedExerciseSheet> createState() => _PlannedExerciseSheetState();
}

class _PlannedExerciseSheetState extends State<_PlannedExerciseSheet> {
  PlannedExercise get pe => widget.planned;
  late final _weight = TextEditingController();
  late final _notes = TextEditingController(text: pe.notes);

  @override
  void initState() {
    super.initState();
    final unit = context.read<AppState>().profile.unit;
    if (pe.targetWeight != null) _weight.text = fmtWeight(pe.targetWeight!, unit, withUnit: false);
  }

  @override
  void dispose() {
    final unit = context.read<AppState>().profile.unit;
    final w = double.tryParse(_weight.text.replaceAll(',', '.'));
    pe.targetWeight = w == null || w <= 0 ? null : displayToKg(w, unit);
    pe.notes = _notes.text.trim();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = context.read<AppState>().profile.unit;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.name, style: context.text.titleLarge),
          const SizedBox(height: 16),
          _Stepper(label: 'Sets', value: pe.sets, min: 1, max: 12, onChanged: (v) => setState(() => pe.sets = v)),
          _Stepper(
            label: 'Min reps',
            value: pe.repMin,
            min: 1,
            max: 100,
            onChanged: (v) => setState(() {
              pe.repMin = v;
              if (pe.repMax < v) pe.repMax = v;
            }),
          ),
          _Stepper(
            label: 'Max reps',
            value: pe.repMax,
            min: 1,
            max: 100,
            onChanged: (v) => setState(() {
              pe.repMax = v;
              if (pe.repMin > v) pe.repMin = v;
            }),
          ),
          const SizedBox(height: 12),
          Text('Rest between sets', style: context.text.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in [30, 60, 90, 120, 150, 180, 240, 300])
              ChoiceChip(
                label: Text(fmtRest(s)),
                selected: pe.restSeconds == s,
                showCheckmark: false,
                onSelected: (_) => setState(() => pe.restSeconds = s),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Target weight (${unit.name}, optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes, e.g. pause at the bottom'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ]),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        IconButton.filledTonal(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 48,
          child: Text('$value',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.textPrimary)),
        ),
        IconButton.filledTonal(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ]),
    );
  }
}


/// Read-only view of a coach's program for the client, with a way to make an
/// editable copy.
class _LockedRoutineView extends StatelessWidget {
  final Routine routine;
  const _LockedRoutineView({required this.routine});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final unit = state.profile.unit;
    final isActive = state.profile.activeRoutineId == routine.id;
    return Scaffold(
      appBar: AppBar(title: Text(routine.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        AppCard(
          color: p.accent.withValues(alpha: 0.08),
          borderColor: p.accent.withValues(alpha: 0.4),
          child: Row(children: [
            Icon(Icons.lock_outline, color: p.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Program from ${routine.coachName ?? 'your coach'}. You can train it and log sets; '
                  'only your coach can change it.'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: isActive
                ? OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.check), label: const Text('Active plan'))
                : FilledButton(onPressed: () => state.setActiveRoutine(routine.id), child: const Text('Make active plan')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final copy = await state.duplicateRoutine(routine);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved "${copy.name}" to your routines')));
                }
              },
              child: const Text('Copy to my routines'),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        for (final d in routine.days) ...[
          Text(d.name, style: context.text.titleMedium),
          if (routine.mode == ScheduleMode.weekdays && d.weekdays.isNotEmpty)
            Text(d.weekdays.map((w) => kWeekdayShort[w - 1]).join(', '), style: TextStyle(color: p.textSecondary)),
          const SizedBox(height: 8),
          for (final pe in d.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => context.push('/exercise/${Uri.encodeComponent(pe.exerciseId)}'),
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ExerciseThumb(state.exercise(pe.exerciseId), size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(state.exercise(pe.exerciseId).name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          '${pe.sets} × ${pe.repLabel} reps',
                          if (pe.targetWeight != null) fmtWeight(pe.targetWeight!, unit),
                          'rest ${fmtRest(pe.restSeconds)}',
                        ].join(' · '),
                        style: TextStyle(color: p.textSecondary, fontSize: 13),
                      ),
                      if (pe.notes.isNotEmpty) Text(pe.notes, style: TextStyle(color: p.accent2, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}
