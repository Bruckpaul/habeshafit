import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/coaching.dart';
import '../../state/app_state.dart';
import '../../state/coaching_state.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/coaching_widgets.dart';
import '../../widgets/common.dart';

class CoachTabScreen extends StatelessWidget {
  const CoachTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final asCoach = coaching.isCoach && coaching.view == CoachView.coach;
    return Scaffold(
      appBar: AppBar(
        title: Text(asCoach ? 'Coach dashboard' : 'Coaching'),
        actions: [InboxButton(audience: asCoach ? Audience.coach : Audience.client)],
        bottom: coaching.isCoach
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<CoachView>(
                      segments: const [
                        ButtonSegment(value: CoachView.client, icon: Icon(Icons.person_outline), label: Text('My training')),
                        ButtonSegment(value: CoachView.coach, icon: Icon(Icons.groups_outlined), label: Text('My clients')),
                      ],
                      selected: {coaching.view},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => coaching.setView(v.first),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: asCoach ? const _CoachDashboard() : const _ClientSide(),
    );
  }
}

// ---------------------------------------------------------------------------
// Client side

class _ClientSide extends StatelessWidget {
  const _ClientSide();

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final coach = coaching.myCoach;
    if (coach == null) return const _NoCoach();
    final p = context.palette;
    final link = coaching.myLink!;
    final programs = coaching.programsFor(kMeClientId, coach.id);
    final today = coaching.myRemindersToday;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      AppCard(
        onTap: () => context.push('/coach/profile/${coach.id}'),
        child: Row(children: [
          _Avatar(name: coach.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR COACH', style: TextStyle(color: p.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Text(coach.name, style: context.text.titleMedium),
              Text('Since ${DateFormat('MMM d, yyyy').format(link.since)}', style: TextStyle(color: p.textSecondary, fontSize: 13)),
            ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
      if (today.isNotEmpty) ...[
        const SizedBox(height: 20),
        const SectionHeader('Today\'s reminders'),
        for (final r in today)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(reminderIcon(r.type), color: p.accent2),
                const SizedBox(width: 12),
                Expanded(child: Text(r.text, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(r.time, style: TextStyle(color: p.accent2, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 20),
      const SectionHeader('Program'),
      if (programs.isEmpty)
        AppCard(child: Text('Your coach hasn\'t assigned a program yet.', style: TextStyle(color: p.textSecondary)))
      else
        for (final r in programs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => context.push('/routine/${r.id}'),
              child: Row(children: [
                Icon(Icons.assignment_outlined, color: p.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${r.days.length} days · updated ${relativeDay(r.updatedAt, coaching.now).toLowerCase()}',
                        style: TextStyle(color: p.textSecondary, fontSize: 13)),
                  ]),
                ),
                if (context.read<AppState>().profile.activeRoutineId == r.id) Tag('ACTIVE', color: p.accent),
              ]),
            ),
          ),
      const SizedBox(height: 20),
      const SectionHeader('Goal board'),
      GoalBoard(clientId: kMeClientId, coachId: coach.id, editable: false),
      const SizedBox(height: 20),
      const SectionHeader('Meal plan'),
      MealPlanView(clientId: kMeClientId, coachId: coach.id, editable: false),
      const SizedBox(height: 20),
      const SectionHeader('Reminders'),
      ReminderList(clientId: kMeClientId, coachId: coach.id, editable: false),
      const SizedBox(height: 24),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: p.danger),
        onPressed: () async {
          if (await confirm(context,
              title: 'End coaching with ${coach.name}?',
              message: 'You keep your workout history and programs.',
              confirmLabel: 'End coaching',
              destructive: true)) {
            await coaching.endLink(link);
          }
        },
        child: const Text('End coaching'),
      ),
    ]);
  }
}

