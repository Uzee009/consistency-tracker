import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';

class AddTaskBottomSheet extends StatefulWidget {
  final TaskType type;
  final VoidCallback onTaskAdded;

  const AddTaskBottomSheet({
    super.key,
    required this.type,
    required this.onTaskAdded,
  });

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  bool _isPerpetual = false;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Add ${widget.type == TaskType.daily ? 'Daily' : 'Temporary'} Task',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Define your new consistency goal below.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Text(
            'Task Name',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: const InputDecoration(
              hintText: 'e.g. Read for 30 mins',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (widget.type == TaskType.daily) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: SwitchListTile(
                title: Text(
                  'Permanent Task',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                ),
                subtitle: Text('Does not expire', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                value: _isPerpetual,
                activeTrackColor: isDark ? Colors.white : Colors.black,
                inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                onChanged: (value) => setState(() => _isPerpetual = value),
              ),
            ),
            if (!_isPerpetual) ...[
              const SizedBox(height: 20),
              Text(
                'Duration in Days',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _durationController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: const InputDecoration(
                  hintText: '30',
                  helperText: 'How many days this task should appear',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveTask,
                  child: const Text('Save Task'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveTask() async {
    final String taskName = _nameController.text.trim();
    if (taskName.isEmpty) return;

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch,
      name: taskName,
      type: widget.type,
      isPerpetual: widget.type == TaskType.daily ? _isPerpetual : false,
      durationDays: widget.type == TaskType.daily && !_isPerpetual
          ? (int.tryParse(_durationController.text) ?? 30)
          : 0,
      createdAt: DateTime.now(),
    );

    await DatabaseService.instance.addTask(newTask);
    widget.onTaskAdded();
    if (mounted) Navigator.of(context).pop();
  }
}
