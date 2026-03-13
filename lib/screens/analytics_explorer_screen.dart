// lib/screens/analytics_explorer_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/database_service.dart';
import '../services/scoring_service.dart';
import '../widgets/consistency_heatmap.dart';
import '../widgets/analytics_kpis.dart';
import '../widgets/analytics_carousel.dart';

class AnalyticsExplorerScreen extends StatefulWidget {
  final Task? initialSelectedTask;

  const AnalyticsExplorerScreen({super.key, this.initialSelectedTask});

  @override
  State<AnalyticsExplorerScreen> createState() => _AnalyticsExplorerScreenState();
}

class _AnalyticsExplorerScreenState extends State<AnalyticsExplorerScreen> {
  // 1. Data Notifiers
  final ValueNotifier<Task?> _selectedTaskNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<DateTime?> _visibleMonthNotifier = ValueNotifier(null); 
  final ValueNotifier<DateTimeRange?> _streakInspectionNotifier = ValueNotifier(null);
  
  List<Task> _primaryCache = [];
  List<Task> _secondaryCache = [];
  List<DayRecord> _allRecordsForCache = [];
  
  // Analytics State
  Map<DateTime, int> _heatmapData = {};
  AnalyticsResult _analytics = AnalyticsResult.empty();
  String _heatmapRange = '3M';
  List<MomentumPoint> _momentumData = [];
  List<VolumePoint> _volumeData = [];

  // Inspector State
  final ValueNotifier<DateTime?> _inspectedDateNotifier = ValueNotifier(null);
  DayRecord? _inspectedRecord;
  List<Task> _inspectedTasks = [];

  @override
  void initState() {
    super.initState();
    _selectedTaskNotifier.value = widget.initialSelectedTask;
    _loadInitialData();
    _selectedTaskNotifier.addListener(_onTaskSelectionChanged);
  }

  @override
  void dispose() {
    _selectedTaskNotifier.removeListener(_onTaskSelectionChanged);
    _selectedTaskNotifier.dispose();
    _isLoadingNotifier.dispose();
    _inspectedDateNotifier.dispose();
    _visibleMonthNotifier.dispose();
    _streakInspectionNotifier.dispose();
    super.dispose();
  }

  void _onTaskSelectionChanged() {
    final selected = _selectedTaskNotifier.value;
    _streakInspectionNotifier.value = null; 
    
    if (selected != null && !selected.isActive) {
      _visibleMonthNotifier.value = selected.createdAt;
    } else {
      _visibleMonthNotifier.value = DateTime.now();
    }
    _refreshAnalytics();
  }

