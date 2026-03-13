// lib/screens/task_form_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/models/task_model.dart';

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
  late bool _isPerpetual;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _taskType = widget.task?.type ?? widget.initialTaskType ?? TaskType.daily;
    _durationController = TextEditingController(text: (widget.task?.durationDays ?? 30).toString());
    _isPerpetual = widget.task?.isPerpetual ?? false;
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

      if (taskName.isNotEmpty) {
        // --- NEW TASK: HABIT REVIVAL CHECK ---
        if (widget.task == null) {
          final existing = await DatabaseService.instance.findDuplicateTask(taskName);
          if (existing != null && mounted) {
            final action = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Habit Already Exists', style: TextStyle(fontWeight: FontWeight.w900)),
                content: Text('You have a history with "${existing.name}". Would you like to revive your old progress or start fresh?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('CANCEL')),
                  TextButton(onPressed: () => Navigator.pop(ctx, 'restart'), child: const Text('RESTART FRESH', style: TextStyle(color: Colors.red))),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, 'revive'), child: const Text('REVIVE PROGRESS')),
                ],
              ),
            );

            if (action == null || action == 'cancel') return;

            if (action == 'revive') {
              final revived = Task(
                id: existing.id,
                name: existing.name,
                type: existing.type,
                durationDays: existing.durationDays,
                isPerpetual: existing.isPerpetual,
                createdAt: existing.createdAt,
                isActive: true,
              );
              await DatabaseService.instance.updateTask(revived);
              if (mounted) Navigator.of(context).pop();
              return;
            }

            if (action == 'restart') {
              final dateStr = DateTime.now().toIso8601String().split('T')[0];
              final archived = Task(
                id: existing.id,
                name: "${existing.name} (Archived $dateStr)",
                type: existing.type,
                durationDays: existing.durationDays,
                isPerpetual: existing.isPerpetual,
                createdAt: existing.createdAt,
                isActive: false,
              );
              await DatabaseService.instance.updateTask(archived);
            }
          }
        }

        // --- ACTUAL SAVE/UPDATE ---
        if (widget.task != null) {
          // Editing existing
          final Task updatedTask = Task(
            id: widget.task!.id,
            name: taskName,
            type: widget.task!.type,
            durationDays: _isPerpetual ? 0 : duration,
            isPerpetual: _isPerpetual,
            createdAt: widget.task!.createdAt,
            isActive: widget.task!.isActive,
          );
          await DatabaseService.instance.updateTask(updatedTask);
        } else {
          // Creating new
          final newTask = Task(
            id: DateTime.now().millisecondsSinceEpoch,
            name: taskName,
            type: _taskType,
            isPerpetual: _isPerpetual,
            durationDays: _isPerpetual ? 0 : duration,
            createdAt: DateTime.now(),
          );
          await DatabaseService.instance.addTask(newTask);
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add New Task' : 'Edit Task'),
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
              if (_taskType == TaskType.daily) ...[
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text('Permanent Task'),
                  subtitle: const Text('This task will not expire.'),
                  value: _isPerpetual,
                  onChanged: (bool value) {
                    setState(() {
                      _isPerpetual = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _durationController,
                  enabled: !_isPerpetual, // Disable if task is perpetual
                  decoration: InputDecoration(
                    labelText: 'Duration in Days (e.g., 30, 90)',
                    border: const OutlineInputBorder(),
                    filled: _isPerpetual,
                    fillColor: Colors.grey[200],
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_isPerpetual) {
                      if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) {
                        return 'Please enter a valid positive number of days';
                      }
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
