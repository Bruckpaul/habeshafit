import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../theme.dart';
import '../util/format.dart';

/// Flat surface card with a hairline border.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(16);
    return Material(
      color: color ?? p.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: borderColor ?? p.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 36)),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. a muscle group.
class Tag extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  const Tag(this.label, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: p.accent),
          ),
          const SizedBox(height: 16),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: p.textSecondary), textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      ),
    );
  }
}

/// Square exercise thumbnail with a muscle-initial fallback (offline, custom).
class ExerciseThumb extends StatelessWidget {
  final Exercise exercise;
  final double size;
  const ExerciseThumb(this.exercise, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final urls = exercise.imageUrls;
    final fallback = Container(
      color: p.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        capitalize(exercise.primaryMuscle).substring(0, 1),
        style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: size * 0.38),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox(
        width: size,
        height: size,
        child: urls.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: urls.first,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// Plays the exercise's start/end photos in a loop, like a demo animation.
class ExerciseDemo extends StatefulWidget {
  final Exercise exercise;
  final double aspectRatio;
  const ExerciseDemo(this.exercise, {super.key, this.aspectRatio = 4 / 3});

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.exercise.imageUrls.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % widget.exercise.imageUrls.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final urls = widget.exercise.imageUrls;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: Colors.white,
          child: urls.isEmpty
              ? Container(
                  color: p.surfaceAlt,
                  child: Icon(Icons.fitness_center, size: 56, color: p.textSecondary),
                )
              : Stack(fit: StackFit.expand, children: [
                  for (var i = 0; i < urls.length; i++)
                    AnimatedOpacity(
                      opacity: i == _frame ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: CachedNetworkImage(
                        imageUrl: urls[i],
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (_, __, ___) => Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.wifi_off, color: p.textSecondary),
                            const SizedBox(height: 6),
                            Text('Demo loads when online', style: TextStyle(color: p.textSecondary)),
                          ]),
                        ),
                      ),
                    ),
                ]),
        ),
      ),
    );
  }
}

/// Number + caption, used in summary rows.
class Stat extends StatelessWidget {
  final String value;
  final String label;
  final CrossAxisAlignment align;
  const Stat(this.value, this.label, {super.key, this.align = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: context.palette.textSecondary, fontSize: 12)),
    ]);
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final p = context.palette;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String action = 'Save',
}) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(action)),
      ],
    ),
  );
  return (result == null || result.isEmpty) ? null : result;
}
