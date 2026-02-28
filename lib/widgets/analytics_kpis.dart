import 'package:flutter/material.dart';
import '../services/scoring_service.dart';

class AnalyticsKPIs extends StatelessWidget {
  final AnalyticsResult analytics;
  final bool isHorizontal;
  final bool isFocused;
  final bool isEmbedded;

  const AnalyticsKPIs({
    super.key,
    required this.analytics,
    this.isHorizontal = true,
    this.isFocused = false,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = isHorizontal 
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _buildItems(context, isDark),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _buildItems(context, isDark),
          );

    if (isEmbedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: content,
    );
  }

  List<Widget> _buildItems(BuildContext context, bool isDark) {
    final separator = isHorizontal 
        ? VerticalDivider(color: isDark ? Colors.white10 : Colors.black12, width: 20, indent: 4, endIndent: 4)
        : Divider(color: isDark ? Colors.white10 : Colors.black12, height: 16);

    if (isFocused) {
      // Individual Habit KPIs
      return [
        _buildKPIItem(
          context,
          label: analytics.isAtRisk ? 'STREAK AT RISK' : 'CURRENT',
          value: analytics.currentStreak.toString(),
          subtitle: analytics.isAtRisk ? 'SAVE IT TODAY!' : 'STREAK',
          color: analytics.isAtRisk ? Colors.orange[700]! : Theme.of(context).colorScheme.primary,
          isWarning: analytics.isAtRisk,
        ),
        separator,
        _buildKPIItem(
          context,
          label: 'LONGEST',
          value: analytics.longestStreak.toString(),
          subtitle: 'STREAK',
          color: Colors.orange[400]!,
        ),
        separator,
        _buildKPIItem(
          context,
          label: '30-DAY',
          value: '${(analytics.consistencyRate * 100).toStringAsFixed(0)}%',
          subtitle: 'CONSISTENCY',
          color: _getConsistencyColor(analytics.consistencyRate),
        ),
      ];
    } else {
      // Global View KPIs
      return [
        _buildKPIItem(
          context,
          label: 'HABITS',
          value: analytics.totalDailyCompleted.toString(),
          subtitle: 'COMPLETED',
          color: Theme.of(context).colorScheme.primary,
        ),
        separator,
        _buildKPIItem(
          context,
          label: 'TEMP TASKS',
          value: analytics.totalTempCompleted.toString(),
          subtitle: 'DONE',
          color: Colors.blue[400]!,
        ),
        separator,
        _buildKPIItem(
          context,
          label: '7-DAY',
          value: '${(analytics.momentum7Day * 100).toStringAsFixed(0)}%',
          subtitle: 'MOMENTUM',
          color: _getConsistencyColor(analytics.momentum7Day),
        ),
      ];
    }
  }

  Color _getConsistencyColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF10B981); // High: Green
    if (rate >= 0.6) return Colors.orange[400]!;     // Med-High: Orange
    if (rate >= 0.4) return Colors.yellow[600]!;     // Med-Low: Yellow
    return Colors.red[400]!;                         // Low: Red
  }

  Widget _buildKPIItem(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    bool isWarning = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isWarning ? label : "$label $subtitle",
            maxLines: 1,
            style: TextStyle(
              fontSize: isWarning ? 6 : 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: isWarning ? Colors.orange[700] : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.1,
                ),
              ),
            ),
          ),
          if (isWarning)
            Text(
              subtitle,
              maxLines: 1,
              style: TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w800,
                color: Colors.orange[700],
              ),
            ),
        ],
      ),
    );
  }
}
