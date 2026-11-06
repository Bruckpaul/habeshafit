import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/coaching.dart';
import '../models/workout.dart';
import '../state/app_state.dart';
import '../state/coaching_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/ids.dart';
import 'common.dart';

const kWeekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

// ---------------------------------------------------------------------------
// Goal board

class GoalBoard extends StatelessWidget {
  final String clientId;
  final String coachId;
  final bool editable;
  const GoalBoard({super.key, required this.clientId, required this.coachId, required this.editable});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final goals = coaching.goalsFor(clientId, coachId);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (goals.isEmpty)
        AppCard(
          child: Text(editable ? 'No goals yet. Add the first target for this client.' : 'Your coach hasn\'t set goals yet.',
              style: TextStyle(color: p.textSecondary)),
        ),
      for (final g in goals)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GoalCard(goal: g, editable: editable),
        ),
      if (editable)
        OutlinedButton.icon(
          onPressed: () => showGoalSheet(context, clientId: clientId, coachId: coachId),
          icon: const Icon(Icons.add),
          label: const Text('Add goal'),
        ),
    ]);
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final bool editable;
  const _GoalCard({required this.goal, required this.editable});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final app = context.read<AppState>();
    final p = context.palette;
    final unit = app.profile.unit;
    final progress = coaching.goalProgress(goal);
    final current = coaching.goalCurrent(goal);
    String fmt(double v) => switch (goal.type) {
          GoalType.lift || GoalType.bodyweight => fmtWeight(v, unit),
          GoalType.measurement => '${fmtNumber(v)} cm',
          GoalType.habit => '${v.round()} / week',
          GoalType.custom => fmtNumber(v),
        };
    final done = goal.achieved || progress >= 1;
    return AppCard(
      onTap: editable || goal.type == GoalType.custom ? () => showGoalSheet(context, existing: goal, clientId: goal.clientId, coachId: goal.coachId) : null,
      borderColor: done ? p.success.withValues(alpha: 0.5) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(done ? Icons.emoji_events : _icon(goal.type), color: done ? p.success : p.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w800))),
          if (goal.deadline != null)
            Text('by ${DateFormat('MMM d').format(goal.deadline!)}', style: TextStyle(color: p.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: p.surfaceAlt,
            color: done ? p.success : p.accent,
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text(current == null ? 'No data yet' : 'Now ${fmt(current)}', style: TextStyle(color: p.textSecondary, fontSize: 12)),
          const Spacer(),
          Text('Target ${fmt(goal.target)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  IconData _icon(GoalType t) => switch (t) {
        GoalType.lift => Icons.fitness_center,
        GoalType.bodyweight => Icons.monitor_weight_outlined,
        GoalType.measurement => Icons.straighten,
        GoalType.habit => Icons.event_repeat,
        GoalType.custom => Icons.flag_outlined,
      };
}

Future<void> showGoalSheet(BuildContext context,
    {Goal? existing, required String clientId, required String coachId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GoalSheet(existing: existing, clientId: clientId, coachId: coachId),
  );
}

class _GoalSheet extends StatefulWidget {
  final Goal? existing;
  final String clientId;
  final String coachId;
  const _GoalSheet({this.existing, required this.clientId, required this.coachId});
  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late GoalType _type = widget.existing?.type ?? GoalType.lift;
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _target = TextEditingController();
  late final _start = TextEditingController();
  late final _manual = TextEditingController();
  String? _ref;
  DateTime? _deadline;

  bool get _isCoach => context.read<CoachingState>().myCoachId == widget.coachId;
  bool get _weightType => _type == GoalType.lift || _type == GoalType.bodyweight;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    final unit = context.read<AppState>().profile.unit;
    String show(double? v) => v == null ? '' : (_weightType ? fmtWeight(v, unit, withUnit: false) : fmtNumber(v));
    if (g != null) {
      _ref = g.ref;
      _deadline = g.deadline;
      _target.text = show(g.target);
      _start.text = show(g.start);
      _manual.text = show(g.manual);
    }
  }

  double? _parse(TextEditingController c) {
    final v = double.tryParse(c.text.replaceAll(',', '.'));
    if (v == null) return null;
    return _weightType ? displayToKg(v, context.read<AppState>().profile.unit) : v;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final coaching = context.read<CoachingState>();
    final unitLabel = switch (_type) {
      GoalType.lift || GoalType.bodyweight => app.profile.unit.name,
      GoalType.measurement => 'cm',
      GoalType.habit => 'sessions/week',
      GoalType.custom => 'value',
    };
    final readOnly = !_isCoach; // client may only update custom progress
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.existing == null ? 'New goal' : (readOnly ? widget.existing!.title : 'Edit goal'), style: context.text.titleLarge),
          const SizedBox(height: 16),
          if (!readOnly) ...[
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in GoalType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _type == t,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _type = t;
                    _ref = null;
                  }),
                ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Goal, e.g. Bench 100 kg'),
            ),
            const SizedBox(height: 12),
            if (_type == GoalType.lift)
              OutlinedButton.icon(
                onPressed: () async {
                  final ids = await context.push<List<String>>('/exercises/pick');
                  if (ids != null && ids.isNotEmpty) setState(() => _ref = ids.first);
                },
                icon: const Icon(Icons.fitness_center),
                label: Text(_ref == null ? 'Choose exercise' : app.exercise(_ref!).name),
              ),
            if (_type == GoalType.measurement)
              DropdownButtonFormField<String>(
                initialValue: _ref,
                decoration: const InputDecoration(labelText: 'Measurement'),
                items: [
                  for (final m in ['waist', 'chest', 'arms', 'thighs', 'hips', 'neck'])
                    DropdownMenuItem(value: m, child: Text(capitalize(m))),
                ],
                onChanged: (v) => setState(() => _ref = v),
              ),
            const SizedBox(height: 12),
            Row(children: [
              if (_type != GoalType.habit) ...[
                Expanded(
                  child: TextField(
                    controller: _start,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Start ($unitLabel)'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Target ($unitLabel)'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDate: _deadline ?? DateTime.now().add(const Duration(days: 56)),
                );
                if (d != null) setState(() => _deadline = d);
              },
              icon: const Icon(Icons.event),
              label: Text(_deadline == null ? 'Target date (optional)' : DateFormat('MMM d, yyyy').format(_deadline!)),
            ),
          ],
          if (_type == GoalType.custom || widget.clientId != kMeClientId) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _manual,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Current progress ($unitLabel)'),
            ),
          ] else if (!readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Progress updates automatically from logged workouts and measurements.',
                  style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final ex = widget.existing;
              if (readOnly && ex != null) {
                ex.manual = _parse(_manual);
                await coaching.saveGoal(ex);
                if (context.mounted) Navigator.pop(context);
                return;
              }
              final target = _parse(_target);
              if (_title.text.trim().isEmpty || target == null) return;
              final g = Goal(
                id: ex?.id,
                clientId: widget.clientId,
                coachId: widget.coachId,
                type: _type,
                title: _title.text.trim(),
                ref: _ref,
                start: _parse(_start),
                target: target,
                manual: _parse(_manual),
                deadline: _deadline,
                achieved: ex?.achieved ?? false,
                createdAt: ex?.createdAt,
              );
              await coaching.saveGoal(g);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save goal'),
          ),
          if (widget.existing != null && !readOnly)
            TextButton(
              onPressed: () async {
                await coaching.deleteGoal(widget.existing!);
                if (context.mounted) Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: context.palette.danger),
              child: const Text('Delete goal'),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal plan

class MealPlanView extends StatelessWidget {
  final String clientId;
  final String coachId;
  final bool editable;
  const MealPlanView({super.key, required this.clientId, required this.coachId, required this.editable});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final plan = coaching.mealPlanFor(clientId, coachId);
    if (plan == null) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(editable ? 'No meal plan yet.' : 'Your coach hasn\'t sent a meal plan yet.',
              style: TextStyle(color: p.textSecondary)),
          if (editable) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _edit(context, MealPlan(clientId: clientId, coachId: coachId, meals: _starterMeals())),
              child: const Text('Create meal plan'),
            ),
          ],
        ]),
      );
    }
    final eatenToday = plan.eaten[dayKey(coaching.now)] ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Stat('${plan.calories}', 'kcal / day')),
            Expanded(child: Stat('${plan.protein} g', 'Protein')),
            Expanded(child: Stat('${plan.carbs} g', 'Carbs')),
            Expanded(child: Stat('${plan.fat} g', 'Fat')),
          ]),
          if (plan.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(plan.notes, style: TextStyle(color: p.accent2)),
          ],
          const SizedBox(height: 8),
          Text(
            'Adherence last 7 days: ${(coaching.mealAdherence(plan) * 100).round()}% · updated ${relativeDay(plan.updatedAt, coaching.now).toLowerCase()}',
            style: TextStyle(color: p.textSecondary, fontSize: 12),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      for (final m in plan.meals..sort((a, b) => a.time.compareTo(b.time)))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 52,
                child: Text(m.time, style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name + (m.calories == null ? '' : ' · ${m.calories} kcal'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (m.items.isNotEmpty)
                    Text(m.items, style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.35)),
                ]),
              ),
              if (!editable)
                Checkbox(
                  value: eatenToday.contains(m.id),
                  onChanged: (_) => coaching.toggleMealEaten(plan, m),
                ),
            ]),
          ),
        ),
      if (editable)
        FilledButton.icon(
          onPressed: () => _edit(context, MealPlan.fromJson(plan.toJson())),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit meal plan'),
        ),
    ]);
  }

  static List<Meal> _starterMeals() => [
        Meal(time: '07:30', name: 'Breakfast', items: 'Chechebsa or ful with eggs\nTea / coffee'),
        Meal(time: '13:00', name: 'Lunch', items: 'Injera with shiro or tibs\nSalad'),
        Meal(time: '16:30', name: 'Snack', items: 'Fruit and yogurt'),
        Meal(time: '20:00', name: 'Dinner', items: 'Injera with misir wot\nVegetables'),
      ];

  void _edit(BuildContext context, MealPlan draft) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MealPlanEditor(draft: draft)));
  }
}

