import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/coaching.dart';
import '../../state/app_state.dart';
import '../../state/coaching_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

const kSpecialtySuggestions = [
  'Strength', 'Bodybuilding', 'Powerlifting', 'Fat loss', 'Boxing', 'Taekwondo', 'Kickboxing',
  'Calisthenics', 'Athletics', 'Rehab & mobility', 'Women\'s fitness', 'Beginners',
];
const kSports = ['Bodybuilding', 'Physique', 'Powerlifting', 'Boxing', 'Taekwondo', 'Karate', 'Kickboxing', 'Athletics', 'Other'];

/// Apply as a training center + coach, or edit an existing coach profile.
class CoachApplyScreen extends StatefulWidget {
  final bool editing;
  const CoachApplyScreen({super.key, this.editing = false});
  @override
  State<CoachApplyScreen> createState() => _CoachApplyScreenState();
}

class _CoachApplyScreenState extends State<CoachApplyScreen> {
  late final CoachingState coaching = context.read<CoachingState>();
  late final TrainingCenter center = widget.editing && coaching.myCenter != null
      ? TrainingCenter.fromJson(coaching.myCenter!.toJson())
      : TrainingCenter(name: '');
  late final CoachProfile profile = widget.editing && coaching.myCoachProfile != null
      ? CoachProfile.fromJson(coaching.myCoachProfile!.toJson())
      : CoachProfile(name: context.read<AppState>().profile.name, centerId: center.id);

  late final _centerName = TextEditingController(text: center.name);
  late final _centerCity = TextEditingController(text: center.city);
  late final _centerContact = TextEditingController(text: center.contact);
  late final _centerAbout = TextEditingController(text: center.about);
  late final _name = TextEditingController(text: profile.name);
  late final _bio = TextEditingController(text: profile.bio);
  late final _gyms = TextEditingController(text: profile.gyms.join(', '));
  late final _city = TextEditingController(text: profile.city);
  late final _years = TextEditingController(text: profile.yearsExperience == 0 ? '' : '${profile.yearsExperience}');
  late final _certs = TextEditingController(text: profile.certifications.join(', '));
  late final _physique = TextEditingController(text: profile.physique);
  late final _capacity = TextEditingController(text: '${profile.capacity}');

