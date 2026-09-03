import 'package:flutter/material.dart';
import 'workout_plan.dart';
import 'plan_screen.dart';
import 'progress_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

class MainTabScreen extends StatefulWidget {
  final WorkoutPlan plan;
  final String goal;

  const MainTabScreen({super.key, required this.plan, required this.goal});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  static const _progressTabIndex = 1;

  int _selectedIndex = 0;
  late final List<Widget> _tabs;
  final _progressKey = GlobalKey<ProgressScreenState>();

  @override
  void initState() {
    super.initState();
    _tabs = [
      PlanScreen(plan: widget.plan, goal: widget.goal),
      ProgressScreen(key: _progressKey),
      const FriendsScreen(),
      const ProfileScreen(),
    ];
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    if (index == _progressTabIndex) {
      _progressKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Training'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Social'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
