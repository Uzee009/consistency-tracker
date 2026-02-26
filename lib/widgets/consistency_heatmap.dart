import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/style_service.dart';
import '../main.dart';

class ConsistencyHeatmap extends StatefulWidget {
  final Map<DateTime, int> heatmapData;
  final Function(DateTime)? onDateSelected;
  final DateTime? selectedDate;
  final String? focusedTaskName;
  final VoidCallback? onClearFocus;

  const ConsistencyHeatmap({
    super.key,
    required this.heatmapData,
    this.onDateSelected,
    this.selectedDate,
    this.focusedTaskName,
    this.onClearFocus,
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
        Text(text, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;
    final containerBg = StyleService.getHeatmapBg(style, isDark);
    final borderColor = StyleService.getDailyTaskBorder(style, isDark);

    final today = DateTime.now();
    final bool isViewingToday = widget.selectedDate == null || 
        (widget.selectedDate!.year == today.year && 
         widget.selectedDate!.month == today.month && 
         widget.selectedDate!.day == today.day);

    final List<String> monthNamesShort = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final String dateString = widget.selectedDate == null ? "" : "${widget.selectedDate!.day} ${monthNamesShort[widget.selectedDate!.month - 1]} ${widget.selectedDate!.year}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                        if (widget.focusedTaskName == null) ...[
                          _buildLegendItem(Colors.orange[400]!, 'Cheat'),
                          _buildLegendItem(const Color(0xFF10B981), 'Star', hasStar: true),
                          _buildLegendItem(StyleService.getHeatmapEmptyCell(style, isDark), 'None'),
                          const SizedBox(width: 2),
                          _buildLegendItem(const Color(0xFFD1FAE5), ''),
                          _buildLegendItem(const Color(0xFFA7F3D0), ''),
                          _buildLegendItem(const Color(0xFF6EE7B7), ''),
                          _buildLegendItem(const Color(0xFF34D399), ''),
                          _buildLegendItem(const Color(0xFF10B981), ''),
                        ] else ...[
                          _buildLegendItem(StyleService.getHeatmapEmptyCell(style, isDark), 'Missed'),
                          _buildLegendItem(const Color(0xFF10B981), 'Achieved'),
                        ],
                      ],
                    ),
                    if (widget.focusedTaskName != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.focusedTaskName!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: widget.onClearFocus,
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!isViewingToday) ...[
                      const SizedBox(width: 4),
                      Container(
                        height: 20,
                        width: 1,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateString,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          if (widget.onDateSelected != null) {
                            widget.onDateSelected!(DateTime.now());
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.today_rounded, 
                                size: 12, 
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                      color: isDark ? Colors.white : Colors.black,
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
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              range,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
          const SizedBox(height: 16),
          Expanded(child: _buildHeatmapGrid()),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_heatmapRange == '1M') {
          return _build1MView(constraints);
        } else if (_heatmapRange == '3M') {
          return _buildGenericView(constraints, 3, is1M: true, showCurrentMonthHighlight: true);
        } else {
          return _buildGenericView(constraints, _heatmapRange == '6M' ? 6 : 12);
        }
      },
    );
  }

  Widget _build1MView(BoxConstraints constraints) {
    final double availableWidth = constraints.maxWidth;
    final double availableHeight = constraints.maxHeight;
    final List<String> weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
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
    
    final double headerHeight = 40.0;
    final double weekdayHeaderHeight = 25.0;
    final double contentHeight = availableHeight - headerHeight - weekdayHeaderHeight;
    
    final double cellWidth = (availableWidth - 2.0) / 7;
    final double cellHeight = ((contentHeight - 2.0) / weeksInMonth);
    
    final double totalGridWidth = cellWidth * 7;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;
    
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
            else cellColor = StyleService.getHeatmapEmptyCell(style, isDark);
            
            final bool isSelected = widget.selectedDate != null && 
                dDate.year == widget.selectedDate!.year && 
                dDate.month == widget.selectedDate!.month && 
                dDate.day == widget.selectedDate!.day;
            
            weekRowCells.add(
              GestureDetector(
                onTap: () {
                  if (widget.onDateSelected != null) {
                    widget.onDateSelected!(dDate);
                  }
                },
                child: Container(
                  width: cellWidth,
                  height: cellHeight,
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected 
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Center(
                       child: intensity == -2
                        ? Icon(Icons.star, size: cellHeight * 0.35, color: Colors.white)
                        : Text('${dDate.day}', style: TextStyle(fontSize: (cellHeight*0.3).clamp(12, 18), color: (cellColor.computeLuminance() > 0.5) ? Colors.black87 : Colors.white, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500)),
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
                  icon: const Icon(Icons.chevron_left, color: Colors.grey, size: 22),
                  onPressed: () {
                    setState(() {
                      _current1MDate = DateTime(_current1MDate.year, _current1MDate.month - 1, 1);
                    });
                  },
                ),
                Text(
                  '${monthNames[month - 1]} $year',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurface
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
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
                  child: Center(child: Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5))),
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

  Widget _buildGenericView(BoxConstraints constraints, int monthsCount, {bool is1M = false, bool showCurrentMonthHighlight = true}) {
    final double availableWidth = constraints.maxWidth;
    final double availableHeight = constraints.maxHeight;
    final today = DateTime.now();
    final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final List<String> weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;
    
    const double verticalPadding = 6.0;
    const double monthLabelHeight = 18.0;
    const double horizontalPaddingPerMonth = 16.0; 
    final double reservedHeight = 55.0; 
    final double dynamicTotalCellHeight = (availableHeight - reservedHeight) / 7.0;
    
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

    final double staticWidthTotal = (monthsCount * horizontalPaddingPerMonth) + 30.0;
    final double availableWidthForCells = availableWidth - staticWidthTotal;

    if (is1M) {
      unitWidth = availableWidthForCells / totalUnits;
    } else {
      unitWidth = dynamicTotalCellHeight; 
      if (unitWidth * totalUnits > availableWidthForCells) {
        shouldScroll = true;
      }
    }

    final double dynamicTotalCellSize = unitWidth;
    
    final List<Widget> dynamicMonthWidgets = [];

    final Widget dynamicDayLabelColumn = SizedBox(
      width: 20,
      child: Column(
        children: weekdays.map((name) => SizedBox(
          height: dynamicTotalCellHeight,
          child: Center(child: Text(name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[500]))),
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
          else cellColor = StyleService.getHeatmapEmptyCell(style, isDark);

          final bool isSelected = widget.selectedDate != null && 
              day.year == widget.selectedDate!.year && 
              day.month == widget.selectedDate!.month && 
              day.day == widget.selectedDate!.day;

          dayCellsInWeek.add(
            GestureDetector(
              onTap: () {
                if (widget.onDateSelected != null) {
                  widget.onDateSelected!(day);
                }
              },
              child: SizedBox(
                width: dynamicTotalCellSize,
                height: dynamicTotalCellHeight,
                child: Padding(
                  padding: const EdgeInsets.all(1.2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(3),
                      border: isSelected 
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: intensity == -2
                          ? Icon(Icons.star, size: dynamicTotalCellHeight * 0.4, color: Colors.white)
                          : Text(
                              day.day.toString(),
                              style: TextStyle(
                                fontSize: (dynamicTotalCellHeight * 0.35).clamp(8, 12),
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                                color: (cellColor.computeLuminance() > 0.5) ? Colors.black87 : Colors.white,
                              ),
                            ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: showHighlight ? StyleService.getHeatmapHighlight(style, isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showHighlight 
                ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
                : Colors.transparent, 
              width: 1,
            ),
            boxShadow: showHighlight ? [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: monthLabelHeight,
                child: Text(monthLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isCurrentMonth ? Theme.of(context).colorScheme.onSurface : Colors.grey[600])),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: thisMonthWeeks),
            ],
          ),
        ),
      );
      
      if (i < monthsCount - 1) {
        dynamicMonthWidgets.add(SizedBox(width: dynamicTotalCellSize * 0.1));
      }
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: verticalPadding + monthLabelHeight + 2.0), 
            child: dynamicDayLabelColumn,
          ),
          Flexible(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: SingleChildScrollView(
                controller: _heatmapScrollController,
                scrollDirection: Axis.horizontal,
                physics: shouldScroll ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                child: Container(
                  width: shouldScroll ? null : availableWidth - 25.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: dynamicMonthWidgets,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
