// lib/widgets/panels/task_panel.dart

import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/dashboard_layout_controller.dart';
import '../../models/task_model.dart';
import '../../widgets/task_section.dart';
import '../../widgets/add_task_bottom_sheet.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_icon_size.dart';

import '../../utils/motion_dialog.dart';

class TaskPanel extends StatefulWidget {
  final DashboardController controller;
  final DashboardLayoutController layoutController;
  final BoxConstraints constraints;
  
  const TaskPanel({
    super.key, 
    required this.controller, 
    required this.layoutController,
    required this.constraints
  });

  static List<Widget> getActions(BuildContext context, DashboardController controller, DashboardLayoutController layoutController) {
    return [
      _TaskAddAction(controller: controller, layoutController: layoutController),
      const SizedBox(width: AppSpacing.xs),
      _TaskCheatAction(controller: controller),
    ];
  }

  @override
  State<TaskPanel> createState() => _TaskPanelState();
}

class _TaskPanelState extends State<TaskPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = widget.layoutController.taskTabIndex;
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        widget.layoutController.setTaskTabIndex(_tabController.index);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final date = widget.controller.selectedDate;
    final now = DateTime.now();
    final isToday = date.day == now.day && date.month == now.month && date.year == now.year;

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final String dayName = weekdays[date.weekday - 1];
    final String dateStr = "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";

    return Column(
      children: [
        // INTEGRATED DATE INDICATOR
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              Text(
                "$dayName, $dateStr",
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w900, 
                  color: isToday ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.primary,
                  letterSpacing: -0.2
                ),
              ),
              if (!isToday) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    "History", 
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)
                  ),
                ),
              ],
            ],
          ),
        ),

        // TABS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                _buildInnerPillTab('Daily', 0),
                _buildInnerPillTab('Temporary', 1),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildTaskSection(TaskType.daily),
              _buildTaskSection(TaskType.temporary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskSection(TaskType type) {
    return TaskSection(
      title: '', 
      type: type, 
      tasks: widget.controller.todaysTasks, 
      dayRecord: widget.controller.todayRecord,
      history: widget.controller.allRecords, // Pass history
      onAddPressed: () {}, 
      onCheatPressed: null,
      onToggleCompletion: _handleToggleTask, 
      onToggleSkip: (task) => widget.controller.toggleTaskSkip(task),
      onEdit: (t) => _editTask(t), 
      onReorder: (oldIndex, newIndex) {
        widget.controller.reorderTasksWithinType(type, oldIndex, newIndex);
      },
      onDelete: (t) async {
        final result = await showMotionDialog<String>(
          context: context,
          child: AlertDialog(
            title: const Text('Manage Task'),
            content: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: <TextSpan>[
                  TextSpan(text: 'Remove "${t.name}"?\n'),
                  const TextSpan(text: 'Archive to hide it while keeping history.\n\n'), // Added extra \n
                  TextSpan(text: 'Delete to permanently erase all data.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive'),
                onPressed: () => Navigator.pop(context, 'archive'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete'), // Changed from 'Delete Permanently'
                onPressed: () => Navigator.pop(context, 'deletePermanently'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (result == 'archive') {
          widget.controller.deleteTask(t.sid); // This now calls archiveTask
        } else if (result == 'deletePermanently') {
          if (!mounted) return;
          final confirmPermanentDelete = await showMotionDialog<bool>(
            context: context,
            child: AlertDialog(
              title: const Text('Confirm Permanent Deletion'),
              content: Text('Permanently delete this task and all its progress?\n\nThis cannot be undone.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)), // Changed from 'Delete Permanently'
                ),
              ],
            ),
          );
          if (confirmPermanentDelete == true) {
            widget.controller.deleteTaskPermanently(t.sid);
          }
        }
      },      onTaskFocusRequested: (_) {}, showTitle: false, isEmbedded: true,
    );
  }

  void _handleToggleTask(Task task, bool? completed) async {
    final isDone = completed ?? false;
    if (widget.controller.isCheatDayConflict(isDone)) {
      final confirm = await showMotionDialog<bool>(context: context, child: AlertDialog(title: const Text('Resume Day?'), content: const Text('Checking off a task will reclaim token?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resume'))]));
      if (confirm == true) await widget.controller.toggleTaskCompletion(task, isDone, reclaimCheat: true);
    } else {
      await widget.controller.toggleTaskCompletion(task, isDone);
    }
  }

  void _editTask(Task task) async {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      showDragHandle: true,
      builder: (_) => AddTaskBottomSheet(
        type: task.type, 
        task: task, // V8: Pass the task to edit
        initialDate: widget.controller.selectedDate, // V12: Pass selected date
        onTaskAdded: () => widget.controller.initialize(widget.controller.selectedDate, showLoading: false)
      )
    );
  }

  Widget _buildInnerPillTab(String label, int index) {
    final isSelected = _tabController.index == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: GestureDetector(onTap: () => _tabController.animateTo(index), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))] : null), child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant)))));
  }
}

