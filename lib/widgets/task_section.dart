import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import 'task_item.dart';

class TaskSection extends StatelessWidget {
  final String title;
  final TaskType type;
  final Color bgColor;
  final Color borderColor;
  final List<Task> tasks;
  final DayRecord dayRecord;
  final VoidCallback onAddPressed;
  final VoidCallback? onCheatPressed;
  final Function(Task, bool?) onToggleCompletion;
  final Function(Task) onToggleSkip;
  final Function(Task) onEdit;
  final Function(Task) onDelete;

  const TaskSection({
    super.key,
    required this.title,
    required this.type,
    required this.bgColor,
    required this.borderColor,
    required this.tasks,
    required this.dayRecord,
    required this.onAddPressed,
    this.onCheatPressed,
    required this.onToggleCompletion,
    required this.onToggleSkip,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTasks = tasks.where((task) => task.type == type).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : bgColor.withOpacity(isDark ? 0.05 : 0.4),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isDark ? Colors.white10 : borderColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    if (type == TaskType.daily && onCheatPressed != null)
                      _buildHeaderButton(
                        context,
                        label: 'Cheat',
                        icon: Icons.celebration_outlined,
                        color: dayRecord.completedTaskIds.isNotEmpty
                            ? Colors.blueGrey[200]!
                            : Colors.orange[600]!,
                        tooltip: dayRecord.completedTaskIds.isNotEmpty
                            ? 'Cheat Day locked'
                            : 'Declare Cheat Day',
                        onPressed: onCheatPressed!,
                      ),
                    const SizedBox(width: 4),
                    _buildHeaderButton(
                      context,
                      icon: Icons.add_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      tooltip: 'Add Task',
                      onPressed: onAddPressed,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: filteredTasks.isEmpty
                ? Center(
                    child: Text(
                      'No tasks yet',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      final isCompleted =
                          dayRecord.completedTaskIds.contains(task.id);
                      final isSkipped =
                          dayRecord.skippedTaskIds.contains(task.id);

                      return TaskItem(
                        task: task,
                        isCompleted: isCompleted,
                        isSkipped: isSkipped,
                        onToggleCompletion: (val) =>
                            onToggleCompletion(task, val),
                        onToggleSkip: () => onToggleSkip(task),
                        onEdit: () => onEdit(task),
                        onDelete: () => onDelete(task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(
    BuildContext context, {
    required IconData icon,
    String? label,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) ...[
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(icon, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
