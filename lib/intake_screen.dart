import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'plan_screen.dart';
import 'workout_plan.dart';
import 'firestore_service.dart';

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

  Future<void> _submitForm() async {
    final url = Uri.parse('http://localhost:8080/api/generate-plan');

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
      }),
    );

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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PlanScreen(plan: plan)),
        );
      }
    } else {
      print('Error: ${response.statusCode} - ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about yourself')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text('Experience level'),
            DropdownButtonFormField<String>(
              value: _experienceLevel,
              items: const [
                DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
              ],
              onChanged: (value) => setState(() => _experienceLevel = value),
            ),
            const SizedBox(height: 16),

            const Text('Days per week available'),
            DropdownButtonFormField<int>(
              value: _daysPerWeek,
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
            DropdownButtonFormField<String>(
              value: _goal,
              items: const [
                DropdownMenuItem(value: 'strength', child: Text('Strength')),
                DropdownMenuItem(value: 'hypertrophy', child: Text('Hypertrophy (muscle growth)')),
                DropdownMenuItem(value: 'general_fitness', child: Text('General fitness')),
              ],
              onChanged: (value) => setState(() => _goal = value),
            ),
            const SizedBox(height: 16),

            const Text('Equipment access'),
            DropdownButtonFormField<String>(
              value: _equipmentAccess,
              items: const [
                DropdownMenuItem(value: 'full_gym', child: Text('Full gym')),
                DropdownMenuItem(value: 'dumbbells_only', child: Text('Dumbbells only')),
                DropdownMenuItem(value: 'bodyweight_only', child: Text('Bodyweight only')),
              ],
              onChanged: (value) => setState(() => _equipmentAccess = value),
            ),
            const SizedBox(height: 16),

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
            TextField(
              controller: _injuriesController,
              decoration: const InputDecoration(hintText: 'e.g. bad left knee'),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submitForm,
              child: const Text('Generate my plan'),
            ),
          ],
        ),
      ),
    );
  }
}