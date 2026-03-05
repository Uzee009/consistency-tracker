// lib/widgets/panels/calendar_panel.dart

import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../widgets/consistency_heatmap.dart';

class CalendarPanel extends StatefulWidget {
  final DashboardController controller;
  final BoxConstraints constraints;
  const CalendarPanel({super.key, required this.controller, required this.constraints});

  static List<Widget> getActions(BuildContext context, DashboardController controller) {
    return [
      _CalendarResetAction(controller: controller),
    ];
  }

  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  DateTime _viewedMonth = DateTime.now();
  Key _heatmapKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ConsistencyHeatmap(
        key: _heatmapKey,
        heatmapData: widget.controller.heatmapData,
        selectedDate: widget.controller.selectedDate,
        onDateSelected: (date) => widget.controller.setSelectedDate(date, showLoading: false),
        onMonthChanged: (m) => setState(() => _viewedMonth = m),
        selectedRange: '1M', 
        onRangeChanged: (_) {},
        hideControls: true,
      ),
    );
  }
}

class _CalendarResetAction extends StatelessWidget {
  final DashboardController controller;
  const _CalendarResetAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Reset to Today',
      child: GestureDetector(
        onTap: () => controller.setSelectedDate(DateTime.now(), showLoading: false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.today_rounded, size: 12, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
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
