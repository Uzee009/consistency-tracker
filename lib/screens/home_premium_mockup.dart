// lib/screens/home_premium_mockup.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/screens/task_form_screen.dart';
import 'package:consistency_tracker_v1/screens/analytics_explorer_screen.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/scoring_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/models/task_model.dart';
import 'package:consistency_tracker_v1/models/day_record_model.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/widgets/task_section.dart';
import 'package:consistency_tracker_v1/widgets/add_task_bottom_sheet.dart';
import 'package:consistency_tracker_v1/widgets/pomodoro_timer.dart';
import 'package:consistency_tracker_v1/widgets/user_menu.dart';
import 'package:consistency_tracker_v1/main.dart';

class HomePremiumMockup extends StatefulWidget {
  const HomePremiumMockup({super.key});

  @override
  State<HomePremiumMockup> createState() => _HomePremiumMockupState();
}

class _HomePremiumMockupState extends State<HomePremiumMockup> {
  List<Task> _todaysTasks = [];
  DayRecord _todayRecord = DayRecord(date: '', completedTaskIds: [], skippedTaskIds: []);
  User? _currentUser;
  int _cheatDaysUsed = 0;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<DateTime, int> _recentHistoryData = {};

  @override
  void initState() {
    super.initState();
    _initializeData(_selectedDate);
  }

  void _initializeData(DateTime date) async {
    final dateFormatted = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final yearMonth = "${date.year}-${date.month.toString().padLeft(2, '0')}";

    final record = await DatabaseService.instance.getDayRecord(dateFormatted) ??
        DayRecord(date: dateFormatted, completedTaskIds: [], skippedTaskIds: []);

    final users = await DatabaseService.instance.getAllUsers();
    User? currentUser;
    if (users.isNotEmpty) currentUser = users.first;

    final cheatUsed = await DatabaseService.instance.getCheatDaysUsed(yearMonth);
    final tasks = await DatabaseService.instance.getActiveTasksForDate(date);
    final allRecords = await DatabaseService.instance.getDayRecords(limit: 14);
    final historyData = ScoringService.mapRecordsToHeatmapData(allRecords);

    if (mounted) {
      setState(() {
        _selectedDate = date;
        _todayRecord = record;
        _currentUser = currentUser;
        _cheatDaysUsed = cheatUsed;
        _todaysTasks = tasks;
        _recentHistoryData = historyData;
        _isLoading = false;
      });
    }
  }

  void _onDateSelected(DateTime date) => _initializeData(date);

  void _toggleTaskCompletion(Task task, bool? completed) async {
    List<int> updatedCompletedIds = List.from(_todayRecord.completedTaskIds);
    List<int> updatedSkippedIds = List.from(_todayRecord.skippedTaskIds);
    if (completed == true) {
      updatedCompletedIds.add(task.id);
      updatedSkippedIds.remove(task.id);
    } else {
      updatedCompletedIds.remove(task.id);
    }
    await _updateDayRecordInDb(updatedCompletedIds, updatedSkippedIds);
    _initializeData(_selectedDate);
  }

  void _toggleTaskSkip(Task task) async {
    List<int> updatedCompletedIds = List.from(_todayRecord.completedTaskIds);
    List<int> updatedSkippedIds = List.from(_todayRecord.skippedTaskIds);
    if (updatedSkippedIds.contains(task.id)) {
      updatedSkippedIds.remove(task.id);
    } else {
      updatedSkippedIds.add(task.id);
      updatedCompletedIds.remove(task.id);
    }
    await _updateDayRecordInDb(updatedCompletedIds, updatedSkippedIds);
    _initializeData(_selectedDate);
  }

  Future<void> _updateDayRecordInDb(List<int> completedIds, List<int> skippedIds) async {
    final activeTasks = await DatabaseService.instance.getActiveTasksForDate(_selectedDate);
    final scoreResult = ScoringService.calculateDayScore(
      allTasks: activeTasks, 
      dayRecord: DayRecord(date: _todayRecord.date, completedTaskIds: completedIds, skippedTaskIds: skippedIds, cheatUsed: _todayRecord.cheatUsed),
    );
    final updatedRecord = DayRecord(
      date: _todayRecord.date, completedTaskIds: completedIds, skippedTaskIds: skippedIds,
      cheatUsed: _todayRecord.cheatUsed, completionScore: scoreResult.completionScore,
      visualState: _todayRecord.cheatUsed ? VisualState.cheat : scoreResult.visualState,
    );
    await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
  }

  void _showAddTaskSheet({required TaskType type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTaskBottomSheet(
        type: type,
        onTaskAdded: () => _initializeData(_selectedDate),
      ),
    );
  }

