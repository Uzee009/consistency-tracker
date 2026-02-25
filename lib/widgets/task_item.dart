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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.white.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isCompleted ? Colors.transparent : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: 0.9,
            child: Checkbox(
              value: isCompleted,
              onChanged: onToggleCompletion,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: task.type == TaskType.daily ? Colors.blue[600] : Colors.amber[700],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCompleted ? FontWeight.w400 : FontWeight.w500,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted 
                        ? Colors.grey[400] 
                        : (isSkipped ? Colors.grey[500] : Colors.blueGrey[900]),
                    fontStyle: isSkipped ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (isSkipped)
                  const Text(
                    'Skipped',
                    style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          _buildActionButton(
            icon: isSkipped ? Icons.remove_circle : Icons.remove_circle_outline,
            color: isSkipped ? Colors.orange : Colors.blueGrey[400]!,
            tooltip: 'Skip',
            onPressed: onToggleSkip,
          ),
          _buildActionButton(
            icon: Icons.edit_outlined,
            color: Colors.blueGrey[400]!,
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          _buildActionButton(
            icon: Icons.delete_outline,
            color: Colors.red[300]!,
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
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
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
