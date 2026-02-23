// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:consistancy_tacker_v1/screens/task_form_screen.dart';
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
  late DayRecord _todayRecord;

  @override
  void initState() {
    super.initState();
    _todaysTasksFuture = Future.value([]);
    _initializeTodaysData();
  }

  void _initializeTodaysData() async {
    final today = DateTime.now();
    final todayFormatted = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    _todayRecord = await DatabaseService.instance.getDayRecord(todayFormatted) ??
        DayRecord(date: todayFormatted, completedTaskIds: [], skippedTaskIds: []);

    setState(() {
      _todaysTasksFuture = DatabaseService.instance.getActiveTasksForDate(today);
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

    _updateTodayRecord(updatedCompletedIds, updatedSkippedIds);
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteTask(task.id);
      _initializeTodaysData();
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
              bottom: MediaQuery.of(context).viewInsets.bottom + 16, // Added padding
              top: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add ${type == TaskType.daily ? 'Daily' : 'Temporary'} Task', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Task Name', border: OutlineInputBorder()), autofocus: true),
                if (type == TaskType.daily) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Permanent Task'),
                    value: isPerpetual,
                    onChanged: (value) {
                      setSheetState(() {
                        isPerpetual = value;
                      });
                    },
                  ),
                  if (!isPerpetual)
                    TextField(
                      controller: durationController,
                      decoration: const InputDecoration(labelText: 'Duration in Days', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final String taskName = nameController.text.trim();
                        if (taskName.isNotEmpty) {
                          final newTask = Task(
                            id: DateTime.now().millisecondsSinceEpoch,
                            name: taskName,
                            type: type,
                            isPerpetual: type == TaskType.daily ? isPerpetual : false,
                            durationDays: type == TaskType.daily && !isPerpetual ? (int.tryParse(durationController.text) ?? 30) : 0,
                            createdAt: DateTime.now(),
                          );
                          await DatabaseService.instance.addTask(newTask);
                          Navigator.of(context).pop();
                          _initializeTodaysData();
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
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Row(
              children: <Widget>[
                Expanded(child: _buildTaskSection('Daily Tasks', TaskType.daily, Colors.lightBlue[50]!, Colors.blueAccent)),
                Expanded(child: _buildTaskSection('Temporary Tasks', TaskType.temporary, Colors.yellow[100]!, Colors.orangeAccent)),
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
                    color: Colors.grey[200],
                    margin: const EdgeInsets.all(8.0),
                    child: const Center(child: Text('GitHub-style Consistency Chart (Coming Soon!)', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey))),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.blueGrey)),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Streaks', style: TextStyle(fontWeight: FontWeight.bold)), Text('Max: 0', style: TextStyle(color: Colors.blueGrey)), Text('Current: 0', style: TextStyle(color: Colors.blueGrey))]),
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
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8.0), border: Border.all(color: borderColor)),
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
                  onPressed: () => _showAddTaskSheet(type: type),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<Task>>(
                future: _todaysTasksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  final tasks = snapshot.data?.where((task) => task.type == type).toList() ?? [];
                  if (tasks.isEmpty) return Center(child: Text('No $title.'));
                  
                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isCompleted = _todayRecord.completedTaskIds.contains(task.id);
                      final isSkipped = _todayRecord.skippedTaskIds.contains(task.id);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        leading: Checkbox(value: isCompleted, onChanged: (bool? value) => _toggleTaskCompletion(task, value)),
                        title: Text(
                          task.name,
                          style: TextStyle(
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isSkipped ? Colors.grey : Colors.black,
                            fontStyle: isSkipped ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        subtitle: isSkipped ? const Text('Skipped', style: TextStyle(fontSize: 10, color: Colors.grey)) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: Icon(isSkipped ? Icons.remove_circle : Icons.remove_circle_outline, color: isSkipped ? Colors.orange : Colors.grey, size: 20), tooltip: 'Skip task', onPressed: () => _toggleTaskSkip(task)),
                            IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey), onPressed: () => _editTask(task)),
                            IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent), onPressed: () => _deleteTask(task)),
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