  List<String> _split(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  bool get _valid =>
      _centerName.text.trim().isNotEmpty && _name.text.trim().isNotEmpty && _centerContact.text.trim().isNotEmpty;

  Future<void> _submit() async {
    center
      ..name = _centerName.text.trim()
      ..city = _centerCity.text.trim()
      ..contact = _centerContact.text.trim()
      ..about = _centerAbout.text.trim();
    profile
      ..name = _name.text.trim()
      ..bio = _bio.text.trim()
      ..gyms = _split(_gyms.text)
      ..city = _city.text.trim().isEmpty ? center.city : _city.text.trim()
      ..yearsExperience = int.tryParse(_years.text) ?? 0
      ..certifications = _split(_certs.text)
      ..physique = _physique.text.trim()
      ..capacity = int.tryParse(_capacity.text) ?? profile.capacity;
    if (profile.gyms.isEmpty) profile.gyms = [center.name];
    if (widget.editing) {
      final c = coaching.myCenter!;
      c
        ..name = center.name
        ..city = center.city
        ..contact = center.contact
        ..about = center.about;
      await coaching.saveCenter(c);
      await coaching.saveCoachProfile(profile);
    } else {
      await coaching.applyAsCoach(center: center, profile: profile);
    }
    if (!mounted) return;
    if (!widget.editing) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Application sent'),
          content: Text('${center.name} is now waiting for approval. '
              'Once approved, the $kTrialDays-day premium free trial starts.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing ? 'Edit coach profile' : 'Coach account')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        if (!widget.editing)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppCard(
              color: p.accent2.withValues(alpha: 0.08),
              borderColor: p.accent2.withValues(alpha: 0.4),
              child: Row(children: [
                Icon(Icons.workspace_premium_outlined, color: p.accent2),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Coaching is a premium edition for approved training centers. '
                      'Apply below; after approval you get a free trial.'),
                ),
              ]),
            ),
          ),
        Text('Training center', style: context.text.titleMedium),
        const SizedBox(height: 10),
        _f(_centerName, 'Gym / center name *'),
        _f(_centerCity, 'City'),
        _f(_centerContact, 'Phone or email *', type: TextInputType.emailAddress),
        _f(_centerAbout, 'About the center, license or registration no.', lines: 2),
        const SizedBox(height: 16),
        Text('Coach profile', style: context.text.titleMedium),
        const SizedBox(height: 4),
        Text('This is what clients see when they look for a coach.', style: TextStyle(color: p.textSecondary)),
        const SizedBox(height: 10),
        _f(_name, 'Your name *', caps: TextCapitalization.words),
        _f(_bio, 'Bio: how you coach, who you help', lines: 3),
        Text('Specialties', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in kSpecialtySuggestions)
            FilterChip(
              label: Text(s),
              selected: profile.specialties.contains(s),
              onSelected: (v) => setState(() => v ? profile.specialties.add(s) : profile.specialties.remove(s)),
            ),
        ]),
        const SizedBox(height: 14),
        _f(_gyms, 'Gyms you work at (comma separated)'),
        Row(children: [
          Expanded(child: _f(_city, 'City')),
          const SizedBox(width: 10),
          SizedBox(width: 120, child: _f(_years, 'Years coaching', type: TextInputType.number)),
        ]),
        _f(_certs, 'Certifications (comma separated)'),
        _f(_physique, 'Your physique, e.g. 178 cm · 85 kg · Men\'s physique'),
        const SizedBox(height: 4),
        Text('Training mode', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          for (final m in TrainingMode.values)
            ChoiceChip(
              label: Text(m.label),
              selected: profile.mode == m,
              showCheckmark: false,
              onSelected: (_) => setState(() => profile.mode = m),
            ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: profile.acceptingClients,
          onChanged: (v) => setState(() => profile.acceptingClients = v),
          title: const Text('Accepting new clients'),
        ),
        _f(_capacity, 'Max clients', type: TextInputType.number),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Competitions & achievements', style: context.text.titleMedium)),
          TextButton.icon(onPressed: _addAchievement, icon: const Icon(Icons.add), label: const Text('Add')),
        ]),
        if (profile.achievements.isEmpty)
          Text('Bodybuilding shows, boxing or taekwondo titles, and other results.',
              style: TextStyle(color: p.textSecondary)),
        for (final a in profile.achievements)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.emoji_events_outlined, color: p.accent2),
            title: Text(a.title),
            subtitle: Text([a.sport, if (a.year != null) '${a.year}'].where((e) => e.isNotEmpty).join(' · ')),
            trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => profile.achievements.remove(a)),
            ),
          ),
        const SizedBox(height: 24),
        StatefulBuilder(
          builder: (_, __) => FilledButton(
            onPressed: _valid ? _submit : null,
            child: Text(widget.editing ? 'Save profile' : 'Submit application'),
          ),
        ),
        if (!_valid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Fields marked * are required.', style: TextStyle(color: p.textSecondary, fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _f(TextEditingController c, String label,
          {int lines = 1, TextInputType? type, TextCapitalization caps = TextCapitalization.sentences}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: lines,
          keyboardType: type,
          textCapitalization: caps,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _addAchievement() async {
    final title = TextEditingController();
    final year = TextEditingController();
    var sport = kSports.first;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Achievement', style: ctx.text.titleLarge),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in kSports)
                ChoiceChip(label: Text(s), selected: sport == s, showCheckmark: false, onSelected: (_) => set(() => sport = s)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title, e.g. National championship, 2nd place'),
            ),
            const SizedBox(height: 10),
            TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year')),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ]),
        ),
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      setState(() => profile.achievements.add(Achievement(title: title.text.trim(), sport: sport, year: int.tryParse(year.text))));
    }
  }
}
