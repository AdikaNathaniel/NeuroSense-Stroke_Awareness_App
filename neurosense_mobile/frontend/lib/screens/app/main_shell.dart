import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'risk_assessment.dart';
import 'chat_screen.dart';
import 'analytics_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) => setState(() => _currentIndex = index);

  static const _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.monitor_heart_outlined),
      activeIcon: Icon(Icons.monitor_heart_rounded),
      label: 'Assess',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline_rounded),
      activeIcon: Icon(Icons.chat_bubble_rounded),
      label: 'AI Chat',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart_rounded),
      label: 'Analytics',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          RiskAssessmentScreen(),
          ChatScreen(),
          AnalyticsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: switchTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        backgroundColor: Colors.white,
        elevation: 12,
        items: _navItems,
      ),
    );
  }
}
