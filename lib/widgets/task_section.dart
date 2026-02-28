import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/style_service.dart';
import '../main.dart';
import 'task_item.dart';

class TaskSection extends StatelessWidget {
  final String title;
  final TaskType type;
  final List<Task> tasks;
  final DayRecord dayRecord;
  final VoidCallback onAddPressed;
  final VoidCallback? onCheatPressed;
  final Function(Task, bool?) onToggleCompletion;
  final Function(Task) onToggleSkip;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final Function(Task) onTaskFocusRequested;
  final bool showTitle;
  final bool isEmbedded;

  const TaskSection({
    super.key,
    required this.title,
    required this.type,
    required this.tasks,
    required this.dayRecord,
    required this.onAddPressed,
    this.onCheatPressed,
    required this.onToggleCompletion,
    required this.onToggleSkip,
    required this.onEdit,
    required this.onDelete,
    required this.onTaskFocusRequested,
    this.showTitle = true,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTasks = tasks.where((task) => task.type == type).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;

    // Use StyleService backgrounds even if embedded to maintain visual identity
    final bgColor = type == TaskType.daily 
        ? StyleService.getDailyTaskBg(style, isDark)
        : StyleService.getTempTaskBg(style, isDark);
    
    final borderColor = isEmbedded
        ? Colors.transparent
        : (type == TaskType.daily
            ? StyleService.getDailyTaskBorder(style, isDark)
            : StyleService.getTempTaskBorder(style, isDark));

    return Container(
      margin: isEmbedded ? EdgeInsets.zero : const EdgeInsets.all(8.0),
      decoration: isEmbedded 
        ? BoxDecoration(color: bgColor) // Only color when embedded, no border/shadow
        : BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Row(
                  children: [
                    if (type == TaskType.daily && onCheatPressed != null)
                      _buildHeaderButton(
                        context,
                        label: 'CHEAT',
                        icon: Icons.celebration_outlined,
                        color: dayRecord.completedTaskIds.isNotEmpty
                            ? (isDark ? Colors.white10 : Colors.black12)
                            : Colors.orange[400]!,
                        tooltip: dayRecord.completedTaskIds.isNotEmpty
                            ? 'Cheat Day locked'
                            : 'Declare Cheat Day',
                        onPressed: onCheatPressed!,
                      ),
                    const SizedBox(width: 4),
                    _buildHeaderButton(
                      context,
                      icon: Icons.add_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      tooltip: 'Add Task',
                      onPressed: onAddPressed,
                    ),
                  ],
                ),
              ],
                          ),
                        ),
                      if (showTitle) const Divider(),
                      Expanded(
                        child: filteredTasks.isEmpty
            
                ? Center(
                    child: Text(
                      'No tasks yet',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), fontSize: 13),
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
                        onFocusRequested: () => onTaskFocusRequested(task),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) ...[
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(icon, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
