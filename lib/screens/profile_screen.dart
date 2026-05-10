import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/data_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../models/models.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final user = provider.user;
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.accent,
              child: CircleAvatar(
                radius: 47,
                backgroundColor: AppColors.surface,
                child: Text(user.name[0].toUpperCase(),
                    style:
                        const TextStyle(fontSize: 36, color: AppColors.accent)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(user.name,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Member since ${DateFormat('MMM y').format(user.memberSince)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department,
                  color: AppColors.secondaryAccent),
              Text(' ${user.streak} day streak',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              const Text('·'),
              const SizedBox(width: 16),
              const Icon(Icons.fitness_center, color: AppColors.accent),
              Text(' ${user.totalWorkouts} workouts',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Challenges', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...provider.challenges.map((c) => GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${c.daysLeft} days left',
                            style: TextStyle(color: AppColors.secondaryAccent)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.description,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: c.progress / c.target,
                      backgroundColor: AppColors.surface,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 4),
                    Text('${c.progress}/${c.target}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )),
          ElevatedButton.icon(
            onPressed: () => _joinChallengeSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Join Challenge'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryAccent),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Units (kg/lbs)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Rest Timer Default'),
            trailing: const Text('60s',
                style: TextStyle(color: AppColors.textSecondary)),
            onTap: () {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            value: true,
            onChanged: (_) {},
            activeColor: AppColors.accent,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Log out'),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Log out'),
                  content: const Text('Are you sure?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/login');
                      },
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _joinChallengeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Predefined Challenges',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: const Text('50 Push-ups'),
              onTap: () {
                context.read<DataProvider>().joinChallenge(Challenge(
                      id: 'c_temp',
                      name: '50 Push-ups',
                      description: '50 push-ups daily for 30 days',
                      target: 50,
                      progress: 0,
                      daysLeft: 30,
                    ));
                Navigator.pop(context);
              },
            ),
            const Divider(),
            const Text('Create Custom',
                style: TextStyle(color: AppColors.accent)),
            // Not fully implemented
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