  Future<void> _loadInitialData() async {
    _isLoadingNotifier.value = true;
    final allTasks = await DatabaseService.instance.getAllTasks();
    _allRecordsForCache = await DatabaseService.instance.getDayRecords(limit: 5000); 
    
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));

    _primaryCache = [];
    _secondaryCache = [];

    for (var task in allTasks) {
      bool isRecent = task.isActive || task.createdAt.isAfter(oneYearAgo);
      if (!isRecent) {
        final recentActivity = _allRecordsForCache.where((r) {
          final d = DateTime.tryParse(r.date) ?? DateTime(2000);
          return d.isAfter(oneYearAgo) && r.completedTaskIds.contains(task.id);
        });
        if (recentActivity.isNotEmpty) isRecent = true;
      }
      if (isRecent) { _primaryCache.add(task); } else { _secondaryCache.add(task); }
    }

    if (mounted) { _refreshAnalytics(); }
  }

  Future<void> _refreshAnalytics() async {
    final selected = _selectedTaskNotifier.value;
    final allRecords = await DatabaseService.instance.getDayRecords(limit: 5000);
    final allTasks = await DatabaseService.instance.getAllTasks();
    final taskTypeMap = {for (var t in allTasks) t.id: t.type};

    Map<DateTime, int> hData;
    AnalyticsResult res;

    if (selected != null) {
      hData = ScoringService.mapTaskRecordsToHeatmapData(allRecords, selected.id);
      res = ScoringService.calculateAnalytics(allRecords, taskId: selected.id);
    } else {
      hData = ScoringService.mapRecordsToHeatmapData(allRecords);
      res = ScoringService.calculateAnalytics(allRecords, taskTypeMap: taskTypeMap);
    }

    final mData = ScoringService.calculateMomentumData(allRecords, _heatmapRange, taskId: selected?.id);
    final vData = ScoringService.calculateVolumeData(allRecords, _heatmapRange, taskTypeMap);

    if (mounted) {
      setState(() {
        _heatmapData = hData;
        _analytics = res;
        _momentumData = mData;
        _volumeData = vData;
        _isLoadingNotifier.value = false;
      });
    }
  }

  Future<void> _fetchInspectedDayData(DateTime date) async {
    final dateFormatted = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final record = await DatabaseService.instance.getDayRecord(dateFormatted) ?? DayRecord(date: dateFormatted, completedTaskIds: [], skippedTaskIds: []);
    final tasks = await DatabaseService.instance.getActiveTasksForDate(date, includeArchived: true);
    if (mounted) {
      setState(() {
        _inspectedRecord = record;
        _inspectedTasks = tasks;
        _inspectedDateNotifier.value = date;
      });
    }
  }

  void _handleTaskToggle(Task t, bool comp) async {
    if (_inspectedRecord == null) return;
    List<int> cIds = List.from(_inspectedRecord!.completedTaskIds);
    List<int> sIds = List.from(_inspectedRecord!.skippedTaskIds);
    if (comp) { cIds.add(t.id); sIds.remove(t.id); } else { cIds.remove(t.id); }
    await _saveUpdate(cIds, sIds);
  }

  void _handleSkipToggle(Task t) async {
    if (_inspectedRecord == null) return;
    List<int> cIds = List.from(_inspectedRecord!.completedTaskIds);
    List<int> sIds = List.from(_inspectedRecord!.skippedTaskIds);
    if (sIds.contains(t.id)) { sIds.remove(t.id); } else { sIds.add(t.id); cIds.remove(t.id); }
    await _saveUpdate(cIds, sIds);
  }

  Future<void> _saveUpdate(List<int> cIds, List<int> sIds) async {
    final scoreResult = ScoringService.calculateDayScore(allTasks: _inspectedTasks, dayRecord: DayRecord(date: _inspectedRecord!.date, completedTaskIds: cIds, skippedTaskIds: sIds, cheatUsed: _inspectedRecord!.cheatUsed));
    final updated = DayRecord(date: _inspectedRecord!.date, completedTaskIds: cIds, skippedTaskIds: sIds, cheatUsed: _inspectedRecord!.cheatUsed, completionScore: _inspectedRecord!.cheatUsed ? 0.0 : scoreResult.completionScore, visualState: _inspectedRecord!.cheatUsed ? VisualState.cheat : scoreResult.visualState);
    await DatabaseService.instance.createOrUpdateDayRecord(updated);
    _fetchInspectedDayData(_inspectedDateNotifier.value!);
    _refreshAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SearchSidebar(
          primaryCache: _primaryCache,
          secondaryCache: _secondaryCache,
          selectedTaskNotifier: _selectedTaskNotifier,
          onToggleArchive: (task) async {
            final updated = Task(id: task.id, name: task.name, type: task.type, durationDays: task.durationDays, isPerpetual: task.isPerpetual, createdAt: task.createdAt, isActive: !task.isActive);
            await DatabaseService.instance.updateTask(updated);
            _loadInitialData();
          },
        ),
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: _isLoadingNotifier,
            builder: (context, loading, _) {
              if (loading) return const Center(child: CircularProgressIndicator());
              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 120, 
                      child: AnalyticsKPIs(
                        analytics: _analytics, 
                        isFocused: _selectedTaskNotifier.value != null,
                        onJump: (targetDate) {
                          _visibleMonthNotifier.value = targetDate;
                          _fetchInspectedDayData(targetDate);
                          if (targetDate == _analytics.longestStreakStart) {
                            _streakInspectionNotifier.value = DateTimeRange(start: _analytics.longestStreakStart!, end: _analytics.longestStreakEnd!);
                          }
                        },
                      )
                    ),
                    const SizedBox(height: 32),
                    _section(context, 'CONSISTENCY HEATMAP', 'Click to inspect.', 
                      SizedBox(height: 420, child: ValueListenableBuilder<DateTime?>(
                        valueListenable: _visibleMonthNotifier,
                        builder: (context, vMonth, _) {
                          return ConsistencyHeatmap(
                            key: ValueKey(_selectedTaskNotifier.value?.id ?? -1),
                            heatmapData: _heatmapData, 
                            selectedDate: _inspectedDateNotifier.value, 
                            visibleMonth: vMonth,
                            onDateSelected: _fetchInspectedDayData, 
                            selectedRange: _heatmapRange, 
                            focusedTaskName: _selectedTaskNotifier.value?.name, 
                            onRangeChanged: (r) { setState(() => _heatmapRange = r); _refreshAnalytics(); }
                          );
                        }
                      ))
                    ),
                    const SizedBox(height: 32),
                    _section(context, 'MOMENTUM & PERFORMANCE TRENDS', 'EMA Trends.', 
                      SizedBox(height: 450, child: AnalyticsCarousel(
                        momentumData: _momentumData, 
                        volumeData: _volumeData, 
                        title: _heatmapRange, 
                        focusedTaskName: _selectedTaskNotifier.value?.name, 
                        onDateSelected: _fetchInspectedDayData
                      ))
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        ValueListenableBuilder<DateTime?>(
          valueListenable: _inspectedDateNotifier,
          builder: (context, date, _) {
            if (date == null) return const SizedBox.shrink();
            return _Inspector(
              date: date,
              record: _inspectedRecord,
              tasks: _inspectedTasks,
              onClose: () => _inspectedDateNotifier.value = null,
              onToggleComp: _handleTaskToggle,
              onToggleSkip: _handleSkipToggle,
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ValueListenableBuilder<DateTimeRange?>(
      valueListenable: _streakInspectionNotifier,
      builder: (context, streakRange, _) {
        final sel = _selectedTaskNotifier.value;
        final String mainTitle = sel == null ? 'Global Performance' : _toTitleCase(sel.name);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(mainTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            if (streakRange != null) 
              Row(
                children: [
                  Text("Streak Started: ", style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  _clickableDate(streakRange.start),
                  Text(" • Ended: ", style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  _clickableDate(streakRange.end),
                ],
              )
            else if (sel != null)
              Row(
                children: [
                  Text("Habit Start Date: ", style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  _clickableDate(sel.createdAt),
                ],
              )
            else
              Text('Aggregated metrics for all habits.', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ]
        );
      }
    );
  }

  Widget _clickableDate(DateTime date) {
    final dateStr = "${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}";
    return InkWell(
      onTap: () {
        _visibleMonthNotifier.value = date;
        _fetchInspectedDayData(date);
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          dateStr, 
          style: TextStyle(
            fontSize: 13, 
            color: Theme.of(context).colorScheme.primary, 
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
          )
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

  Widget _section(BuildContext context, String title, String help, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey[500])),
          const SizedBox(width: 8),
          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
        ])),
        const Divider(height: 1),
        child,
      ]),
    );
  }
}

// --- SIDEBAR ---
class _SearchSidebar extends StatefulWidget {
  final List<Task> primaryCache;
  final List<Task> secondaryCache;
  final ValueNotifier<Task?> selectedTaskNotifier;
  final Function(Task) onToggleArchive;

  const _SearchSidebar({required this.primaryCache, required this.secondaryCache, required this.selectedTaskNotifier, required this.onToggleArchive});

  @override
  State<_SearchSidebar> createState() => _SearchSidebarState();
}

class _SearchSidebarState extends State<_SearchSidebar> {
  final TextEditingController _ctrl = TextEditingController();
  int _cat = 0;
  Timer? _debounce;
  List<Task> _filtered = [];

  @override
  void initState() { super.initState(); _applyFilter(); }

  @override
  void didUpdateWidget(_SearchSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryCache != widget.primaryCache) _applyFilter();
  }

  @override
  void dispose() { _ctrl.dispose(); _debounce?.cancel(); super.dispose(); }

  void _onSearchChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _applyFilter);
    if (v.isEmpty) setState(() {}); 
  }

  void _applyFilter() {
    final query = _ctrl.text.toLowerCase().trim();
    final allTasks = [...widget.primaryCache, ...widget.secondaryCache];
    final result = allTasks.where((t) {
      final nameMatch = t.name.toLowerCase().contains(query);
      if (!nameMatch) return false;
      if (_cat == 0) return t.isActive && t.type == TaskType.daily;
      if (_cat == 1) return t.isActive && t.type == TaskType.temporary;
      return !t.isActive;
    }).toList();
    result.sort((a, b) {
      final aP = widget.primaryCache.any((p) => p.id == a.id);
      final bP = widget.primaryCache.any((p) => p.id == b.id);
      if (aP && !bP) return -1;
      if (!aP && bP) return 1;
      return a.name.compareTo(b.name);
    });
    if (mounted) setState(() => _filtered = result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 280,
      decoration: BoxDecoration(color: isDark ? Colors.black.withValues(alpha: 0.1) : Colors.white, border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black12))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 12), child: TextField(
          controller: _ctrl, onChanged: _onSearchChanged,
          decoration: InputDecoration(hintText: 'Search habits...', prefixIcon: const Icon(Icons.search, size: 16), suffixIcon: _ctrl.text.isNotEmpty ? IconButton(onPressed: () { _ctrl.clear(); _applyFilter(); }, icon: const Icon(Icons.close, size: 14)) : null, contentPadding: EdgeInsets.zero),
          style: const TextStyle(fontSize: 13),
        )),
        _tile(null),
        const Divider(height: 16, indent: 16, endIndent: 16),
        _tabs(isDark),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(itemCount: _filtered.length, itemBuilder: (c, i) => _tile(_filtered[i]))),
      ]),
    );
  }

  Widget _tabs(bool isDark) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: Row(children: [
      _t(0, 'Daily'), _t(1, 'Temp'), _t(2, 'Archive'),
    ]));
  }

  Widget _t(int i, String l) {
    final s = _cat == i;
    return Expanded(child: GestureDetector(onTap: () { setState(() => _cat = i); _applyFilter(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: s ? (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(6)), child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: s ? FontWeight.w700 : FontWeight.w500)))));
  }

  Widget _tile(Task? t) {
    return ValueListenableBuilder<Task?>(
      valueListenable: widget.selectedTaskNotifier,
      builder: (context, current, _) {
        final isG = t == null;
        final sel = isG ? current == null : current?.id == t.id;
        final isPrimary = !isG && widget.primaryCache.any((p) => p.id == t.id);
        final String displayName = isG ? 'Global Performance' : _toTitleCase(t.name);

        return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: InkWell(
          onTap: () => widget.selectedTaskNotifier.value = t,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
            decoration: BoxDecoration(color: sel ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent)), 
            child: Row(children: [
              Icon(
                isG ? Icons.insights_rounded : (t.isPerpetual ? Icons.cached : Icons.timer_outlined), 
                size: 16, color: sel ? Theme.of(context).colorScheme.primary : (isPrimary ? Colors.grey : Colors.grey.withValues(alpha: 0.5))
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(displayName, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w900 : FontWeight.w600, color: sel ? Theme.of(context).colorScheme.primary : (isPrimary ? null : Colors.grey)))),
              if (!isG) IconButton(onPressed: () => widget.onToggleArchive(t), icon: Icon(t.isActive ? Icons.archive_outlined : Icons.unarchive_outlined, size: 14), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ])
          ),
        ));
      }
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

