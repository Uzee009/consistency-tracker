import 'package:flutter/material.dart';
import '../models/task_model.dart';

class TaskItem extends StatelessWidget {
  final Task task;
  final bool isCompleted;
  final bool isSkipped;
  final Function(bool?) onToggleCompletion;
  final VoidCallback onToggleSkip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskItem({
    super.key,
    required this.task,
    required this.isCompleted,
    required this.isSkipped,
    required this.onToggleCompletion,
    required this.onToggleSkip,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01)),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isCompleted,
              onChanged: onToggleCompletion,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: Colors.deepPurple,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCompleted ? FontWeight.w400 : FontWeight.w500,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted 
                        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3)
                        : (isSkipped ? Colors.orange.withOpacity(0.8) : Theme.of(context).colorScheme.onSurface),
                    fontStyle: isSkipped ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (!isCompleted) ...[
            _buildActionButton(
              icon: isSkipped ? Icons.remove_circle : Icons.remove_circle_outline,
              color: isSkipped ? Colors.orange : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              tooltip: 'Skip',
              onPressed: onToggleSkip,
            ),
            _buildActionButton(
              icon: Icons.edit_outlined,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            _buildActionButton(
              icon: Icons.delete_outline,
              color: Colors.red.withOpacity(0.4),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
