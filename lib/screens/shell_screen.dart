import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends StatefulWidget {
  @override
  State<_BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<_BottomNavBar> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    final routes = ['/home', '/workout', '/progress', '/profile'];
    if (index < routes.length) {
      context.go(routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
              icon: Icons.home,
              label: 'Home',
              isSelected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0)),
          _NavItem(
              icon: Icons.fitness_center,
              label: 'Workout',
              isSelected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1)),
          _NavItem(
              icon: Icons.show_chart,
              label: 'Progress',
              isSelected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2)),
          _NavItem(
              icon: Icons.person,
              label: 'Profile',
              isSelected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
