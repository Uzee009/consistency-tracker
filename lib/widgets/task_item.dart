import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/style_service.dart';
import '../services/scoring_service.dart';
import '../main.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_icon_size.dart';
import '../theme/motion.dart';
import '../utils/motion_accessibility.dart';
import 'motion/press_scale.dart';
import 'motion/hover_lift.dart';
import 'motion/cursor_glow.dart';

class TaskItem extends StatefulWidget {
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
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: Motion.base,
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.18).chain(CurveTween(curve: Motion.emphasized)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.0).chain(CurveTween(curve: Motion.standardEase)),
        weight: 50,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(TaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted && !oldWidget.isCompleted) {
      _bounceController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;
    final accessibility = MotionAccessibility.of(context);

    // Sync duration with accessibility settings
    _bounceController.duration = accessibility.apply(Motion.base);
    
    // Weekly Progress Logic
    final progress = ScoringService.getWeeklyProgress(widget.task, widget.selectedDate, widget.history);
    final bool isGoalMet = progress.isGoalMet;
    final bool isOptional = !progress.isRequiredToday && !isGoalMet && widget.task.frequencyType == FrequencyType.weekly;
    
    // Dimming Logic: Dim if completed, goal already met for the week, or skipped.
    final bool isDimmed = widget.isCompleted || isGoalMet || widget.isSkipped;

    return AnimatedOpacity(
      duration: accessibility.apply(Motion.medium),
      opacity: isDimmed ? 0.4 : 1.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: HoverLift(
          liftPx: 2,
          hoverElevation: 6,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: CursorGlow(
            maxOpacity: 0.025,
            child: AnimatedContainer(
              duration: accessibility.apply(Motion.medium),
              curve: Motion.standardEase,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs, horizontal: AppSpacing.xxs),
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: widget.isCompleted 
                    ? Colors.transparent 
                    : StyleService.getTaskItemBg(style, isDark, widget.task.type),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: widget.isCompleted 
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
                  child: AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      final scale = accessibility.reduce ? 1.0 : _bounceAnimation.value;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Checkbox(
                      value: widget.isCompleted,
                      onChanged: widget.isSkipped ? null : widget.onToggleCompletion,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      activeColor: isDark ? Colors.white : Colors.black,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: widget.isSkipped ? 0.1 : 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
                    child: InkWell(
                      onTap: widget.isSkipped ? null : () => widget.onToggleCompletion(!widget.isCompleted),
                      onLongPress: widget.onFocusRequested,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _toTitleCase(widget.task.name),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: (widget.isCompleted || widget.isSkipped) ? FontWeight.w400 : FontWeight.w600,
                                decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
                                color: widget.isCompleted 
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                                    : (widget.isSkipped 
                                       ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8) 
                                       : Theme.of(context).colorScheme.onSurface),
                                fontStyle: widget.isSkipped ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                            if (widget.task.frequencyType == FrequencyType.weekly) ...[
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
                ),
                AnimatedOpacity(
                  opacity: accessibility.reduce ? 1.0 : (_isHovered ? 0.85 : 0.0),
                  duration: Motion.fast,
                  curve: Motion.standardEase,
                  child: PressScale(
                    child: PopupMenuButton<String>(
                      tooltip: 'More actions',
                      onSelected: _handleMenuAction,
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
                      itemBuilder: (context) => _buildMenuItems(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    return [
      PopupMenuItem<String>(
        value: 'skip',
        enabled: !widget.isCompleted,
        child: Row(
          children: [
            Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: widget.isCompleted 
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              widget.isSkipped ? 'Unskip' : 'Skip',
              style: TextStyle(
                color: widget.isCompleted 
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
    ];
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'skip':
        widget.onToggleSkip();
        break;
      case 'edit':
        widget.onEdit();
        break;
      case 'delete':
        widget.onDelete();
        break;
    }
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: _buildMenuItems(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
    if (result != null) {
      _handleMenuAction(result);
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((str) {
      if (str.isEmpty) return str;
      return '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
