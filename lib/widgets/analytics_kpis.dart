import 'package:flutter/material.dart';
import '../services/scoring_service.dart';

class AnalyticsKPIs extends StatelessWidget {
  final AnalyticsResult analytics;
  final bool isHorizontal;

  const AnalyticsKPIs({
    super.key,
    required this.analytics,
    this.isHorizontal = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: isHorizontal 
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _buildItems(context, isDark),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _buildItems(context, isDark),
          ),
    );
  }

  List<Widget> _buildItems(BuildContext context, bool isDark) {
    final separator = isHorizontal 
        ? VerticalDivider(color: isDark ? Colors.white10 : Colors.black12, width: 20, indent: 4, endIndent: 4)
        : Divider(color: isDark ? Colors.white10 : Colors.black12, height: 16);

    return [
      _buildKPIItem(
        context,
        label: 'RECOVERY',
        value: '${(analytics.recoveryRate * 100).toStringAsFixed(0)}%',
        subtitle: 'RATE',
        color: _getRecoveryColor(analytics.recoveryRate),
      ),
      separator,
      _buildKPIItem(
        context,
        label: 'CURRENT',
        value: analytics.currentStreak.toString(),
        subtitle: 'STREAK',
        color: Theme.of(context).colorScheme.primary,
      ),
      separator,
      _buildKPIItem(
        context,
        label: 'LONGEST',
        value: analytics.longestStreak.toString(),
        subtitle: 'STREAK',
        color: Colors.orange[400]!,
      ),
    ];
  }

  Widget _buildKPIItem(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label $subtitle",
            maxLines: 1,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
        ],
      ),
    );
  }

  Color _getRecoveryColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF10B981); // Green
    if (rate >= 0.5) return Colors.orange[400]!;     // Orange
    return Colors.red[400]!;                         // Red
  }
}
