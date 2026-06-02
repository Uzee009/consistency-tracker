import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/style_service.dart';
import '../main.dart';
import 'task_item.dart';
import 'empty_state.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_icon_size.dart';
import '../theme/motion.dart';
import '../utils/motion_accessibility.dart';
import 'motion/animated_tooltip.dart';
import 'motion/staggered_entry.dart';

class TaskSection extends StatefulWidget {
  final String title;
  final TaskType type;
  final List<Task> tasks;
  final DayRecord dayRecord;
  final List<DayRecord> history; // V10: Pass history for weekly logic
  final VoidCallback onAddPressed;
  final VoidCallback? onCheatPressed;
  final Function(Task, bool?) onToggleCompletion;
  final Function(Task) onToggleSkip;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final Function(Task) onTaskFocusRequested;
  final Function(int oldIndex, int newIndex)? onReorder;
  final bool showTitle;
  final bool isEmbedded;

  const TaskSection({
    super.key,
    required this.title,
    required this.type,
    required this.tasks,
    required this.dayRecord,
    this.history = const [],
    required this.onAddPressed,
    this.onCheatPressed,
    required this.onToggleCompletion,
    required this.onToggleSkip,
    required this.onEdit,
    required this.onDelete,
    required this.onTaskFocusRequested,
    this.onReorder,
    this.showTitle = true,
    this.isEmbedded = false,
  });

  @override
  State<TaskSection> createState() => _TaskSectionState();
}

class _TaskSectionState extends State<TaskSection> {
  int? _hoverIndex;

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final accessibility = MotionAccessibility.of(context);
        if (accessibility.reduce) return child!;

        final double animValue = Motion.emphasized.transform(animation.value);
        final double scale = lerpDouble(1.0, 1.03, animValue)!;
        final double elevation = lerpDouble(0.0, 8.0, animValue)!;
        final double rotation = lerpDouble(0.0, math.pi / 360, animValue)!; // 0.5 degrees

        return Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: Material(
              elevation: elevation,
              color: Colors.transparent,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = widget.tasks.where((task) => task.type == widget.type).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;
    final accessibility = MotionAccessibility.of(context);

    // Use StyleService backgrounds even if embedded to maintain visual identity
    final bgColor = widget.type == TaskType.daily 
        ? StyleService.getDailyTaskBg(style, isDark)
        : StyleService.getTempTaskBg(style, isDark);
    
    final borderColor = widget.isEmbedded
        ? Colors.transparent
        : (widget.type == TaskType.daily
            ? StyleService.getDailyTaskBorder(style, isDark)
            : StyleService.getTempTaskBorder(style, isDark));

    return Container(
      margin: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.xs),
      decoration: widget.isEmbedded 
        ? const BoxDecoration(color: Colors.transparent) // V6 Seamless
        : BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
          if (widget.showTitle)
            Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Row(
                  children: [
                    if (widget.type == TaskType.daily && widget.onCheatPressed != null)
                      _buildHeaderButton(
                        context,
                        label: 'CHEAT',
                        icon: Icons.celebration_outlined,
                        color: widget.dayRecord.completedTaskIds.isNotEmpty
                            ? (isDark ? Colors.white10 : Colors.black12)
                            : Theme.of(context).colorScheme.tertiary,
                        tooltip: widget.dayRecord.completedTaskIds.isNotEmpty
                            ? 'Cheat Day locked'
                            : 'Declare Cheat Day',
                        onPressed: widget.onCheatPressed!,
                      ),
                    const SizedBox(width: AppSpacing.xxs),
                    _buildHeaderButton(
                      context,
                      icon: Icons.add_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      tooltip: 'Add Task',
                      onPressed: widget.onAddPressed,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.showTitle) const Divider(),
          Expanded(
            child: filteredTasks.isEmpty
                ? const EmptyState(
                    icon: Icons.checklist_outlined,
                    title: 'No tasks yet',
                    subtitle: 'Tap + to add your first one.',
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs, horizontal: AppSpacing.xs),
                    itemCount: filteredTasks.length,
                    onReorder: widget.onReorder ?? (_, __) {},
                    buildDefaultDragHandles: false,
                    physics: const BouncingScrollPhysics(),
                    proxyDecorator: _proxyDecorator,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      final isCompleted =
                          widget.dayRecord.completedTaskIds.contains(task.sid);
                      final isSkipped =
                          widget.dayRecord.skippedTaskIds.contains(task.sid);

                      return StaggeredEntry(
                        key: ValueKey(task.sid),
                        index: index,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoverIndex = index),
                          onExit: (_) => setState(() => _hoverIndex = null),
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: AnimatedOpacity(
                                        opacity: accessibility.reduce ? 0.7 : (_hoverIndex == index ? 0.7 : 0.0),
                                        duration: Motion.fast,
                                        curve: Motion.standardEase,
                                        child: Icon(
                                          Icons.drag_indicator,
                                          size: AppIconSize.md,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TaskItem(
                                    task: task,
                                    history: widget.history,
                                    selectedDate: DateTime.parse(widget.dayRecord.date),
                                    isCompleted: isCompleted,
                                    isSkipped: isSkipped,
                                    onToggleCompletion: (val) =>
                                        widget.onToggleCompletion(task, val),
                                    onToggleSkip: () => widget.onToggleSkip(task),
                                    onEdit: () => widget.onEdit(task),
                                    onDelete: () => widget.onDelete(task),
                                    onFocusRequested: () => widget.onTaskFocusRequested(task),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
    return AnimatedTooltip(
      message: tooltip,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
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
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Icon(icon, size: AppIconSize.md, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
