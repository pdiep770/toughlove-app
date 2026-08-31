import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_service.dart';
import 'profile_setup_screen.dart';
import 'intake_screen.dart';
import 'plan_screen.dart';
import 'workout_plan.dart';
import 'auth_screen.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const AuthScreen();
        }
        return const _ProfileRouter();
      },
    );
  }
}

enum _Destination { loading, profileSetup, intake, plan }

class _ProfileRouter extends StatefulWidget {
  const _ProfileRouter();

  @override
  State<_ProfileRouter> createState() => _ProfileRouterState();
}

class _ProfileRouterState extends State<_ProfileRouter> {
  _Destination _destination = _Destination.loading;
  WorkoutPlan? _plan;
  String? _goal;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final profile = await UserProfileService().getProfile();
    if (!mounted) return;

    if (profile == null) {
      setState(() => _destination = _Destination.profileSetup);
      return;
    }

    final currentPlan = profile['currentPlan'];
    if (currentPlan != null) {
      setState(() {
        _plan = WorkoutPlan.fromJson(currentPlan);
        _goal = profile['goal'] as String;
        _destination = _Destination.plan;
      });
      return;
    }

    setState(() => _destination = _Destination.intake);
  }

  @override
  Widget build(BuildContext context) {
    switch (_destination) {
      case _Destination.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Destination.profileSetup:
        return const ProfileSetupScreen();
      case _Destination.intake:
        return const IntakeScreen();
      case _Destination.plan:
        return PlanScreen(plan: _plan!, goal: _goal!);
    }
  }
}