class _TaskAddAction extends StatelessWidget {
  final DashboardController controller;
  final DashboardLayoutController layoutController; // V9: Access current tab
  const _TaskAddAction({required this.controller, required this.layoutController});

  @override
  Widget build(BuildContext context) {
    final currentType = layoutController.taskTabIndex == 0 ? TaskType.daily : TaskType.temporary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FilledButton.icon(
        onPressed: () => showModalBottomSheet(
          context: context, 
          isScrollControlled: true, 
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          enableDrag: true,
          showDragHandle: true,
          builder: (_) => AddTaskBottomSheet(
            type: currentType, 
            initialDate: controller.selectedDate, // V12: Pass selected date
            onTaskAdded: () => controller.initialize(controller.selectedDate, showLoading: false)
          )
        ),
        icon: const Icon(Icons.add_rounded, size: AppIconSize.lg),
        label: const Text(
          'ADD TASK', 
          style: TextStyle(
            fontSize: 10, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.0
          )
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          // Background is handled by Theme primary via FilledButton
        ),
      ),
    );
  }
}

class _TaskCheatAction extends StatelessWidget {
  final DashboardController controller;
  const _TaskCheatAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isCheatUsed = controller.todayRecord.cheatUsed;
    final int tokens = (controller.currentUser?.monthlyCheatDays ?? 0) - controller.cheatDaysUsed;
    final bool canUseCheat = controller.selectedDate.day == DateTime.now().day && tokens > 0 && controller.todayRecord.completedTaskIds.isEmpty && !isCheatUsed;
    final Color mainColor = isCheatUsed ? Theme.of(context).colorScheme.tertiary : (canUseCheat ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onSurfaceVariant);

    return GestureDetector(
      onTap: canUseCheat ? () => _onDeclareCheatDay(context) : (isCheatUsed ? () => _onUndoCheatDay(context) : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: isCheatUsed ? Theme.of(context).colorScheme.tertiary : mainColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: mainColor.withValues(alpha: 0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isCheatUsed ? Icons.celebration_rounded : Icons.celebration_outlined, size: AppIconSize.xs, color: isCheatUsed ? Colors.white : mainColor),
          const SizedBox(width: 6),
          Text(isCheatUsed ? 'Used' : 'Cheat ($tokens)', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isCheatUsed ? Colors.white : mainColor, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  void _onUndoCheatDay(BuildContext context) async {
    final confirm = await showMotionDialog<bool>(context: context, child: AlertDialog(title: const Text('Undo Cheat Day?'), content: const Text('Reclaim token?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Undo', style: TextStyle(color: Theme.of(context).colorScheme.tertiary)))]));
    if (confirm == true) await controller.undoCheatDay();
  }

  void _onDeclareCheatDay(BuildContext context) async {
    final confirm = await showMotionDialog<bool>(context: context, child: AlertDialog(title: const Text('Use Cheat Day?'), content: const Text('Use a token?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Use Token', style: TextStyle(color: Theme.of(context).colorScheme.tertiary)))]));
    if (confirm == true) await controller.claimCheatDay();
  }
}
