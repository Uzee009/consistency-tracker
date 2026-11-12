import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/dashboard_controller.dart';
import '../models/task_model.dart';
import '../services/audio_service.dart';
import '../services/window_mode_service.dart';
import '../services/badge_service.dart';
import '../services/scoring_service.dart';
import '../services/quote_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_icon_size.dart';
import '../widgets/motion/press_scale.dart';
import '../widgets/add_task_bottom_sheet.dart';
import '../utils/motion_dialog.dart';

class DesktopWidgetView extends StatefulWidget {
  final DashboardController controller;

  const DesktopWidgetView({
    super.key,
    required this.controller,
  });

  @override
  State<DesktopWidgetView> createState() => _DesktopWidgetViewState();
}

class _DesktopWidgetViewState extends State<DesktopWidgetView> {
  bool _completedExpanded = false;

  Color _getUrgencyColor(int pendingCount) {
    if (pendingCount <= 0) return const Color(0xFF10B981); // Green complete
    final hour = DateTime.now().hour;
    if (hour < 12) return const Color(0xFF3B82F6); // Fresh morning blue
    if (hour < 16) return const Color(0xFFEAB308); // Midday yellow
    if (hour < BadgeService.instance.eodHour) return const Color(0xFFF97316); // Late afternoon orange
    return const Color(0xFFEF4444); // Evening red urgency
  }

  String _getUrgencyLabel(int pendingCount) {
    if (pendingCount <= 0) return 'All tasks completed!';
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning focus';
    if (hour < 16) return 'Midday progress';
    if (hour < BadgeService.instance.eodHour) return 'Afternoon push';
    return 'End of day countdown';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final allTasks = widget.controller.todaysTasks;
        final completedIds = widget.controller.todayRecord.completedTaskIds;
        final skippedIds = widget.controller.todayRecord.skippedTaskIds;

        final pendingTasks = allTasks.where((t) => !completedIds.contains(t.sid) && !skippedIds.contains(t.sid)).toList();
        final completedTasks = allTasks.where((t) => completedIds.contains(t.sid)).toList();
        final skippedTasks = allTasks.where((t) => skippedIds.contains(t.sid)).toList();

        final int totalTasks = allTasks.length;
        final int doneCount = completedTasks.length;
        final double progress = totalTasks > 0 ? (doneCount / totalTasks).clamp(0.0, 1.0) : 0.0;
        final urgencyColor = _getUrgencyColor(pendingTasks.length);
        final streak = widget.controller.analytics.currentStreak;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: DragToResizeArea(
            resizeEdgeSize: 8,
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.xxs),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. DRAGGABLE TITLE BAR & QUICK CONTROLS
                    DragToMoveArea(
                      child: _buildHeader(context, isDark, primaryColor, urgencyColor, pendingTasks.length),
                    ),

                    // 2. MOMENTUM PROGRESS BAR
                    _buildProgressBar(context, isDark, primaryColor, progress, doneCount, totalTasks),

                    // 3. TASK LIST HEADER WITH COMPACT ADD BUTTONS
                    _buildTaskListHeader(context, isDark, primaryColor),

                    // 4. SCROLLABLE TASK LIST
                    Expanded(
                      child: allTasks.isEmpty
                          ? _buildEmptyState(context, isDark)
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              children: [
                                if (pendingTasks.isNotEmpty) ...[
                                  ...pendingTasks.map((t) => _buildTaskRow(context, t, isDark, false, false)),
                                ],

                                if (skippedTasks.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxs),
                                    child: Text(
                                      'SKIPPED (${skippedTasks.length})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  ...skippedTasks.map((t) => _buildTaskRow(context, t, isDark, false, true)),
                                ],

                                if (completedTasks.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  _buildCompletedAccordionHeader(context, isDark, completedTasks.length),
                                  if (_completedExpanded) ...[
                                    ...completedTasks.map((t) => _buildTaskRow(context, t, isDark, true, false)),
                                  ],
                                ],
                              ],
                            ),
                    ),

