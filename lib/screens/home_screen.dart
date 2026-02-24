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
import 'package:consistancy_tacker_v1/widgets/consistency_heatmap.dart';

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
                  child: ConsistencyHeatmap(heatmapData: _heatmapData),
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
}
