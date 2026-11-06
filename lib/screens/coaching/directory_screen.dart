import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/coaching.dart';
import '../../state/coaching_state.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';
import 'coach_apply_screen.dart' show kSpecialtySuggestions;

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _q = TextEditingController();
  String? _specialty;
  TrainingMode? _mode;

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final q = _q.text.toLowerCase().trim();
    final list = coaching.coaches.where((c) {
      final center = coaching.centerById(c.centerId);
      if (center?.status != CenterStatus.approved) return false;
      if (_specialty != null && !c.specialties.contains(_specialty)) return false;
      if (_mode != null && c.mode != _mode && c.mode != TrainingMode.both) return false;
      if (q.isEmpty) return true;
      final hay = [c.name, c.city, center?.name ?? '', ...c.gyms, ...c.specialties].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList()
      // Real coaches first, then accepting, then name.
      ..sort((a, b) {
        if (a.isSample != b.isSample) return a.isSample ? 1 : -1;
        if (a.acceptingClients != b.acceptingClients) return a.acceptingClients ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Find a coach')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Search name, gym, city, sport', prefixIcon: Icon(Icons.search)),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final m in TrainingMode.values.where((m) => m != TrainingMode.both))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(m.label),
                  selected: _mode == m,
                  showCheckmark: false,
                  onSelected: (v) => setState(() => _mode = v ? m : null),
                ),
              ),
            for (final s in kSpecialtySuggestions)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s),
                  selected: _specialty == s,
                  showCheckmark: false,
                  onSelected: (v) => setState(() => _specialty = v ? s : null),
                ),
              ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.person_search, title: 'No coaches match', message: 'Try fewer filters.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final center = coaching.centerById(c.centerId);
                    return AppCard(
                      onTap: () => context.push('/coach/profile/${c.id}'),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(
                            backgroundColor: p.accent.withValues(alpha: 0.16),
                            child: Icon(Icons.sports, color: p.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text([center?.name, c.city].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                                  style: TextStyle(color: p.textSecondary, fontSize: 13)),
                            ]),
                          ),
                          if (c.isSample) Tag('SAMPLE', color: p.accent2),
                          if (c.id == coaching.myCoachId) Tag('YOU', color: p.accent),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final s in c.specialties.take(4)) Tag(s, color: p.accent),
                          Tag('${c.yearsExperience} yrs'),
                          if (c.achievements.isNotEmpty) Tag(plural(c.achievements.length, 'title'), icon: Icons.emoji_events_outlined),
                          if (!c.acceptingClients) const Tag('Full'),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
