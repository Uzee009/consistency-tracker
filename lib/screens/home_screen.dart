// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:consistency_tracker_v1/screens/task_form_screen.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/scoring_service.dart';
import 'package:consistency_tracker_v1/models/task_model.dart';
import 'package:consistency_tracker_v1/models/day_record_model.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/screens/settings_screen.dart';
import 'package:consistency_tracker_v1/widgets/consistency_heatmap.dart';
import 'package:consistency_tracker_v1/widgets/add_task_bottom_sheet.dart';
import 'package:consistency_tracker_v1/widgets/task_section.dart';
import 'package:consistency_tracker_v1/widgets/streak_board.dart';
import 'package:consistency_tracker_v1/widgets/user_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> _todaysTasks = [];
  late DayRecord _todayRecord;
  User? _currentUser;
  int _cheatDaysUsed = 0;
  Map<DateTime, int> _heatmapData = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    final today = DateTime.now();
    final todayFormatted =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final yearMonth = "${today.year}-${today.month.toString().padLeft(2, '0')}";

    _todayRecord = await DatabaseService.instance.getDayRecord(todayFormatted) ??
        DayRecord(date: todayFormatted, completedTaskIds: [], skippedTaskIds: []);

    final users = await DatabaseService.instance.getAllUsers();
    if (users.isNotEmpty) {
      _currentUser = users.first;
    }

    _cheatDaysUsed = await DatabaseService.instance.getCheatDaysUsed(yearMonth);
    await _loadHeatmapData();

    final tasks = await DatabaseService.instance.getActiveTasksForDate(today);

    setState(() {
      _todaysTasks = tasks;
    });
  }

  Future<void> _loadHeatmapData() async {
    final records = await DatabaseService.instance.getDayRecords(limit: 366);
    setState(() {
      _heatmapData = ScoringService.mapRecordsToHeatmapData(records);
    });
  }

  void _toggleTaskCompletion(Task task, bool? isCompleted) async {
    List<int> updatedCompletedIds = List.from(_todayRecord.completedTaskIds);
    List<int> updatedSkippedIds = List.from(_todayRecord.skippedTaskIds);

    if (isCompleted == true) {
      updatedCompletedIds.add(task.id);
      updatedSkippedIds.remove(task.id);
    } else {
      updatedCompletedIds.remove(task.id);
    }

    _updateTodayRecord(completedIds: updatedCompletedIds, skippedIds: updatedSkippedIds);
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
    _initializeData();
  }

  void _editTask(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    await _refreshTodayRecord();
    _initializeData();
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
      _initializeData();
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
          _initializeData();
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consistency Tracker'),
        centerTitle: true,
        actions: [
          if (_currentUser != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  children: [
                    if (_todayRecord.completedTaskIds.isNotEmpty)
                      const Tooltip(
                        message: 'Cheat Day locked (tasks completed)',
                        child: Icon(Icons.lock_outline, size: 14, color: Colors.orange),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      'Tokens: ${(_currentUser!.monthlyCheatDays - _cheatDaysUsed).clamp(0, _currentUser!.monthlyCheatDays)}/${_currentUser!.monthlyCheatDays}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          UserMenu(
            currentUser: _currentUser,
            onSettingsReturn: _initializeData,
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
                    title: 'Daily Tasks',
                    type: TaskType.daily,
                    bgColor: const Color(0xFFE0F2FE), // Blue 100
                    borderColor: const Color(0xFF7DD3FC), // Blue 300
                    tasks: _todaysTasks,
                    dayRecord: _todayRecord,
                    onAddPressed: () => _showAddTaskSheet(type: TaskType.daily),
                    onCheatPressed: _onDeclareCheatDayPressed,
                    onToggleCompletion: _toggleTaskCompletion,
                    onToggleSkip: _toggleTaskSkip,
                    onEdit: _editTask,
                    onDelete: _deleteTask,
                  ),
                ),
                Expanded(
                  child: TaskSection(
                    title: 'Temporary Tasks',
                    type: TaskType.temporary,
                    bgColor: const Color(0xFFFEF9C3), // Yellow 100
                    borderColor: const Color(0xFFFDE047), // Yellow 300
                    tasks: _todaysTasks,
                    dayRecord: _todayRecord,
                    onAddPressed: () => _showAddTaskSheet(type: TaskType.temporary),
                    onToggleCompletion: _toggleTaskCompletion,
                    onToggleSkip: _toggleTaskSkip,
                    onEdit: _editTask,
                    onDelete: _deleteTask,
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
                  child: ConsistencyHeatmap(heatmapData: _heatmapData),
                ),
                const Expanded(
                  flex: 1,
                  child: StreakBoard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
