// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/screens/task_form_screen.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/scoring_service.dart';
import 'package:consistency_tracker_v1/models/task_model.dart';
import 'package:consistency_tracker_v1/models/day_record_model.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/widgets/consistency_heatmap.dart';
import 'package:consistency_tracker_v1/widgets/add_task_bottom_sheet.dart';
import 'package:consistency_tracker_v1/widgets/task_section.dart';
import 'package:consistency_tracker_v1/widgets/analytics_kpis.dart';
import 'package:consistency_tracker_v1/widgets/user_menu.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> _todaysTasks = [];
  DayRecord _todayRecord = DayRecord(
    date: DateTime.now().toIso8601String().split('T')[0],
    completedTaskIds: [],
  );
  User? _currentUser;
  int _cheatDaysUsed = 0;
  Map<DateTime, int> _heatmapData = {};
  DateTime _selectedDate = DateTime.now();
  Task? _focusedTask;
  AnalyticsResult _analytics = AnalyticsResult.empty();

  @override
  void initState() {
    super.initState();
    _initializeData(_selectedDate);
  }

  void _initializeData(DateTime date) async {
    final dateFormatted =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final yearMonth = "${date.year}-${date.month.toString().padLeft(2, '0')}";

    final record = await DatabaseService.instance.getDayRecord(dateFormatted) ??
        DayRecord(date: dateFormatted, completedTaskIds: [], skippedTaskIds: []);

    final users = await DatabaseService.instance.getAllUsers();
    User? currentUser;
    if (users.isNotEmpty) {
      currentUser = users.first;
    }

    final cheatUsed = await DatabaseService.instance.getCheatDaysUsed(yearMonth);
    
    // Fetch records for analytics and heatmap
    final allRecords = await DatabaseService.instance.getDayRecords(limit: 366);
    
    // Determine Heatmap Data and Analytics: Global vs Focused Task
    Map<DateTime, int> heatmapData;
    AnalyticsResult analytics;

    if (_focusedTask != null) {
      final taskHistory = await DatabaseService.instance.getTaskHistory(_focusedTask!.id);
      heatmapData = ScoringService.mapTaskRecordsToHeatmapData(taskHistory);
      analytics = ScoringService.calculateAnalytics(taskHistory, taskId: _focusedTask!.id);
    } else {
      heatmapData = ScoringService.mapRecordsToHeatmapData(allRecords);
      analytics = ScoringService.calculateAnalytics(allRecords);
    }

    final tasks = await DatabaseService.instance.getActiveTasksForDate(date);

    if (mounted) {
      setState(() {
        _selectedDate = date;
        _todayRecord = record;
        _currentUser = currentUser;
        _cheatDaysUsed = cheatUsed;
        _heatmapData = heatmapData;
        _todaysTasks = tasks;
        _analytics = analytics;
      });
    }
  }

  void _onTaskFocusRequested(Task task) {
    setState(() {
      _focusedTask = task;
    });
    _initializeData(_selectedDate);
  }

  void _onClearFocus() {
    setState(() {
      _focusedTask = null;
    });
    _initializeData(_selectedDate);
  }

  void _onDateSelected(DateTime date) {
    if (date.isAfter(DateTime.now())) return; // Prevent selecting future dates
    _initializeData(date);
  }

  void _toggleTaskCompletion(Task task, bool? isCompleted) async {
    bool cheatUsed = _todayRecord.cheatUsed;

    if (cheatUsed && isCompleted == true) {
      final bool? cancelCheat = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Cheat Day?'),
          content: const Text('You are starting to work! Would you like to cancel your Cheat Day and get your token back?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Cheat'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel Cheat & Refund', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );

      if (cancelCheat == true) {
        final today = DateTime.now();
        final yearMonth = "${today.year}-${today.month.toString().padLeft(2, '0')}";
        await DatabaseService.instance.decrementCheatDaysUsed(yearMonth);
        cheatUsed = false; // Update local variable to prevent further popups in this call
        _updateTodayRecord(cheatUsed: false);
      }
    }

    List<int> updatedCompletedIds = List.from(_todayRecord.completedTaskIds);
    List<int> updatedSkippedIds = List.from(_todayRecord.skippedTaskIds);

    if (isCompleted == true) {
      updatedCompletedIds.add(task.id);
      updatedSkippedIds.remove(task.id);
    } else {
      updatedCompletedIds.remove(task.id);
    }

    _updateTodayRecord(
      completedIds: updatedCompletedIds, 
      skippedIds: updatedSkippedIds,
      cheatUsed: cheatUsed, // Ensure we pass the updated state
    );
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

    _updateTodayRecord(completedIds: updatedCompletedIds, skippedIds: updatedSkippedIds);
  }

  void _updateTodayRecord({
    List<int>? completedIds,
    List<int>? skippedIds,
    bool? cheatUsed,
  }) async {
    final currentRecord = DayRecord(
      date: _todayRecord.date,
      completedTaskIds: completedIds ?? _todayRecord.completedTaskIds,
      skippedTaskIds: skippedIds ?? _todayRecord.skippedTaskIds,
      cheatUsed: cheatUsed ?? _todayRecord.cheatUsed,
    );

    final allActiveTasksForToday = await DatabaseService.instance.getActiveTasksForDate(DateTime.parse(currentRecord.date));

    final scoreResult = ScoringService.calculateDayScore(
      allTasks: allActiveTasksForToday,
      dayRecord: currentRecord,
    );

    _todayRecord = DayRecord(
      date: currentRecord.date,
      completedTaskIds: currentRecord.completedTaskIds,
      skippedTaskIds: currentRecord.skippedTaskIds,
      cheatUsed: currentRecord.cheatUsed,
      completionScore: scoreResult.completionScore,
      visualState: scoreResult.visualState,
    );

    await DatabaseService.instance.createOrUpdateDayRecord(_todayRecord);
    _initializeData(_selectedDate);
  }

  void _editTask(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    await _refreshTodayRecord();
    _initializeData(_selectedDate);
  }

  void _deleteTask(Task task) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteTask(task.id);
      await _refreshTodayRecord();
      _initializeData(_selectedDate);
    }
  }

  Future<void> _refreshTodayRecord() async {
    final allActiveTasksForToday = await DatabaseService.instance.getActiveTasksForDate(DateTime.parse(_todayRecord.date));

    final scoreResult = ScoringService.calculateDayScore(
      allTasks: allActiveTasksForToday,
      dayRecord: _todayRecord,
    );

    _todayRecord = DayRecord(
      date: _todayRecord.date,
      completedTaskIds: _todayRecord.completedTaskIds,
      skippedTaskIds: _todayRecord.skippedTaskIds,
      cheatUsed: _todayRecord.cheatUsed,
      completionScore: scoreResult.completionScore,
      visualState: scoreResult.visualState,
    );

    await DatabaseService.instance.createOrUpdateDayRecord(_todayRecord);
  }

  void _onDeclareCheatDayPressed() async {
    if (_currentUser == null) return;
    
    if (_todayRecord.completedTaskIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot declare a Cheat Day if you have already completed tasks!')),
      );
      return;
    }

    if (_todayRecord.cheatUsed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Today is already a Cheat Day!')));
      return;
    }

    final tokensLeft = _currentUser!.monthlyCheatDays - _cheatDaysUsed;
    if (tokensLeft <= 0) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('No Cheat Days Left'),
                content: const Text('You have used all your cheat days for this month.'),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
              ));
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Declare Cheat Day?'),
        content: Text('This will use one of your $tokensLeft remaining Cheat Day tokens. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );

    if (confirm == true) {
      final today = DateTime.now();
      final yearMonth = "${today.year}-${today.month.toString().padLeft(2, '0')}";
      await DatabaseService.instance.incrementCheatDaysUsed(yearMonth);
      _updateTodayRecord(cheatUsed: true);
    }
  }

  void _showAddTaskSheet({required TaskType type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTaskBottomSheet(
        type: type,
        onTaskAdded: () async {
          await _refreshTodayRecord();
          _initializeData(_selectedDate);
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisualStyle>(
      valueListenable: styleNotifier,
      builder: (context, style, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          appBar: AppBar(
            title: const Text('CONSISTENCY'),
            centerTitle: true,
            actions: [
              if (_currentUser != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      children: [
                        if (_todayRecord.completedTaskIds.isNotEmpty)
                          Tooltip(
                            message: 'Cheat Day locked (tasks completed)',
                            child: Icon(Icons.lock_outline, size: 12, color: Colors.orange.withValues(alpha: 0.6)),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          'Tokens: ${(_currentUser!.monthlyCheatDays - _cheatDaysUsed).clamp(0, _currentUser!.monthlyCheatDays)}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              UserMenu(
                currentUser: _currentUser,
                onSettingsReturn: () => _initializeData(_selectedDate),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                flex: 1,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TaskSection(
                        title: 'DAILY',
                        type: TaskType.daily,
                        tasks: _todaysTasks,
                        dayRecord: _todayRecord,
                        onAddPressed: () => _showAddTaskSheet(type: TaskType.daily),
                        onCheatPressed: _onDeclareCheatDayPressed,
                        onToggleCompletion: _toggleTaskCompletion,
                        onToggleSkip: _toggleTaskSkip,
                        onEdit: _editTask,
                        onDelete: _deleteTask,
                        onTaskFocusRequested: _onTaskFocusRequested,
                      ),
                    ),
                    Expanded(
                      child: TaskSection(
                        title: 'TEMPORARY',
                        type: TaskType.temporary,
                        tasks: _todaysTasks,
                        dayRecord: _todayRecord,
                        onAddPressed: () => _showAddTaskSheet(type: TaskType.temporary),
                        onToggleCompletion: _toggleTaskCompletion,
                        onToggleSkip: _toggleTaskSkip,
                        onEdit: _editTask,
                        onDelete: _deleteTask,
                        onTaskFocusRequested: _onTaskFocusRequested,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ConsistencyHeatmap(
                        heatmapData: _heatmapData,
                        selectedDate: _selectedDate,
                        onDateSelected: _onDateSelected,
                        focusedTaskName: _focusedTask?.name,
                        onClearFocus: _onClearFocus,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 2, // 20% of this section
                            child: AnalyticsKPIs(analytics: _analytics, isHorizontal: true),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: 8, // 80% of this section
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'GRAPH CAROUSEL PLACEHOLDER',
                                  style: TextStyle(fontSize: 8, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
