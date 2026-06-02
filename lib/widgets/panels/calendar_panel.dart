// lib/widgets/panels/calendar_panel.dart

import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/dashboard_layout_controller.dart';
import '../../widgets/consistency_heatmap.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_icon_size.dart';
import '../motion/animated_tooltip.dart';

class CalendarPanel extends StatefulWidget {
  final DashboardController controller;
  final BoxConstraints constraints;
  const CalendarPanel({super.key, required this.controller, required this.constraints});

  static List<Widget> getActions(BuildContext context, DashboardController controller, DashboardLayoutController layoutController) {
    return [
      _CalendarResetAction(controller: controller),
    ];
  }


  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {

  @override
  Widget build(BuildContext context) {
    return ConsistencyHeatmap(
      key: const ValueKey('calendar_heatmap_stable'), // V8: Stable key to prevent resets
      heatmapData: widget.controller.heatmapData,
      selectedDate: widget.controller.selectedDate,
      onDateSelected: (date) => widget.controller.setSelectedDate(date, showLoading: false),
      onMonthChanged: (_) {},
      selectedRange: '1M', 
      onRangeChanged: (_) {},
      hideControls: true,
    );
  }
}

class _CalendarResetAction extends StatelessWidget {
  final DashboardController controller;
  const _CalendarResetAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedTooltip(
      message: 'Reset to Today',
      child: GestureDetector(
        onTap: () => controller.setSelectedDate(DateTime.now(), showLoading: false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm)
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.today_rounded, size: AppIconSize.xs, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                'TODAY',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
