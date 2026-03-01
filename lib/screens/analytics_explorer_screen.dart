// lib/screens/analytics_explorer_screen.dart

import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/database_service.dart';
import '../services/scoring_service.dart';
import '../services/style_service.dart';
import '../widgets/consistency_heatmap.dart';
import '../widgets/analytics_kpis.dart';
import '../widgets/analytics_carousel.dart';
import '../main.dart';

class AnalyticsExplorerScreen extends StatefulWidget {
  final Task? initialSelectedTask;

  const AnalyticsExplorerScreen({super.key, this.initialSelectedTask});

  @override
  State<AnalyticsExplorerScreen> createState() => _AnalyticsExplorerScreenState();
}

class _AnalyticsExplorerScreenState extends State<AnalyticsExplorerScreen> {
  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];
  Task? _selectedTask;
  String _searchQuery = '';
  int _activeCategoryIndex = 0; // 0: Daily, 1: Temp, 2: Archive
  
  // Analytics Data
  Map<DateTime, int> _heatmapData = {};
  AnalyticsResult _analytics = AnalyticsResult.empty();
  String _heatmapRange = '3M';
  List<MomentumPoint> _momentumData = [];
  List<VolumePoint> _volumeData = [];
  bool _isLoading = true;

  // Day Inspector State
  DateTime? _inspectedDate;
  DayRecord? _inspectedRecord;
  List<Task> _inspectedTasks = [];

  @override
  void initState() {
    super.initState();
    _selectedTask = widget.initialSelectedTask;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final tasks = await DatabaseService.instance.getAllTasks();
    
    if (mounted) {
      setState(() {
        _allTasks = tasks;
        _applyFilters();
        _isLoading = false;
      });
      _refreshAnalytics();
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTasks = _allTasks.where((task) {
        final matchesSearch = task.name.toLowerCase().contains(_searchQuery.toLowerCase());
        bool matchesCategory = false;
        
        if (_activeCategoryIndex == 0) {
          matchesCategory = task.isActive && task.type == TaskType.daily;
        } else if (_activeCategoryIndex == 1) {
          matchesCategory = task.isActive && task.type == TaskType.temporary;
        } else {
          matchesCategory = !task.isActive;
        }
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _refreshAnalytics() async {
    final allRecords = await DatabaseService.instance.getDayRecords(limit: 366);
    final allTasks = await DatabaseService.instance.getAllTasks();
    final taskTypeMap = {for (var t in allTasks) t.id: t.type};

    Map<DateTime, int> heatmapData;
    AnalyticsResult analytics;

    if (_selectedTask != null) {
      heatmapData = ScoringService.mapTaskRecordsToHeatmapData(allRecords, _selectedTask!.id);
      analytics = ScoringService.calculateAnalytics(allRecords, taskId: _selectedTask!.id);
    } else {
      heatmapData = ScoringService.mapRecordsToHeatmapData(allRecords);
      analytics = ScoringService.calculateAnalytics(allRecords, taskTypeMap: taskTypeMap);
    }

    final momentumData = ScoringService.calculateMomentumData(
      allRecords, 
      _heatmapRange, 
      taskId: _selectedTask?.id
    );
    final volumeData = ScoringService.calculateVolumeData(
      allRecords, 
      _heatmapRange, 
      taskTypeMap
    );

    if (mounted) {
      setState(() {
        _heatmapData = heatmapData;
        _analytics = analytics;
        _momentumData = momentumData;
        _volumeData = volumeData;
      });
    }
  }

  Future<void> _fetchInspectedDayData(DateTime date) async {
    final dateFormatted = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final record = await DatabaseService.instance.getDayRecord(dateFormatted) ?? 
        DayRecord(date: dateFormatted, completedTaskIds: [], skippedTaskIds: []);
    final tasks = await DatabaseService.instance.getActiveTasksForDate(date);

    if (mounted) {
      setState(() {
        _inspectedDate = date;
        _inspectedRecord = record;
        _inspectedTasks = tasks;
      });
    }
  }

  void _toggleTaskCompletion(Task task, bool completed) async {
    if (_inspectedRecord == null) return;

    List<int> updatedCompletedIds = List.from(_inspectedRecord!.completedTaskIds);
    List<int> updatedSkippedIds = List.from(_inspectedRecord!.skippedTaskIds);

    if (completed) {
      updatedCompletedIds.add(task.id);
      updatedSkippedIds.remove(task.id);
    } else {
      updatedCompletedIds.remove(task.id);
    }

    await _updateDayRecordInDb(updatedCompletedIds, updatedSkippedIds);
    
    await _fetchInspectedDayData(_inspectedDate!);
    await _refreshAnalytics();
  }

  Future<void> _updateDayRecordInDb(List<int> completedIds, List<int> skippedIds) async {
    final scoreResult = ScoringService.calculateDayScore(
      allTasks: _inspectedTasks, 
      dayRecord: DayRecord(
        date: _inspectedRecord!.date,
        completedTaskIds: completedIds,
        skippedTaskIds: skippedIds,
        cheatUsed: _inspectedRecord!.cheatUsed,
      ),
    );

    final updatedRecord = DayRecord(
      date: _inspectedRecord!.date,
      completedTaskIds: completedIds,
      skippedTaskIds: skippedIds,
      cheatUsed: _inspectedRecord!.cheatUsed,
      completionScore: scoreResult.completionScore,
      visualState: _inspectedRecord!.cheatUsed ? VisualState.cheat : scoreResult.visualState,
    );

    await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Column(
        children: [
          _buildGlobalHeader(context),
          Divider(
            height: 1, 
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)
          ),
          Expanded(
            child: Row(
              children: [
                // ZONE 2: Contextual Sidebar
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.1) : Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: TextField(
                          onChanged: (v) {
                            _searchQuery = v;
                            _applyFilters();
                          },
                          decoration: InputDecoration(
                            hintText: 'Search habits...',
                            prefixIcon: const Icon(Icons.search, size: 16),
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildHabitTile(null),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            _buildCategoryTab(0, 'Daily'),
                            _buildCategoryTab(1, 'Temp'),
                            _buildCategoryTab(2, 'Archive'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _filteredTasks.length,
                              itemBuilder: (context, index) => _buildHabitTile(_filteredTasks[index]),
                            ),
                      ),
                    ],
                  ),
                ),

                // ZONE 3: Workspace
                Expanded(
                  child: Container(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.02),
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailHeader(),
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 100,
                                child: AnalyticsKPIs(
                                  analytics: _analytics, 
                                  isHorizontal: true,
                                  isFocused: _selectedTask != null,
                                  isEmbedded: false,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildSectionContainer(
                                title: 'CONSISTENCY HEATMAP',
                                helpText: 'Click a day to inspect specific habits performed.',
                                child: SizedBox(
                                  height: 320,
                                  child: ConsistencyHeatmap(
                                    heatmapData: _heatmapData,
                                    selectedDate: _inspectedDate,
                                    onDateSelected: _fetchInspectedDayData,
                                    selectedRange: _heatmapRange,
                                    focusedTaskName: _selectedTask?.name,
                                    onRangeChanged: (range) {
                                      setState(() => _heatmapRange = range);
                                      _refreshAnalytics();
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildSectionContainer(
                                title: 'MOMENTUM & PERFORMANCE TRENDS',
                                helpText: 'EMA Momentum trends and output volume over time.',
                                child: SizedBox(
                                  height: 450,
                                  child: AnalyticsCarousel(
                                    momentumData: _momentumData,
                                    volumeData: _volumeData,
                                    title: _heatmapRange,
                                    focusedTaskName: _selectedTask?.name,
                                    isEmbedded: false,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildInsightsSection(),
                            ],
                          ),
                        ),
                  ),
                ),

                // ZONE 4: Inspector
                if (_inspectedDate != null)
                  _buildDayInspector(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final List<String> months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? const Color(0xFF09090B) : Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopTab(context, 'Dashboard', Icons.dashboard_rounded, false, () => Navigator.pop(context)),
                _buildTopTab(context, 'Explorer', Icons.explore_rounded, true, () {}),
                _buildTopTab(context, 'Settings', Icons.settings_rounded, false, () {}),
              ],
            ),
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                'Consistency Tracker v1.0',
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 14,
            backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            child: Icon(Icons.person_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTab(BuildContext context, String label, IconData icon, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))
          ] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[500]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(int index, String label) {
    final isSelected = _activeCategoryIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeCategoryIndex = index);
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitTile(Task? task) {
    final isSelected = _selectedTask?.id == task?.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: () {
            setState(() => _selectedTask = task);
            _refreshAnalytics();
          },
          leading: Icon(
            task == null ? Icons.dashboard_rounded : (task.type == TaskType.daily ? Icons.cached : Icons.bolt),
            size: 16,
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[500],
          ),
          title: Text(
            task?.name ?? 'Global Performance',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedTask?.name.toUpperCase() ?? 'GLOBAL PERFORMANCE',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        Text(
          _selectedTask == null ? 'Aggregated metrics for all habits.' : 'Detailed analysis for the "${_selectedTask!.name}" habit.',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildSectionContainer({required String title, required String helpText, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleNotifier.value;
    return Container(
      decoration: BoxDecoration(
        color: StyleService.getHeatmapBg(style, isDark),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: StyleService.getDailyTaskBorder(style, isDark), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                const SizedBox(width: 8),
                Tooltip(message: helpText, child: Icon(Icons.info_outline, size: 14, color: Colors.grey[500])),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return _buildSectionContainer(
      title: 'QUICK INSIGHTS',
      helpText: 'Automated observations based on your data.',
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildInsightItem(Icons.trending_up_rounded, 'Momentum is stable.', 'You are maintaining output levels above average.'),
            const Divider(height: 32),
            _buildInsightItem(Icons.calendar_month_rounded, 'Strongest day: Tuesday.', 'Statistically, you complete more tasks on Tuesdays.'),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(description, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayInspector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> monthNamesShort = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dateStr = "${_inspectedDate!.day} ${monthNamesShort[_inspectedDate!.month - 1]} ${_inspectedDate!.year}";
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090B) : Colors.white,
        border: Border(left: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DAY LOG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey[500])),
                  Text(dateStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                IconButton(onPressed: () => setState(() => _inspectedDate = null), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1))),
              child: Row(children: [
                Stack(alignment: Alignment.center, children: [
                  SizedBox(width: 40, height: 40, child: CircularProgressIndicator(value: _inspectedRecord?.completionScore ?? 0, strokeWidth: 4, backgroundColor: Colors.grey.withValues(alpha: 0.1))),
                  Text('${((_inspectedRecord?.completionScore ?? 0) * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(width: 16),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Daily Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Completion rate', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildInspectorSubHeader('TASKS PERFORMED'),
                if (_inspectedTasks.isNotEmpty)
                  ..._inspectedTasks.map((t) {
                    final isCompleted = _inspectedRecord?.completedTaskIds.contains(t.id) ?? false;
                    return _buildInspectorTaskTile(t, isCompleted);
                  })
                else
                  _buildEmptyState('No active tasks for this day'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorSubHeader(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey[500])));
  }

  Widget _buildInspectorTaskTile(Task task, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _toggleTaskCompletion(task, !completed),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(children: [
            SizedBox(width: 24, height: 24, child: Checkbox(value: completed, onChanged: (v) => _toggleTaskCompletion(task, v ?? false), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), activeColor: Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: Text(task.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: completed ? null : Colors.grey[500]))),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Text(text, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[400]));
  }
}
