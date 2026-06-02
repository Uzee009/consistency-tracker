import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/database_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_icon_size.dart';
import 'motion/press_scale.dart';
import 'motion/cursor_glow.dart';

class AddTaskBottomSheet extends StatefulWidget {
  final TaskType type;
  final VoidCallback onTaskAdded;
  final Task? task; // V8: Optional task for editing
  final DateTime? initialDate; // V12: Date to start task from

  const AddTaskBottomSheet({
    super.key,
    required this.type,
    required this.onTaskAdded,
    this.task,
    this.initialDate,
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
  late bool _autoCheck; // V12: Auto-check for historical dates

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _durationController = TextEditingController(text: widget.task?.durationDays.toString() ?? '30');
    _isPerpetual = widget.task?.isPerpetual ?? false;
    _frequencyType = widget.task?.frequencyType ?? FrequencyType.daily;
    _weeklyTarget = widget.task?.weeklyTarget ?? 3;
    
    // Default autoCheck to true if we are adding a new task to a historical date
    final isToday = widget.initialDate == null || 
                    (widget.initialDate!.day == DateTime.now().day && 
                     widget.initialDate!.month == DateTime.now().month && 
                     widget.initialDate!.year == DateTime.now().year);
    _autoCheck = !isToday && widget.task == null;
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
    final isToday = widget.initialDate == null || 
                    (widget.initialDate!.day == DateTime.now().day && 
                     widget.initialDate!.month == DateTime.now().month && 
                     widget.initialDate!.year == DateTime.now().year);
    final dateStr = widget.initialDate != null 
        ? "${widget.initialDate!.day}/${widget.initialDate!.month}/${widget.initialDate!.year}"
        : "Today";

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        top: AppSpacing.xs,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppSpacing.xxxl,
                height: AppSpacing.xxs,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
            if (!isToday && widget.task == null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1), // Amber[500]
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: AppIconSize.md, color: Color(0xFFF59E0B)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Adding task starting from $dateStr',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              widget.task == null ? 'Add ${widget.type == TaskType.daily ? 'Daily' : 'Temporary'} Task' : 'Edit Task',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Define your new consistency goal below.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Task Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: AppSpacing.xs),
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
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Every Day',
                      selected: _frequencyType == FrequencyType.daily,
                      onSelected: (s) => setState(() => _frequencyType = FrequencyType.daily),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
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
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
                            icon: const Icon(Icons.remove_circle_outline, size: AppIconSize.xl),
                          ),
                          Text('$_weeklyTarget', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          IconButton(
                            onPressed: _weeklyTarget < 7 ? () => setState(() => _weeklyTarget++) : null,
                            icon: const Icon(Icons.add_circle_outline, size: AppIconSize.xl),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Duration in Days',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: AppSpacing.xs),
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
            if (!isToday && widget.task == null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Mark as Completed',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  subtitle: Text('Log completion for $dateStr', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                  value: _autoCheck,
                  activeTrackColor: isDark ? Colors.white : Colors.black,
                  inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                  onChanged: (value) => setState(() => _autoCheck = value),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PressScale(
                    child: CursorGlow(
                      radius: 80,
                      maxOpacity: 0.12,
                      child: ElevatedButton(
                        onPressed: _saveTask,
                        child: Text(widget.task == null ? 'Save Task' : 'Update Task'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: BorderSide.none),
    );
  }

  Future<void> _saveTask() async {
    final String taskName = _nameController.text.trim();
    if (taskName.isEmpty) return;

    if (widget.task != null) {
      // V8 UPDATE: Simple update logic for existing tasks
      final updated = Task(
        sid: widget.task!.sid,
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
                child: Text('RESTART FRESH', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
            sid: existing.sid,
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

          if (_autoCheck && widget.initialDate != null) {
             await _handleAutoCheck(revived.sid);
          }

          widget.onTaskAdded();
          if (mounted) Navigator.pop(context);
          return;
        }

        if (action == 'restart') {
          // Restart: Rename the old one to avoid naming conflict
          final dateStr = DateTime.now().toIso8601String().split('T')[0];
          final archived = Task(
            sid: existing.sid,
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
      sid: const Uuid().v4(),
      name: taskName,
      type: widget.type,
      isPerpetual: widget.type == TaskType.daily ? _isPerpetual : false,
      durationDays: widget.type == TaskType.daily && !_isPerpetual
          ? (int.tryParse(_durationController.text) ?? 30)
          : 0,
      createdAt: widget.initialDate ?? DateTime.now(), // V12: Use initialDate
      frequencyType: _frequencyType,
      weeklyTarget: _weeklyTarget,
    );

    await DatabaseService.instance.addTask(newTask);

    if (_autoCheck && widget.initialDate != null) {
      await _handleAutoCheck(newTask.sid);
    }

    widget.onTaskAdded();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleAutoCheck(String taskSid) async {
    final date = widget.initialDate!;
    final dateFormatted = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final record = await DatabaseService.instance.getDayRecord(dateFormatted) ??
                  DayRecord(date: dateFormatted, completedTaskIds: [], skippedTaskIds: []);

    if (!record.completedTaskIds.contains(taskSid)) {
      final updatedIds = List<String>.from(record.completedTaskIds)..add(taskSid);
      final updatedSkipped = List<String>.from(record.skippedTaskIds)..remove(taskSid);

      // We don't have direct access to DashboardController here easily without context,
      // but we can update the DB directly. The callback widget.onTaskAdded() will trigger the refresh.
      final updatedRecord = record.copyWith(
        completedTaskIds: updatedIds,
        skippedTaskIds: updatedSkipped,
      );
      await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
    }
  }
}
