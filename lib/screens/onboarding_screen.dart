import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final pages = const [
    _OnboardPage(
      lottie: 'https://assets10.lottiefiles.com/packages/lf20_pvxjvkvg.json',
      title: 'Track Your Workouts',
      subtitle: 'Log every set, rep, and weight effortlessly.',
    ),
    _OnboardPage(
      lottie: 'https://assets1.lottiefiles.com/packages/lf20_hvtltxsc.json',
      title: 'Measure Progress',
      subtitle: 'See your strength gains with detailed charts.',
    ),
    _OnboardPage(
      lottie: 'https://assets9.lottiefiles.com/packages/lf20_01jwre1t.json',
      title: 'Join Challenges',
      subtitle: 'Stay motivated with streaks and challenges.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.accent
                        : AppColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_currentPage == pages.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<DataProvider>().completeOnboarding();
                      context.go('/home');
                    },
                    child: const Text('Get Started'),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Skip',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String lottie;
  final String title;
  final String subtitle;

  const _OnboardPage(
      {required this.lottie, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(lottie, height: 250),
          const SizedBox(height: 32),
          Text(title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}
