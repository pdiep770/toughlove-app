import 'package:flutter/material.dart';
import 'user_profile_service.dart';
import 'profile_setup_screen.dart';
import 'intake_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _loading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final profile = await UserProfileService().getProfile();
    if (mounted) {
      setState(() {
        _hasProfile = profile != null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasProfile) {
      return const IntakeScreen();
    }

    return const ProfileSetupScreen();
  }
}