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
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: isCompleted 
            ? Colors.transparent 
            : (isDark ? const Color(0xFF27272A) : Colors.white),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isCompleted 
              ? Colors.transparent 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isCompleted,
              onChanged: onToggleCompletion,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              activeColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCompleted ? FontWeight.w400 : FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted 
                        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3)
                        : (isSkipped ? Colors.orange[400] : Theme.of(context).colorScheme.onSurface),
                    fontStyle: isSkipped ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (!isCompleted) ...[
            _buildActionButton(
              context,
              icon: isSkipped ? Icons.remove_circle : Icons.remove_circle_outline,
              color: isSkipped ? Colors.orange[400]! : (isDark ? Colors.white : Colors.black),
              bgColor: isSkipped ? Colors.orange.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
              tooltip: 'Skip',
              onPressed: onToggleSkip,
            ),
            const SizedBox(width: 6),
            _buildActionButton(
              context,
              icon: Icons.edit_outlined,
              color: isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.7),
              bgColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            const SizedBox(width: 6),
            _buildActionButton(
              context,
              icon: Icons.delete_outline,
              color: Colors.red[400]!,
              bgColor: Colors.red.withOpacity(0.1),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
