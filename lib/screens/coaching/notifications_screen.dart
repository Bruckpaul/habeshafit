import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/coaching.dart';
import '../../state/coaching_state.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  final Audience audience;
  const NotificationsScreen({super.key, required this.audience});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final CoachingState _coaching;

  @override
  void initState() {
    super.initState();
    _coaching = context.read<CoachingState>();
  }

  @override
  void dispose() {
    // Opening the inbox marks everything as read when leaving.
    final c = _coaching, a = widget.audience;
    Future.microtask(() => c.markRead(a));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coaching = context.watch<CoachingState>();
    final p = context.palette;
    final list = coaching.inbox(widget.audience);
    return Scaffold(
      appBar: AppBar(title: Text(widget.audience == Audience.coach ? 'Coach notifications' : 'Notifications')),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'All caught up',
              message: 'Program updates, goals, meal plans, reminders and feedback show up here.',
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(indent: 72),
              itemBuilder: (_, i) {
                final n = list[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: (n.read ? p.surfaceAlt : p.accent.withValues(alpha: 0.18)),
                    child: Icon(Icons.notifications, color: n.read ? p.textSecondary : p.accent, size: 20),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                  subtitle: Text('${n.body}\n${relativeDay(n.at, coaching.now)}', style: TextStyle(color: p.textSecondary)),
                  isThreeLine: true,
                  onTap: n.link == null ? null : () => context.push(n.link!),
                );
              },
            ),
    );
  }
}
