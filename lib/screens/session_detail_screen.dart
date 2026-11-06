import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/coaching_widgets.dart';
import '../widgets/common.dart';
import '../widgets/workout_editor.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 2));
  bool _celebrated = false;

  bool get _isSummary =>
      GoRouterState.of(context).uri.queryParameters['summary'] == '1';

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final s = state.sessionById(widget.sessionId);
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Workout not found', message: 'It may have been deleted.'));
    }
    final unit = state.profile.unit;
    final summary = _isSummary;
    if (summary && !_celebrated) {
      _celebrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(summary ? 'Workout complete' : s.name),
        actions: [
          IconButton(
            tooltip: 'Edit workout',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _EditSessionScreen(original: s),
            )),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'routine') {
                await _saveAsRoutine(context, s);
                return;
              }
              final sure = await confirm(context,
                  title: 'Delete workout?', message: 'This removes it from your history and stats.', confirmLabel: 'Delete', destructive: true);
              if (!sure) return;
              await state.deleteSession(s.id);
              if (context.mounted) context.pop();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'routine', child: Text('Save as routine')),
              PopupMenuItem(value: 'delete', child: Text('Delete workout')),
            ],
          ),
        ],
      ),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            if (summary) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: p.success.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(Icons.emoji_events, size: 44, color: p.success),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text('Nice work${state.profile.name.isEmpty ? '' : ', ${state.profile.name.split(' ').first}'}!', style: context.text.headlineSmall)),
              const SizedBox(height: 4),
              Center(
                child: Text('Workout #${state.sessions.length} saved', style: TextStyle(color: p.textSecondary)),
              ),
              const SizedBox(height: 20),
            ],
            Text('${s.name} · ${DateFormat('EEE, MMM d · HH:mm').format(s.start)}',
                style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            AppCard(
              child: Row(children: [
                Expanded(child: Stat(fmtDuration(s.duration), 'Duration')),
                Expanded(child: Stat(fmtVolume(s.volume, unit), 'Volume')),
                Expanded(child: Stat('${s.doneSets}', 'Sets')),
                Expanded(child: Stat('${s.records.length}', 'PRs')),
              ]),
            ),
            if (s.records.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppCard(
                color: p.accent2.withValues(alpha: 0.08),
                borderColor: p.accent2.withValues(alpha: 0.4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.emoji_events, color: p.accent2),
                    const SizedBox(width: 8),
                    Text('Personal records', style: context.text.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  for (final r in s.records)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Expanded(child: Text(state.exercise(r.exerciseId).name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('${r.label}: ', style: TextStyle(color: p.textSecondary, fontSize: 13)),
                        Text(r.type == 'volume' ? fmtVolume(r.value, unit) : fmtWeight(r.value, unit),
                            style: TextStyle(color: p.accent2, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                ]),
              ),
            ],
            if (summary && !s.isFromRoutine) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _saveAsRoutine(context, s),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save as routine'),
              ),
            ],
            const SizedBox(height: 16),
            _NotesField(session: s),
            const SizedBox(height: 16),
            SessionComments(session: s),
            const SizedBox(height: 16),
            for (final e in s.exercises) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => context.push('/exercise/${Uri.encodeComponent(e.exerciseId)}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      ExerciseThumb(state.exercise(e.exerciseId), size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(state.exercise(e.exerciseId).name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      if (s.records.any((r) => r.exerciseId == e.exerciseId))
                        Icon(Icons.emoji_events, size: 18, color: p.accent2),
                    ]),
                    const SizedBox(height: 8),
                    for (final (i, set) in e.sets.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          SizedBox(
                            width: 28,
                            child: Text(set.kind == SetKind.normal ? '${i + 1}' : set.kind.short,
                                style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w700)),
                          ),
                          Text('${fmtWeight(set.weight ?? 0, unit)} × ${set.reps ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (set.assisted > 0)
                            Text('  +${set.assisted} assisted',
                                style: TextStyle(color: p.accent2, fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                    if (e.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(e.notes, style: TextStyle(color: p.accent2, fontSize: 13)),
                      ),
                  ]),
                ),
              ),
            ],
            if (summary) ...[
              const SizedBox(height: 8),
              FilledButton(onPressed: () => context.go('/home'), child: const Text('Done')),
            ],
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            colors: [p.accent, p.accent2, p.success],
          ),
        ),
      ]),
    );
  }

  Future<void> _saveAsRoutine(BuildContext context, WorkoutSession s) async {
    final name = await promptText(context, title: 'Save as routine', initial: s.name, action: 'Save');
    if (name == null || !context.mounted) return;
    final r = await context.read<AppState>().routineFromSession(s, name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved "${r.name}" to your routines'),
        action: SnackBarAction(label: 'Edit', onPressed: () => context.push('/routine/${r.id}')),
      ));
    }
  }
}

class _NotesField extends StatefulWidget {
  final WorkoutSession session;
  const _NotesField({required this.session});
  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final _c = TextEditingController(text: widget.session.notes);

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (has) {
        if (!has && _c.text.trim() != widget.session.notes) {
          widget.session.notes = _c.text.trim();
          context.read<AppState>().saveSession(widget.session);
        }
      },
      child: TextField(
        controller: _c,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'How did it feel? Add a note…', prefixIcon: Icon(Icons.notes)),
      ),
    );
  }
}

/// Edits a finished workout on a copy; saved only on "Save".
class _EditSessionScreen extends StatefulWidget {
  final WorkoutSession original;
  const _EditSessionScreen({required this.original});
  @override
  State<_EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<_EditSessionScreen> {
  late final WorkoutSession _copy = widget.original.copy();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit workout'),
        actions: [
          TextButton(
            onPressed: () async {
              for (final e in _copy.exercises) {
                e.sets.removeWhere((x) => !x.done);
              }
              _copy.exercises.removeWhere((e) => e.sets.isEmpty);
              await context.read<AppState>().saveSession(_copy);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: WorkoutEditor(
        session: _copy,
        onChanged: () => setState(() {}),
        onToggleSet: (e, i) async => setState(() => e.sets[i].done = !e.sets[i].done),
        onAddExercises: () async {
          final ids = await context.push<List<String>>('/exercises/pick');
          if (ids == null) return;
          setState(() => _copy.exercises.addAll(ids.map((id) => ExerciseEntry(exerciseId: id, sets: [SetEntry()]))));
        },
        header: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('Unticked sets are removed when you save.', style: TextStyle(color: context.palette.textSecondary)),
          ),
        ],
      ),
    );
  }
}