class _NoCoach extends StatelessWidget {
  const _NoCoach();

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final pending = coaching.myRequests.where((r) => r.status == RequestStatus.pending).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [p.accent.withValues(alpha: 0.18), p.accent2.withValues(alpha: 0.12)]),
          border: Border.all(color: p.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.sports, color: p.accent, size: 34),
          const SizedBox(height: 10),
          Text('Train with a coach', style: context.text.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'A coach writes your program, rep ranges and meal plan, sets goals with you, and reviews every workout you log.',
            style: TextStyle(color: p.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/coach/directory'),
            icon: const Icon(Icons.search),
            label: const Text('Find a coach'),
          ),
        ]),
      ),
      if (pending.isNotEmpty) ...[
        const SizedBox(height: 20),
        const SectionHeader('Your requests'),
        for (final r in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => context.push('/coach/profile/${r.coachId}'),
              child: Row(children: [
                Icon(Icons.hourglass_top, color: p.accent2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(coaching.coachById(r.coachId)?.name ?? 'Coach', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('Waiting for reply · sent ${relativeDay(r.at, coaching.now).toLowerCase()}',
                        style: TextStyle(color: p.textSecondary, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 24),
      if (!coaching.isCoach)
        AppCard(
          onTap: () => context.push('/coach/apply'),
          child: Row(children: [
            Icon(Icons.workspace_premium_outlined, color: p.accent2, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Are you a coach?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Training centers apply for a premium coach account, with a free trial after approval.',
                    style: TextStyle(color: p.textSecondary, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Coach side

class _CoachDashboard extends StatelessWidget {
  const _CoachDashboard();

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final center = coaching.myCenter;
    final me = coaching.myCoachProfile!;

    if (!coaching.coachApproved) {
      final rejected = center?.status == CenterStatus.rejected;
      return ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(rejected ? Icons.block : Icons.hourglass_top, color: rejected ? p.danger : p.accent2, size: 32),
            const SizedBox(height: 10),
            Text(rejected ? 'Application not approved' : 'Application under review', style: context.text.titleLarge),
            const SizedBox(height: 6),
            Text(
              rejected
                  ? (center?.rejectionReason ?? 'Contact support for details.')
                  : '${center?.name ?? 'Your center'} applied ${relativeDay(center?.appliedAt ?? coaching.now, coaching.now).toLowerCase()}. '
                      'Coaching tools unlock once HabeshaFit approves the center.',
              style: TextStyle(color: p.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: () => context.push('/coach/profile/${me.id}'), child: const Text('Preview my coach profile')),
          ]),
        ),
        const SizedBox(height: 12),
        _OwnerToolsCard(),
      ]);
    }

    final clients = coaching.myClients;
    final requests = coaching.incomingRequests;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      if (!coaching.trialActive)
        _Banner(color: p.danger, icon: Icons.lock_clock, text: 'Free trial ended. Subscribe to keep editing client programs (payments arrive in phase 3).')
      else if (center?.trialEndsAt != null)
        _Banner(color: p.accent2, icon: Icons.workspace_premium_outlined, text: 'Premium free trial: ${coaching.trialDaysLeft} days left'),
      const SizedBox(height: 12),
      AppCard(
        onTap: () => context.push('/coach/profile/${me.id}'),
        child: Row(children: [
          _Avatar(name: me.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(me.name, style: context.text.titleMedium),
              Text('${center?.name ?? ''} · ${clients.length} client${clients.length == 1 ? '' : 's'}',
                  style: TextStyle(color: p.textSecondary, fontSize: 13)),
            ]),
          ),
          Text('Profile', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
        ]),
      ),
      if (requests.isNotEmpty) ...[
        const SizedBox(height: 20),
        SectionHeader('Requests (${requests.length})'),
        for (final r in requests)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.fromName, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text([
                  if (r.goal.isNotEmpty) 'Goal: ${r.goal}',
                  if (r.experience.isNotEmpty) 'Experience: ${r.experience}',
                  if (r.availability.isNotEmpty) 'Available: ${r.availability}',
                ].join('\n'), style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.4)),
                if (r.message.isNotEmpty) ...[const SizedBox(height: 6), Text('"${r.message}"')],
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => coaching.answerRequest(r, accept: false),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => coaching.answerRequest(r, accept: true),
                      child: const Text('Accept'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 20),
      SectionHeader('Clients', action: coaching.canCoach ? 'Add client' : null, onAction: () => _addClient(context)),
      if (clients.isEmpty)
        EmptyState(
          icon: Icons.group_add_outlined,
          title: 'No clients yet',
          message: 'Add a client to write their program, goals, meals and reminders. '
              'Add yourself to preview exactly what your clients see.',
          action: coaching.canCoach ? 'Add client' : null,
          onAction: () => _addClient(context),
        ),
      for (final c in clients)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ClientTile(client: c),
        ),
      const SizedBox(height: 12),
      _OwnerToolsCard(),
    ]);
  }

  Future<void> _addClient(BuildContext context) async {
    final coaching = context.read<CoachingState>();
    final app = context.read<AppState>();
    final name = TextEditingController();
    final goal = TextEditingController();
    var isMe = coaching.myLink == null;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add client', style: ctx.text.titleLarge),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isMe,
              onChanged: (v) => setSheet(() => isMe = v),
              title: const Text('Add myself (preview the client side)'),
              subtitle: const Text('Programs, goals and reminders you write show up in "My training" on this phone.'),
            ),
            if (!isMe) ...[
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Client name'),
              ),
              const SizedBox(height: 6),
              Text('Until cloud sync is live, this client won\'t receive anything on their own phone.',
                  style: TextStyle(color: ctx.palette.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            TextField(controller: goal, decoration: const InputDecoration(labelText: 'Main goal (optional)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add client')),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final n = isMe ? (app.profile.name.isEmpty ? 'Me' : app.profile.name) : name.text.trim();
    if (n.isEmpty) return;
    final c = await coaching.addClient(name: n, goal: goal.text.trim(), isMe: isMe);
    if (context.mounted) context.push('/coach/client/${c.id}');
  }
}

class _ClientTile extends StatelessWidget {
  final CoachClient client;
  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final sessions = coaching.sessionsOf(client);
    final last = sessions.firstOrNull;
    final compliance = coaching.weeklyCompliance(client);
    final goals = coaching.goalsFor(client.id, client.coachId);
    return AppCard(
      onTap: () => context.push('/coach/client/${client.id}'),
      child: Row(children: [
        _Avatar(name: client.name),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(client.name, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              if (client.isMe) ...[const SizedBox(width: 6), Tag('YOU', color: p.accent)],
            ]),
            Text(
              [
                last == null ? 'No workouts logged' : 'Last: ${last.name}, ${relativeDay(last.start, coaching.now).toLowerCase()}',
                if (goals.isNotEmpty) '${goals.where((g) => g.achieved).length}/${goals.length} goals',
              ].join(' · '),
              style: TextStyle(color: p.textSecondary, fontSize: 13),
            ),
          ]),
        ),
        if (compliance != null)
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: compliance, strokeWidth: 4, backgroundColor: p.surfaceAlt, color: p.success),
              Text('${(compliance * 100).round()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    );
  }
}

class _OwnerToolsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final n = coaching.pendingCenters.length;
    return AppCard(
      onTap: () => context.push('/admin'),
      color: p.surfaceAlt,
      child: Row(children: [
        Icon(Icons.admin_panel_settings_outlined, color: p.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Owner tools', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(n == 0 ? 'Review training-center applications' : '$n application${n == 1 ? '' : 's'} waiting',
                style: TextStyle(color: p.textSecondary, fontSize: 13)),
          ]),
        ),
        if (n > 0) Badge(label: Text('$n')),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
        ]),
      );
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initials = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0])).take(2).map((w) => w[0].toUpperCase()).join();
    return CircleAvatar(
      radius: 24,
      backgroundColor: p.accent.withValues(alpha: 0.16),
      child: Text(initials.isEmpty ? '?' : initials, style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
    );
  }
}