                    // 5. BOTTOM ENCOURAGEMENT & QUOTES BAR (Step 19F)
                    _buildQuoteBottomBar(context, isDark, streak, pendingTasks.length, progress >= 1.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color urgencyColor,
    int pendingCount,
  ) {
    final streak = widget.controller.analytics.currentStreak;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // STREAK BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: const Color(0xFFF97316).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '${streak}d',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.xs),

          // URGENCY PULSE DOT & STATUS
          Tooltip(
            excludeFromSemantics: true,
            message: _getUrgencyLabel(pendingCount),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: urgencyColor.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  pendingCount == 0 ? 'Done' : '$pendingCount left',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // CONTROLS (Pin, Expand, Close to Tray)
          ValueListenableBuilder<bool>(
            valueListenable: WindowModeService.instance.isPinnedNotifier,
            builder: (context, isPinned, _) {
              return IconButton(
                iconSize: AppIconSize.md,
                splashRadius: 16,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: isPinned ? 'Always on Top (Active)' : 'Pin on Top',
                icon: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: isPinned ? primaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () => WindowModeService.instance.togglePin(),
              );
            },
          ),

          IconButton(
            iconSize: AppIconSize.md,
            splashRadius: 16,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Expand to Full Dashboard',
            icon: Icon(
              Icons.open_in_full_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => WindowModeService.instance.switchToDashboard(),
          ),

          IconButton(
            iconSize: AppIconSize.md,
            splashRadius: 16,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Hide to System Tray',
            icon: Icon(
              Icons.close_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => WindowModeService.instance.hideToTray(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    double progress,
    int doneCount,
    int totalCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TODAY\'S PROGRESS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '$doneCount / $totalCount (${(progress * 100).toInt()}%)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0 ? const Color(0xFF10B981) : primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskListHeader(BuildContext context, bool isDark, Color primaryColor) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.sm, 2),
      child: Row(
        children: [
          Text(
            'TASKS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          // + HABIT PILL
          PressScale(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => _openOriginalTaskSheet(TaskType.daily),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  color: primaryColor.withValues(alpha: 0.1),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: AppIconSize.xs, color: primaryColor),
                    const SizedBox(width: 3),
                    Text(
                      'Habit',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // + TEMP PILL
          PressScale(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => _openOriginalTaskSheet(TaskType.temporary),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on_rounded, size: AppIconSize.xs, color: Color(0xFFD97706)),
                    SizedBox(width: 3),
                    Text(
                      'Temp',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(
    BuildContext context,
    Task task,
    bool isDark,
    bool isCompleted,
    bool isSkipped,
  ) {
    final theme = Theme.of(context);
    final isTemp = task.type == TaskType.temporary;

    // Weekly progress info if weekly frequency
    final weeklyProgress = ScoringService.getWeeklyProgress(
      task,
      widget.controller.selectedDate,
      widget.controller.allRecords,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02))
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isCompleted
              ? Colors.transparent
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          // CHECKBOX
          PressScale(
            child: Transform.scale(
              scale: 0.9,
              child: Checkbox(
                value: isCompleted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                activeColor: theme.colorScheme.primary,
                onChanged: (val) async {
                  final isDone = val ?? false;
                  if (widget.controller.isCheatDayConflict(isDone)) {
                    final confirm = await showMotionDialog<bool>(
                      context: context,
                      child: AlertDialog(
                        title: const Text('Resume Day?'),
                        content: const Text('Checking off a task will reclaim token?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resume')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await widget.controller.toggleTaskCompletion(task, isDone, reclaimCheat: true);
                      if (isDone) {
                        AudioService.instance.playSound(AudioType.goalReached);
                      }
                    }
                  } else {
                    await widget.controller.toggleTaskCompletion(task, isDone);
                    if (isDone) {
                      AudioService.instance.playSound(AudioType.goalReached);
                    }
                  }
                },
              ),
            ),
          ),

          // TASK TITLE & BADGES
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final isDone = !isCompleted;
                await widget.controller.toggleTaskCompletion(task, isDone);
                if (isDone) {
                  AudioService.instance.playSound(AudioType.goalReached);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isCompleted ? FontWeight.w400 : FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (isTemp || task.frequencyType == FrequencyType.weekly) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isTemp)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'TEMP',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        if (task.frequencyType == FrequencyType.weekly)
                          Text(
                            '${weeklyProgress.sessionsCompleted}/${task.weeklyTarget} this wk',
                            style: TextStyle(
                              fontSize: 10,
                              color: weeklyProgress.isGoalMet
                                  ? const Color(0xFF10B981)
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // SKIP / MENU ACTION
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: AppIconSize.sm,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'skip',
                height: 36,
                child: Row(
                  children: [
                    Icon(
                      isSkipped ? Icons.undo_rounded : Icons.skip_next_rounded,
                      size: AppIconSize.md,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSkipped ? 'Unskip Task' : 'Skip Today',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                height: 36,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: AppIconSize.md),
                    SizedBox(width: 8),
                    Text('Edit Task', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'skip') {
                widget.controller.toggleTaskSkip(task);
              } else if (val == 'edit') {
                _openOriginalTaskSheet(task.type, task: task);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedAccordionHeader(BuildContext context, bool isDark, int count) {
    return GestureDetector(
      onTap: () => setState(() => _completedExpanded = !_completedExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              _completedExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
              size: AppIconSize.md,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'COMPLETED ($count)',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            const Text(
              '✓',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: AppIconSize.xxl * 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No tasks scheduled for today',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the + Habit or + Temp buttons above to add one.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteBottomBar(
    BuildContext context,
    bool isDark,
    int streak,
    int pendingCount,
    bool isCompleted,
  ) {
    final theme = Theme.of(context);
    final quote = QuoteService.instance.getQuote(
      streak: streak,
      pendingTasks: pendingCount,
      isCompleted: isCompleted,
    );

    return Tooltip(
      excludeFromSemantics: true,
      message: 'Tap to rotate quote',
      child: GestureDetector(
        onTap: () => setState(() => QuoteService.instance.nextQuote()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 6),
                child: Icon(
                  Icons.format_quote_rounded,
                  size: 14,
                  color: isCompleted
                      ? const Color(0xFF10B981)
                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
              Expanded(
                child: Text(
                  quote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openOriginalTaskSheet(TaskType type, {Task? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => AddTaskBottomSheet(
        type: type,
        task: task,
        initialDate: widget.controller.selectedDate,
        onTaskAdded: () {
          widget.controller.initialize(widget.controller.selectedDate, showLoading: false);
        },
      ),
    );
  }
}
