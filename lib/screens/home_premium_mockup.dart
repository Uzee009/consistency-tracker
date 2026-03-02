// lib/screens/home_premium_mockup.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../controllers/dashboard_controller.dart';
import '../screens/task_form_screen.dart';
import '../screens/analytics_explorer_screen.dart';
import '../models/task_model.dart';
import '../services/style_service.dart';
import '../widgets/task_section.dart';
import '../widgets/add_task_bottom_sheet.dart';
import '../widgets/consistency_heatmap.dart';
import '../widgets/user_menu.dart';
import '../main.dart';

class HomePremiumMockup extends StatefulWidget {
  const HomePremiumMockup({super.key});

  @override
  State<HomePremiumMockup> createState() => _HomePremiumMockupState();
}

class _HomePremiumMockupState extends State<HomePremiumMockup> with TickerProviderStateMixin {
  final DashboardController _controller = DashboardController();
  late TabController _tabController;
  late AnimationController _jiggleController;
  
  DateTime _viewedMonth = DateTime.now();
  Key _heatmapKey = UniqueKey();

  // Modular State
  bool _isEditMode = false;
  List<String> _moduleOrder = ['tasks', 'calendar'];

  // Resize State
  double _taskSectionWidth = 850; 
  final double _minTaskWidth = 500;
  final double _minSidebarWidth = 350;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _jiggleController.reverse();
        else if (status == AnimationStatus.dismissed) _jiggleController.forward();
      });

    _controller.initialize(DateTime.now());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jiggleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _jiggleController.forward();
      } else {
        _jiggleController.stop();
        _jiggleController.reset();
      }
    });
  }

  void _handleResize(DragUpdateDetails details) {
    setState(() {
      final isTaskFirst = _moduleOrder.first == 'tasks';
      _taskSectionWidth += isTaskFirst ? details.delta.dx : -details.delta.dx;
      _taskSectionWidth = _taskSectionWidth.clamp(_minTaskWidth, double.infinity);
    });
  }

  void _swapModules(String draggedId, String targetId) {
    if (draggedId == targetId) return;
    setState(() {
      final draggedIndex = _moduleOrder.indexOf(draggedId);
      final targetIndex = _moduleOrder.indexOf(targetId);
      final temp = _moduleOrder[draggedIndex];
      _moduleOrder[draggedIndex] = _moduleOrder[targetIndex];
      _moduleOrder[targetIndex] = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return ValueListenableBuilder<VisualStyle>(
          valueListenable: styleNotifier,
          builder: (context, style, _) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final screenWidth = MediaQuery.of(context).size.width;
            
            final maxPossibleTaskWidth = screenWidth - _minSidebarWidth - 64 - 48; 
            if (_taskSectionWidth > maxPossibleTaskWidth) {
              _taskSectionWidth = maxPossibleTaskWidth;
            }

            return Scaffold(
              body: Column(
                children: [
                  _buildGlobalHeader(context),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  
                  Expanded(
                    child: _controller.isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: _buildModularLayout(context, isDark),
                          ),
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildModularLayout(BuildContext context, bool isDark) {
    List<Widget> widgets = [];
    for (int i = 0; i < _moduleOrder.length; i++) {
      final moduleId = _moduleOrder[i];
      final bool isFirst = i == 0;

      if (moduleId == 'tasks') {
        widgets.add(
          SizedBox(
            width: _taskSectionWidth,
            child: _buildReorderableWrapper(id: 'tasks', child: _buildTaskWorkspace(context)),
          ),
        );
      } else {
        widgets.add(
          Expanded(
            child: _buildReorderableWrapper(id: 'calendar', child: _buildSidebarCalendar(context)),
          ),
        );
      }

      if (isFirst) widgets.add(_buildResizerHandle(isDark));
    }
    return widgets;
  }

  Widget _buildReorderableWrapper({required String id, required Widget child}) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != id,
      onAcceptWithDetails: (details) => _swapModules(details.data, id),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<String>(
          data: id,
          maxSimultaneousDrags: _isEditMode ? 1 : 0,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: id == 'tasks' ? _taskSectionWidth : 400,
              height: 600,
              child: Opacity(opacity: 0.8, child: child),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.2, child: child),
          child: AnimatedBuilder(
            animation: _jiggleController,
            builder: (context, child) {
              // SUBTLE JIGGLE (0.002 instead of 0.005)
              final rotation = _isEditMode 
                  ? (math.sin(_jiggleController.value * math.pi * 2) * 0.002) 
                  : 0.0;
              
              return Transform.rotate(
                angle: rotation,
                child: Stack(
                  children: [
                    child!,
                    if (_isEditMode) ...[
                      // DRAG HANDLE (Top Center)
                      Positioned(
                        top: 12, left: 0, right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                            ),
                            child: const Icon(Icons.drag_indicator_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      // DELETE/CLOSE INDICATOR
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildResizerHandle(bool isDark) {
    if (_isEditMode) return const SizedBox(width: 16); 
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onPanUpdate: _handleResize,
        child: Container(
          width: 16, color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2, height: 60,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64, padding: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark ? const Color(0xFF09090B) : Colors.white,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _buildPillTab(context, 'Dashboard', Icons.dashboard_rounded, true, () {}),
            _buildPillTab(context, 'Explorer', Icons.explore_rounded, false, () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsExplorerScreen()));
            }),
            _buildPillTab(context, 'Focus', Icons.timer_rounded, false, () {}),
          ]),
        ),
        const Spacer(),
        _buildHeaderIconButton(
          context, 
          _isEditMode ? Icons.check_circle_outline_rounded : Icons.edit_note_rounded, 
          _isEditMode ? 'Done' : 'Customize Layout', 
          _isEditMode ? Colors.green : Theme.of(context).colorScheme.onSurface, 
          _toggleEditMode
        ),
        const SizedBox(width: 12),
        UserMenu(currentUser: _controller.currentUser, onSettingsReturn: () => _controller.initialize(_controller.selectedDate)),
      ]),
    );
  }

  Widget _buildSidebarCalendar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = _controller.selectedDate.year == now.year && _controller.selectedDate.month == now.month && _controller.selectedDate.day == now.day;
    final isCurrentMonth = _viewedMonth.year == now.year && _viewedMonth.month == now.month;
    
    return Container(
      decoration: BoxDecoration(
        color: StyleService.getHeatmapBg(styleNotifier.value, isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(children: [
            Text('MONTHLY STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey[500])),
            const Spacer(),
            if (!isCurrentMonth)
              _buildHeaderIconButton(context, Icons.refresh_rounded, 'Reset Month', Theme.of(context).colorScheme.primary, () {
                setState(() { _heatmapKey = UniqueKey(); _viewedMonth = DateTime.now(); });
              }),
            if (!isToday) ...[
              const SizedBox(width: 8),
              _buildSidebarHeaderAction('GO TO TODAY', () {
                _controller.setSelectedDate(DateTime.now());
                setState(() { _heatmapKey = UniqueKey(); _viewedMonth = DateTime.now(); });
              }),
            ],
            if (isToday && isCurrentMonth)
              const Icon(Icons.calendar_month_rounded, size: 14, color: Colors.grey),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: ConsistencyHeatmap(
            key: _heatmapKey,
            heatmapData: _controller.heatmapData,
            selectedDate: _controller.selectedDate,
            onDateSelected: (date) => _controller.setSelectedDate(date, showLoading: false),
            onMonthChanged: (m) => setState(() => _viewedMonth = m),
            selectedRange: '1M', 
 onRangeChanged: (_) {}, hideControls: true,
          ),
        )),
      ]),
    );
  }

  Widget _buildTaskWorkspace(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final displayDateStr = "${months[_controller.selectedDate.month - 1].toUpperCase()} ${_controller.selectedDate.day}";
    final displayDayStr = weekdays[_controller.selectedDate.weekday - 1].toUpperCase();
    final isToday = _controller.selectedDate.year == DateTime.now().year && _controller.selectedDate.month == DateTime.now().month && _controller.selectedDate.day == DateTime.now().day;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$displayDayStr, $displayDateStr', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(isToday ? 'TODAY\'S MISSION' : 'VIEWING HISTORY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isToday ? Colors.grey[500] : Theme.of(context).colorScheme.primary, letterSpacing: 1)),
            ]),
            const Spacer(),
            _buildHeaderIconButton(context, Icons.add_rounded, 'Add Task', Theme.of(context).colorScheme.onSurface, () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => AddTaskBottomSheet(type: _tabController.index == 0 ? TaskType.daily : TaskType.temporary, onTaskAdded: () => _controller.initialize(_controller.selectedDate)))),
            const SizedBox(width: 12),
            _buildCheatDayAction(context, isToday),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [_buildInnerPillTab(context, 'Habits', 0), _buildInnerPillTab(context, 'Temporary', 1)]),
          ),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: TabBarView(controller: _tabController, children: [
            TaskSection(title: 'DAILY', type: TaskType.daily, tasks: _controller.todaysTasks, dayRecord: _controller.todayRecord, onAddPressed: () {}, onCheatPressed: null, onToggleCompletion: _handleToggleTask, onToggleSkip: (task) => _controller.toggleTaskSkip(task), onEdit: (t) => _editTask(t), onDelete: (t) => _deleteTask(t), onTaskFocusRequested: (_) {}, showTitle: false, isEmbedded: true),
            TaskSection(title: 'TEMP', type: TaskType.temporary, tasks: _controller.todaysTasks, dayRecord: _controller.todayRecord, onAddPressed: () {}, onCheatPressed: null, onToggleCompletion: _handleToggleTask, onToggleSkip: (task) => _controller.toggleTaskSkip(task), onEdit: (t) => _editTask(t), onDelete: (t) => _deleteTask(t), onTaskFocusRequested: (_) {}, showTitle: false, isEmbedded: true),
          ]),
        )),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _handleToggleTask(Task task, bool? completed) async {
    final isDone = completed ?? false;
    if (_controller.isCheatDayConflict(isDone)) {
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Resume Day?'),
        content: const Text('Checking off a task will reclaim your cheat token and resume scoring for today. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resume', style: TextStyle(color: Colors.orange))),
        ],
      ));
      if (confirm == true) await _controller.toggleTaskCompletion(task, isDone, reclaimCheat: true);
    } else {
      // Lazy refresh: we don't call initialize() immediately if we just want to save.
      // But the controller needs to save. I'll stick to current for now but optimize controller later.
      await _controller.toggleTaskCompletion(task, isDone);
    }
  }

  Widget _buildCheatDayAction(BuildContext context, bool isToday) {
    final bool isCheatUsed = _controller.todayRecord.cheatUsed;
    final int tokens = (_controller.currentUser?.monthlyCheatDays ?? 0) - _controller.cheatDaysUsed;
    final bool canUseCheat = isToday && tokens > 0 && _controller.todayRecord.completedTaskIds.isEmpty && !isCheatUsed;
    final Color mainColor = isCheatUsed ? Colors.orange : (canUseCheat ? Colors.orange : Colors.grey[400]!);
    return GestureDetector(
      onTap: isToday ? (isCheatUsed ? _onUndoCheatDay : (canUseCheat ? _onDeclareCheatDayPressed : null)) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isCheatUsed ? Colors.orange : mainColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: mainColor.withValues(alpha: 0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isCheatUsed ? Icons.celebration_rounded : Icons.celebration_outlined, size: 14, color: isCheatUsed ? Colors.white : mainColor),
          const SizedBox(width: 8),
          Text(isCheatUsed ? 'USED' : 'CHEAT ($tokens)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isCheatUsed ? Colors.white : mainColor, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  void _onUndoCheatDay() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Undo Cheat Day?'),
      content: const Text('Do you want to reclaim your token and resume today\'s habits?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Undo', style: TextStyle(color: Colors.orange))),
      ],
    ));
    if (confirm == true) await _controller.undoCheatDay();
  }

  void _onDeclareCheatDayPressed() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Use Cheat Day?'),
      content: const Text('Use a token to preserve your streak?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use Token', style: TextStyle(color: Colors.orange))),
      ],
    ));
    if (confirm == true) await _controller.claimCheatDay();
  }

  Widget _buildSidebarHeaderAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }

  Widget _buildHeaderIconButton(BuildContext context, IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(message: tooltip, child: Material(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: color.withValues(alpha: 0.6), size: 18)))));
  }

  Widget _buildInnerPillTab(BuildContext context, String label, int index) {
    final isSelected = _tabController.index == index;
    return Expanded(child: GestureDetector(onTap: () => _tabController.animateTo(index), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))] : null), child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey[500])))));
  }

  void _editTask(Task task) async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskFormScreen(task: task))); _controller.initialize(_controller.selectedDate); }
  void _deleteTask(Task task) async { final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Task?'), content: Text('Delete "${task.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))])); if (confirm == true) await _controller.deleteTask(task.id); }

  Widget _buildPillTab(BuildContext context, String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))] : null), child: Row(children: [Icon(icon, size: 16, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[500]), const SizedBox(width: 8), Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey[500]))])));
  }
}
