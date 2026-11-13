import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/dashboard_controller.dart';
import '../models/task_model.dart';
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
  bool _showPomodoro = false;

  Color _getTimerAccentColor(BuildContext context, String mode) {
    switch (mode) {
      case 'focus':
        return Theme.of(context).colorScheme.primary;
      case 'shortBreak':
        return const Color(0xFF10B981);
      case 'longBreak':
        return const Color(0xFF60A5FA);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatTimerTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

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

        // Pomodoro State
        final int timerSeconds = widget.controller.timerSecondsRemaining;
        final bool isTimerRunning = widget.controller.isTimerRunning;
        final String timerMode = widget.controller.timerMode;
        final Color timerAccentColor = _getTimerAccentColor(context, timerMode);
        final int totalDuration = widget.controller.timerDurations[timerMode] ?? (25 * 60);
        final bool hasActiveTimer = isTimerRunning || (timerSeconds < totalDuration);

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
                      child: _buildHeader(
                        context,
                        isDark,
                        primaryColor,
                        urgencyColor,
                        pendingTasks.length,
                        isTimerRunning,
                        timerAccentColor,
                        timerSeconds,
                      ),
                    ),

                    if (_showPomodoro)
                      Expanded(
                        child: _buildFullPomodoroView(context, isDark, primaryColor, timerAccentColor),
                      )
                    else ...[
                      // 2. COLLAPSIBLE MINI POMODORO BAR (When timer active, placed above progress)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        child: hasActiveTimer
                            ? _buildMiniPomodoroBar(context, isDark, timerAccentColor)
                            : const SizedBox.shrink(),
                      ),

                      // 2.5 MOMENTUM PROGRESS BAR
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
                    ],

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
    bool isTimerRunning,
    Color timerAccentColor,
    int timerSeconds,
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

          // POMODORO TIMER TOGGLE
          IconButton(
            iconSize: AppIconSize.md,
            splashRadius: 16,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: _showPomodoro
                ? 'Back to Tasks'
                : (isTimerRunning
                    ? 'Pomodoro Active (${_formatTimerTime(timerSeconds)})'
                    : 'Pomodoro Timer'),
            icon: Icon(
              _showPomodoro
                  ? Icons.checklist_rounded
                  : (isTimerRunning ? Icons.timer_rounded : Icons.timer_outlined),
              color: (_showPomodoro || isTimerRunning)
                  ? timerAccentColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _showPomodoro = !_showPomodoro),
          ),

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
                    }
                  } else {
                    await widget.controller.toggleTaskCompletion(task, isDone);
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

  Widget _buildMiniPomodoroBar(
    BuildContext context,
    bool isDark,
    Color accentColor,
  ) {
    final controller = widget.controller;
    final isRunning = controller.isTimerRunning;
    final seconds = controller.timerSecondsRemaining;
    final mode = controller.timerMode;
    final modeLabel = mode == 'focus'
        ? 'Focus'
        : (mode == 'shortBreak' ? 'Short Break' : 'Long Break');

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xxs, AppSpacing.sm, AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: accentColor.withValues(alpha: isRunning ? 0.35 : 0.2),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Mode badge & live countdown (tap anywhere on this side to expand)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showPomodoro = true),
              child: Row(
                children: [
                  Icon(
                    isRunning ? Icons.hourglass_top_rounded : Icons.pause_circle_outline_rounded,
                    size: 15,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    modeLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: accentColor.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimerTime(seconds),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Play/Pause button
          PressScale(
            onTap: controller.toggleTimer,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 16,
                color: accentColor,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Expand to Full Timer
          IconButton(
            iconSize: 16,
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Expand Focus Mode',
            icon: Icon(
              Icons.open_in_full_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _showPomodoro = true),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPomodoroView(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color accentColor,
  ) {
    final controller = widget.controller;
    final seconds = controller.timerSecondsRemaining;
    final isRunning = controller.isTimerRunning;
    final mode = controller.timerMode;
    final goal = controller.todayRecord.pomodoroGoal;
    final completed = controller.todayRecord.pomodoroSessionsCompleted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xs),

          // 1. MODE SELECTOR PILLS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPomodoroModeChip(context, 'Focus', 'focus', mode, accentColor),
              const SizedBox(width: 6),
              _buildPomodoroModeChip(context, 'Short Break', 'shortBreak', mode, accentColor),
              const SizedBox(width: 6),
              _buildPomodoroModeChip(context, 'Long Break', 'longBreak', mode, accentColor),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 2. BIG HERO DIGITAL TIMER (Clickable to play/pause)
          GestureDetector(
            onTap: controller.toggleTimer,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  _formatTimerTime(seconds),
                  style: GoogleFonts.inter(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2.0,
                    color: isRunning ? accentColor : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isRunning
                      ? (mode == 'focus' ? 'Deep Work in Progress' : 'Resting & Recharging')
                      : 'Tap to ${seconds == (controller.timerDurations[mode] ?? 1500) ? 'Start' : 'Resume'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 3. MAIN CONTROLS (Reset, Play/Pause, Settings - Outlined, No Glow)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset Button
              IconButton(
                iconSize: 20,
                splashRadius: 18,
                tooltip: 'Reset Timer',
                icon: Icon(
                  Icons.refresh_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                onPressed: controller.resetTimer,
              ),

              const SizedBox(width: AppSpacing.md),

              // Main Play/Pause Button (Outlined, No Glow)
              PressScale(
                onTap: controller.toggleTimer,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isRunning ? Icons.pause_outlined : Icons.play_arrow_outlined,
                    size: 28,
                    color: accentColor,
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Settings Button
              IconButton(
                iconSize: 20,
                splashRadius: 18,
                tooltip: 'Timer Settings',
                icon: Icon(
                  Icons.tune_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                onPressed: () => _showTimerSettingsDialog(context, controller),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 4. DAILY SESSIONS PROGRESS (Dots only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(goal, (index) {
                final isDone = index < completed;
                return Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? accentColor : Colors.transparent,
                    border: Border.all(
                      color: isDone
                          ? accentColor
                          : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 5. RETURN TO TASKS BUTTON
          PressScale(
            onTap: () => setState(() => _showPomodoro = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Back to Tasks',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPomodoroModeChip(
    BuildContext context,
    String label,
    String modeId,
    String currentMode,
    Color accentColor,
  ) {
    final isSelected = currentMode == modeId;
    return GestureDetector(
      onTap: () => widget.controller.setTimerMode(modeId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? accentColor.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: isSelected
                ? accentColor
                : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  void _showTimerSettingsDialog(BuildContext context, DashboardController controller) {
    final focusController = TextEditingController(text: (controller.timerDurations['focus']! ~/ 60).toString());
    final shortController = TextEditingController(text: (controller.timerDurations['shortBreak']! ~/ 60).toString());
    final longController = TextEditingController(text: (controller.timerDurations['longBreak']! ~/ 60).toString());
    final goalController = TextEditingController(text: controller.todayRecord.pomodoroGoal.toString());

    showMotionDialog(
      context: context,
      child: AlertDialog(
        title: const Text('Timer Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDurationField('Focus Duration (mins)', focusController),
            _buildDurationField('Short Break (mins)', shortController),
            _buildDurationField('Long Break (mins)', longController),
            _buildDurationField('Daily Session Goal', goalController),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.updateTimerSettings(
                int.tryParse(focusController.text) ?? 25,
                int.tryParse(shortController.text) ?? 5,
                int.tryParse(longController.text) ?? 15,
                int.tryParse(goalController.text) ?? 4,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationField(String label, TextEditingController textController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextField(
        controller: textController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
