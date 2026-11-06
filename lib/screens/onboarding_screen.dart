import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/templates.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;
  final _name = TextEditingController();
  TrainingGoal _goal = TrainingGoal.muscle;
  String _experience = 'beginner';
  WeightUnit _unit = WeightUnit.kg;
  int _days = 4;
  int? _template = 0; // null = build my own

  static const _steps = 4;

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == _steps - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _page.animateToPage(_step, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _back() {
    setState(() => _step--);
    _page.animateToPage(_step, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    if (_template != null) {
      await state.saveRoutine(kRoutineTemplates[_template!].build(), makeActive: true);
    }
    await state.updateProfile((p) {
      p.name = _name.text.trim();
      p.goal = _goal;
      p.experience = _experience;
      p.unit = _unit;
      p.weeklyTarget = _days;
      p.onboardingComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
            child: Row(children: [
              IconButton(
                onPressed: _step == 0 ? null : _back,
                icon: Icon(Icons.arrow_back, color: _step == 0 ? Colors.transparent : p.textPrimary),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _steps,
                    minHeight: 6,
                    backgroundColor: p.surfaceAlt,
                    color: p.accent,
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [_welcome(), _aboutYou(), _training(), _starter()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _next,
                child: Text(_step == _steps - 1 ? 'Start training' : 'Continue'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pad(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: children,
      );

  Widget _title(String t, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: context.text.headlineSmall),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(color: context.palette.textSecondary, fontSize: 15)),
        ]),
      );

  Widget _welcome() {
    final p = context.palette;
    return _pad([
      const SizedBox(height: 32),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.accent, p.accent2]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.fitness_center, color: Colors.white, size: 44),
        ),
      ),
      const SizedBox(height: 28),
      Text('HabeshaFit', style: context.text.headlineMedium),
      const SizedBox(height: 8),
      Text('Plan your split, open the app, and know exactly what to train today.',
          style: TextStyle(color: p.textSecondary, fontSize: 16, height: 1.4)),
      const SizedBox(height: 32),
      for (final (icon, text) in [
        (Icons.today_outlined, "Today's workout from your own schedule"),
        (Icons.history, 'Last session\'s weights on every set'),
        (Icons.emoji_events_outlined, 'Personal records and progress charts'),
        (Icons.cloud_off_outlined, 'Works fully offline; your data stays on your phone'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(children: [
            Icon(icon, color: p.accent),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
          ]),
        ),
    ]);
  }

  Widget _aboutYou() {
    return _pad([
      _title('About you', 'This shapes your starter plan and stats.'),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Your name'),
      ),
      const SizedBox(height: 24),
      Text('Main goal', style: context.text.titleSmall),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in TrainingGoal.values)
          ChoiceChip(label: Text(g.label), selected: _goal == g, onSelected: (_) => setState(() => _goal = g)),
      ]),
      const SizedBox(height: 24),
      Text('Experience', style: context.text.titleSmall),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'beginner', label: Text('Beginner')),
          ButtonSegment(value: 'intermediate', label: Text('Intermediate')),
          ButtonSegment(value: 'advanced', label: Text('Advanced')),
        ],
        selected: {_experience},
        showSelectedIcon: false,
        onSelectionChanged: (v) => setState(() => _experience = v.first),
      ),
    ]);
  }

  Widget _training() {
    final p = context.palette;
    return _pad([
      _title('Your training', 'You can change these any time in Profile.'),
      Text('Weight unit', style: context.text.titleSmall),
      const SizedBox(height: 10),
      SegmentedButton<WeightUnit>(
        segments: const [
          ButtonSegment(value: WeightUnit.kg, label: Text('Kilograms (kg)')),
          ButtonSegment(value: WeightUnit.lb, label: Text('Pounds (lb)')),
        ],
        selected: {_unit},
        showSelectedIcon: false,
        onSelectionChanged: (v) => setState(() => _unit = v.first),
      ),
      const SizedBox(height: 28),
      Text('Training days per week', style: context.text.titleSmall),
      const SizedBox(height: 4),
      Text('Hit this many days in a week to keep your streak.', style: TextStyle(color: p.textSecondary)),
      const SizedBox(height: 12),
      Row(children: [
        for (var d = 2; d <= 6; d++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: SizedBox(width: double.infinity, child: Text('$d', textAlign: TextAlign.center)),
                selected: _days == d,
                showCheckmark: false,
                onSelected: (_) => setState(() => _days = d),
              ),
            ),
          ),
      ]),
    ]);
  }

  Widget _starter() {
    final p = context.palette;
    Widget option(int? i, String name, String desc, IconData icon) {
      final selected = _template == i;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: selected ? p.accent.withValues(alpha: 0.10) : p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? p.accent : p.border, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _template = i),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(icon, color: selected ? p.accent : p.textSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(desc, style: TextStyle(color: p.textSecondary)),
                  ]),
                ),
                if (selected) Icon(Icons.check_circle, color: p.accent),
              ]),
            ),
          ),
        ),
      );
    }

    return _pad([
      _title('Pick a starting plan', 'Edit any exercise, set or day later.'),
      for (var i = 0; i < kRoutineTemplates.length; i++)
        option(i, kRoutineTemplates[i].name, kRoutineTemplates[i].description, Icons.calendar_view_week),
      option(null, 'I\'ll build my own', 'Start with an empty plan', Icons.edit_outlined),
    ]);
  }
}
