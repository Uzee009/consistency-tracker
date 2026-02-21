// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:consistancy_tacker_v1/screens/task_form_screen.dart';
import 'package:consistancy_tacker_v1/screens/tasks_list_screen.dart';
import 'package:consistancy_tacker_v1/services/database_service.dart';
import 'package:consistancy_tacker_v1/models/task_model.dart';
import 'package:consistancy_tacker_v1/models/day_record_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Task>> _todaysTasksFuture;
  late DayRecord _todayRecord; // To store and update today's record

  @override
  void initState() {
    super.initState();
    // Initialize with an empty future to prevent LateInitializationError
    _todaysTasksFuture = Future.value([]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load data every time the screen comes into view
    _initializeTodaysData();
  }

  void _initializeTodaysData() async {
    // Get today's date in YYYY-MM-DD format
    final today = DateTime.now();
    final todayFormatted = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Get or create today's DayRecord
    // Ensure _todayRecord is always initialized before _todaysTasksFuture is set
    _todayRecord = await DatabaseService.instance.getDayRecord(todayFormatted) ??
        DayRecord(date: todayFormatted, completedTaskIds: [], skippedTaskIds: []);

    // Load today's active tasks
    setState(() {
      _todaysTasksFuture = DatabaseService.instance.getActiveTasksForDate(today);
    });
  }

  // Method to handle task completion toggle
  void _toggleTaskCompletion(Task task, bool? isCompleted) async {
    List<int> updatedCompletedIds = List.from(_todayRecord.completedTaskIds);
    List<int> updatedSkippedIds = List.from(_todayRecord.skippedTaskIds);

    if (isCompleted == true) {
      updatedCompletedIds.add(task.id);
      updatedSkippedIds.remove(task.id); // Cannot be both completed and skipped
    } else {
      updatedCompletedIds.remove(task.id);
    }

    _updateTodayRecord(updatedCompletedIds, updatedSkippedIds);
  }

  // Method to handle task skip toggle
  void _toggleTaskSkip(Task task) async {
    List<int> updatedCompletedIds = List.from(_todayRecord.completedTaskIds);
    List<int> updatedSkippedIds = List.from(_todayRecord.skippedTaskIds);

    if (updatedSkippedIds.contains(task.id)) {
      updatedSkippedIds.remove(task.id);
    } else {
      updatedSkippedIds.add(task.id);
      updatedCompletedIds.remove(task.id); // Cannot be both completed and skipped
    }

    _updateTodayRecord(updatedCompletedIds, updatedSkippedIds);
  }

  void _updateTodayRecord(List<int> completedIds, List<int> skippedIds) async {
    _todayRecord = DayRecord(
      date: _todayRecord.date,
      completedTaskIds: completedIds,
      skippedTaskIds: skippedIds,
      cheatUsed: _todayRecord.cheatUsed,
      completionScore: _todayRecord.completionScore,
      visualState: _todayRecord.visualState,
    );

    await DatabaseService.instance.createOrUpdateDayRecord(_todayRecord);

    // Rebuild the UI to reflect changes
    setState(() {});
  }

  void _editTask(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    _initializeTodaysData();
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteTask(task.id);
      _initializeTodaysData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Row: Daily and Temporary Tasks
          Expanded(
            flex: 1,
            child: Row(
              children: <Widget>[
                // Daily Tasks Column
                Expanded(
                  flex: 1,
                  child: _buildTaskSection('Daily Tasks', TaskType.daily, Colors.lightBlue[50]!, Colors.blueAccent),
                ),
                // Temporary Tasks Column
                Expanded(
                  flex: 1,
                  child: _buildTaskSection('Temporary Tasks', TaskType.temporary, Colors.yellow[100]!, Colors.orangeAccent),
                ),
              ],
            ),
          ),
          // Bottom Row: Consistency Chart and Streaks
          Expanded(
            flex: 1,
            child: Row(
              children: [
                // GitHub-type Chart Placeholder
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.grey[200],
                    margin: const EdgeInsets.all(8.0),
                    child: const Center(
                      child: Text(
                        'GitHub-style Consistency Chart (Coming Soon!)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                // Task Streaks Placeholder
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[100],
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.blueGrey),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Streaks', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Max: 0', style: TextStyle(color: Colors.blueGrey)),
                          Text('Current: 0', style: TextStyle(color: Colors.blueGrey)),
                        ],
                      ),
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

  Widget _buildTaskSection(String title, TaskType type, Color bgColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TaskFormScreen(initialTaskType: type)),
                    );
                    _initializeTodaysData();
                  },
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<Task>>(
                future: _todaysTasksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.where((task) => task.type == type).isEmpty) {
                    return Center(child: Text('No $title.'));
                  } else {
                    final tasks = snapshot.data!.where((task) => task.type == type).toList();
                    return ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final isCompleted = _todayRecord.completedTaskIds.contains(task.id);
                        final isSkipped = _todayRecord.skippedTaskIds.contains(task.id);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                          leading: Checkbox(
                            value: isCompleted,
                            onChanged: (bool? value) => _toggleTaskCompletion(task, value),
                          ),
                          title: Text(
                            task.name,
                            style: TextStyle(
                              decoration: isCompleted ? TextDecoration.lineThrough : (isSkipped ? TextDecoration.none : null),
                              color: isSkipped ? Colors.grey : Colors.black,
                              fontStyle: isSkipped ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                          subtitle: isSkipped ? const Text('Skipped', style: TextStyle(fontSize: 10, color: Colors.grey)) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isSkipped ? Icons.remove_circle : Icons.remove_circle_outline,
                                  color: isSkipped ? Colors.orange : Colors.grey,
                                  size: 20,
                                ),
                                tooltip: 'Skip task',
                                onPressed: () => _toggleTaskSkip(task),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                                onPressed: () => _editTask(task),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                                onPressed: () => _deleteTask(task),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
