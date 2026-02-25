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

    return Container(
      margin: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.5),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Colors.blueGrey,
                  ),
                ),
                Row(
                  children: [
                    if (type == TaskType.daily && onCheatPressed != null)
                      _buildHeaderButton(
                        label: 'Cheat Day',
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
                      icon: Icons.add_rounded,
                      color: Colors.blueGrey[600]!,
                      tooltip: 'Add Task',
                      onPressed: onAddPressed,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          Expanded(
            child: filteredTasks.isEmpty
                ? Center(
                    child: Text(
                      'No tasks yet',
                      style: TextStyle(color: Colors.blueGrey[300], fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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

  Widget _buildHeaderButton({
    required IconData icon,
    String? label,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(icon, size: 20, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
