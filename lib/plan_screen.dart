import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
      body: ListView.builder(
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
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
                        child: Text('${ex.name} — ${ex.sets}x${ex.repsLow}-${ex.repsHigh} @ ${ex.weight.toStringAsFixed(0)} lbs'),
                      )),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => _logWorkout(day),
                      child: const Text('Log this workout'),
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
