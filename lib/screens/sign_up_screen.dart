import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'Name', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 16),
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined))),
              const SizedBox(height: 16),
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                  obscureText: true),
              const SizedBox(height: 32),
              ElevatedButton(
                  onPressed: () => context.go('/onboarding'),
                  child: const Text('Sign Up')),
            ],
          ),
        ),
      ),
    );
  }
}
