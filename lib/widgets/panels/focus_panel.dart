// lib/widgets/panels/focus_panel.dart

import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/dashboard_layout_controller.dart';
import '../../widgets/pomodoro_timer.dart';

class FocusPanel extends StatelessWidget {
  final DashboardController controller;
  final BoxConstraints constraints;
  
  const FocusPanel({super.key, required this.controller, required this.constraints});

  static List<Widget> getActions(BuildContext context, DashboardController controller, DashboardLayoutController layoutController) {
    return [
      const Icon(Icons.timer_rounded, size: 14, color: Colors.grey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PomodoroTimer(controller: controller),
    );
  }
}
