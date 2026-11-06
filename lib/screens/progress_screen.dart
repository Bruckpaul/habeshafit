import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic/stats.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../state/coaching_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress'),
          bottom: TabBar(
            indicatorColor: p.accent,
            labelColor: p.textPrimary,
            unselectedLabelColor: p.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            dividerColor: p.border,
            tabs: const [Tab(text: 'Overview'), Tab(text: 'Exercises'), Tab(text: 'Body')],
          ),
        ),
        body: const TabBarView(children: [_OverviewTab(), _ExercisesTab(), _BodyTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final now = state.clock();
    if (state.sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.insights,
        title: 'Your stats start here',
        message: 'Finish a workout to see weekly volume, muscles trained and records.',
      );
    }
    final thisWeek = weekStart(now);
    final weeks = [for (var i = 7; i >= 0; i--) thisWeek.subtract(Duration(days: 7 * i))];
    final perWeek = [
      for (final w in weeks)
        state.sessions.where((s) => !s.start.isBefore(w) && s.start.isBefore(w.add(const Duration(days: 7)))).length
    ];
    final muscles = setsPerMuscle(
      state.sessions,
      (id) => state.exercise(id).primaryMuscle,
      thisWeek,
      thisWeek.add(const Duration(days: 7)),
    );
    final last4 = setsPerMuscle(
      state.sessions,
      (id) => state.exercise(id).primaryMuscle,
      thisWeek.subtract(const Duration(days: 28)),
      thisWeek,
    );
    final keys = {...muscles.keys, ...last4.keys}.toList()
      ..sort((a, b) => (muscles[b] ?? 0).compareTo(muscles[a] ?? 0));
    final maxSets = keys.fold<double>(1, (m, k) => math.max(m, math.max((muscles[k] ?? 0).toDouble(), (last4[k] ?? 0) / 4)));
    final totalVolume = state.sessions.fold(0.0, (a, s) => a + s.volume);
    final prs = state.sessions.fold(0, (a, s) => a + s.records.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          child: Row(children: [
            Expanded(child: Stat('${state.sessions.length}', 'Workouts')),
            Expanded(child: Stat(fmtVolume(totalVolume, state.profile.unit), 'Total volume')),
            Expanded(child: Stat('$prs', 'PRs')),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Workouts per week', style: context.text.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2, bottom: 12),
              child: Text('Target ${state.profile.weeklyTarget} per week (dashed line)',
                  style: TextStyle(color: p.textSecondary, fontSize: 12)),
            ),
            SizedBox(
              height: 160,
              child: BarChart(BarChartData(
                maxY: math.max(perWeek.reduce(math.max), state.profile.weeklyTarget).toDouble() + 1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: state.profile.weeklyTarget.toDouble(),
                    color: p.accent2,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                ]),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          v.toInt() == weeks.length - 1 ? 'Now' : DateFormat('d/M').format(weeks[v.toInt()]),
                          style: TextStyle(color: p.textSecondary, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => p.textPrimary,
                    getTooltipItem: (g, _, r, __) => BarTooltipItem(
                        '${r.toY.toInt()} workouts', TextStyle(color: p.background, fontWeight: FontWeight.w700)),
                  ),
                ),
                barGroups: [
                  for (final (i, n) in perWeek.indexed)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: n.toDouble(),
                        width: 18,
                        color: n >= state.profile.weeklyTarget ? p.accent : p.accent.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ]),
                ],
              )),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sets per muscle this week', style: context.text.titleMedium),
            const SizedBox(height: 2),
            Text('Bar = this week · tick = your 4-week weekly average',
                style: TextStyle(color: p.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            if (keys.isEmpty) Text('No sets logged in the last 5 weeks.', style: TextStyle(color: p.textSecondary)),
            for (final k in keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(width: 96, child: Text(capitalize(k), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  Expanded(
                    child: LayoutBuilder(builder: (_, c) {
                      final w = c.maxWidth;
                      final cur = (muscles[k] ?? 0) / maxSets;
                      final avg = ((last4[k] ?? 0) / 4) / maxSets;
                      return SizedBox(
                        height: 14,
                        child: Stack(children: [
                          Container(decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(7))),
                          Container(
                            width: w * cur,
                            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(7)),
                          ),
                          if (avg > 0)
                            Positioned(left: (w * avg - 1.5).clamp(0, w - 3), top: 0, bottom: 0, child: Container(width: 3, color: p.accent2)),
                        ]),
                      );
                    }),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('${muscles[k] ?? 0}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ExercisesTab extends StatelessWidget {
  const _ExercisesTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final unit = state.profile.unit;
    final ids = <String>[];
    final count = <String, int>{};
    for (final s in state.sessions) {
      for (final e in s.exercises) {
        if (e.doneSets == 0) continue;
        if (!count.containsKey(e.exerciseId)) ids.add(e.exerciseId);
        count[e.exerciseId] = (count[e.exerciseId] ?? 0) + 1;
      }
    }
    if (ids.isEmpty) {
      return const EmptyState(
        icon: Icons.fitness_center,
        title: 'No exercises logged',
        message: 'Each exercise you log gets its own chart and records here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: ids.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = state.exercise(ids[i]);
        final b = bestsFor(e.id, state.sessions);
        return AppCard(
          onTap: () => context.push('/exercise/${Uri.encodeComponent(e.id)}'),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ExerciseThumb(e, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${count[e.id]} sessions · best ${fmtWeight(b.maxWeight, unit)}',
                    style: TextStyle(color: p.textSecondary, fontSize: 13)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtWeight(b.bestE1rm, unit), style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
              Text('est. 1RM', style: TextStyle(color: p.textSecondary, fontSize: 11)),
            ]),
          ]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

const _bodyParts = ['waist', 'chest', 'arms', 'thighs', 'hips', 'neck'];

class _BodyTab extends StatelessWidget {
  const _BodyTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final unit = state.profile.unit;
    final weights = state.measurements.where((m) => m.type == 'bodyweight').toList().reversed.toList();
    final latest = weights.isEmpty ? null : weights.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Body weight', style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Text(latest == null ? 'Not logged yet' : fmtWeight(latest.value, unit),
                      style: context.text.headlineSmall),
                  if (weights.length >= 2)
                    Text(
                      '${weights.last.value >= weights.first.value ? '+' : '−'}${fmtWeight((weights.last.value - weights.first.value).abs(), unit)} since ${DateFormat('MMM d').format(weights.first.date)}',
                      style: TextStyle(color: p.textSecondary, fontSize: 13),
                    ),
                ]),
              ),
              FilledButton.icon(
                onPressed: () => _log(context, 'bodyweight'),
                icon: const Icon(Icons.add),
                label: const Text('Log'),
              ),
            ]),
            if (weights.length >= 2) ...[
              const SizedBox(height: 16),
              SizedBox(height: 150, child: _WeightChart(points: weights.map((m) => (m.date, kgToDisplay(m.value, unit))).toList())),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Measurements (cm)'),
        for (final part in _bodyParts)
          Builder(builder: (context) {
            final list = state.measurements.where((m) => m.type == part).toList(); // newest first
            final delta = list.length >= 2 ? list.first.value - list[1].value : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => _log(context, part),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(child: Text(capitalize(part), style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (list.isNotEmpty) ...[
                    if (delta != null && delta != 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text('${delta > 0 ? '+' : '−'}${fmtNumber(delta.abs())}',
                            style: TextStyle(color: p.textSecondary, fontSize: 13)),
                      ),
                    Text('${fmtNumber(list.first.value)} cm', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ] else
                    Text('Add', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: p.textSecondary),
                ]),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _log(BuildContext context, String type) async {
    final state = context.read<AppState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MeasurementSheet(type: type, unit: state.profile.unit),
    );
  }
}

class _MeasurementSheet extends StatefulWidget {
  final String type;
  final WeightUnit unit;
  const _MeasurementSheet({required this.type, required this.unit});
  @override
  State<_MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends State<_MeasurementSheet> {
  final _c = TextEditingController();

  bool get _isWeight => widget.type == 'bodyweight';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final history = state.measurements.where((m) => m.type == widget.type).take(8).toList();
    final unitLabel = _isWeight ? widget.unit.name : 'cm';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_isWeight ? 'Body weight' : capitalize(widget.type), style: context.text.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Today ($unitLabel)'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final v = double.tryParse(_c.text.replaceAll(',', '.'));
            if (v == null || v <= 0) return;
            final coaching = context.read<CoachingState>();
            await state.addMeasurement(widget.type, _isWeight ? displayToKg(v, widget.unit) : v);
            await coaching.refreshGoals();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Recent', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w700)),
          for (final m in history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_isWeight ? fmtWeight(m.value, widget.unit) : '${fmtNumber(m.value)} cm'),
              subtitle: Text(DateFormat('EEE, MMM d').format(m.date)),
              trailing: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => state.deleteMeasurement(m.id),
              ),
            ),
        ],
      ]),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<(DateTime, double)> points; // oldest first
  const _WeightChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ys = points.map((e) => e.$2);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final pad = math.max(1.0, (maxY - minY) * 0.2);
    final first = points.first.$1;
    return LineChart(LineChartData(
      minY: (minY - pad).floorToDouble(),
      maxY: (maxY + pad).ceilToDouble(),
      gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                ? const SizedBox.shrink()
                : Text(fmtNumber(v), style: TextStyle(color: p.textSecondary, fontSize: 11)),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => p.textPrimary,
          getTooltipItems: (s) => [
            for (final x in s)
              LineTooltipItem(
                '${fmtNumber(x.y)} · ${DateFormat('MMM d').format(first.add(Duration(hours: x.x.round())))}',
                TextStyle(color: p.background, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [for (final (d, v) in points) FlSpot(d.difference(first).inHours.toDouble(), v)],
          isCurved: true,
          preventCurveOverShooting: true,
          color: p.accent,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: p.accent.withValues(alpha: 0.12)),
        ),
      ],
    ));
  }
}
