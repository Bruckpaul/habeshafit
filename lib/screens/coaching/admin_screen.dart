import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/coaching.dart';
import '../../state/coaching_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// App owner tools: approve or reject training-center applications.
/// On this phone the owner is the admin; with a cloud backend this moves to
/// an admin-only account.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final pending = coaching.pendingCenters;
    final others = coaching.centers.where((c) => c.status != CenterStatus.pending && c.id != 'sample_center').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Owner tools')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Text('Training centers apply for premium coach accounts. Approving starts a $kTrialDays-day free trial.',
            style: TextStyle(color: p.textSecondary)),
        const SizedBox(height: 16),
        SectionHeader('Waiting for review (${pending.length})'),
        if (pending.isEmpty) Text('No applications waiting.', style: TextStyle(color: p.textSecondary)),
        for (final c in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: context.text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  [
                    if (c.city.isNotEmpty) c.city,
                    'Contact: ${c.contact}',
                    'Applied ${DateFormat('MMM d, HH:mm').format(c.appliedAt)}',
                    'Coaches: ${coaching.coaches.where((x) => x.centerId == c.id).map((x) => x.name).join(', ')}',
                  ].join('\n'),
                  style: TextStyle(color: p.textSecondary, height: 1.4),
                ),
                if (c.about.isNotEmpty) ...[const SizedBox(height: 6), Text(c.about)],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final reason = await promptText(context, title: 'Reason for rejection', hint: 'Missing license details…', action: 'Reject');
                        if (reason != null) await coaching.reviewCenter(c, approve: false, reason: reason);
                      },
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => coaching.reviewCenter(c, approve: true),
                      child: const Text('Approve'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader('Reviewed'),
          for (final c in others)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(c.status == CenterStatus.approved ? Icons.check_circle : Icons.cancel,
                  color: c.status == CenterStatus.approved ? p.success : p.danger),
              title: Text(c.name),
              subtitle: Text(c.status == CenterStatus.approved
                  ? 'Approved · trial until ${c.trialEndsAt == null ? '—' : DateFormat('MMM d, yyyy').format(c.trialEndsAt!)}'
                  : 'Rejected: ${c.rejectionReason ?? ''}'),
              trailing: c.status == CenterStatus.rejected
                  ? TextButton(onPressed: () => coaching.reviewCenter(c, approve: true), child: const Text('Approve'))
                  : null,
            ),
        ],
      ]),
    );
  }
}
