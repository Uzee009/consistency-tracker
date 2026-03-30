import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';

class AddTaskBottomSheet extends StatefulWidget {
  final TaskType type;
  final VoidCallback onTaskAdded;
  final Task? task; // V8: Optional task for editing

  const AddTaskBottomSheet({
    super.key,
    required this.type,
    required this.onTaskAdded,
    this.task,
  });

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late bool _isPerpetual;
  late FrequencyType _frequencyType;
  late int _weeklyTarget;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _durationController = TextEditingController(text: widget.task?.durationDays.toString() ?? '30');
    _isPerpetual = widget.task?.isPerpetual ?? false;
    _frequencyType = widget.task?.frequencyType ?? FrequencyType.daily;
    _weeklyTarget = widget.task?.weeklyTarget ?? 3;
  }

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
            widget.task == null ? 'Add ${widget.type == TaskType.daily ? 'Daily' : 'Temporary'} Task' : 'Edit Task',
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
            Row(
              children: [
                Expanded(
                  child: _buildChoiceChip(
                    label: 'Every Day',
                    selected: _frequencyType == FrequencyType.daily,
                    onSelected: (s) => setState(() => _frequencyType = FrequencyType.daily),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChoiceChip(
                    label: 'Weekly Goal',
                    selected: _frequencyType == FrequencyType.weekly,
                    onSelected: (s) => setState(() => _frequencyType = FrequencyType.weekly),
                  ),
                ),
              ],
            ),
            if (_frequencyType == FrequencyType.weekly) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sessions per week', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                          Text('Target to hit per 7 days', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _weeklyTarget > 1 ? () => setState(() => _weeklyTarget--) : null,
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                        ),
                        Text('$_weeklyTarget', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        IconButton(
                          onPressed: _weeklyTarget < 7 ? () => setState(() => _weeklyTarget++) : null,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
                  child: Text(widget.task == null ? 'Save Task' : 'Update Task'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({required String label, required bool selected, required Function(bool) onSelected}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Container(
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? (isDark ? Colors.black : Colors.white) : Theme.of(context).colorScheme.onSurface)),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: isDark ? Colors.white : Colors.black,
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
    );
  }

  Future<void> _saveTask() async {
    final String taskName = _nameController.text.trim();
    if (taskName.isEmpty) return;

    if (widget.task != null) {
      // V8 UPDATE: Simple update logic for existing tasks
      final updated = Task(
        id: widget.task!.id,
        name: taskName,
        type: widget.task!.type,
        isPerpetual: widget.task!.type == TaskType.daily ? _isPerpetual : false,
        durationDays: widget.task!.type == TaskType.daily && !_isPerpetual
            ? (int.tryParse(_durationController.text) ?? 30)
            : 0,
        createdAt: widget.task!.createdAt,
        isActive: widget.task!.isActive,
        frequencyType: _frequencyType,
        weeklyTarget: _weeklyTarget,
      );
      await DatabaseService.instance.updateTask(updated);
      widget.onTaskAdded();
      if (mounted) Navigator.pop(context);
      return;
    }

    // --- HABIT REVIVAL CHECK (Only for new tasks) ---
    final existing = await DatabaseService.instance.findDuplicateTask(taskName);
    
    if (existing != null) {
      if (mounted) {
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Habit Already Exists', style: TextStyle(fontWeight: FontWeight.w900)),
            content: Text('You have a history with "${existing.name}". Would you like to revive your old progress or start fresh?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'restart'),
                child: const Text('RESTART FRESH', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'revive'),
                child: const Text('REVIVE PROGRESS'),
              ),
            ],
          ),
        );

        if (action == null || action == 'cancel') return;

        if (action == 'revive') {
          // Revival: Just reactivate the existing task
          final revived = Task(
            id: existing.id,
            name: existing.name,
            type: existing.type,
            durationDays: existing.durationDays,
            isPerpetual: existing.isPerpetual,
            createdAt: existing.createdAt, // Keep original start date
            isActive: true,
            frequencyType: _frequencyType,
            weeklyTarget: _weeklyTarget,
          );
          await DatabaseService.instance.updateTask(revived);
          widget.onTaskAdded();
          if (mounted) Navigator.pop(context);
          return;
        }

        if (action == 'restart') {
          // Restart: Rename the old one to avoid naming conflict
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
          // Continue to create new one below...
        }
      }
    }

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch,
      name: taskName,
      type: widget.type,
      isPerpetual: widget.type == TaskType.daily ? _isPerpetual : false,
      durationDays: widget.type == TaskType.daily && !_isPerpetual
          ? (int.tryParse(_durationController.text) ?? 30)
          : 0,
      createdAt: DateTime.now(),
      frequencyType: _frequencyType,
      weeklyTarget: _weeklyTarget,
    );

    await DatabaseService.instance.addTask(newTask);
    widget.onTaskAdded();
    if (mounted) Navigator.of(context).pop();
  }
}
