import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/coaching.dart';
import '../../models/profile.dart';
import '../../state/app_state.dart';
import '../../state/coaching_state.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';

class CoachProfileScreen extends StatelessWidget {
  final String coachId;
  const CoachProfileScreen({super.key, required this.coachId});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final c = coaching.coachById(coachId);
    if (c == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.person_off, title: 'Coach not found', message: ''));
    }
    final mine = c.id == coaching.myCoachId;
    final center = coaching.centerById(c.centerId);
    final isMyCoach = coaching.myLink?.coachId == c.id;
    final pending = coaching.myRequests.any((r) => r.coachId == c.id && r.status == RequestStatus.pending);
    final unit = context.read<AppState>().profile.unit;
    final shownTransformations = mine ? c.transformations : c.transformations.where((t) => t.consent).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(mine ? 'My coach profile' : 'Coach'),
        actions: [
          if (mine) IconButton(tooltip: 'Edit', onPressed: () => context.push('/coach/edit'), icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      bottomNavigationBar: mine || isMyCoach
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: !c.acceptingClients || pending || coaching.myLink != null ? null : () => _request(context, c),
                  child: Text(pending
                      ? 'Request sent'
                      : coaching.myLink != null
                          ? 'You already have a coach'
                          : c.acceptingClients
                              ? 'Request coaching'
                              : 'Not taking new clients'),
                ),
              ),
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Row(children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: p.accent.withValues(alpha: 0.16),
            child: Icon(Icons.sports, color: p.accent, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: context.text.titleLarge),
              Text([center?.name, c.city].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(color: p.textSecondary)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (c.isSample) Tag('SAMPLE PROFILE', color: p.accent2),
                if (isMyCoach) Tag('YOUR COACH', color: p.accent),
                Tag(c.acceptingClients ? 'Accepting clients' : 'Full', color: c.acceptingClients ? p.success : p.textSecondary),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        AppCard(
          child: Row(children: [
            Expanded(child: Stat('${c.yearsExperience} yrs', 'Coaching')),
            Expanded(child: Stat('${c.achievements.length}', 'Titles')),
            Expanded(child: Stat('${shownTransformations.length}', 'Transformations')),
          ]),
        ),
        if (c.bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(c.bio, style: const TextStyle(height: 1.45)),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final s in c.specialties) Tag(s, color: p.accent)]),
        const SizedBox(height: 20),
        const SectionHeader('Details'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _row(context, Icons.place_outlined, 'Trains at', c.gyms.isEmpty ? '—' : c.gyms.join(', ')),
            _row(context, Icons.wifi_tethering, 'Mode', c.mode.label),
            if (c.certifications.isNotEmpty) _row(context, Icons.verified_outlined, 'Certifications', c.certifications.join(', ')),
            if (c.physique.isNotEmpty) _row(context, Icons.accessibility_new, 'Physique', c.physique),
          ]),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Competitions & achievements'),
        if (c.achievements.isEmpty)
          Text('None listed yet.', style: TextStyle(color: p.textSecondary))
        else
          for (final a in c.achievements)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.emoji_events, color: p.accent2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text([a.sport, if (a.year != null) '${a.year}'].where((e) => e.isNotEmpty).join(' · '),
                          style: TextStyle(color: p.textSecondary, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ),
        const SizedBox(height: 20),
        SectionHeader('Client transformations', action: mine ? 'Add' : null, onAction: () => _addTransformation(context, c)),
        if (shownTransformations.isEmpty)
          Text(mine ? 'Show results to build trust. Only results with client consent are public.' : 'No public results yet.',
              style: TextStyle(color: p.textSecondary)),
        for (final t in shownTransformations)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t.clientName, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (mine && !t.consent) Tag('Private: no consent', color: p.textSecondary),
                ]),
                const SizedBox(height: 4),
                if (t.summary.isNotEmpty) Text(t.summary, style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 16)),
                if (t.weightBefore != null && t.weightAfter != null)
                  Text(
                    '${fmtWeight(t.weightBefore!, unit)} → ${fmtWeight(t.weightAfter!, unit)}${t.weeks == null ? '' : ' in ${t.weeks} weeks'}',
                    style: TextStyle(color: p.textSecondary),
                  ),
                if (t.details.isNotEmpty) ...[const SizedBox(height: 6), Text(t.details)],
                if (mine)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        c.transformations.remove(t);
                        coaching.saveCoachProfile(c);
                      },
                      child: const Text('Remove'),
                    ),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Text('Before/after photos arrive with cloud storage.', style: TextStyle(color: p.textSecondary, fontSize: 12)),
      ]),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) => ListTile(
        leading: Icon(icon),
        title: Text(label, style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
        subtitle: Text(value, style: TextStyle(color: context.palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      );

  Future<void> _request(BuildContext context, CoachProfile c) async {
    final app = context.read<AppState>();
    final goal = TextEditingController(text: app.profile.goal.label);
    final avail = TextEditingController();
    final msg = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Request ${c.name}', style: ctx.text.titleLarge),
          const SizedBox(height: 14),
          TextField(controller: goal, decoration: const InputDecoration(labelText: 'Your goal')),
          const SizedBox(height: 10),
          TextField(controller: avail, decoration: const InputDecoration(labelText: 'When can you train? e.g. Mon–Fri evenings')),
          const SizedBox(height: 10),
          TextField(
            controller: msg,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Message (injuries, experience, questions)'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send request')),
        ]),
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<CoachingState>().sendRequest(
          c,
          goal: goal.text.trim(),
          experience: capitalize(app.profile.experience),
          availability: avail.text.trim(),
          message: msg.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(c.isSample
            ? 'Request saved. Sample coaches don\'t reply; real coaches will once accounts sync.'
            : 'Request sent to ${c.name}'),
      ));
    }
  }

  Future<void> _addTransformation(BuildContext context, CoachProfile c) async {
    final unit = context.read<AppState>().profile.unit;
    final name = TextEditingController();
    final summary = TextEditingController();
    final before = TextEditingController();
    final after = TextEditingController();
    final weeks = TextEditingController();
    final details = TextEditingController();
    var consent = false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Client transformation', style: ctx.text.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Client name or initials')),
              const SizedBox(height: 10),
              TextField(controller: summary, decoration: const InputDecoration(labelText: 'Headline, e.g. −12 kg, first pull-up')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: before, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Before (${unit.name})'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: after, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'After (${unit.name})'))),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextField(controller: weeks, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weeks'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: details, maxLines: 3, decoration: const InputDecoration(labelText: 'What you did together')),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: (v) => set(() => consent = v ?? false),
                title: const Text('The client agreed to show this publicly'),
              ),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !context.mounted) return;
    double? w(TextEditingController t) {
      final v = double.tryParse(t.text.replaceAll(',', '.'));
      return v == null ? null : displayToKg(v, unit);
    }

    c.transformations.add(Transformation(
      clientName: name.text.trim(),
      summary: summary.text.trim(),
      details: details.text.trim(),
      weightBefore: w(before),
      weightAfter: w(after),
      weeks: int.tryParse(weeks.text),
      consent: consent,
    ));
    await context.read<CoachingState>().saveCoachProfile(c);
  }
}