  void _onDeclareCheatDayPressed() async {
    if (_currentUser == null || _todayRecord.completedTaskIds.isNotEmpty) return;
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Use Cheat Day?'),
      content: const Text('Use one token to preserve your streak for today?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use Token', style: TextStyle(color: Colors.orange))),
      ],
    ));
    if (confirm == true) {
      final updatedRecord = DayRecord(date: _todayRecord.date, completedTaskIds: _todayRecord.completedTaskIds, skippedTaskIds: _todayRecord.skippedTaskIds, cheatUsed: true, completionScore: _todayRecord.completionScore, visualState: VisualState.cheat);
      await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
      _initializeData(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisualStyle>(
      valueListenable: styleNotifier,
      builder: (context, style, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          body: Column(
            children: [
              _buildGlobalHeader(context),
              _buildTimelineStrip(context),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(flex: 3, child: Container(
                          margin: const EdgeInsets.all(16),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: style == VisualStyle.vibrant ? Colors.transparent : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: StyleService.getDailyTaskBorder(style, isDark), width: 1),
                          ),
                          child: _buildTaskWorkspace(context),
                        )),
                        Expanded(flex: 2, child: Container(
                          margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: StyleService.getHeatmapBg(style, isDark),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: StyleService.getDailyTaskBorder(style, isDark), width: 1),
                          ),
                          child: const PomodoroTimer(),
                        )),
                      ],
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark ? const Color(0xFF09090B) : Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopTab(context, 'Dashboard', Icons.dashboard_rounded, true, () {}),
                _buildTopTab(context, 'Explorer', Icons.explore_rounded, false, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsExplorerScreen()));
                }),
                _buildTopTab(context, 'Settings', Icons.settings_rounded, false, () {}),
              ],
            ),
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${now.day}/${now.month}/${now.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text('Tokens: ${(_currentUser?.monthlyCheatDays ?? 0) - _cheatDaysUsed}', style: TextStyle(fontSize: 11, color: Colors.orange[400], fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 16),
          UserMenu(currentUser: _currentUser, onSettingsReturn: () => _initializeData(_selectedDate)),
        ],
      ),
    );
  }

  Widget _buildTopTab(BuildContext context, String label, IconData icon, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[500]),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStrip(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark ? const Color(0xFF09090B).withValues(alpha: 0.5) : Colors.grey[50],
      child: Row(
        children: [
          const Text('HISTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey)),
          const SizedBox(width: 20),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              itemBuilder: (context, index) {
                final date = today.subtract(Duration(days: 9 - index));
                final dateOnly = DateTime(date.year, date.month, date.day);
                final scoreIntensity = _recentHistoryData[dateOnly] ?? 0;
                final isSelected = _selectedDate.day == date.day && _selectedDate.month == date.month;
                Color color = StyleService.getHeatmapEmptyCell(VisualStyle.minimalist, isDark);
                if (scoreIntensity == -1) color = Colors.orange[400]!;
                else if (scoreIntensity == -2) color = const Color(0xFF10B981);
                else if (scoreIntensity > 0) color = const Color(0xFF10B981).withValues(alpha: 0.2 * scoreIntensity);
                return GestureDetector(
                  onTap: () => _onDateSelected(dateOnly),
                  child: Container(
                    width: 45,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(['S','M','T','W','T','F','S'][date.weekday % 7], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70)),
                          Text('${date.day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskWorkspace(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Text('DAILY MISSION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const Spacer(),
              if (_selectedDate.day != DateTime.now().day)
                TextButton.icon(onPressed: () => _onDateSelected(DateTime.now()), icon: const Icon(Icons.today, size: 14), label: const Text('Today', style: TextStyle(fontSize: 11))),
            ],
          ),
        ),
        Expanded(child: DefaultTabController(length: 2, child: Column(children: [
          const TabBar(tabs: [Tab(text: 'Habits'), Tab(text: 'Temp')], labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), dividerColor: Colors.transparent),
          Expanded(child: TabBarView(children: [
            TaskSection(title: 'DAILY', type: TaskType.daily, tasks: _todaysTasks, dayRecord: _todayRecord, onAddPressed: () {}, onCheatPressed: null, onToggleCompletion: _toggleTaskCompletion, onToggleSkip: _toggleTaskSkip, onEdit: (t) {}, onDelete: (t) {}, onTaskFocusRequested: (_) {}, showTitle: false, isEmbedded: true),
            TaskSection(title: 'TEMP', type: TaskType.temporary, tasks: _todaysTasks, dayRecord: _todayRecord, onAddPressed: () {}, onCheatPressed: null, onToggleCompletion: _toggleTaskCompletion, onToggleSkip: _toggleTaskSkip, onEdit: (t) {}, onDelete: (t) {}, onTaskFocusRequested: (_) {}, showTitle: false, isEmbedded: true),
          ]))
        ]))),
        _buildActionFooter(context),
      ],
    );
  }

  Widget _buildActionFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)))),
      child: Row(
        children: [
          ElevatedButton.icon(onPressed: () => _showAddTaskSheet(type: TaskType.daily), icon: const Icon(Icons.add, size: 16), label: const Text('Add Habit')),
          const SizedBox(width: 12),
          OutlinedButton.icon(onPressed: _onDeclareCheatDayPressed, icon: const Icon(Icons.celebration, size: 16), label: const Text('Cheat Day')),
        ],
      ),
    );
  }
}
