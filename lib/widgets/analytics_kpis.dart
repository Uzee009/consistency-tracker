import 'package:flutter/material.dart';
import '../services/scoring_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

class AnalyticsKPIs extends StatelessWidget {
  final AnalyticsResult analytics;
  final bool isHorizontal;
  final bool isFocused;
  final bool isEmbedded;
  final Function(DateTime)? onJump;

  const AnalyticsKPIs({
    super.key,
    required this.analytics,
    this.isHorizontal = true,
    this.isFocused = false,
    this.isEmbedded = false,
    this.onJump,
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
        padding: EdgeInsets.zero, // Shell handles padding
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: content,
    );
  }

  List<Widget> _buildItems(BuildContext context, bool isDark) {
    final separator = isHorizontal 
        ? VerticalDivider(color: isDark ? Colors.white10 : Colors.black12, width: AppSpacing.lg, indent: 4, endIndent: 4)
        : Divider(color: isDark ? Colors.white10 : Colors.black12, height: AppSpacing.md);

    if (isFocused) {
      // Individual Habit KPIs
      return [
        _buildKPIItem(
          context,
          label: analytics.isAtRisk ? 'STREAK AT RISK' : 'CURRENT',
          value: analytics.currentStreak.toString(),
          subtitle: analytics.isAtRisk ? 'SAVE IT TODAY!' : 'STREAK',
          color: analytics.isAtRisk ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary,
          isWarning: analytics.isAtRisk,
        ),
        separator,
        _buildKPIItem(
          context,
          label: 'LONGEST',
          value: analytics.longestStreak.toString(),
          subtitle: 'STREAK',
          color: Theme.of(context).colorScheme.tertiary,
          isClickable: analytics.longestStreakStart != null,
          onTap: analytics.longestStreakStart != null ? () => onJump?.call(analytics.longestStreakStart!) : null,
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
          color: Theme.of(context).colorScheme.primary,
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

  // Semantic consistency gradient — colors are intentionally not theme-mapped.
  Color _getConsistencyColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF10B981); // High: Green
    if (rate >= 0.6) return const Color(0xFFFB923C); // Med-High: Orange (Colors.orange[400])
    if (rate >= 0.4) return const Color(0xFFCA8A04); // Med-Low: Yellow (Colors.yellow[600])
    return const Color(0xFFF87171);                  // Low: Red (Colors.red[400])
  }

  Widget _buildKPIItem(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    bool isWarning = false,
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isWarning ? label : "$label $subtitle",
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isWarning ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isClickable) ...[
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(Icons.north_east_rounded, size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            if (isWarning) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
