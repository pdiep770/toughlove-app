import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'plan_screen.dart';
import 'workout_plan.dart';
import 'firestore_service.dart';
import 'api_config.dart';

class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key});

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  String? _experienceLevel;
  int? _daysPerWeek;
  String? _goal;
  String? _equipmentAccess;
  bool _includeExplosiveTraining = false;
  final TextEditingController _injuriesController = TextEditingController();
  final TextEditingController _squatMaxController = TextEditingController();
  final TextEditingController _benchMaxController = TextEditingController();
  final TextEditingController _deadliftMaxController = TextEditingController();
  final TextEditingController _ohpMaxController = TextEditingController();

  bool get _showMaxFields =>
      (_experienceLevel == 'intermediate' || _experienceLevel == 'advanced') &&
      _equipmentAccess == 'full_gym';

  Future<void> _submitForm() async {
    final url = Uri.parse('$apiBaseUrl/api/generate-plan');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'experienceLevel': _experienceLevel,
        'daysPerWeek': _daysPerWeek,
        'goal': _goal,
        'equipmentAccess': _equipmentAccess,
        'injuries': _injuriesController.text,
        'includeExplosiveTraining': _includeExplosiveTraining,
        'squatOneRepMax': double.tryParse(_squatMaxController.text),
        'benchOneRepMax': double.tryParse(_benchMaxController.text),
        'deadliftOneRepMax': double.tryParse(_deadliftMaxController.text),
        'overheadPressOneRepMax': double.tryParse(_ohpMaxController.text),
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final plan = WorkoutPlan.fromJson(jsonDecode(response.body));

      await FirestoreService().saveIntakeAndPlan(
        experienceLevel: _experienceLevel!,
        daysPerWeek: _daysPerWeek!,
        goal: _goal!,
        equipmentAccess: _equipmentAccess!,
        injuries: _injuriesController.text,
        plan: plan,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PlanScreen(plan: plan, goal: _goal!)),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating plan: ${response.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about yourself')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Your training',
            children: [
              const Text('Experience level'),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _experienceLevel,
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                ],
                onChanged: (value) => setState(() => _experienceLevel = value),
              ),
              const SizedBox(height: 16),

              const Text('Days per week available'),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                initialValue: _daysPerWeek,
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 days')),
                  DropdownMenuItem(value: 4, child: Text('4 days')),
                  DropdownMenuItem(value: 5, child: Text('5 days')),
                  DropdownMenuItem(value: 6, child: Text('6 days')),
                ],
                onChanged: (value) => setState(() => _daysPerWeek = value),
              ),
              const SizedBox(height: 16),

              const Text('Goal'),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _goal,
                items: const [
                  DropdownMenuItem(value: 'strength', child: Text('Strength')),
                  DropdownMenuItem(value: 'hypertrophy', child: Text('Hypertrophy (muscle growth)')),
                  DropdownMenuItem(value: 'general_fitness', child: Text('General fitness')),
                ],
                onChanged: (value) => setState(() => _goal = value),
              ),
              const SizedBox(height: 16),

              const Text('Equipment access'),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _equipmentAccess,
                items: const [
                  DropdownMenuItem(value: 'full_gym', child: Text('Full gym')),
                  DropdownMenuItem(value: 'dumbbells_only', child: Text('Dumbbells only')),
                  DropdownMenuItem(value: 'bodyweight_only', child: Text('Bodyweight only')),
                ],
                onChanged: (value) => setState(() => _equipmentAccess = value),
              ),
            ],
          ),

          if (_showMaxFields)
            _SectionCard(
              title: 'Known 1-rep maxes (optional)',
              children: [
                Text(
                  "Enter your true max if you know it. Not sure? Estimate from a recent hard set: weight × (1 + reps ÷ 30).",
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                _maxField('Squat', _squatMaxController),
                const SizedBox(height: 8),
                _maxField('Bench Press', _benchMaxController),
                const SizedBox(height: 8),
                _maxField('Deadlift', _deadliftMaxController),
                const SizedBox(height: 8),
                _maxField('Overhead Press', _ohpMaxController),
              ],
            ),

          _SectionCard(
            title: 'Anything else?',
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Include explosive/plyometric training'),
                subtitle: const Text('Jump and power work — great for volleyball, basketball, and other jump sports'),
                value: _includeExplosiveTraining,
                onChanged: (value) => setState(() => _includeExplosiveTraining = value ?? false),
              ),
              const SizedBox(height: 8),
              const Text('Injuries or limitations (optional)'),
              const SizedBox(height: 4),
              TextField(
                controller: _injuriesController,
                decoration: const InputDecoration(hintText: 'e.g. bad left knee'),
              ),
            ],
          ),

          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submitForm,
            child: const Text('Generate my plan'),
          ),
        ],
      ),
    );
  }

  Widget _maxField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(suffixText: 'lbs', isDense: true),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}