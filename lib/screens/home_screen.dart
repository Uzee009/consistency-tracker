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
import 'package:consistency_tracker_v1/widgets/analytics_carousel.dart';
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
  String _heatmapRange = '1M';
  List<MomentumPoint> _momentumData = [];
  List<VolumePoint> _volumeData = [];

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
    
    // Build a map of Task IDs to types for global analytics
    final allTasks = await DatabaseService.instance.getAllTasks();
    final taskTypeMap = {for (var t in allTasks) t.id: t.type};

    // Determine Heatmap Data and Analytics: Global vs Focused Task
    Map<DateTime, int> heatmapData;
    AnalyticsResult analytics;

    if (_focusedTask != null) {
      heatmapData = ScoringService.mapTaskRecordsToHeatmapData(allRecords, _focusedTask!.id);
      analytics = ScoringService.calculateAnalytics(allRecords, taskId: _focusedTask!.id);
    } else {
      heatmapData = ScoringService.mapRecordsToHeatmapData(allRecords);
      analytics = ScoringService.calculateAnalytics(allRecords, taskTypeMap: taskTypeMap);
    }

    // Graph Data
    final momentumData = ScoringService.calculateMomentumData(
      allRecords, 
      _heatmapRange, 
      taskId: _focusedTask?.id
    );
    final volumeData = ScoringService.calculateVolumeData(
      allRecords, 
      _heatmapRange, 
      taskTypeMap
    );

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
        _momentumData = momentumData;
        _volumeData = volumeData;
      });
    }
  }

  Widget _buildHeaderIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
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
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DefaultTabController(
                          length: 2,
                          child: Builder(
                            builder: (context) {
                              return Column(
                                children: [
                                  // Header: Tabs + Buttons
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                                    child: Row(
                                      children: [
                                        // ShadCN-style Tabs (Reduced width ~20%)
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            height: 32,
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: TabBar(
                                              tabs: const [
                                                Tab(text: 'Daily'),
                                                Tab(text: 'Temp'),
                                              ],
                                              labelStyle: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Inter', 
                                              ),
                                              unselectedLabelStyle: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              indicatorSize: TabBarIndicatorSize.tab,
                                              indicator: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surface,
                                                borderRadius: BorderRadius.circular(6),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.05),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              dividerColor: Colors.transparent,
                                              labelColor: Theme.of(context).colorScheme.onSurface,
                                              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                              splashFactory: NoSplash.splashFactory,
                                              overlayColor: WidgetStateProperty.all(Colors.transparent),
                                            ),
                                          ),
                                        ),
                                        const Spacer(flex: 6),
                                        // Action Buttons
                                        Row(
                                          children: [
                                            if (_todayRecord.completedTaskIds.isNotEmpty)
                                              Tooltip(
                                                message: 'Cheat Day locked',
                                                child: Icon(Icons.lock_outline, size: 14, color: Colors.orange.withValues(alpha: 0.5)),
                                              )
                                            else
                                              _buildHeaderIconButton(
                                                context,
                                                icon: Icons.celebration_outlined,
                                                tooltip: 'Declare Cheat Day',
                                                onPressed: _onDeclareCheatDayPressed,
                                                color: Colors.orange[400]!,
                                              ),
                                            const SizedBox(width: 8),
                                            _buildHeaderIconButton(
                                              context,
                                              icon: Icons.add_rounded,
                                              tooltip: 'Add Task',
                                              onPressed: () {
                                                final tabController = DefaultTabController.of(context);
                                                _showAddTaskSheet(
                                                  type: tabController.index == 0 ? TaskType.daily : TaskType.temporary
                                                );
                                              },
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  // Task Lists
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        TaskSection(
                                          title: 'DAILY',
                                          type: TaskType.daily,
                                          tasks: _todaysTasks,
                                          dayRecord: _todayRecord,
                                          onAddPressed: () {}, 
                                          onCheatPressed: null, 
                                          onToggleCompletion: _toggleTaskCompletion,
                                          onToggleSkip: _toggleTaskSkip,
                                          onEdit: _editTask,
                                          onDelete: _deleteTask,
                                          onTaskFocusRequested: _onTaskFocusRequested,
                                          showTitle: false,
                                          isEmbedded: true,
                                        ),
                                        TaskSection(
                                          title: 'TEMPORARY',
                                          type: TaskType.temporary,
                                          tasks: _todaysTasks,
                                          dayRecord: _todayRecord,
                                          onAddPressed: () {}, 
                                          onCheatPressed: null, 
                                          onToggleCompletion: _toggleTaskCompletion,
                                          onToggleSkip: _toggleTaskSkip,
                                          onEdit: _editTask,
                                          onDelete: _deleteTask,
                                          onTaskFocusRequested: _onTaskFocusRequested,
                                          showTitle: false,
                                          isEmbedded: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'POMODORO TIMER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
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
                        selectedRange: _heatmapRange,
                        onRangeChanged: (range) {
                          setState(() => _heatmapRange = range);
                          _initializeData(_selectedDate);
                        },
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: StyleService.getHeatmapBg(style, isDark),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: StyleService.getDailyTaskBorder(style, isDark),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 2, // 20% of this section
                              child: AnalyticsKPIs(
                                analytics: _analytics, 
                                isHorizontal: true,
                                isFocused: _focusedTask != null,
                                isEmbedded: true,
                              ),
                            ),
                            Divider(
                              height: 1, 
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                              indent: 16,
                              endIndent: 16,
                            ),
                            Expanded(
                              flex: 8, // 80% of this section
                              child: AnalyticsCarousel(
                                momentumData: _momentumData,
                                volumeData: _volumeData,
                                title: _heatmapRange,
                                focusedTaskName: _focusedTask?.name,
                                isEmbedded: true,
                              ),
                            ),
                          ],
                        ),
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