class MealPlanEditor extends StatefulWidget {
  final MealPlan draft;
  const MealPlanEditor({super.key, required this.draft});
  @override
  State<MealPlanEditor> createState() => _MealPlanEditorState();
}

class _MealPlanEditorState extends State<MealPlanEditor> {
  MealPlan get plan => widget.draft;
  late final _cal = TextEditingController(text: '${plan.calories}');
  late final _pro = TextEditingController(text: '${plan.protein}');
  late final _carb = TextEditingController(text: '${plan.carbs}');
  late final _fat = TextEditingController(text: '${plan.fat}');
  late final _notes = TextEditingController(text: plan.notes);

  Future<void> _editMeal([Meal? meal]) async {
    final m = meal ?? Meal(time: '12:00', name: 'Meal');
    final time = TextEditingController(text: m.time);
    final name = TextEditingController(text: m.name);
    final items = TextEditingController(text: m.items);
    final kcal = TextEditingController(text: m.calories?.toString() ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(width: 100, child: TextField(controller: time, decoration: const InputDecoration(labelText: 'Time'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: name, decoration: const InputDecoration(labelText: 'Name'))),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: items,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Foods and amounts (one per line)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: kcal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories (optional)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save meal')),
        ]),
      ),
    );
    if (ok != true) return;
    setState(() {
      m
        ..time = time.text.trim()
        ..name = name.text.trim().isEmpty ? 'Meal' : name.text.trim()
        ..items = items.text.trim()
        ..calories = int.tryParse(kcal.text);
      if (meal == null) plan.meals.add(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget num(TextEditingController c, String label) => Expanded(
          child: TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Meal plan')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Row(children: [num(_cal, 'kcal'), const SizedBox(width: 8), num(_pro, 'Protein g')]),
        const SizedBox(height: 8),
        Row(children: [num(_carb, 'Carbs g'), const SizedBox(width: 8), num(_fat, 'Fat g')]),
        const SizedBox(height: 8),
        TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes for the client')),
        const SizedBox(height: 20),
        const SectionHeader('Meals'),
        for (final m in plan.meals)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => _editMeal(m),
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              child: Row(children: [
                SizedBox(width: 52, child: Text(m.time, style: TextStyle(color: p.accent, fontWeight: FontWeight.w800))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (m.items.isNotEmpty)
                      Text(m.items, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textSecondary, fontSize: 13)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Remove meal',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => plan.meals.remove(m)),
                ),
              ]),
            ),
          ),
        OutlinedButton.icon(onPressed: () => _editMeal(), icon: const Icon(Icons.add), label: const Text('Add meal')),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () async {
            plan
              ..calories = int.tryParse(_cal.text) ?? plan.calories
              ..protein = int.tryParse(_pro.text) ?? plan.protein
              ..carbs = int.tryParse(_carb.text) ?? plan.carbs
              ..fat = int.tryParse(_fat.text) ?? plan.fat
              ..notes = _notes.text.trim();
            await context.read<CoachingState>().saveMealPlan(plan);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Send to client'),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Reminders

class ReminderList extends StatelessWidget {
  final String clientId;
  final String coachId;
  final bool editable;
  const ReminderList({super.key, required this.clientId, required this.coachId, required this.editable});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final list = coaching.remindersFor(clientId, coachId);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (list.isEmpty)
        AppCard(
          child: Text(editable ? 'No reminders yet. Schedule training times, meals, water or check-ins.' : 'No reminders from your coach.',
              style: TextStyle(color: p.textSecondary)),
        ),
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            onTap: editable ? () => showReminderSheet(context, clientId: clientId, coachId: coachId, existing: r) : null,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(reminderIcon(r.type), color: r.active ? p.accent : p.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r.time} · ${r.type.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(r.text, style: TextStyle(color: p.textSecondary, fontSize: 13)),
                  Text(
                    r.weekdays.isEmpty
                        ? (r.date == null ? 'Once' : 'Once · ${DateFormat('EEE, MMM d').format(r.date!)}')
                        : (r.weekdays.length == 7 ? 'Every day' : r.weekdays.map((d) => DateFormat('E').format(DateTime(2026, 11, 1 + d))).join(', ')),
                    style: TextStyle(color: p.textSecondary, fontSize: 12),
                  ),
                ]),
              ),
              if (editable)
                Switch(
                  value: r.active,
                  onChanged: (v) {
                    r.active = v;
                    coaching.saveReminder(r);
                  },
                ),
            ]),
          ),
        ),
      if (editable)
        OutlinedButton.icon(
          onPressed: () => showReminderSheet(context, clientId: clientId, coachId: coachId),
          icon: const Icon(Icons.add_alarm),
          label: const Text('Add reminder'),
        ),
    ]);
  }
}

