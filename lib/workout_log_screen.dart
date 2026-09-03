import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exercise.dart';
import 'workout_day.dart';
import 'adjustment_result.dart';
import 'firestore_service.dart';
import 'api_config.dart';

class WorkoutLogScreen extends StatefulWidget {
  final String dayLabel;
  final List<Exercise> exercises;
  final String goal;

  const WorkoutLogScreen({
    super.key,
    required this.dayLabel,
    required this.exercises,
    required this.goal,
  });

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  late final List<TextEditingController> _weightControllers;
  late final List<String> _feltRatings;
  bool _submitting = false;
  List<AdjustmentResult>? _results;

  static const _ratingOptions = [
    ('easy', 'Easy'),
    ('moderate', 'Moderate'),
    ('hard', 'Hard'),
    ('failed', "Couldn't finish"),
  ];

  @override
  void initState() {
    super.initState();
    _weightControllers = widget.exercises
        .map((ex) => TextEditingController(text: ex.weight.toStringAsFixed(0)))
        .toList();
    _feltRatings = List.filled(widget.exercises.length, 'moderate');
  }

  @override
  void dispose() {
    for (final c in _weightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitLog() async {
    setState(() => _submitting = true);

    final url = Uri.parse('$apiBaseUrl/api/log-workout');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'dayLabel': widget.dayLabel,
        'goal': widget.goal,
        'exercises': List.generate(widget.exercises.length, (i) {
          final ex = widget.exercises[i];
          return {
            'exerciseName': ex.name,
            'sets': ex.sets,
            'repsLow': ex.repsLow,
            'repsHigh': ex.repsHigh,
            'weight': double.tryParse(_weightControllers[i].text) ?? ex.weight,
            'feltRating': _feltRatings[i],
          };
        }),
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final results = (decoded['results'] as List)
          .map((r) => AdjustmentResult.fromJson(r))
          .toList();

      final updatedExercises = results.map((r) => r.updatedExercise).toList();

      await FirestoreService().saveWorkoutLog(
        dayLabel: widget.dayLabel,
        exercises: updatedExercises,
      );
      await FirestoreService().updateDayExercises(
        dayLabel: widget.dayLabel,
        exercises: updatedExercises,
      );

      setState(() {
        _results = results;
        _submitting = false;
      });
    } else {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging workout: ${response.statusCode}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_results != null) {
      return _buildResultsView();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Log: ${widget.dayLabel}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.exercises.length,
        itemBuilder: (context, i) {
          final ex = widget.exercises[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.name, style: Theme.of(context).textTheme.titleMedium),
                  Text('${ex.sets} sets x ${ex.repsLow}-${ex.repsHigh} reps'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Weight used: '),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _weightControllers[i],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(suffixText: 'lbs', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _ratingOptions.map((option) {
                      final (value, label) = option;
                      return ChoiceChip(
                        label: Text(label),
                        selected: _feltRatings[i] == value,
                        onSelected: (_) => setState(() => _feltRatings[i] = value),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitLog,
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit workout'),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final results = _results!;
    return Scaffold(
      appBar: AppBar(title: const Text('Nice work!')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final result = results[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.updatedExercise.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Next time: ${result.updatedExercise.sets}x${result.updatedExercise.repsLow}-${result.updatedExercise.repsHigh} @ ${result.updatedExercise.weight.toStringAsFixed(0)} lbs',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              final updatedDay = WorkoutDay(
                dayLabel: widget.dayLabel,
                exercises: results.map((r) => r.updatedExercise).toList(),
              );
              Navigator.pop(context, updatedDay);
            },
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }
}
