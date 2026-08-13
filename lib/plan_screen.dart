import 'package:flutter/material.dart';
import 'workout_plan.dart';

class PlanScreen extends StatelessWidget {
  final WorkoutPlan plan;

  const PlanScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Your ${plan.splitType.replaceAll('_', ' ')} plan')),
      body: ListView.builder(
        itemCount: plan.days.length,
        itemBuilder: (context, index) {
          final day = plan.days[index];
          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.dayLabel, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...day.exercises.map((ex) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${ex.name} — ${ex.sets}x${ex.repsLow}-${ex.repsHigh} @ ${ex.weight.toStringAsFixed(0)} lbs',
                        ),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}