IconData reminderIcon(ReminderType t) => switch (t) {
      ReminderType.training => Icons.fitness_center,
      ReminderType.meal => Icons.restaurant,
      ReminderType.water => Icons.water_drop_outlined,
      ReminderType.sleep => Icons.bedtime_outlined,
      ReminderType.checkIn => Icons.photo_camera_outlined,
      ReminderType.custom => Icons.notifications_outlined,
    };

Future<void> showReminderSheet(BuildContext context,
    {required String clientId, required String coachId, Reminder? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReminderSheet(clientId: clientId, coachId: coachId, existing: existing),
  );
}

class _ReminderSheet extends StatefulWidget {
  final String clientId;
  final String coachId;
  final Reminder? existing;
  const _ReminderSheet({required this.clientId, required this.coachId, this.existing});
  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late ReminderType _type = widget.existing?.type ?? ReminderType.training;
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  late TimeOfDay _time = _parseTime(widget.existing?.time ?? '18:00');
  late final Set<int> _days = {...?widget.existing?.weekdays};

  static TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 18, minute: int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0);
  }

  String get _timeText => '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final coaching = context.read<CoachingState>();
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.existing == null ? 'New reminder' : 'Edit reminder', style: context.text.titleLarge),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in ReminderType.values)
            ChoiceChip(
              avatar: Icon(reminderIcon(t), size: 16),
              label: Text(t.label),
              selected: _type == t,
              showCheckmark: false,
              onSelected: (_) => setState(() => _type = t),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _text,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Message',
            hintText: switch (_type) {
              ReminderType.training => 'Leg day at the gym, bring belt',
              ReminderType.meal => 'Post-workout meal: protein + carbs',
              ReminderType.water => 'Drink 500 ml of water',
              ReminderType.sleep => 'Lights off, 8 hours tonight',
              ReminderType.checkIn => 'Weekly check-in photo and weight',
              ReminderType.custom => 'Your message',
            },
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: _time);
            if (t != null) setState(() => _time = t);
          },
          icon: const Icon(Icons.schedule),
          label: Text('At $_timeText'),
        ),
        const SizedBox(height: 12),
        Text('Repeat on', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          for (var d = 1; d <= 7; d++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilterChip(
                  label: SizedBox(width: double.infinity, child: Text(kWeekdayLetters[d - 1], textAlign: TextAlign.center)),
                  labelPadding: EdgeInsets.zero,
                  showCheckmark: false,
                  selected: _days.contains(d),
                  onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                ),
              ),
            ),
        ]),
        Text(_days.isEmpty ? 'No days selected: fires once, today.' : '', style: TextStyle(color: p.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            if (_text.text.trim().isEmpty) return;
            final r = Reminder(
              id: widget.existing?.id,
              clientId: widget.clientId,
              coachId: widget.coachId,
              type: _type,
              text: _text.text.trim(),
              time: _timeText,
              weekdays: _days.toList()..sort(),
              date: _days.isEmpty ? coaching.now : null,
            );
            await coaching.saveReminder(r);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save reminder'),
        ),
        if (widget.existing != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: p.danger),
            onPressed: () async {
              await coaching.deleteReminder(widget.existing!);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete reminder'),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Comments on a workout

/// Coach ↔ client feedback thread under a finished workout. Shown when the
/// phone owner has a coach, or coaches themselves.
class SessionComments extends StatefulWidget {
  final WorkoutSession session;
  const SessionComments({super.key, required this.session});
  @override
  State<SessionComments> createState() => _SessionCommentsState();
}

class _SessionCommentsState extends State<SessionComments> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final link = coaching.myLink;
    // Coaching yourself: comment as coach in coach view, else as client.
    final asCoach = link != null && link.coachId == coaching.myCoachId && coaching.view == CoachView.coach;
    if (link == null && coaching.commentsFor(widget.session.id).isEmpty) return const SizedBox.shrink();
    final thread = coaching.commentsFor(widget.session.id);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(asCoach ? 'Feedback for ${link.name}' : 'Coach feedback'),
      if (thread.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(asCoach ? 'Leave feedback on this workout.' : 'Your coach\'s comments on this workout appear here.',
              style: TextStyle(color: p.textSecondary)),
        ),
      for (final c in thread)
        Align(
          alignment: (c.author == 'coach') == asCoach ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.author == 'coach' ? p.accent.withValues(alpha: 0.14) : p.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.author == 'coach' ? 'Coach ' : ''}${c.authorName} · ${DateFormat('MMM d, HH:mm').format(c.at)}',
                  style: TextStyle(color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(c.text),
            ]),
          ),
        ),
      if (link != null)
        Row(children: [
          Expanded(
            child: TextField(
              controller: _c,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: asCoach ? 'Comment as coach…' : 'Reply to your coach…'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: () async {
              final text = _c.text.trim();
              if (text.isEmpty) return;
              _c.clear();
              await coaching.addComment(
                session: widget.session,
                clientId: kMeClientId,
                fromCoach: asCoach,
                text: text,
              );
            },
            icon: const Icon(Icons.send),
          ),
        ]),
    ]);
  }
}

/// Bell with unread count.
class InboxButton extends StatelessWidget {
  final Audience audience;
  const InboxButton({super.key, required this.audience});

  @override
  Widget build(BuildContext context) {
    final n = context.select<CoachingState, int>((c) => c.unread(audience));
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications?for=${audience.name}'),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
