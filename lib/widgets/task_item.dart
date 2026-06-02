import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/style_service.dart';
import '../services/scoring_service.dart';
import '../main.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_icon_size.dart';

class TaskItem extends StatelessWidget {
  final Task task;
  final List<DayRecord> history;
  final DateTime selectedDate;
  final bool isCompleted;
  final bool isSkipped;
  final Function(bool?) onToggleCompletion;
  final VoidCallback onToggleSkip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFocusRequested;

  const TaskItem({
    super.key,
    required this.task,
    this.history = const [],
    required this.selectedDate,
    required this.isCompleted,
    required this.isSkipped,
    required this.onToggleCompletion,
    required this.onToggleSkip,
    required this.onEdit,
    required this.onDelete,
    required this.onFocusRequested,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;
    
    // Weekly Progress Logic
    final progress = ScoringService.getWeeklyProgress(task, selectedDate, history);
    final bool isGoalMet = progress.isGoalMet;
    final bool isOptional = !progress.isRequiredToday && !isGoalMet && task.frequencyType == FrequencyType.weekly;
    
    // Dimming Logic: Dim if completed, goal already met for the week, or skipped.
    final bool isDimmed = isCompleted || isGoalMet || isSkipped;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDimmed ? 0.4 : 1.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs, horizontal: AppSpacing.xxs),
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isCompleted 
                ? Colors.transparent 
                : StyleService.getTaskItemBg(style, isDark, task.type),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isCompleted 
                  ? Colors.transparent 
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
              width: 1,
            ),
          ),
        child: Row(
          children: [
            SizedBox(
              width: AppSpacing.xl,
              height: AppSpacing.xl,
              child: Checkbox(
                value: isCompleted,
                onChanged: isSkipped ? null : onToggleCompletion,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                activeColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: isSkipped ? 0.1 : 0.4),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                onTap: isSkipped ? null : () => onToggleCompletion(!isCompleted),
                onLongPress: onFocusRequested,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _toTitleCase(task.name),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (isCompleted || isSkipped) ? FontWeight.w400 : FontWeight.w600,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted 
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                              : (isSkipped 
                                 ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8) 
                                 : Theme.of(context).colorScheme.onSurface),
                          fontStyle: isSkipped ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      if (task.frequencyType == FrequencyType.weekly) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              isGoalMet 
                                  ? 'Goal Met' 
                                  : '(${progress.sessionsCompleted}/${progress.sessionsTarget}) sessions',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isGoalMet 
                                    ? const Color(0xFF10B981) 
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            if (!isGoalMet) ...[
                              Text(
                                ' • ',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), fontSize: 10),
                              ),
                              Text(
                                '${progress.daysRemainingInWeek + 1} days left',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: progress.isRequiredToday 
                                      ? Theme.of(context).colorScheme.error 
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                            if (isOptional && !isGoalMet) ...[
                               const SizedBox(width: 6),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                 decoration: BoxDecoration(
                                   color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(AppRadius.xs),
                                 ),
                                 child: Text('OPTIONAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                               ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (value) {
                switch (value) {
                  case 'skip':
                    onToggleSkip();
                    break;
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Material(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                shape: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.more_vert,
                    size: AppIconSize.md,
                    color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.7),
                  ),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'skip',
                  enabled: !isCompleted,
                  child: Row(
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        size: 20,
                        color: isCompleted 
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isSkipped ? 'Unskip' : 'Skip',
                        style: TextStyle(
                          color: isCompleted 
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Edit',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          ),
          ),
          ),
          );
          }
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((str) {
      if (str.isEmpty) return str;
      return '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
