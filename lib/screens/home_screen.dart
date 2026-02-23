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

  // For heatmap grid sizing
  static const double _cellSize = 18.0;
  static const double _cellMargin = 2.0;
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
    _loadHeatmapData();

    setState(() {
      _todaysTasksFuture = DatabaseService.instance.getActiveTasksForDate(today);
    });
  }

  void _loadHeatmapData() async {
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
                child: Text(
                  'Tokens: ${(_currentUser!.monthlyCheatDays - _cheatDaysUsed).clamp(0, _currentUser!.monthlyCheatDays)}/${_currentUser!.monthlyCheatDays}',
                  style: const TextStyle(fontSize: 12),
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
                      color: const Color(0xFFF6B4FF),
                       borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      children: [
                        // Heatmap Legend
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLegendItem(Colors.orange, 'Cheat Day'),
                              _buildLegendItem(Colors.amber, 'Star Day'),
                              _buildLegendItem(const Color(0xFFCB5DDA), 'No Activity'),
                              _buildLegendItem(const Color(0xFFC8E6C9), 'Low'),
                              _buildLegendItem(const Color(0xFF81C784), 'Medium'),
                              _buildLegendItem(const Color(0xFF388E3C), 'High'),
                            ],
                          ),
                        ),
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
                        icon: const Icon(Icons.skip_next_outlined),
                        tooltip: 'Declare Cheat Day',
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
  
  Widget _buildLegendItem(Color color, String text) {
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
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildHeatmapGrid() {
    final List<Widget> weekColumns = [];
    final today = DateTime.now();
    
    DateTime rawStartDate = DateTime(today.year, 1, 1);
    
    DateTime startDate = rawStartDate;
    while (startDate.weekday != DateTime.sunday) {
      startDate = startDate.subtract(const Duration(days: 1));
    }

    DateTime endDate = DateTime(today.year, 12, 31);
    while (endDate.weekday != DateTime.saturday) {
        endDate = endDate.add(const Duration(days: 1));
    }

    final List<MonthLabelData> monthLabelsData = [];
    final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final List<String> weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final Widget dayLabelColumn = Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((name) => Container(
        height: _totalCellSize,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: _cellMargin),
        child: Text(name, style: const TextStyle(fontSize: 10, color: Color(0xFF2F0035))),
      )).toList(),
    );
    
    DateTime currentDate = startDate;
    int lastMonth = -1;
    double currentMonthSpanWidth = 0;

    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      if (currentDate.month != lastMonth && lastMonth != -1) {
        monthLabelsData.add(
          MonthLabelData(
            name: monthNames[lastMonth - 1],
            width: currentMonthSpanWidth,
          ),
        );
        weekColumns.add(
          const SizedBox(width: _totalCellSize),
        );
        monthLabelsData.add(
          MonthLabelData(name: '', width: _totalCellSize),
        );
        currentMonthSpanWidth = 0;
      }
      lastMonth = currentDate.month;
      
      currentMonthSpanWidth += _totalCellSize;

      List<Widget> dayCellsInWeek = [];
      for (int i = 0; i < 7; i++) {
        final day = currentDate.add(Duration(days: i));
        
        bool isDayWithinYear = day.year == today.year && day.isAfter(rawStartDate.subtract(const Duration(days:1))) && day.isBefore(DateTime(today.year, 12, 31).add(const Duration(days:1)));

        final int intensity = _heatmapData[DateTime(day.year, day.month, day.day)] ?? 0;
        Color cellColor;

        if (intensity == -1) {
          cellColor = Colors.orange;
        } else if (intensity == -2) {
          cellColor = Colors.amber;
        } else if (intensity == 1) {
          cellColor = const Color(0xFFC8E6C9);
        } else if (intensity == 2) {
          cellColor = const Color(0xFF81C784);
        } else if (intensity == 3) {
          cellColor = const Color(0xFF388E3C);
        } else {
          cellColor = const Color(0xFFCB5DDA);
        }

        dayCellsInWeek.add(
          isDayWithinYear ?
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
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: Text(
                  day.day.toString(),
                  style: TextStyle(
                    fontSize: 8,
                    color: (cellColor.computeLuminance() > 0.5) ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          )
          : const SizedBox(width: _totalCellSize, height: _totalCellSize),
        );
      }
      weekColumns.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: dayCellsInWeek,
        ),
      );
      currentDate = currentDate.add(const Duration(days: 7));
    }

    if (currentMonthSpanWidth > 0) {
      monthLabelsData.add(
        MonthLabelData(
          name: monthNames[lastMonth - 1],
          width: currentMonthSpanWidth,
        ),
      );
    }
    
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
              child: Row(
                children: [
                  const SizedBox(width: _totalCellSize * 1.5),
                  ...monthLabelsData.map((data) => SizedBox(
                    width: data.width,
                    child: Text(data.name, textAlign: TextAlign.left, style: const TextStyle(fontSize: 10, color: Color(0xFF2F0035))),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dayLabelColumn,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: weekColumns,
                ),
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
