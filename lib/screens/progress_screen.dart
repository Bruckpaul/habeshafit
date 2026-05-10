import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/models.dart'; // <-- Add this to resolve Measurement
import '../providers/data_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Progress'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Exercises'),
            Tab(text: 'Photos'),
            Tab(text: 'Measurements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ExercisesTab(),
          _PhotosTab(),
          _MeasurementsTab(),
        ],
      ),
    );
  }
}

class _ExercisesTab extends StatefulWidget {
  const _ExercisesTab();

  @override
  State<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<_ExercisesTab> {
  String? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final exerciseNames = provider.exerciseLibrary;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedExerciseId,
            decoration: const InputDecoration(labelText: 'Select exercise'),
            items: exerciseNames
                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedExerciseId = v),
          ),
          const SizedBox(height: 20),
          if (_selectedExerciseId != null) ...[
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getDummySpots(),
                      isCurved: true,
                      color: AppColors.accent,
                      belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.accent.withOpacity(0.15)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (_, i) => ListTile(
                  title: Text('Session ${i + 1}'),
                  subtitle: const Text('80 kg × 8 reps'),
                  trailing: Text(
                      '${DateTime.now().subtract(Duration(days: i * 7)).day}/${DateTime.now().month}'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<FlSpot> _getDummySpots() {
    return List.generate(12, (i) => FlSpot(i.toDouble(), (50.0 + i * 2.5)));
  }
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 9,
          itemBuilder: (_, i) => Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              // Replace with actual image asset or placeholder
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.black54,
                child: Text(
                  'Week ${i + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            backgroundColor: AppColors.accent,
            onPressed: () {
              // Placeholder: add photo logic
            },
            child: const Icon(Icons.add_a_photo,
                color: AppColors.primaryBackground),
          ),
        ),
      ],
    );
  }
}

class _MeasurementsTab extends StatelessWidget {
  const _MeasurementsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final parts = ['Biceps', 'Chest', 'Waist', 'Thighs'];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: parts.length,
      itemBuilder: (_, i) {
        final part = parts[i];
        final latest = provider.measurements
            .where((m) => m.bodyPart == part)
            .fold<Measurement?>(
                null,
                (prev, m) =>
                    (prev == null || m.date.isAfter(prev.date)) ? m : prev);
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title:
                Text(part, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: latest != null
                ? Text('${latest.value.toStringAsFixed(1)} cm')
                : const Text('No data'),
            trailing: Icon(Icons.show_chart, color: AppColors.accent),
            onTap: () => _showAddDialog(context, part),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, String part) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Log $part',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Value (cm)')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(ctrl.text) ?? 0;
                if (value > 0) {
                  context.read<DataProvider>().addMeasurement(Measurement(
                        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
                        date: DateTime.now(),
                        bodyPart: part,
                        value: value,
                        isMetric: true,
                      ));
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
