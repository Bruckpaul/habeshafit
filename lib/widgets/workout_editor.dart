import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/stats.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';

/// Exercise blocks with set tables. Used by the live workout and by the
/// editor for finished workouts.
class WorkoutEditor extends StatelessWidget {
  final WorkoutSession session;

  /// Called after any change to [session]; the caller persists it.
  final VoidCallback onChanged;

  /// Marks a set done/undone. The live workout also fills hints and starts
  /// the rest timer.
  final Future<void> Function(ExerciseEntry entry, int index) onToggleSet;
  final Future<void> Function() onAddExercises;
  final List<Widget> header;
  final List<Widget> footer;

  const WorkoutEditor({
    super.key,
    required this.session,
    required this.onChanged,
    required this.onToggleSet,
    required this.onAddExercises,
    this.header = const [],
    this.footer = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ...header,
        for (final (i, e) in session.exercises.indexed)
          Padding(
            key: ValueKey(e.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: _ExerciseBlock(
              session: session,
              entry: e,
              index: i,
              onChanged: onChanged,
              onToggleSet: onToggleSet,
            ),
          ),
        if (session.exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              icon: Icons.add_circle_outline,
              title: 'Add your first exercise',
              message: 'Pick one or several; you can add more at any point.',
              action: 'Add exercises',
              onAction: onAddExercises,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: onAddExercises,
              icon: const Icon(Icons.add),
              label: const Text('Add exercises'),
            ),
          ),
        ...footer,
      ],
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  final WorkoutSession session;
  final ExerciseEntry entry;
  final int index;
  final VoidCallback onChanged;
  final Future<void> Function(ExerciseEntry entry, int index) onToggleSet;

  const _ExerciseBlock({
    required this.session,
    required this.entry,
    required this.index,
    required this.onChanged,
    required this.onToggleSet,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final ex = state.exercise(entry.exerciseId);
    final unit = state.profile.unit;
    final prev = previousSets(entry.exerciseId, state.sessions, excludeSessionId: session.id);
    final progress = shouldProgress(prev, entry.repMax);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => context.push('/exercise/${Uri.encodeComponent(ex.id)}'),
            child: ExerciseThumb(ex, size: 44),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/exercise/${Uri.encodeComponent(ex.id)}'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ex.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.accent)),
                Text(
                  [
                    if (entry.repTarget != null) 'Target ${entry.repTarget} reps',
                    'Rest ${fmtRest(entry.restSeconds)}',
                  ].join(' · '),
                  style: TextStyle(color: p.textSecondary, fontSize: 12),
                ),
              ]),
            ),
          ),
          _menu(context, state),
        ]),
        if (progress)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Tag('You hit ${entry.repMax} reps on every set last time. Add weight.',
                color: p.success, icon: Icons.trending_up),
          ),
        if (entry.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Text(entry.notes, style: TextStyle(color: p.accent2, fontSize: 13)),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            _head('SET', 40),
            Expanded(flex: 5, child: _headText('PREVIOUS', p)),
            Expanded(flex: 3, child: _headText(unit.name.toUpperCase(), p, center: true)),
            Expanded(flex: 3, child: _headText('REPS', p, center: true)),
            const SizedBox(width: 48, child: Icon(Icons.check, size: 16)),
          ]),
        ),
        for (final (i, set) in entry.sets.indexed)
          Dismissible(
            key: ObjectKey(set),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: p.danger,
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) {
              entry.sets.remove(set);
              onChanged();
            },
            child: _SetRow(
              key: ObjectKey(set),
              set: set,
              number: _numberFor(i),
              previous: i < prev.length ? prev[i] : null,
              hint: i < prev.length
                  ? prev[i]
                  : (i > 0 && entry.sets[i - 1].reps != null ? entry.sets[i - 1] : null),
              unit: unit,
              onChanged: onChanged,
              onToggle: () => onToggleSet(entry, i),
              onKind: (k) {
                set.kind = k;
                onChanged();
              },
              onDelete: () {
                entry.sets.remove(set);
                onChanged();
              },
            ),
          ),
        TextButton.icon(
          onPressed: () {
            entry.sets.add(SetEntry());
            onChanged();
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add set'),
        ),
      ]),
    );
  }

  /// Working sets are numbered; warm-up/drop/failure sets show a letter.
  String _numberFor(int i) {
    final kind = entry.sets[i].kind;
    if (kind != SetKind.normal) return kind.short;
    var n = 0;
    for (var j = 0; j <= i; j++) {
      if (entry.sets[j].kind == SetKind.normal) n++;
    }
    return '$n';
  }

  Widget _head(String t, double w) => SizedBox(
        width: w,
        child: Builder(builder: (c) => _headText(t, c.palette, center: true)),
      );

  Widget _headText(String t, Palette p, {bool center = false}) => Text(
        t,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      );

  Widget _menu(BuildContext context, AppState state) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'notes':
            final n = await promptText(context, title: 'Notes', initial: entry.notes, hint: 'Seat height 4, slow negatives…');
            if (n != null) {
              entry.notes = n;
              onChanged();
            }
          case 'rest':
            final s = await showModalBottomSheet<int>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Wrap(children: [
                  for (final sec in [0, 30, 60, 90, 120, 150, 180, 240, 300])
                    ListTile(
                      title: Text(sec == 0 ? 'Off' : fmtRest(sec)),
                      trailing: entry.restSeconds == sec ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(ctx, sec),
                    ),
                ]),
              ),
            );
            if (s != null) {
              entry.restSeconds = s;
              onChanged();
            }
          case 'replace':
            final ids = await context.push<List<String>>('/exercises/pick');
            if (ids != null && ids.isNotEmpty) {
              entry.exerciseId = ids.first;
              onChanged();
            }
          case 'up':
            session.exercises.insert(index - 1, session.exercises.removeAt(index));
            onChanged();
          case 'down':
            session.exercises.insert(index + 1, session.exercises.removeAt(index));
            onChanged();
          case 'remove':
            if (entry.doneSets == 0 ||
                await confirm(context,
                    title: 'Remove exercise?',
                    message: 'Its logged sets will be removed from this workout.',
                    confirmLabel: 'Remove',
                    destructive: true)) {
              session.exercises.remove(entry);
              onChanged();
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'notes', child: Text('Add note')),
        const PopupMenuItem(value: 'rest', child: Text('Rest timer')),
        const PopupMenuItem(value: 'replace', child: Text('Replace exercise')),
        if (index > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
        if (index < session.exercises.length - 1) const PopupMenuItem(value: 'down', child: Text('Move down')),
        const PopupMenuItem(value: 'remove', child: Text('Remove')),
      ],
    );
  }
}