// --- INSPECTOR ---
class _Inspector extends StatelessWidget {
  final DateTime date;
  final DayRecord? record;
  final List<Task> tasks;
  final VoidCallback onClose;
  final Function(Task, bool) onToggleComp;
  final Function(Task) onToggleSkip;

  const _Inspector({required this.date, required this.record, required this.tasks, required this.onClose, required this.onToggleComp, required this.onToggleSkip});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isC = record?.cheatUsed ?? false;
    final List<String> mNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

    return Container(
      width: 320,
      decoration: BoxDecoration(color: isDark ? const Color(0xFF09090B) : Colors.white, border: Border(left: BorderSide(color: isDark ? Colors.white10 : Colors.black12))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(24), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DAY LOG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
            Text("${date.day} ${mNames[date.month-1]} ${date.year}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ]),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
        ])),
        const Divider(height: 1),
        _score(context, isC),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 24), children: [
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('HABITS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey))),
          ...tasks.map((t) => _tTile(context, t)),
        ])),
      ]),
    );
  }

  Widget _score(BuildContext context, bool isC) {
    final color = isC ? Colors.orange[400]! : Theme.of(context).colorScheme.primary;
    return Container(margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.1))), child: Row(children: [
      Stack(alignment: Alignment.center, children: [
        SizedBox(width: 48, height: 48, child: CircularProgressIndicator(value: isC ? 1.0 : (record?.completionScore ?? 0), strokeWidth: 5, valueColor: AlwaysStoppedAnimation(color))),
        Text(isC ? '100%' : '${((record?.completionScore ?? 0)*100).toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isC ? Colors.orange[700] : null)),
      ]),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isC ? 'CHEAT DAY' : 'DAILY SCORE', style: TextStyle(fontWeight: FontWeight.w900, color: isC ? Colors.orange[700] : null)),
        Text(isC ? 'Streak protected' : 'Completion rate', style: TextStyle(fontSize: 11, color: isC ? Colors.orange[400] : Colors.grey[500])),
      ])),
    ]));
  }

  Widget _tTile(BuildContext context, Task t) {
    final c = record?.completedTaskIds.contains(t.id) ?? false;
    final s = record?.skippedTaskIds.contains(t.id) ?? false;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.05))), child: Row(children: [
      Checkbox(value: c, onChanged: (v) => onToggleComp(t, v ?? false), activeColor: Colors.green),
      Expanded(child: Text(t.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c ? null : (s ? Colors.orange[700] : null), decoration: c ? TextDecoration.lineThrough : null))),
      IconButton(onPressed: () => onToggleSkip(t), icon: Icon(s ? Icons.block_flipped : Icons.block, size: 18, color: s ? Colors.orange[700] : Colors.grey[300])),
    ]));
  }
}
