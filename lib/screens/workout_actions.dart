import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/routine.dart';
import '../services/notification_scheduler.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Returns true when it is fine to start a new workout. If one is already
/// running, offers to resume it (and returns false) or discard it.
Future<bool> _clearActive(BuildContext context) async {
  final state = context.read<AppState>();
  final current = state.active;
  if (current == null) return true;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Workout in progress'),
      content: Text('"${current.name}" is still running. Resume it or discard it and start a new one?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'resume'), child: const Text('Resume')),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (choice == 'resume') {
    context.push('/workout');
    return false;
  }
  if (choice == 'discard') {
    final sure = await confirm(context,
        title: 'Discard workout?', message: 'Logged sets in this workout will be lost.', confirmLabel: 'Discard', destructive: true);
    if (!sure) return false;
    await state.discardActive();
    return true;
  }
  return false;
}

Future<void> startRoutineDay(BuildContext context, Routine routine, RoutineDay day, {int? slotIndex}) async {
  if (!await _clearActive(context)) return;
  if (!context.mounted) return;
  final scheduler = context.read<NotificationScheduler>();
  await context.read<AppState>().startRoutineWorkout(routine, day, slotIndex: slotIndex);
  if (context.mounted) context.push('/workout');
  // First workout: ask for notifications so the rest timer can alert.
  await scheduler.ensurePermission();
}

Future<void> startEmpty(BuildContext context) async {
  if (!await _clearActive(context)) return;
  if (!context.mounted) return;
  final scheduler = context.read<NotificationScheduler>();
  await context.read<AppState>().startEmptyWorkout();
  if (context.mounted) context.push('/workout');
  await scheduler.ensurePermission();
}
