// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/screens/task_form_screen.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/scoring_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/models/task_model.dart';
import 'package:consistency_tracker_v1/models/day_record_model.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/widgets/task_section.dart';
import 'package:consistency_tracker_v1/widgets/add_task_bottom_sheet.dart';
import 'package:consistency_tracker_v1/widgets/consistency_heatmap.dart';
import 'package:consistency_tracker_v1/widgets/analytics_kpis.dart';
import 'package:consistency_tracker_v1/widgets/analytics_carousel.dart';
import 'package:consistency_tracker_v1/widgets/pomodoro_timer.dart';
import 'package:consistency_tracker_v1/widgets/user_menu.dart';
import 'package:consistency_tracker_v1/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> _todaysTasks = [];
  DayRecord _todayRecord = DayRecord(date: '', completedTaskIds: [], skippedTaskIds: []);
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

  void _onDateSelected(DateTime date) {
    _initializeData(date);
  }

  Future<void> _refreshTodayRecord() async {
    final dateFormatted =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final record = await DatabaseService.instance.getDayRecord(dateFormatted);
    if (record != null) {
      setState(() {
        _todayRecord = record;
      });
    }
  }

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
    
    // Create a temporary record to calculate the score
    final tempRecord = DayRecord(
      date: _todayRecord.date,
      completedTaskIds: completedIds,
      skippedTaskIds: skippedIds,
      cheatUsed: _todayRecord.cheatUsed,
    );

    final scoreResult = ScoringService.calculateDayScore(
      allTasks: activeTasks, 
      dayRecord: tempRecord,
    );

    final updatedRecord = DayRecord(
      date: _todayRecord.date,
      completedTaskIds: completedIds,
      skippedTaskIds: skippedIds,
      cheatUsed: _todayRecord.cheatUsed,
      completionScore: scoreResult.completionScore,
      visualState: _todayRecord.cheatUsed ? VisualState.cheat : scoreResult.visualState,
    );

    await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
  }

  void _editTask(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: task),
      ),
    );
    _initializeData(_selectedDate);
  }

  void _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "${task.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteTask(task.id);
      _initializeData(_selectedDate);
    }
  }

  void _onDeclareCheatDayPressed() async {
    if (_currentUser == null) return;
    
    if (_todayRecord.completedTaskIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot use Cheat Day after completing tasks!')),
      );
      return;
    }

    if (_cheatDaysUsed >= _currentUser!.monthlyCheatDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Cheat Day tokens left for this month!')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Cheat Day?'),
        content: const Text('This will mark today as a "Cheat Day". It preserves your streak but provides no score. Use one token?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use Token', style: TextStyle(color: Colors.orange))),
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

  void _updateTodayRecord({required bool cheatUsed}) async {
    final updatedRecord = DayRecord(
      date: _todayRecord.date,
      completedTaskIds: _todayRecord.completedTaskIds,
      skippedTaskIds: _todayRecord.skippedTaskIds,
      cheatUsed: cheatUsed,
      completionScore: _todayRecord.completionScore,
      visualState: cheatUsed ? VisualState.cheat : _todayRecord.visualState,
    );
    await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
    _initializeData(_selectedDate);
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

  Widget _buildInternalHeader(BuildContext context, String title, String helpText, {Widget? suffix}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: helpText,
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              if (suffix != null) ...[
                const Spacer(),
                suffix,
              ],
            ],
          ),
        ),
        Divider(
          height: 1, 
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ],
    );
  }

  Widget _buildHeatmapHeaderSuffix(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final bool isViewingToday = _selectedDate.year == today.year && 
         _selectedDate.month == today.month && 
         _selectedDate.day == today.day;

    final List<String> monthNamesShort = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final String dateString = "${_selectedDate.day} ${monthNamesShort[_selectedDate.month - 1]} ${_selectedDate.year}";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_focusedTask != null) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _focusedTask!.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _onClearFocus,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (!isViewingToday) ...[
          Text(
            dateString,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onDateSelected(DateTime.now()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.today_rounded, 
                    size: 10, 
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 8,
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
    );
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
                  children: [
                    // LEFT: Tabbed Task Section
                    Expanded(
                      flex: 1,
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: style == VisualStyle.vibrant 
                              ? Colors.transparent 
                              : Theme.of(context).colorScheme.surface,
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
                            _buildInternalHeader(
                              context, 
                              'TASKS', 
                              'Manage your daily habits and one-off temporary goals here.'
                            ),
                            Expanded(
                              child: DefaultTabController(
                                length: 2,
                                child: Builder(
                                  builder: (context) {
                                    return Column(
                                      children: [
                                        // Header: Tabs + Buttons
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                                          child: Row(
                                            children: [
                                              // ShadCN-style Tabs
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  height: 28,
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
                                                    labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                                                    unselectedLabelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                                                    indicatorSize: TabBarIndicatorSize.tab,
                                                    indicator: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.surface,
                                                      borderRadius: BorderRadius.circular(6),
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
                                              Row(
                                                children: [
                                                  if (_todayRecord.completedTaskIds.isNotEmpty)
                                                    Icon(Icons.lock_outline, size: 12, color: Colors.orange.withValues(alpha: 0.5))
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
                                                onEdit: (task) => _editTask(task),
                                                onDelete: (task) => _deleteTask(task),
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
                                                onEdit: (task) => _editTask(task),
                                                onDelete: (task) => _deleteTask(task),
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
                          ],
                        ),
                      ),
                    ),
                    
                    // RIGHT: Pomodoro Timer Section
                    Expanded(
                      flex: 1,
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        clipBehavior: Clip.antiAlias, // Added this
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
                            _buildInternalHeader(
                              context, 
                              'FOCUS ZONE', 
                              'Use the Pomodoro timer to maintain deep focus on your tasks.'
                            ),
                            const Expanded(child: PomodoroTimer()),
                          ],
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
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        clipBehavior: Clip.antiAlias, // Added this
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
                            _buildInternalHeader(
                              context, 
                              'CONSISTENCY', 
                              'Visual history of your daily discipline over time.',
                              suffix: _buildHeatmapHeaderSuffix(context),
                            ),
                            Expanded(
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
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        clipBehavior: Clip.antiAlias, // Added this
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
                            _buildInternalHeader(
                              context, 
                              'PERFORMANCE', 
                              'Quantified trends of your habit mastery and output volume.'
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 2,
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
                                    flex: 8,
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
