import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic/stats.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final String exerciseId;
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final e = state.exercise(exerciseId);
    final unit = state.profile.unit;

    // Sessions with this exercise, oldest first.
    final history = state.sessions
        .where((s) => s.exercises.any((x) => x.exerciseId == e.id && x.doneSets > 0))
        .toList()
        .reversed
        .toList();
    final bests = bestsFor(e.id, history);

    return Scaffold(
      appBar: AppBar(title: Text(e.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ExerciseDemo(e),
          const SizedBox(height: 16),
          Text(e.name, style: context.text.headlineSmall),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in e.primaryMuscles) Tag(capitalize(m), color: p.accent),
            for (final m in e.secondaryMuscles) Tag(capitalize(m)),
          ]),
          const SizedBox(height: 16),
          AppCard(
            child: Row(children: [
              Expanded(child: Stat(capitalize(e.equipment), 'Equipment')),
              Expanded(child: Stat(capitalize(e.level ?? '—'), 'Level')),
              Expanded(child: Stat(capitalize(e.category), 'Type')),
            ]),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Your history'),
          if (history.isEmpty)
            Text('You haven\'t logged this exercise yet.', style: TextStyle(color: p.textSecondary))
          else ...[
            AppCard(
              child: Row(children: [
                Expanded(child: Stat(fmtWeight(bests.maxWeight, unit), 'Heaviest')),
                Expanded(child: Stat(fmtWeight(bests.bestE1rm, unit), 'Best est. 1RM')),
                Expanded(child: Stat('${history.length}', 'Sessions')),
              ]),
            ),
            if (history.length >= 2) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text('Estimated 1RM (${unit.name})', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(height: 180, child: _E1rmChart(sessions: history, exerciseId: e.id, unit: unit)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            for (final s in history.reversed.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => context.push('/session/${s.id}'),
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${DateFormat('EEE, MMM d').format(s.start)} · ${s.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      s.exercises
                          .where((x) => x.exerciseId == e.id)
                          .expand((x) => x.sets)
                          .where((x) => x.done)
                          .map((x) => '${fmtWeight(x.weight ?? 0, unit, withUnit: false)}×${x.repsLabel}${x.kind.short.isEmpty ? '' : ' ${x.kind.short}'}')
                          .join('   '),
                      style: TextStyle(color: p.textSecondary),
                    ),
                  ]),
                ),
              ),
          ],
          if (e.instructions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader('How to do it'),
            for (final (i, step) in e.instructions.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step, style: const TextStyle(height: 1.45))),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

class _E1rmChart extends StatelessWidget {
  final List<WorkoutSession> sessions; // oldest first
  final String exerciseId;
  final WeightUnit unit;
  const _E1rmChart({required this.sessions, required this.exerciseId, required this.unit});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final spots = <FlSpot>[];
    for (final (i, s) in sessions.indexed) {
      final b = bestsFor(exerciseId, [s]);
      if (b.bestE1rm > 0) spots.add(FlSpot(i.toDouble(), kgToDisplay(b.bestE1rm, unit)));
    }
    if (spots.length < 2) return const SizedBox.shrink();
    final ys = spots.map((s) => s.y);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final pad = math.max(2.5, (maxY - minY) * 0.15);
    return LineChart(LineChartData(
      minY: (minY - pad).floorToDouble(),
      maxY: (maxY + pad).ceilToDouble(),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                ? const SizedBox.shrink()
                : Text(fmtNumber(v), style: TextStyle(color: p.textSecondary, fontSize: 11)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: math.max(1, (sessions.length / 4).ceilToDouble()),
            getTitlesWidget: (v, _) {
              final i = v.round();
              if (i < 0 || i >= sessions.length || v != i.toDouble()) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(DateFormat('MMM d').format(sessions[i].start),
                    style: TextStyle(color: p.textSecondary, fontSize: 11)),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => p.textPrimary,
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem('${fmtNumber(s.y)} ${unit.name}', TextStyle(color: p.background, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: p.accent,
          barWidth: 3,
          dotData: FlDotData(
            getDotPainter: (_, __, ___, ____) =>
                FlDotCirclePainter(radius: 3.5, color: p.accent, strokeWidth: 2, strokeColor: p.surface),
          ),
          belowBarData: BarAreaData(show: true, color: p.accent.withValues(alpha: 0.12)),
        ),
      ],
    ));
  }
}
