import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell shell;
  const ShellScreen({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    final hasActive = context.select<AppState, bool>((s) => s.active != null);
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (hasActive) const _ResumeBar(),
        NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Workouts'),
            NavigationDestination(
                icon: Icon(Icons.sports_outlined), selectedIcon: Icon(Icons.sports), label: 'Coach'),
            NavigationDestination(
                icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ]),
    );
  }
}

/// "Workout in progress" strip above the navigation bar.
class _ResumeBar extends StatefulWidget {
  const _ResumeBar();
  @override
  State<_ResumeBar> createState() => _ResumeBarState();
}

class _ResumeBarState extends State<_ResumeBar> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.watch<AppState>().active;
    if (s == null) return const SizedBox.shrink();
    return Material(
      color: p.accent,
      child: InkWell(
        onTap: () => context.push('/workout'),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(Icons.timer_outlined, color: p.onAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${s.name} · ${fmtClock(s.duration)}',
                    style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              ),
              Text('Resume', style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w800)),
              Icon(Icons.chevron_right, color: p.onAccent),
            ]),
          ),
        ),
      ),
    );
  }
}
