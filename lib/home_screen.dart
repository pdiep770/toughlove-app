import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_plan.dart';
import 'plan_screen.dart';
import 'intake_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatelessWidget {
  final WorkoutPlan plan;
  final String goal;

  const HomeScreen({super.key, required this.plan, required this.goal});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _confirmNewPlan(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate a new plan?'),
        content: const Text('This will replace your current plan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const IntakeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chalked In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Friends',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.fitness_center, size: 48, color: colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT PLAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${plan.splitType.replaceAll('_', ' ')} · ${plan.days.length} days/week',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PlanScreen(plan: plan, goal: goal)),
                    );
                  },
                  child: const Text('View My Plan'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _confirmNewPlan(context),
                  child: const Text('Generate New Plan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
