// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:consistancy_tacker_v1/screens/task_form_screen.dart';
import 'package:consistancy_tacker_v1/services/database_service.dart';
import 'package:consistancy_tacker_v1/services/scoring_service.dart';
import 'package:consistancy_tacker_v1/models/task_model.dart';
import 'package:consistancy_tacker_v1/models/day_record_model.dart';
import 'package:consistancy_tacker_v1/models/user_model.dart';
import 'package:consistancy_tacker_v1/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Task>> _todaysTasksFuture;
  late DayRecord _todayRecord;
  User? _currentUser;
  int _cheatDaysUsed = 0;
  Map<DateTime, int> _heatmapData = {};
  final ScrollController _heatmapScrollController = ScrollController();
  bool _hasInitialScrolled = false;
  String _heatmapRange = '1Y';
  bool _isReportMode = false;

  // For heatmap grid sizing
  static const double _cellSize = 22.0; // Increased from 18
  static const double _cellMargin = 3.0; // Increased from 2
  static const double _totalCellSize = _cellSize + (2 * _cellMargin);

  @override
  void initState() {
    super.initState();
    _todaysTasksFuture = Future.value([]);
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

    setState(() {
      _todaysTasksFuture = DatabaseService.instance.getActiveTasksForDate(today);
    });
  }

  Future<void> _loadHeatmapData() async {
    final today = DateTime.now();
    final startOfYear = DateTime(today.year, 1, 1);
    
    final records = await DatabaseService.instance.getDayRecords(limit: 366);
    final Map<DateTime, int> data = {};
    for (var record in records) {
      final date = DateTime.parse(record.date);
      final cleanDate = DateTime(date.year, date.month, date.day); 

      int intensity;

      if (record.visualState == VisualState.cheat) {
        intensity = -1;
      } else if (record.visualState == VisualState.star) {
        intensity = -2;
      } else if (record.visualState == VisualState.empty) {
        intensity = 0;
      } else if (record.visualState == VisualState.lightGreen) {
        intensity = 1;
      } else if (record.visualState == VisualState.green) {
        intensity = 2;
      } else if (record.visualState == VisualState.darkGreen) {
        intensity = 3;
      } else {
        intensity = 0;
      }

      data[cleanDate] = intensity;
    }
    setState(() {
      _heatmapData = data;
    });
    
    if (!_hasInitialScrolled) {
      _scrollToCurrentMonth();
    }
  }

  void _scrollToCurrentMonth() async {
    // Wait a bit to ensure layout is complete and maxScrollExtent is calculated
    await Future.delayed(const Duration(milliseconds: 150));
    if (!_heatmapScrollController.hasClients) return;

    final today = DateTime.now();
    int monthsCount = 12;
    if (_heatmapRange == '1M') {
      monthsCount = 1;
    } else if (_heatmapRange == '3M') {
      monthsCount = 3;
    } else if (_heatmapRange == '6M') {
      monthsCount = 6;
    }

    double targetOffset = _totalCellSize * 1.5; // Start after dayLabelColumn
    double currentMonthWidth = 0;
    bool foundCurrentMonth = false;

    // We need to mirror the logic in _buildHeatmapGrid to find the exact offset
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
      
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);
      
      int weeks = 0;
      DateTime tempDay = firstDay;
      while (tempDay.isBefore(lastDay.add(const Duration(days: 1)))) {
        weeks++;
        int startWeekday = tempDay.weekday % 7;
        int daysLeftInWeek = 7 - startWeekday;
        tempDay = tempDay.add(Duration(days: daysLeftInWeek));
      }
      
      final monthW = weeks * _totalCellSize;
      
      if (month == today.month && year == today.year) {
        currentMonthWidth = monthW;
        foundCurrentMonth = true;
        break; // Found it, stop adding to offset
      }

      targetOffset += monthW;
      targetOffset += (_totalCellSize / 2); // The gap
    }

    if (!foundCurrentMonth) return;

    final screenWidth = MediaQuery.of(context).size.width * 0.75;
    double finalScroll = targetOffset + (currentMonthWidth / 2) - (screenWidth / 2);
    finalScroll = finalScroll.clamp(0.0, _heatmapScrollController.position.maxScrollExtent);

    _heatmapScrollController.animateTo(
      finalScroll,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
    _hasInitialScrolled = true;
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
      _initializeData();
    }
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
    final nameController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    bool isPerpetual = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    'Add ${type == TaskType.daily ? 'Daily' : 'Temporary'} Task',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: 'Task Name', border: OutlineInputBorder()),
                    autofocus: true),
                if (type == TaskType.daily) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Permanent Task'),
                    value: isPerpetual,
                    onChanged: (value) =>
                        setSheetState(() => isPerpetual = value),
                  ),
                  if (!isPerpetual)
                    TextField(
                      controller: durationController,
                      decoration: const InputDecoration(
                          labelText: 'Duration in Days',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final String taskName = nameController.text.trim();
                        if (taskName.isNotEmpty) {
                          final newTask = Task(
                            id: DateTime.now().millisecondsSinceEpoch,
                            name: taskName,
                            type: type,
                            isPerpetual:
                                type == TaskType.daily ? isPerpetual : false,
                            durationDays: type == TaskType.daily && !isPerpetual
                                ? (int.tryParse(durationController.text) ?? 30)
                                : 0,
                            createdAt: DateTime.now(),
                          );
                          await DatabaseService.instance.addTask(newTask);
                          Navigator.of(context).pop();
                          _initializeData();
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          );
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
          if (_currentUser != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'copy_id') {
                  Clipboard.setData(
                      ClipboardData(text: _currentUser!.id.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User ID copied to clipboard!')));
                } else if (value == 'settings') {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
                      .then((_) => _initializeData());
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(_currentUser!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'copy_id',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ID: ${_currentUser!.id.toString()}'),
                      const Icon(Icons.copy, size: 18),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: ListTile(
                      leading: Icon(Icons.settings), title: Text('Settings')),
                ),
              ],
              icon: const Icon(Icons.account_circle),
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
                    child: _buildTaskSection('Daily Tasks', TaskType.daily,
                        Colors.lightBlue[50]!, Colors.blueAccent)),
                Expanded(
                    child: _buildTaskSection(
                        'Temporary Tasks',
                        TaskType.temporary,
                        Colors.yellow[100]!,
                        Colors.orangeAccent)),
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
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: Colors.deepPurple[50]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Responsive Header: Legends on Left, Tabs on Right
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Legends & Status (Left Side)
                            Expanded(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _buildLegendItem(Colors.orange[300]!, 'Cheat'),
                                      _buildLegendItem(Colors.green[600]!, 'Star', hasStar: true),
                                      _buildLegendItem(Colors.deepPurple[50]!, 'None'),
                                      const SizedBox(width: 4),
                                      const Text('|', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                      const SizedBox(width: 4),
                                      const Text('Less', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                                      _buildLegendItem(Colors.green[100]!, ''),
                                      _buildLegendItem(Colors.green[300]!, ''),
                                      _buildLegendItem(Colors.green[600]!, ''),
                                      const Text('More', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  if (_isReportMode)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple[900],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'REPORT MODE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                                                        // Tabs & Toggle (Right Side)
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            // Report Toggle Button
                                                            IconButton(
                                                              onPressed: () {
                                                                setState(() => _isReportMode = !_isReportMode);
                                                                _scrollToCurrentMonth();
                                                              },
                                                              icon: Icon(
                                                                _isReportMode ? Icons.analytics : Icons.analytics_outlined,
                                                                color: _isReportMode ? Colors.deepPurple[900] : Colors.grey[600],
                                                                size: 20,
                                                              ),
                                                              tooltip: 'Toggle Report Mode',
                                                            ),
                                                            const SizedBox(width: 4),
                                                            // Duration Tabs
                                                            Container(
                                                              padding: const EdgeInsets.all(4),
                                                              decoration: BoxDecoration(
                                                                color: Colors.grey[200],
                                                                borderRadius: BorderRadius.circular(8),
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
                                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                      decoration: BoxDecoration(
                                                                        color: isSelected ? Colors.white : Colors.transparent,
                                                                        borderRadius: BorderRadius.circular(6),
                                                                        boxShadow: isSelected
                                                                            ? [
                                                                                BoxShadow(
                                                                                  color: Colors.black.withOpacity(0.05),
                                                                                  blurRadius: 4,
                                                                                  offset: const Offset(0, 2),
                                                                                )
                                                                              ]
                                                                            : [],
                                                                      ),
                                                                      child: Text(
                                                                        range,
                                                                        style: TextStyle(
                                                                          fontSize: 10,
                                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                                          color: isSelected ? Colors.black : Colors.grey[600],
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
                                                    // Custom Heatmap Grid
                                                    _buildHeatmapGrid(),
                                                  ],
                                                ),
                                              ),
                                            ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                          color: Colors.blueGrey[100],
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.blueGrey)),
                      child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Streaks',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Max: 0',
                                style: TextStyle(color: Colors.blueGrey)),
                            Text('Current: 0',
                                style: TextStyle(color: Colors.blueGrey))
                          ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSection(
      String title, TaskType type, Color bgColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: borderColor)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    if (type == TaskType.daily)
                      IconButton(
                        icon: Icon(
                          Icons.celebration,
                          color: _todayRecord.completedTaskIds.isNotEmpty
                              ? Colors.grey
                              : null,
                        ),
                        tooltip: _todayRecord.completedTaskIds.isNotEmpty
                            ? 'Cannot cheat after completing tasks'
                            : 'Declare Cheat Day',
                        onPressed: _onDeclareCheatDayPressed,
                      ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _showAddTaskSheet(type: type),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<Task>>(
                future: _todaysTasksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final tasks =
                      snapshot.data?.where((task) => task.type == type).toList() ??
                          [];
                  if (tasks.isEmpty) {
                    return Center(child: Text('No $title.'));
                  }

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isCompleted =
                          _todayRecord.completedTaskIds.contains(task.id);
                      final isSkipped =
                          _todayRecord.skippedTaskIds.contains(task.id);

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4.0),
                        leading: Checkbox(
                            value: isCompleted,
                            onChanged: (bool? value) =>
                                _toggleTaskCompletion(task, value)),
                        title: Text(
                          task.name,
                          style: TextStyle(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isSkipped ? Colors.grey : Colors.black,
                            fontStyle:
                                isSkipped ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        subtitle: isSkipped
                            ? const Text('Skipped',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey))
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: Icon(
                                    isSkipped
                                        ? Icons.remove_circle
                                        : Icons.remove_circle_outline,
                                    color: isSkipped
                                        ? Colors.orange
                                        : Colors.grey,
                                    size: 20),
                                tooltip: 'Skip task',
                                onPressed: () => _toggleTaskSkip(task)),
                            IconButton(
                                icon: const Icon(Icons.edit,
                                    size: 20, color: Colors.blueGrey),
                                onPressed: () => _editTask(task)),
                            IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.redAccent),
                                onPressed: () => _deleteTask(task)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(Color color, String text, {bool hasStar = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: hasStar ? const Center(child: Icon(Icons.star, size: 8, color: Colors.white)) : null,
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildHeatmapGrid() {
    final List<Widget> weekColumns = [];
    final today = DateTime.now();
    final List<MonthLabelData> monthLabelsData = [];
    final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final List<String> weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final Widget dayLabelColumn = SizedBox(
      width: _totalCellSize * 1.5,
      child: Column(
        children: weekdays.map((name) => Container(
          height: _totalCellSize,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: _cellMargin),
          child: Text(name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepPurple[900])),
        )).toList(),
      ),
    );

    int monthsCount = 12;
    if (_heatmapRange == '1M') {
      monthsCount = 1;
    } else if (_heatmapRange == '3M') {
      monthsCount = 3;
    } else if (_heatmapRange == '6M') {
      monthsCount = 6;
    }

    for (int i = 0; i < monthsCount; i++) {
      // Logic for calculating the target date based on mode
      DateTime targetDate;
      if (_isReportMode) {
        // Backward looking (Historical)
        targetDate = DateTime(today.year, today.month - (monthsCount - 1 - i), 1);
      } else {
        // Forward looking (Planning)
        if (_heatmapRange == '1Y') {
          // Standard Calendar Year: Jan to Dec
          targetDate = DateTime(today.year, i + 1, 1);
        } else {
          // Current month + X months ahead
          targetDate = DateTime(today.year, today.month + i, 1);
        }
      }

      final month = targetDate.month;
      final year = targetDate.year;

      final firstDayOfMonth = DateTime(year, month, 1);
      final lastDayOfMonth = DateTime(year, month + 1, 0);
      double monthWidth = 0;
      List<Widget> thisMonthWeeks = [];

      DateTime currentDay = firstDayOfMonth;
      while (currentDay.isBefore(lastDayOfMonth.add(const Duration(days: 1)))) {
        List<Widget> dayCellsInWeek = [];
        int startWeekday = currentDay.weekday % 7; // 0 for Sunday

        // Fill leading empty cells for the first week of the month
        if (currentDay.day == 1 && startWeekday != 0) {
          for (int i = 0; i < startWeekday; i++) {
            dayCellsInWeek.add(const SizedBox(width: _totalCellSize, height: _totalCellSize));
          }
        }

        // Fill actual days for the week
        while (dayCellsInWeek.length < 7 && currentDay.isBefore(lastDayOfMonth.add(const Duration(days: 1)))) {
          final day = currentDay;
          final int intensity = _heatmapData[DateTime(day.year, day.month, day.day)] ?? 0;
          Color cellColor;

          if (intensity == -1) {
            cellColor = Colors.orange[300]!;
          } else if (intensity == -2) {
            cellColor = Colors.green[600]!; // Dark green for Star day
          } else if (intensity == 1) {
            cellColor = Colors.green[100]!;
          } else if (intensity == 2) {
            cellColor = Colors.green[300]!;
          } else if (intensity == 3) {
            cellColor = Colors.green[600]!;
          } else {
            cellColor = Colors.deepPurple[50]!;
          }

          dayCellsInWeek.add(
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Date: ${day.toIso8601String().split('T')[0]}')));
              },
              child: Container(
                width: _cellSize,
                height: _cellSize,
                margin: const EdgeInsets.all(_cellMargin),
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: intensity == -2
                      ? const Icon(Icons.star, size: 10, color: Colors.white)
                      : Text(
                          day.day.toString(),
                          style: TextStyle(
                            fontSize: 8,
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

        // Fill trailing empty cells for the last week of the month
        while (dayCellsInWeek.length < 7) {
          dayCellsInWeek.add(const SizedBox(width: _totalCellSize, height: _totalCellSize));
        }

        thisMonthWeeks.add(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: dayCellsInWeek,
          ),
        );
        monthWidth += _totalCellSize;
      }

      final bool isCurrentMonth = month == today.month && year == today.year;

      weekColumns.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: isCurrentMonth
              ? BoxDecoration(
                  color: const Color(0xFFB39DDB), // #B39DDB with 100% opacity
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF9575CD), width: 1),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: thisMonthWeeks,
          ),
        ),
      );

      String monthLabel = monthNames[month - 1];
      if (year != today.year) {
        monthLabel += " '${year.toString().substring(2)}";
      }
      monthLabelsData.add(MonthLabelData(name: monthLabel, width: monthWidth));

      // Add a gap between months
      if (i < monthsCount - 1) {
        weekColumns.add(const SizedBox(width: _totalCellSize / 2));
        monthLabelsData.add(MonthLabelData(name: '', width: _totalCellSize / 2));
      }
    }

    return Expanded(
      child: SingleChildScrollView(
        controller: _heatmapScrollController,
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 25,
              child: Row(
                children: [
                  const SizedBox(width: _totalCellSize * 1.5),
                  ...monthLabelsData.map((data) => SizedBox(
                        width: data.width,
                        child: Text(data.name,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple[900])),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dayLabelColumn,
                ...weekColumns,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MonthLabelData {
  final String name;
  final double width;

  MonthLabelData({required this.name, required this.width});
}
