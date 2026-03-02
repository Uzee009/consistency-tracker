// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../controllers/dashboard_controller.dart';
import '../screens/task_form_screen.dart';
import '../services/style_service.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../widgets/task_section.dart';
import '../widgets/add_task_bottom_sheet.dart';
import '../widgets/consistency_heatmap.dart';
import '../widgets/analytics_kpis.dart';
import '../widgets/analytics_carousel.dart';
import '../widgets/pomodoro_timer.dart';
import '../widgets/user_menu.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardController _controller = DashboardController();

  @override
  void initState() {
    super.initState();
    _controller.initialize(DateTime.now());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _editTask(Task task) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)));
    _controller.initialize(_controller.selectedDate);
  }

  void _handleToggleTask(Task task, bool? completed) async {
    final isDone = completed ?? false;
    
    if (_controller.isCheatDayConflict(isDone)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resume Day?'),
          content: const Text('Checking off a task will reclaim your cheat token and resume scoring for today. Proceed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resume', style: TextStyle(color: Colors.orange))),
          ],
        ),
      );

      if (confirm == true) {
        await _controller.toggleTaskCompletion(task, isDone, reclaimCheat: true);
      }
    } else {
      await _controller.toggleTaskCompletion(task, isDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return ValueListenableBuilder<VisualStyle>(
          valueListenable: styleNotifier, // Fixed typo here
          builder: (context, style, _) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            
            return Scaffold(
              appBar: AppBar(
                title: const Text('CONSISTENCY'),
                centerTitle: true,
                actions: [
                  if (_controller.currentUser != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          children: [
                            if (_controller.todayRecord.cheatUsed)
                              const Tooltip(
                                message: 'Cheat Day active',
                                child: Icon(Icons.celebration, size: 12, color: Colors.orange),
                              )
                            else if (_controller.todayRecord.completedTaskIds.isNotEmpty)
                              Tooltip(
                                message: 'Cheat Day locked (tasks completed)',
                                child: Icon(Icons.lock_outline, size: 12, color: Colors.orange.withValues(alpha: 0.6)),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              'Tokens: ${(_controller.currentUser!.monthlyCheatDays - _controller.cheatDaysUsed).clamp(0, _controller.currentUser!.monthlyCheatDays)}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  UserMenu(
                    currentUser: _controller.currentUser,
                    onSettingsReturn: () => _controller.initialize(_controller.selectedDate),
                  ),
                ],
              ),
              body: _controller.isLoading 
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            // LEFT: Tabbed Task Section
                            Expanded(
                              flex: 1,
                              child: Container(
                                margin: const EdgeInsets.all(8.0),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: style == VisualStyle.vibrant ? Colors.transparent : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(color: StyleService.getDailyTaskBorder(style, isDark), width: 1),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _buildInternalHeader(context, 'TASKS', 'Manage your daily habits and one-off temporary goals here.'),
                                    Expanded(
                                      child: DefaultTabController(
                                        length: 2,
                                        child: Builder(
                                          builder: (context) {
                                            return Column(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 2,
                                                        child: Container(
                                                          height: 28,
                                                          padding: const EdgeInsets.all(2),
                                                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                                                          child: TabBar(
                                                            tabs: const [Tab(text: 'Daily'), Tab(text: 'Temp')],
                                                            labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                                                            unselectedLabelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                                                            indicatorSize: TabBarIndicatorSize.tab,
                                                            indicator: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(6)),
                                                            dividerColor: Colors.transparent,
                                                            labelColor: Theme.of(context).colorScheme.onSurface,
                                                            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                            splashFactory: NoSplash.splashFactory,
                                                            overlayColor: WidgetStateProperty.all(Colors.transparent),
                                                          ),
                                                        ),
                                                      ),
                                                      const Spacer(flex: 6),
                                                      Row(
                                                        children: [
                                                          if (_controller.todayRecord.cheatUsed)
                                                            _buildHeaderIconButton(context, icon: Icons.celebration, tooltip: 'Cheat Day Active', onPressed: _onUndoCheatDayPressed, color: Colors.orange)
                                                          else if (_controller.todayRecord.completedTaskIds.isNotEmpty)
                                                            Icon(Icons.lock_outline, size: 12, color: Colors.orange.withValues(alpha: 0.5))
                                                          else
                                                            _buildHeaderIconButton(context, icon: Icons.celebration_outlined, tooltip: 'Declare Cheat Day', onPressed: _onDeclareCheatDayPressed, color: Colors.orange[400]!),
                                                          const SizedBox(width: 8),
                                                          _buildHeaderIconButton(
                                                            context, icon: Icons.add_rounded, tooltip: 'Add Task',
                                                            onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => AddTaskBottomSheet(type: DefaultTabController.of(context).index == 0 ? TaskType.daily : TaskType.temporary, onTaskAdded: () => _controller.initialize(_controller.selectedDate))),
                                                            color: Theme.of(context).colorScheme.onSurface,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                                Expanded(
                                                  child: TabBarView(
                                                    children: [
                                                      TaskSection(
                                                        title: 'DAILY', type: TaskType.daily, tasks: _controller.todaysTasks, dayRecord: _controller.todayRecord,
                                                        onAddPressed: () {}, onCheatPressed: null,
                                                        onToggleCompletion: _handleToggleTask,
                                                        onToggleSkip: (t) => _controller.toggleTaskSkip(t),
                                                        onEdit: _editTask,
                                                        onDelete: (t) => _controller.deleteTask(t.id),
                                                        onTaskFocusRequested: (_) {}, showTitle: false, isEmbedded: true,
                                                      ),
                                                      TaskSection(
                                                        title: 'TEMP', type: TaskType.temporary, tasks: _controller.todaysTasks, dayRecord: _controller.todayRecord,
                                                        onAddPressed: () {}, onCheatPressed: null,
                                                        onToggleCompletion: _handleToggleTask,
                                                        onToggleSkip: (t) => _controller.toggleTaskSkip(t),
                                                        onEdit: _editTask,
                                                        onDelete: (t) => _controller.deleteTask(t.id),
                                                        onTaskFocusRequested: (_) {}, showTitle: false, isEmbedded: true,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // RIGHT: Pomodoro Timer Section
                            Expanded(
                              flex: 1,
                              child: Container(
                                margin: const EdgeInsets.all(8.0),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: StyleService.getHeatmapBg(style, isDark),
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(color: StyleService.getDailyTaskBorder(style, isDark), width: 1),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _buildInternalHeader(context, 'FOCUS ZONE', 'Use the Pomodoro timer to maintain deep focus on your tasks.'),
                                    const Expanded(child: PomodoroTimer()),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                margin: const EdgeInsets.all(8.0),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: StyleService.getHeatmapBg(style, isDark),
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(color: StyleService.getDailyTaskBorder(style, isDark), width: 1),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _buildInternalHeader(
                                      context, 'CONSISTENCY', 'Visual history of your daily discipline over time.',
                                      suffix: _buildHeatmapHeaderSuffix(context),
                                    ),
                                    Expanded(
                                      child: ConsistencyHeatmap(
                                        heatmapData: _controller.heatmapData,
                                        selectedDate: _controller.selectedDate,
                                        onDateSelected: (date) => _controller.setSelectedDate(date),
                                        focusedTaskName: _controller.focusedTask?.name,
                                        onClearFocus: () => _controller.setFocusedTask(null),
                                        selectedRange: _controller.heatmapRange,
                                        onRangeChanged: (range) => _controller.setHeatmapRange(range),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                margin: const EdgeInsets.all(8.0),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: StyleService.getHeatmapBg(style, isDark),
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(color: StyleService.getDailyTaskBorder(style, isDark), width: 1),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _buildInternalHeader(context, 'PERFORMANCE', 'Quantified trends of your habit mastery and output volume.'),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: AnalyticsKPIs(
                                              analytics: _controller.analytics, 
                                              isHorizontal: true,
                                              isFocused: _controller.focusedTask != null,
                                              isEmbedded: true,
                                            ),
                                          ),
                                          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), indent: 16, endIndent: 16),
                                          Expanded(
                                            flex: 8,
                                            child: AnalyticsCarousel(
                                              momentumData: _controller.momentumData,
                                              volumeData: _controller.volumeData,
                                              title: _controller.heatmapRange,
                                              focusedTaskName: _controller.focusedTask?.name,
                                              isEmbedded: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

  void _onDeclareCheatDayPressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Cheat Day?'),
        content: const Text('This will mark today as a "Cheat Day". Use one token?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use Token', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (confirm == true) {
      await _controller.claimCheatDay();
    }
  }

  void _onUndoCheatDayPressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume Day?'),
        content: const Text('Do you want to reclaim your cheat token and resume your habits?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resume', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (confirm == true) {
      await _controller.undoCheatDay();
    }
  }

  Widget _buildInternalHeader(BuildContext context, String title, String helpText, {Widget? suffix}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              const SizedBox(width: 6),
              Tooltip(message: helpText, triggerMode: TooltipTriggerMode.tap, child: Icon(Icons.info_outline_rounded, size: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2))),
              if (suffix != null) ...[const Spacer(), suffix],
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ],
    );
  }

  Widget _buildHeatmapHeaderSuffix(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final bool isViewingToday = _controller.selectedDate.year == now.year && _controller.selectedDate.month == now.month && _controller.selectedDate.day == now.day;
    final List<String> monthNamesShort = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final String dateString = "${_controller.selectedDate.day} ${monthNamesShort[_controller.selectedDate.month - 1]} ${_controller.selectedDate.year}";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_controller.focusedTask != null) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_controller.focusedTask!.name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface, letterSpacing: 0.5)),
              const SizedBox(width: 4),
              GestureDetector(onTap: () => _controller.setFocusedTask(null), child: Icon(Icons.close_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ]),
          ),
          const SizedBox(width: 12),
        ],
        if (!isViewingToday) ...[
          Text(dateString, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _controller.setSelectedDate(DateTime.now()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.today_rounded, size: 10, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 4),
                Text('TODAY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onPrimary, letterSpacing: 0.5)),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderIconButton(BuildContext context, {required IconData icon, required String tooltip, required VoidCallback onPressed, required Color color}) {
    return Tooltip(message: tooltip, child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(6), child: InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.all(6.0), child: Icon(icon, size: 16, color: color)))));
  }
}
