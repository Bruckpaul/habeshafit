import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../models/models.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final user = provider.user;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('IronStack',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accent.withOpacity(0.15),
                    AppColors.primaryBackground
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 60),
                    _StreakBanner(streak: user.streak),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          backgroundColor: AppColors.primaryBackground,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const _ThisWeekStrip(),
                const SizedBox(height: 24),
                const _QuickActions(),
                const SizedBox(height: 24),
                const _MonthlyOverview(),
                const SizedBox(height: 24),
                const _RecentWorkoutCarousel(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final int streak;
  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department,
              color: AppColors.secondaryAccent, size: 28),
          const SizedBox(width: 8),
          Text('$streak-day streak',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('🔥 Active Challenge',
                style: TextStyle(fontSize: 12, color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

class _ThisWeekStrip extends StatelessWidget {
  const _ThisWeekStrip();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (_, i) {
          final day = monday.add(Duration(days: i));
          final isToday = day.day == now.day && day.month == now.month;
          // Simulate completed days (you could check logs)
          final completed = i < 5; // example: Mon-Fri completed
          return GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.surface,
              builder: (_) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormat('EEEE').format(day),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                        completed
                            ? 'Workout completed: Push Day'
                            : 'No workout logged',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            child: Container(
              width: 50,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isToday ? AppColors.accent : Colors.transparent,
                    width: 2),
                color: completed
                    ? AppColors.accent.withOpacity(0.2)
                    : AppColors.surface,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E').format(day).substring(0, 1),
                      style: TextStyle(
                          color: isToday
                              ? AppColors.accent
                              : AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Icon(Icons.check_circle,
                      size: 16,
                      color: completed
                          ? AppColors.accent
                          : AppColors.textSecondary.withOpacity(0.3)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            onTap: () => context.push('/workout'), // quick empty workout
            child: Column(
              children: [
                Icon(Icons.fitness_center_rounded,
                    color: AppColors.accent, size: 32),
                const SizedBox(height: 8),
                Text('Start Empty Workout',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GlassCard(
            onTap: () {
              // continue last routine – navigate to last routine detail
              final provider = context.read<DataProvider>();
              if (provider.routines.isNotEmpty) {
                context.push('/workout/${provider.routines.first.id}');
              }
            },
            child: Column(
              children: [
                Icon(Icons.play_arrow_rounded,
                    color: AppColors.secondaryAccent, size: 32),
                const SizedBox(height: 8),
                Text('Continue Last Routine',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyOverview extends StatelessWidget {
  const _MonthlyOverview();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Activity',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(daysInMonth, (i) {
              final day = i + 1;
              // Mock intensity based on day number
              final intensity =
                  (day % 5 == 0) ? 1.0 : (day % 3 == 0 ? 0.6 : 0.2);
              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(intensity),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text('14 workouts this month · 12% more than last',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RecentWorkoutCarousel extends StatelessWidget {
  const _RecentWorkoutCarousel();

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<DataProvider>().workoutLogs.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Workouts',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: logs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              if (i == logs.length) {
                return GestureDetector(
                  onTap: () => context.push('/workout'),
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.accent.withOpacity(0.5)),
                    ),
                    child: const Center(
                        child: Text('View all',
                            style: TextStyle(color: AppColors.accent))),
                  ),
                );
              }
              final log = logs[i];
              final routine = context.read<DataProvider>().routines.firstWhere(
                  (r) => r.id == log.routineId,
                  orElse: () => Routine(id: '', name: 'Unknown', days: []));
              return Container(
                width: 160,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('MMM d').format(log.date),
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(routine.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${log.exercises.length} exercises',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
