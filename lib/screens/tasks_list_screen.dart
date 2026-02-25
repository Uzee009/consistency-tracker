// lib/screens/tasks_list_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/models/task_model.dart';
import 'package:consistency_tracker_v1/screens/task_form_screen.dart'; // New Import

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({super.key});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTasks(); // Reload tasks when the route is re-entered (e.g., after adding a new task)
  }

  void _loadTasks() {
    setState(() {
      _tasksFuture = DatabaseService.instance.getAllTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
      ),
      body: FutureBuilder<List<Task>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tasks added yet.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final task = snapshot.data![index];
                return ListTile(
                  title: Text(task.name),
                  subtitle: Text(
                    'Type: ${task.type.toString().split('.').last}'
                    '${task.type == TaskType.daily ? ', Duration: ${task.durationDays} days' : ''}',
                  ),
                  onTap: () async { // Add onTap for editing
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
                    );
                    _loadTasks(); // Reload tasks after returning from edit screen
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
