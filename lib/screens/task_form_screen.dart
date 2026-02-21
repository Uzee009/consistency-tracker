// lib/screens/task_form_screen.dart

import 'package:flutter/material.dart';
import 'package:consistancy_tacker_v1/services/database_service.dart';
import 'package:consistancy_tacker_v1/models/task_model.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task; // Optional task for editing
  final TaskType? initialTaskType; // Optional initial task type
  const TaskFormScreen({super.key, this.task, this.initialTaskType});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TaskType _taskType;
  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _taskType = widget.task?.type ?? widget.initialTaskType ?? TaskType.daily; // Use initialTaskType if provided
    _durationController = TextEditingController(text: (widget.task?.durationDays ?? 1).toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final String taskName = _nameController.text.trim();
      final int duration = int.tryParse(_durationController.text) ?? 0;

      if (taskName.isNotEmpty && (_taskType == TaskType.temporary || duration > 0)) {
        if (widget.task == null) {
          // Add new task
          final Task newTask = Task(
            id: DateTime.now().millisecondsSinceEpoch, // Simple ID generation
            name: taskName,
            type: _taskType,
            durationDays: _taskType == TaskType.daily ? duration : 0,
            createdAt: DateTime.now(),
            isActive: true,
          );
          await DatabaseService.instance.addTask(newTask);
        } else {
          // Update existing task
          final updatedTask = Task(
            id: widget.task!.id,
            name: taskName,
            type: _taskType,
            durationDays: _taskType == TaskType.daily ? duration : 0,
            createdAt: widget.task!.createdAt, // Preserve original creation date
            isActive: widget.task!.isActive, // Preserve original active status
          );
          await DatabaseService.instance.updateTask(updatedTask);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Task "${taskName}" saved!')),
          );
          Navigator.of(context).pop(); // Go back to the previous screen
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add New Task' : 'Edit Task'), // Dynamic title
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Task Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a task name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (widget.task == null && widget.initialTaskType == null) // Show radio buttons only when adding a new task without pre-selected type
                Row(
                  children: <Widget>[
                    Expanded(
                      child: RadioListTile<TaskType>(
                        title: const Text('Daily Task'),
                        value: TaskType.daily, // Value should be specific
                        groupValue: _taskType,
                        onChanged: (TaskType? value) {
                          setState(() {
                            _taskType = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<TaskType>(
                        title: const Text('Temporary Task'),
                        value: TaskType.temporary,
                        groupValue: _taskType,
                        onChanged: (TaskType? value) {
                          setState(() {
                            _taskType = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              if (widget.task == null && widget.initialTaskType == null) // Add a SizedBox if radio buttons are visible
                const SizedBox(height: 20),
              if (_taskType == TaskType.daily) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration in Days (e.g., 30, 7)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Please enter a valid positive number of days';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(widget.task == null ? 'Save Task' : 'Update Task', style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