class _SetRow extends StatefulWidget {
  final SetEntry set;
  final String number;
  final SetEntry? previous;

  /// Grey placeholder values: last session's set, or the set above.
  final SetEntry? hint;
  final WeightUnit unit;
  final VoidCallback onChanged;
  final VoidCallback onToggle;
  final ValueChanged<SetKind> onKind;
  final VoidCallback onDelete;

  const _SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.previous,
    required this.hint,
    required this.unit,
    required this.onChanged,
    required this.onToggle,
    required this.onKind,
    required this.onDelete,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final _w = TextEditingController(text: _weightText());
  late final _r = TextEditingController(text: _repsText());
  final _wf = FocusNode();
  final _rf = FocusNode();

  String _weightText() =>
      widget.set.weight == null ? '' : fmtWeight(widget.set.weight!, widget.unit, withUnit: false);
  String _repsText() => widget.set.reps == null ? '' : '${widget.set.reps}';

  @override
  void didUpdateWidget(covariant _SetRow old) {
    super.didUpdateWidget(old);
    // Values can change outside the fields (hint copied on check).
    if (!_wf.hasFocus && _w.text != _weightText()) _w.text = _weightText();
    if (!_rf.hasFocus && _r.text != _repsText()) _r.text = _repsText();
  }

  @override
  void dispose() {
    _w.dispose();
    _r.dispose();
    _wf.dispose();
    _rf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = widget.set;
    final prev = widget.previous;
    final prevText = prev == null
        ? '—'
        : '${fmtWeight(prev.weight ?? 0, widget.unit, withUnit: false)} × ${prev.repsLabel}';
    final kindColor = switch (s.kind) {
      SetKind.warmup => p.accent2,
      SetKind.drop => Colors.purpleAccent,
      SetKind.failure => p.danger,
      SetKind.normal => p.textPrimary,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(top: 4, right: 8),
      decoration: BoxDecoration(
        color: s.done ? p.success.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        SizedBox(
          width: 40,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _kindSheet(context),
            child: Tooltip(
              message: 'Set type, assisted reps',
              child: Container(
                height: 36,
                alignment: Alignment.center,
                child: Text(widget.number, style: TextStyle(fontWeight: FontWeight.w800, color: kindColor)),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: prev == null
                ? null
                : () {
                    s.weight = prev.weight;
                    s.reps = prev.reps;
                    _w.text = _weightText();
                    _r.text = _repsText();
                    widget.onChanged();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(prevText, style: TextStyle(color: p.textSecondary, fontSize: 13)),
            ),
          ),
        ),
        Expanded(flex: 3, child: _field(_w, _wf, hint: widget.hint?.weight == null ? '0' : fmtWeight(widget.hint!.weight!, widget.unit, withUnit: false), decimal: true, onChanged: (v) {
          final n = double.tryParse(v.replaceAll(',', '.'));
          s.weight = n == null ? null : displayToKg(n, widget.unit);
          widget.onChanged();
        })),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: Stack(clipBehavior: Clip.none, children: [
            _field(_r, _rf, hint: widget.hint?.reps?.toString() ?? '0', decimal: false, onChanged: (v) {
              s.reps = int.tryParse(v);
              widget.onChanged();
            }),
            if (s.assisted > 0)
              Positioned(
                right: -4,
                top: -6,
                child: GestureDetector(
                  onTap: () => _kindSheet(context),
                  child: Tooltip(
                    message: '${s.assisted} assisted rep${s.assisted == 1 ? '' : 's'}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: p.accent2, borderRadius: BorderRadius.circular(8)),
                      child: Text('+${s.assisted}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        SizedBox(
          width: 48,
          child: IconButton(
            tooltip: s.done ? 'Mark not done' : 'Complete set',
            onPressed: () {
              FocusScope.of(context).unfocus();
              HapticFeedback.lightImpact();
              widget.onToggle();
            },
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: s.done ? p.success : p.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check, size: 20, color: s.done ? Colors.white : p.textSecondary),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, FocusNode f,
      {required String hint, required bool decimal, required ValueChanged<String> onChanged}) {
    final p = context.palette;
    return SizedBox(
      height: 36,
      child: TextField(
        controller: c,
        focusNode: f,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        textInputAction: TextInputAction.next,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.textSecondary.withValues(alpha: 0.6)),
          contentPadding: EdgeInsets.zero,
          isDense: true,
          fillColor: widget.set.done ? Colors.transparent : p.surfaceAlt,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: p.accent, width: 1.5)),
        ),
      ),
    );
  }

  Future<void> _kindSheet(BuildContext context) async {
    final before = widget.set.assisted;
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SetOptionsSheet(set: widget.set),
    );
    if (v == 'delete') {
      widget.onDelete();
    } else if (v != null) {
      widget.onKind(SetKind.values.byName(v));
    } else if (widget.set.assisted != before) {
      widget.onChanged();
    }
  }
}

/// Set type, assisted (spotter) reps, and remove.
class _SetOptionsSheet extends StatefulWidget {
  final SetEntry set;
  const _SetOptionsSheet({required this.set});
  @override
  State<_SetOptionsSheet> createState() => _SetOptionsSheetState();
}

class _SetOptionsSheetState extends State<_SetOptionsSheet> {
  SetEntry get set => widget.set;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Assisted reps', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Extra reps a spotter helped with. Records and volume count only your own reps.',
                    style: TextStyle(color: p.textSecondary, fontSize: 13)),
              ]),
            ),
            IconButton.filledTonal(
              onPressed: set.assisted > 0 ? () => setState(() => set.assisted--) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 40,
              child: Text('${set.assisted}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            IconButton.filledTonal(
              onPressed: set.assisted < 20 ? () => setState(() => set.assisted++) : null,
              icon: const Icon(Icons.add),
            ),
          ]),
        ),
        if (set.assisted > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Logged as ${set.repsLabel} reps', style: TextStyle(color: p.accent2, fontWeight: FontWeight.w700)),
          ),
        const Divider(height: 24),
        for (final k in SetKind.values)
          ListTile(
            leading: SizedBox(
              width: 24,
              child: Text(k == SetKind.normal ? '1' : k.short,
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            title: Text(k.label),
            trailing: set.kind == k ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, k.name),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Remove set'),
          onTap: () => Navigator.pop(context, 'delete'),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
