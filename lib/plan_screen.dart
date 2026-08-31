import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_plan.dart';
import 'workout_day.dart';
import 'friends_screen.dart';
import 'workout_log_screen.dart';

class PlanScreen extends StatefulWidget {
  final WorkoutPlan plan;
  final String goal;

  const PlanScreen({super.key, required this.plan, required this.goal});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late List<WorkoutDay> _days;

  @override
  void initState() {
    super.initState();
    _days = widget.plan.days;
  }

  Future<void> _logWorkout(WorkoutDay day) async {
    final updatedDay = await Navigator.push<WorkoutDay>(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutLogScreen(
          dayLabel: day.dayLabel,
          exercises: day.exercises,
          goal: widget.goal,
        ),
      ),
    );

    if (updatedDay != null) {
      setState(() {
        final index = _days.indexWhere((d) => d.dayLabel == updatedDay.dayLabel);
        if (index != -1) {
          _days = List.of(_days)..[index] = updatedDay;
        }
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  IconData _iconForDay(String dayLabel) {
    if (dayLabel.contains('Push')) return Icons.arrow_circle_up_outlined;
    if (dayLabel.contains('Pull')) return Icons.arrow_circle_down_outlined;
    if (dayLabel.contains('Legs') || dayLabel.contains('Lower')) return Icons.directions_run;
    if (dayLabel.contains('Upper')) return Icons.fitness_center;
    if (dayLabel.contains('Full Body')) return Icons.self_improvement;
    return Icons.fitness_center;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your ${widget.plan.splitType.replaceAll('_', ' ')} plan'),
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
            onPressed: _signOut,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconForDay(day.dayLabel), color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(day.dayLabel, style: Theme.of(context).textTheme.titleLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...day.exercises.map((ex) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${ex.sets}x${ex.repsLow}-${ex.repsHigh} @ ${ex.weight.toStringAsFixed(0)} lbs',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => _logWorkout(day),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Log this workout'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
