// lib/widgets/panels/graph_panel.dart

import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../widgets/analytics_kpis.dart';
import '../../widgets/analytics_carousel.dart';

class GraphPanel extends StatelessWidget {
  final DashboardController controller;
  final BoxConstraints constraints;
  
  const GraphPanel({super.key, required this.controller, required this.constraints});

  static List<Widget> getActions(BuildContext context, DashboardController controller) {
    return [
      _GraphRangeAction(controller: controller),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: AnalyticsKPIs(
            analytics: controller.analytics, 
            isHorizontal: true,
            isFocused: controller.focusedTask != null,
            isEmbedded: true,
          ),
        ),
        
        Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), indent: 16, endIndent: 16),
        
        const SizedBox(height: 12),

        Expanded(
          flex: 7,
          child: AnalyticsCarousel(
            momentumData: controller.momentumData,
            volumeData: controller.volumeData,
            title: controller.heatmapRange,
            focusedTaskName: controller.focusedTask?.name,
            isEmbedded: true,
          ),
        ),
      ],
    );
  }
}

class _GraphRangeAction extends StatelessWidget {
  final DashboardController controller;
  const _GraphRangeAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['1M', '3M', '6M'].map((range) {
          final isSelected = controller.heatmapRange == range;
          return GestureDetector(
            onTap: () => controller.setHeatmapRange(range),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(range, style: TextStyle(fontSize: 8, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500, color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
