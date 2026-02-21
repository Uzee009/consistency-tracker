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
        DayRecord(date: todayFormatted, completedTaskIds: []);

    // Load today's active tasks
    setState(() {
      _todaysTasksFuture = DatabaseService.instance.getActiveTasksForDate(today);
    });
  }

  // Method to handle task completion toggle
  void _toggleTaskCompletion(Task task, bool? isCompleted) async {
    // This logic will be more complex later, involving scoring engine, etc.
    // For now, just update the completedTaskIds in _todayRecord and persist.
    List<int> updatedCompletedIds = List.from(_todayRecord.completedTaskIds);
    if (isCompleted == true) {
      updatedCompletedIds.add(task.id);
    } else {
      updatedCompletedIds.remove(task.id);
    }

    _todayRecord = DayRecord(
      date: _todayRecord.date,
      completedTaskIds: updatedCompletedIds,
      cheatUsed: _todayRecord.cheatUsed, // Preserve other data
      completionScore: _todayRecord.completionScore,
      visualState: _todayRecord.visualState,
    );

    await DatabaseService.instance.createOrUpdateDayRecord(_todayRecord);

    // Rebuild the UI to reflect changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consistency Tracker'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TasksListScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Row: Daily and Temporary Tasks
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                // Daily Tasks Column
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue[50],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.blueAccent),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Daily Tasks', style: Theme.of(context).textTheme.titleMedium),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TaskFormScreen(initialTaskType: TaskType.daily)),
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
                                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Center(child: Text('No daily tasks.'));
                                } else {
                                  final dailyTasks = snapshot.data!
                                      .where((task) => task.type == TaskType.daily)
                                      .toList();
                                  if (dailyTasks.isEmpty) {
                                    return const Center(child: Text('No daily tasks.'));
                                  }
                                  return ListView.builder(
                                    itemCount: dailyTasks.length,
                                    itemBuilder: (context, index) {
                                      final task = dailyTasks[index];
                                      final isCompleted = _todayRecord.completedTaskIds.contains(task.id);
                                      return CheckboxListTile(
                                        title: Text(task.name),
                                        value: isCompleted,
                                        onChanged: (bool? value) {
                                          _toggleTaskCompletion(task, value);
                                        },
                                        controlAffinity: ListTileControlAffinity.leading,
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
                  ),
                ),
                // Temporary Tasks Column
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.orangeAccent),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Temporary Tasks', style: Theme.of(context).textTheme.titleMedium),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TaskFormScreen(initialTaskType: TaskType.temporary)),
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
                                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Center(child: Text('No temporary tasks.'));
                                } else {
                                  final temporaryTasks = snapshot.data!
                                      .where((task) => task.type == TaskType.temporary)
                                      .toList();
                                  if (temporaryTasks.isEmpty) {
                                    return const Center(child: Text('No temporary tasks.'));
                                  }
                                  return ListView.builder(
                                    itemCount: temporaryTasks.length,
                                    itemBuilder: (context, index) {
                                      final task = temporaryTasks[index];
                                      final isCompleted = _todayRecord.completedTaskIds.contains(task.id);
                                      return CheckboxListTile(
                                        title: Text(
                                          task.name,
                                          style: const TextStyle(color: Colors.black),
                                        ),
                                        value: isCompleted,
                                        onChanged: (bool? value) {
                                          _toggleTaskCompletion(task, value);
                                        },
                                        controlAffinity: ListTileControlAffinity.leading,
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
                  ),
                ),
              ],
            ),
          ),
          // Bottom Row: Consistency Chart and Streaks
          Expanded(
            flex: 7,
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
}
