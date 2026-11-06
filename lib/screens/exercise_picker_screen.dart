import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

const kMuscles = [
  'chest', 'lats', 'middle back', 'lower back', 'shoulders', 'traps', 'biceps', 'triceps', 'forearms',
  'quadriceps', 'hamstrings', 'glutes', 'calves', 'adductors', 'abductors', 'abdominals', 'neck',
];
const kEquipment = [
  'barbell', 'dumbbell', 'cable', 'machine', 'body only', 'kettlebells', 'bands', 'e-z curl bar',
  'medicine ball', 'exercise ball', 'foam roll', 'other',
];

/// Browse the library. In multi-select mode it pops with the chosen ids;
/// with [single] it is a browser that opens exercise details.
class ExercisePickerScreen extends StatefulWidget {
  final bool single;
  const ExercisePickerScreen({super.key, this.single = false});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final _query = TextEditingController();
  String? _muscle;
  String? _equipment;
  final List<String> _selected = [];

  List<Exercise> _results(AppState state) {
    final words = _query.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    bool matches(Exercise e) {
      if (_muscle != null && !e.primaryMuscles.contains(_muscle)) return false;
      if (_equipment != null && e.equipment != _equipment) return false;
      if (words.isEmpty) return true;
      final name = e.name.toLowerCase();
      return words.every(name.contains);
    }

    final list = state.library.where(matches).toList();
    if (words.isEmpty && _muscle == null && _equipment == null) {
      // Recent first, then the rest alphabetically.
      final recent = state.recentExerciseIds;
      final rank = {for (final (i, id) in recent.indexed) id: i};
      list.sort((a, b) {
        final ra = rank[a.id], rb = rank[b.id];
        if (ra != null && rb != null) return ra.compareTo(rb);
        if (ra != null) return -1;
        if (rb != null) return 1;
        return a.name.compareTo(b.name);
      });
    } else if (words.isNotEmpty) {
      // Names starting with the query rank higher.
      final q = _query.text.toLowerCase().trim();
      list.sort((a, b) {
        final sa = a.name.toLowerCase().startsWith(q) ? 0 : 1;
        final sb = b.name.toLowerCase().startsWith(q) ? 0 : 1;
        return sa != sb ? sa.compareTo(sb) : a.name.compareTo(b.name);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final results = _results(state);
    final recent = state.recentExerciseIds.toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.single ? 'Exercises' : 'Add exercises'),
        actions: [
          IconButton(
            tooltip: 'Create custom exercise',
            onPressed: () => _createCustom(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search ${state.library.length} exercises',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_query.clear),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterMenu(
                label: _muscle == null ? 'Muscle' : capitalize(_muscle!),
                active: _muscle != null,
                options: kMuscles,
                onSelected: (v) => setState(() => _muscle = v),
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: _equipment == null ? 'Equipment' : capitalize(_equipment!),
                active: _equipment != null,
                options: kEquipment,
                onSelected: (v) => setState(() => _equipment = v),
              ),
              const SizedBox(width: 8),
              for (final m in ['chest', 'lats', 'shoulders', 'quadriceps', 'hamstrings', 'biceps', 'triceps', 'abdominals'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(capitalize(m)),
                    selected: _muscle == m,
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _muscle = v ? m : null),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: 'No exercises found',
                  message: 'Try another name or clear the filters, or create your own exercise.',
                  action: 'Create "${_query.text.isEmpty ? 'custom' : _query.text}"',
                  onAction: () => _createCustom(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final e = results[i];
                    final selectedIndex = _selected.indexOf(e.id);
                    final selected = selectedIndex >= 0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: ExerciseThumb(e, size: 52),
                      title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          capitalize(e.primaryMuscle),
                          capitalize(e.equipment),
                          if (recent.contains(e.id)) 'Recent',
                          if (e.isCustom) 'Custom',
                        ].join(' · '),
                        style: TextStyle(color: p.textSecondary),
                      ),
                      selected: selected,
                      selectedTileColor: p.accent.withValues(alpha: 0.08),
                      trailing: widget.single
                          ? const Icon(Icons.chevron_right)
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'Details',
                                icon: Icon(Icons.info_outline, color: p.textSecondary),
                                onPressed: () => context.push('/exercise/${Uri.encodeComponent(e.id)}'),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected ? p.accent : Colors.transparent,
                                  border: Border.all(color: selected ? p.accent : p.border, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: selected
                                    ? Text('${selectedIndex + 1}',
                                        style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w800, fontSize: 13))
                                    : null,
                              ),
                            ]),
                      onTap: () {
                        if (widget.single) {
                          context.push('/exercise/${Uri.encodeComponent(e.id)}');
                          return;
                        }
                        setState(() => selected ? _selected.remove(e.id) : _selected.add(e.id));
                      },
                    );
                  },
                ),
        ),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.single || _selected.isEmpty
          ? null
          : SizedBox(
              width: MediaQuery.sizeOf(context).width - 32,
              child: FilledButton(
                onPressed: () => context.pop(List<String>.from(_selected)),
                child: Text('Add ${_selected.length} exercise${_selected.length == 1 ? '' : 's'}'),
              ),
            ),
    );
  }

  Future<void> _createCustom(BuildContext context) async {
    final created = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomExerciseSheet(initialName: _query.text.trim()),
    );
    if (created != null && mounted && !widget.single) {
      setState(() => _selected.add(created.id));
    }
  }
}

class _FilterMenu extends StatelessWidget {
  final String label;
  final bool active;
  final List<String> options;
  final ValueChanged<String?> onSelected;
  const _FilterMenu({required this.label, required this.active, required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) => onSelected(v == '' ? null : v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('Any')),
        for (final o in options) PopupMenuItem(value: o, child: Text(capitalize(o))),
      ],
      child: IgnorePointer(
        child: FilterChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [Text(label), const Icon(Icons.arrow_drop_down, size: 18)]),
          selected: active,
          showCheckmark: false,
          onSelected: (_) {},
        ),
      ),
    );
  }
}

class _CustomExerciseSheet extends StatefulWidget {
  final String initialName;
  const _CustomExerciseSheet({required this.initialName});
  @override
  State<_CustomExerciseSheet> createState() => _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends State<_CustomExerciseSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  String _muscle = 'chest';
  String _equipment = 'barbell';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Custom exercise', style: context.text.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: widget.initialName.isEmpty,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _muscle,
          decoration: const InputDecoration(labelText: 'Primary muscle'),
          items: [for (final m in kMuscles) DropdownMenuItem(value: m, child: Text(capitalize(m)))],
          onChanged: (v) => setState(() => _muscle = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _equipment,
          decoration: const InputDecoration(labelText: 'Equipment'),
          items: [for (final m in kEquipment) DropdownMenuItem(value: m, child: Text(capitalize(m)))],
          onChanged: (v) => setState(() => _equipment = v!),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () async {
                  final e = await context
                      .read<AppState>()
                      .addCustomExercise(name: _name.text.trim(), muscle: _muscle, equipment: _equipment);
                  if (context.mounted) Navigator.pop(context, e);
                },
          child: const Text('Create exercise'),
        ),
      ]),
    );
  }
}
