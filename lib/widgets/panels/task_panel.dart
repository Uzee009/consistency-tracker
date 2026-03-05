// lib/widgets/panels/task_panel.dart

import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../models/task_model.dart';
import '../../widgets/task_section.dart';
import '../../widgets/add_task_bottom_sheet.dart';
import '../../screens/task_form_screen.dart';

class TaskPanel extends StatefulWidget {
  final DashboardController controller;
  final BoxConstraints constraints;
  
  const TaskPanel({super.key, required this.controller, required this.constraints});

  static List<Widget> getActions(BuildContext context, DashboardController controller) {
    return [
      _TaskAddAction(controller: controller),
      const SizedBox(width: 8),
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
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // MANDATORY DATE HEADER (V6/V7)
        _buildMandatoryDateHeader(),
        
        const SizedBox(height: 12), // Header to content gap

        // TABS (Always visible)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [_buildInnerPillTab('Habits', 0), _buildInnerPillTab('Temporary', 1)]),
          ),
        ),

        // LIST
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTaskSection(TaskType.daily),
              _buildTaskSection(TaskType.temporary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMandatoryDateHeader() {
    final date = widget.controller.selectedDate;
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    final String dayName = weekdays[date.weekday - 1];
    final String dayStr = date.day.toString().padLeft(2, '0');
    final String monthStr = date.month.toString().padLeft(2, '0');
    final String yearStr = date.year.toString();

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SELECTED MISSION",
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[500], letterSpacing: 1),
            ),
            Text(
              "$dayName, $dayStr-$monthStr-$yearStr",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskSection(TaskType type) {
    return TaskSection(
      title: '', type: type, tasks: widget.controller.todaysTasks, dayRecord: widget.controller.todayRecord,
      onAddPressed: () {}, onCheatPressed: null,
      onToggleCompletion: _handleToggleTask, onToggleSkip: (task) => widget.controller.toggleTaskSkip(task),
      onEdit: (t) => _editTask(t), onDelete: (t) => widget.controller.deleteTask(t.id),
      onTaskFocusRequested: (_) {}, showTitle: false, isEmbedded: true,
    );
  }

  void _handleToggleTask(Task task, bool? completed) async {
    final isDone = completed ?? false;
    if (widget.controller.isCheatDayConflict(isDone)) {
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Resume Day?'), content: const Text('Checking off a task will reclaim token?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resume'))]));
      if (confirm == true) await widget.controller.toggleTaskCompletion(task, isDone, reclaimCheat: true);
    } else {
      await widget.controller.toggleTaskCompletion(task, isDone);
    }
  }

  void _editTask(Task task) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)));
    widget.controller.initialize(widget.controller.selectedDate);
  }

  Widget _buildInnerPillTab(String label, int index) {
    final isSelected = _tabController.index == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: GestureDetector(onTap: () => _tabController.animateTo(index), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))] : null), child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey[500])))));
  }
}

class _TaskAddAction extends StatelessWidget {
  final DashboardController controller;
  const _TaskAddAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Add Task',
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => AddTaskBottomSheet(type: TaskType.daily, onTaskAdded: () => controller.initialize(controller.selectedDate))),
          borderRadius: BorderRadius.circular(8),
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add_rounded, size: 16, color: Colors.grey)),
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
    final Color mainColor = isCheatUsed ? Colors.orange : (canUseCheat ? Colors.orange : Colors.grey[400]!);

    return GestureDetector(
      onTap: canUseCheat ? () => _onDeclareCheatDay(context) : (isCheatUsed ? () => _onUndoCheatDay(context) : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: isCheatUsed ? Colors.orange : mainColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: mainColor.withValues(alpha: 0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isCheatUsed ? Icons.celebration_rounded : Icons.celebration_outlined, size: 12, color: isCheatUsed ? Colors.white : mainColor),
          const SizedBox(width: 6),
          Text(isCheatUsed ? 'USED' : 'CHEAT ($tokens)', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isCheatUsed ? Colors.white : mainColor, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  void _onUndoCheatDay(BuildContext context) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Undo Cheat Day?'), content: const Text('Reclaim token?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Undo', style: TextStyle(color: Colors.orange)))]));
    if (confirm == true) await controller.undoCheatDay();
  }

  void _onDeclareCheatDay(BuildContext context) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Use Cheat Day?'), content: const Text('Use a token?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use Token', style: TextStyle(color: Colors.orange)))]));
    if (confirm == true) await controller.claimCheatDay();
  }
}
