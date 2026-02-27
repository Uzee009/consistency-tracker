import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/scoring_service.dart';
import '../services/style_service.dart';
import '../main.dart';

class AnalyticsCarousel extends StatefulWidget {
  final List<MomentumPoint> momentumData;
  final List<VolumePoint> volumeData;
  final String title;
  final String? focusedTaskName;

  const AnalyticsCarousel({
    super.key,
    required this.momentumData,
    required this.volumeData,
    required this.title,
    this.focusedTaskName,
  });

  @override
  State<AnalyticsCarousel> createState() => _AnalyticsCarouselState();
}

class _AnalyticsCarouselState extends State<AnalyticsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;
    final containerBg = StyleService.getHeatmapBg(style, isDark);

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: StyleService.getDailyTaskBorder(style, isDark),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _currentPage == 0 
                          ? (widget.focusedTaskName != null ? 'HABIT MASTERY' : 'DISCIPLINE INDEX')
                          : 'OUTPUT VOLUME',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: _getHelpText(),
                      triggerMode: TooltipTriggerMode.tap,
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 10,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildNavButton(
                      context, 
                      Icons.chevron_left_rounded, 
                      _currentPage > 0 ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null
                    ),
                    const SizedBox(width: 4),
                    _buildNavButton(
                      context, 
                      Icons.chevron_right_rounded, 
                      _currentPage < 1 ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildMomentumChart(context, isDark),
                _buildVolumeChart(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHelpText() {
    if (_currentPage == 1) {
      return "The total count of temporary tasks completed during this period. Measures your raw output.";
    }
    if (widget.focusedTaskName != null) {
      return "How engrained this habit is. Increases with completion, decays with misses. 100% means total mastery.";
    }
    return "Percentage of daily habits successfully completed. Measures your overall adherence to your routines.";
  }

  Widget _buildNavButton(BuildContext context, IconData icon, VoidCallback? onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon, 
          size: 14, 
          color: onPressed != null 
              ? Theme.of(context).colorScheme.onSurface 
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
        ),
      ),
    );
  }

  Widget _buildMomentumChart(BuildContext context, bool isDark) {
    if (widget.momentumData.isEmpty) return _buildEmptyState('Not enough data');
    
    final accentColor = Theme.of(context).colorScheme.primary;
    final spots = widget.momentumData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 8),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => isDark ? Colors.grey[900]! : Colors.white,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  return LineTooltipItem(
                    '${(touchedSpot.y * 100).toStringAsFixed(0)}%',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: (spots.length / 4).clamp(1, 999).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < widget.momentumData.length) {
                    final date = widget.momentumData[index].date;
                    return _buildAxisLabel(
                      widget.title == '1Y' ? _getMonthName(date.month) : date.day.toString(),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 0.5,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return _buildAxisLabel('0%');
                  if (value == 0.5) return _buildAxisLabel('50%');
                  if (value == 1.0) return _buildAxisLabel('100%');
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: accentColor,
              barWidth: 2.0,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: 1.05,
        ),
      ),
    );
  }

  Widget _buildVolumeChart(BuildContext context, bool isDark) {
    if (widget.volumeData.isEmpty) return _buildEmptyState('No tasks completed');

    final accentColor = Colors.blue[400]!;
    final barGroups = widget.volumeData.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.count.toDouble(),
            color: accentColor,
            width: widget.volumeData.length > 30 ? 2 : 6,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(2),
            ),
          ),
        ],
      );
    }).toList();

    double maxY = widget.volumeData.map((e) => e.count).reduce((a, b) => a > b ? a : b).toDouble();
    if (maxY < 5) maxY = 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => isDark ? Colors.grey[900]! : Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  rod.toY.toInt().toString(),
                  TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: (widget.volumeData.length / 4).clamp(1, 999).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < widget.volumeData.length) {
                    final date = widget.volumeData[index].date;
                    return _buildAxisLabel(
                      widget.title == '1Y' ? _getMonthName(date.month) : date.day.toString(),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == maxY.floor() || value == (maxY / 2).floor()) {
                    return _buildAxisLabel(value.toInt().toString());
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          minY: 0,
          maxY: maxY * 1.1,
        ),
      ),
    );
  }

  Widget _buildAxisLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 7, 
          fontWeight: FontWeight.bold, 
          color: Colors.grey[500],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 8, color: Colors.grey),
      ),
    );
  }
}
