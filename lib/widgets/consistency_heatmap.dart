import 'package:flutter/material.dart';

class ConsistencyHeatmap extends StatefulWidget {
  final Map<DateTime, int> heatmapData;

  const ConsistencyHeatmap({
    super.key,
    required this.heatmapData,
  });

  @override
  State<ConsistencyHeatmap> createState() => _ConsistencyHeatmapState();
}

class _ConsistencyHeatmapState extends State<ConsistencyHeatmap> {
  final ScrollController _heatmapScrollController = ScrollController();
  bool _hasInitialScrolled = false;
  String _heatmapRange = '1Y';
  bool _isReportMode = false;
  DateTime _current1MDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentMonth();
    });
  }

  @override
  void didUpdateWidget(ConsistencyHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasInitialScrolled && widget.heatmapData.isNotEmpty) {
      _scrollToCurrentMonth();
    }
  }

  void _scrollToCurrentMonth() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!_heatmapScrollController.hasClients) return;

    if (_isReportMode) {
        _heatmapScrollController.jumpTo(_heatmapScrollController.position.maxScrollExtent);
    } else {
        _heatmapScrollController.jumpTo(0);
    }
    _hasInitialScrolled = true;
  }

  Widget _buildLegendItem(Color color, String text, {bool hasStar = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: hasStar ? const Center(child: Icon(Icons.star, size: 6, color: Colors.white)) : null,
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildLegendItem(Colors.orange[400]!, 'Cheat'),
                        _buildLegendItem(const Color(0xFF10B981), 'Star', hasStar: true),
                        _buildLegendItem(isDark ? const Color(0xFF27272A) : Colors.grey[100]!, 'None'),
                        const SizedBox(width: 2),
                        _buildLegendItem(const Color(0xFFD1FAE5), ''),
                        _buildLegendItem(const Color(0xFFA7F3D0), ''),
                        _buildLegendItem(const Color(0xFF6EE7B7), ''),
                        _buildLegendItem(const Color(0xFF34D399), ''),
                        _buildLegendItem(const Color(0xFF10B981), ''),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _isReportMode = !_isReportMode);
                      _scrollToCurrentMonth();
                    },
                    icon: Icon(
                      _isReportMode ? Icons.analytics : Icons.analytics_outlined,
                      color: _isReportMode ? Colors.deepPurple : Colors.grey[500],
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Toggle Report Mode',
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: ['1M', '3M', '6M', '1Y'].map((range) {
                        final isSelected = _heatmapRange == range;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _heatmapRange = range);
                            _scrollToCurrentMonth();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              range,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey[500],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHeatmapGrid(),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_heatmapRange == '1M') {
            return _build1MView(constraints);
          } else if (_heatmapRange == '3M') {
            return _build3MView(constraints);
          } else {
            return _buildStandardView(constraints, _heatmapRange == '6M' ? 6 : 12);
          }
        },
      ),
    );
  }

  Widget _build1MView(BoxConstraints constraints) {
    return _buildHorizontal1MView(constraints);
  }

  Widget _buildHorizontal1MView(BoxConstraints constraints) {
    final double availableWidth = constraints.maxWidth;
    final double availableHeight = constraints.maxHeight;
    final List<String> weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final List<String> monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    final DateTime targetDate = _current1MDate;
    final month = targetDate.month;
    final year = targetDate.year;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    
    int weeksInMonth = 0;
    DateTime tempDay = firstDayOfMonth;
    while (tempDay.weekday != DateTime.sunday) {
      tempDay = tempDay.subtract(const Duration(days: 1));
    }
    
    DateTime endCheck = lastDayOfMonth;
    while (tempDay.isBefore(endCheck.add(const Duration(days: 1))) || (tempDay.month == endCheck.month && tempDay.day == endCheck.day)) {
        weeksInMonth++;
        tempDay = tempDay.add(const Duration(days: 7));
    }
    
    final double headerHeight = 35.0;
    final double weekdayHeaderHeight = 20.0;
    final double contentHeight = availableHeight - headerHeight - weekdayHeaderHeight;
    
    final double cellWidth = (availableWidth - 2.0) / 7;
    final double cellHeight = ((contentHeight - 2.0) / weeksInMonth);
    
    final double totalGridWidth = cellWidth * 7;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    List<Widget> gridRows = [];
    DateTime iterDay = firstDayOfMonth;
    
    while (iterDay.weekday != DateTime.sunday) {
      iterDay = iterDay.subtract(const Duration(days: 1));
    }
    
    while (iterDay.isBefore(lastDayOfMonth.add(const Duration(days: 1))) || (iterDay.month == lastDayOfMonth.month && iterDay.day == lastDayOfMonth.day)) {
       List<Widget> weekRowCells = [];
       for(int d=0; d<7; d++) {
         DateTime dDate = iterDay.add(Duration(days: d));
         
         if (dDate.month != month || dDate.year != year) {
           weekRowCells.add(SizedBox(width: cellWidth, height: cellHeight));
         } else {
            final int intensity = widget.heatmapData[DateTime(dDate.year, dDate.month, dDate.day)] ?? 0;
            Color cellColor;
            if (intensity == -1) cellColor = Colors.orange[400]!;
            else if (intensity == -2) cellColor = const Color(0xFF10B981);
            else if (intensity == 1) cellColor = const Color(0xFFD1FAE5);
            else if (intensity == 2) cellColor = const Color(0xFFA7F3D0);
            else if (intensity == 3) cellColor = const Color(0xFF6EE7B7);
            else if (intensity == 4) cellColor = const Color(0xFF34D399);
            else if (intensity == 5) cellColor = const Color(0xFF10B981);
            else cellColor = isDark ? const Color(0xFF27272A) : Colors.grey[50]!;
            
            weekRowCells.add(
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Date: ${dDate.toIso8601String().split('T')[0]}')));
                },
                child: Container(
                  width: cellWidth,
                  height: cellHeight,
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                       child: intensity == -2
                        ? Icon(Icons.star, size: cellHeight * 0.3, color: Colors.white)
                        : Text('${dDate.day}', style: TextStyle(fontSize: (cellHeight*0.25).clamp(10, 16), color: (cellColor.computeLuminance() > 0.5) ? Colors.black87 : Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              )
            );
         }
       }
       gridRows.add(Row(mainAxisSize: MainAxisSize.min, children: weekRowCells));
       iterDay = iterDay.add(const Duration(days: 7));
       if (iterDay.year > year || (iterDay.year == year && iterDay.month > month)) break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: headerHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.grey, size: 20),
                  onPressed: () {
                    setState(() {
                      _current1MDate = DateTime(_current1MDate.year, _current1MDate.month - 1, 1);
                    });
                  },
                ),
                Text(
                  '${monthNames[month - 1]} $year',
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w600, 
                    color: Theme.of(context).colorScheme.onSurface
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  onPressed: () {
                    setState(() {
                      _current1MDate = DateTime(_current1MDate.year, _current1MDate.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            width: totalGridWidth,
            height: weekdayHeaderHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ...weekdays.map((day) => SizedBox(
                  width: cellWidth,
                  child: Center(child: Text(day, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500]))),
                )),
              ],
            ),
          ),
          Column(
            children: gridRows,
          ),
        ],
      ),
    );
  }

  Widget _build3MView(BoxConstraints constraints) {
    return _buildGenericView(constraints, 3, is1M: true, showCurrentMonthHighlight: true);
  }

  Widget _buildStandardView(BoxConstraints constraints, int months) {
    return _buildGenericView(constraints, months);
  }

  Widget _buildGenericView(BoxConstraints constraints, int monthsCount, {bool is1M = false, bool showCurrentMonthHighlight = true}) {
    final double availableWidth = constraints.maxWidth;
    final double availableHeight = constraints.maxHeight;
    final today = DateTime.now();
    final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final List<String> weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final double maxPossibleCellHeight = (availableHeight - 30) / 7.5;
    const double weekdayLabelWidth = 20.0;
    final double gridAvailableWidth = availableWidth - weekdayLabelWidth - 2.0;
    
    double totalUnits = 0; 
    List<int> monthWeeksCount = [];
    for (int i = 0; i < monthsCount; i++) {
      DateTime targetDate;
      if (_isReportMode) {
        targetDate = DateTime(today.year, today.month - (monthsCount - 1 - i), 1);
      } else {
        if (_heatmapRange == '1Y') {
          targetDate = DateTime(today.year, i + 1, 1);
        } else {
          targetDate = DateTime(today.year, today.month + i, 1);
        }
      }
      final firstDay = DateTime(targetDate.year, targetDate.month, 1);
      final lastDay = DateTime(targetDate.year, targetDate.month + 1, 0);
      
      int weeks = 0;
      DateTime tempDay = firstDay;
      while (tempDay.isBefore(lastDay.add(const Duration(days: 1)))) {
        weeks++;
        int startWeekday = tempDay.weekday % 7;
        tempDay = tempDay.add(Duration(days: 7 - startWeekday));
      }
      monthWeeksCount.add(weeks);
      totalUnits += weeks;
      if (i < monthsCount - 1) totalUnits += 0.2;
    }

    double unitWidth;
    bool shouldScroll = false;

    if (is1M) {
      unitWidth = gridAvailableWidth / totalUnits;
    } else {
      unitWidth = maxPossibleCellHeight; 
      if (unitWidth * totalUnits > gridAvailableWidth) {
        shouldScroll = true;
      }
    }

    final double dynamicTotalCellSize = unitWidth;
    final double dynamicTotalCellHeight = maxPossibleCellHeight;
    final double dynamicCellWidth = dynamicTotalCellSize * 0.9;
    final double dynamicCellHeight = dynamicTotalCellHeight * 0.85;
    
    final List<Widget> dynamicMonthWidgets = [];

    final Widget dynamicDayLabelColumn = SizedBox(
      width: weekdayLabelWidth,
      child: Column(
        children: weekdays.map((name) => Container(
          height: dynamicTotalCellHeight,
          alignment: Alignment.centerLeft,
          child: Text(name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey[500])),
        )).toList(),
      ),
    );

    for (int i = 0; i < monthsCount; i++) {
      DateTime targetDate;
      if (_isReportMode) {
        targetDate = DateTime(today.year, today.month - (monthsCount - 1 - i), 1);
      } else {
        if (_heatmapRange == '1Y') {
          targetDate = DateTime(today.year, i + 1, 1);
        } else {
          targetDate = DateTime(today.year, today.month + i, 1);
        }
      }
      final month = targetDate.month;
      final year = targetDate.year;
      final firstDayOfMonth = DateTime(year, month, 1);
      final lastDayOfMonth = DateTime(year, month + 1, 0);
      
      List<Widget> thisMonthWeeks = [];
      DateTime currentDay = firstDayOfMonth;

      while (currentDay.isBefore(lastDayOfMonth.add(const Duration(days: 1)))) {
        List<Widget> dayCellsInWeek = [];
        int startWeekday = currentDay.weekday % 7;

        if (currentDay.day == 1 && startWeekday != 0) {
          for (int j = 0; j < startWeekday; j++) {
            dayCellsInWeek.add(SizedBox(width: dynamicTotalCellSize, height: dynamicTotalCellHeight));
          }
        }

        while (dayCellsInWeek.length < 7 && currentDay.isBefore(lastDayOfMonth.add(const Duration(days: 1)))) {
          final day = currentDay;
          final int intensity = widget.heatmapData[DateTime(day.year, day.month, day.day)] ?? 0;
          Color cellColor;

          if (intensity == -1) cellColor = Colors.orange[400]!;
          else if (intensity == -2) cellColor = const Color(0xFF10B981);
          else if (intensity == 1) cellColor = const Color(0xFFD1FAE5);
          else if (intensity == 2) cellColor = const Color(0xFFA7F3D0);
          else if (intensity == 3) cellColor = const Color(0xFF6EE7B7);
          else if (intensity == 4) cellColor = const Color(0xFF34D399);
          else if (intensity == 5) cellColor = const Color(0xFF10B981);
          else cellColor = isDark ? const Color(0xFF27272A) : Colors.grey[50]!;

          dayCellsInWeek.add(
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Date: ${day.toIso8601String().split('T')[0]}')));
              },
              child: Container(
                width: dynamicCellWidth,
                height: dynamicCellHeight,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: intensity == -2
                      ? Icon(Icons.star, size: dynamicCellHeight * 0.4, color: Colors.white)
                      : Text(
                          day.day.toString(),
                          style: TextStyle(
                            fontSize: (dynamicCellHeight * 0.3).clamp(7, 10),
                            fontWeight: FontWeight.w500,
                            color: (cellColor.computeLuminance() > 0.5) ? Colors.black87 : Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          );
          currentDay = currentDay.add(const Duration(days: 1));
        }

        while (dayCellsInWeek.length < 7) {
          dayCellsInWeek.add(SizedBox(width: dynamicTotalCellSize, height: dynamicTotalCellHeight));
        }

        thisMonthWeeks.add(Column(mainAxisSize: MainAxisSize.min, children: dayCellsInWeek));
      }

      final bool isCurrentMonth = month == today.month && year == today.year;
      final bool showHighlight = isCurrentMonth && showCurrentMonthHighlight;
      
      String monthLabel = monthNames[month - 1];
      if (year != today.year) monthLabel += " '${year.toString().substring(2)}";

      dynamicMonthWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 18,
              child: Text(monthLabel,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500])),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: showHighlight
                  ? BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Row(mainAxisSize: MainAxisSize.min, children: thisMonthWeeks),
            ),
          ],
        ),
      );
      
      if (i < monthsCount - 1) {
        dynamicMonthWidgets.add(SizedBox(width: dynamicTotalCellSize * 0.2));
      }
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18.0), 
            child: dynamicDayLabelColumn,
          ),
          Flexible(
            child: SingleChildScrollView(
              controller: _heatmapScrollController,
              scrollDirection: Axis.horizontal,
              physics: shouldScroll ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
              child: Container(
                width: shouldScroll ? null : availableWidth - weekdayLabelWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: dynamicMonthWidgets,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
