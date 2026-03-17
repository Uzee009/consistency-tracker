// lib/controllers/dashboard_controller.dart

import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/scoring_service.dart';

class DashboardController extends ChangeNotifier {
  // --- STATE ---
  List<Task> todaysTasks = [];
  DayRecord todayRecord = DayRecord(date: '', completedTaskIds: [], skippedTaskIds: []);
  User? currentUser;
  int cheatDaysUsed = 0;
  Map<DateTime, int> heatmapData = {};
  DateTime selectedDate = DateTime.now();
  Task? focusedTask;
  AnalyticsResult analytics = AnalyticsResult.empty();
  String heatmapRange = '1M';
  List<MomentumPoint> momentumData = [];
  List<VolumePoint> volumeData = [];
  bool isLoading = true;
  int _lastRequestId = 0; // V8: Protect against race conditions

  // --- INITIALIZATION ---
  /// [showLoading] defaults to true for initial loads or date changes.
  /// Set to false for background updates (toggling tasks) to prevent UI flicker.
  Future<void> initialize(DateTime date, {bool showLoading = true}) async {
    final requestId = ++_lastRequestId;
    
    if (showLoading) {
      isLoading = true;
      notifyListeners();
    }

    selectedDate = date;
    final dateFormatted = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final yearMonth = "${date.year}-${date.month.toString().padLeft(2, '0')}";

    final record = await DatabaseService.instance.getDayRecord(dateFormatted);
    if (requestId != _lastRequestId) return; // Abort if a newer request started

    todayRecord = record ?? DayRecord(date: dateFormatted, completedTaskIds: [], skippedTaskIds: []);

    final users = await DatabaseService.instance.getAllUsers();
    if (requestId != _lastRequestId) return;
    if (users.isNotEmpty) currentUser = users.first;

    cheatDaysUsed = await DatabaseService.instance.getCheatDaysUsed(yearMonth);
    todaysTasks = await DatabaseService.instance.getActiveTasksForDate(date);
    if (requestId != _lastRequestId) return;

    final allRecords = await DatabaseService.instance.getDayRecords(limit: 366);
    final allTasks = await DatabaseService.instance.getAllTasks();
    if (requestId != _lastRequestId) return;

    final taskTypeMap = {for (var t in allTasks) t.id: t.type};

    if (focusedTask != null) {
      heatmapData = ScoringService.mapTaskRecordsToHeatmapData(allRecords, focusedTask!.id);
      analytics = ScoringService.calculateAnalytics(allRecords, taskId: focusedTask!.id, taskCreatedAt: focusedTask!.createdAt);
    } else {
      heatmapData = ScoringService.mapRecordsToHeatmapData(allRecords);
      analytics = ScoringService.calculateAnalytics(allRecords, taskTypeMap: taskTypeMap);
    }

    momentumData = ScoringService.calculateMomentumData(allRecords, heatmapRange, taskId: focusedTask?.id);
    volumeData = ScoringService.calculateVolumeData(allRecords, heatmapRange, taskTypeMap);

    isLoading = false;
    notifyListeners();
  }

  // --- ACTIONS ---

  Future<void> setSelectedDate(DateTime date, {bool showLoading = true}) async {
    // When changing dates via heatmap click, we might want silent refresh
    await initialize(date, showLoading: showLoading);
  }

  /// Returns true if the UI should show a "Resume Day" dialog
  bool isCheatDayConflict(bool completed) {
    return completed && todayRecord.cheatUsed;
  }

  Future<void> toggleTaskCompletion(Task task, bool completed, {bool reclaimCheat = false}) async {
    List<int> updatedCompletedIds = List.from(todayRecord.completedTaskIds);
    List<int> updatedSkippedIds = List.from(todayRecord.skippedTaskIds);

    if (completed) {
      updatedCompletedIds.add(task.id);
      updatedSkippedIds.remove(task.id);
      
      if (todayRecord.cheatUsed) {
        final yearMonth = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}";
        await DatabaseService.instance.decrementCheatDaysUsed(yearMonth);
        reclaimCheat = true;
      }
    } else {
      updatedCompletedIds.remove(task.id);
    }

    await _updateDayRecordInDb(updatedCompletedIds, updatedSkippedIds, forceCheatOff: reclaimCheat);
    // SILENT REFRESH: Update state without the loading spinner
    await initialize(selectedDate, showLoading: false);
  }

  Future<void> toggleTaskSkip(Task task) async {
    List<int> updatedCompletedIds = List.from(todayRecord.completedTaskIds);
    List<int> updatedSkippedIds = List.from(todayRecord.skippedTaskIds);

    if (updatedSkippedIds.contains(task.id)) {
      updatedSkippedIds.remove(task.id);
    } else {
      updatedSkippedIds.add(task.id);
      updatedCompletedIds.remove(task.id);
    }

    await _updateDayRecordInDb(updatedCompletedIds, updatedSkippedIds);
    await initialize(selectedDate, showLoading: false);
  }

  Future<void> claimCheatDay() async {
    if (currentUser == null || todayRecord.cheatUsed) return;
    
    final yearMonth = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}";
    await DatabaseService.instance.incrementCheatDaysUsed(yearMonth);
    
    await _updateDayRecordInDb(todayRecord.completedTaskIds, todayRecord.skippedTaskIds, forceCheatOn: true);
    await initialize(selectedDate, showLoading: false);
  }

  Future<void> undoCheatDay() async {
    if (!todayRecord.cheatUsed) return;

    final yearMonth = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}";
    await DatabaseService.instance.decrementCheatDaysUsed(yearMonth);
    
    final updatedRecord = DayRecord(
      date: todayRecord.date,
      completedTaskIds: todayRecord.completedTaskIds,
      skippedTaskIds: todayRecord.skippedTaskIds,
      cheatUsed: false,
      completionScore: todayRecord.completionScore,
      visualState: VisualState.empty,
    );
    
    await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
    await initialize(selectedDate, showLoading: false);
  }

  Future<void> deleteTask(int taskId) async {
    await DatabaseService.instance.deleteTask(taskId);
    await initialize(selectedDate, showLoading: false);
  }

  void setFocusedTask(Task? task) {
    focusedTask = task;
    initialize(selectedDate, showLoading: false);
  }

  void setHeatmapRange(String range) {
    heatmapRange = range;
    initialize(selectedDate, showLoading: false);
  }

  Future<void> updatePomodoroStats(int completed, int goal) async {
    final updatedRecord = todayRecord.copyWith(
      pomodoroSessionsCompleted: completed,
      pomodoroGoal: goal,
    );
    await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
    // SILENT REFRESH
    await initialize(selectedDate, showLoading: false);
  }

  // --- PRIVATE HELPERS ---

  Future<void> _updateDayRecordInDb(List<int> completedIds, List<int> skippedIds, {bool? forceCheatOn, bool? forceCheatOff}) async {
    bool isCheatUsed = todayRecord.cheatUsed;
    if (forceCheatOn == true) isCheatUsed = true;
    if (forceCheatOff == true) isCheatUsed = false;
    
    final scoreResult = ScoringService.calculateDayScore(
      allTasks: todaysTasks, 
      dayRecord: DayRecord(
        date: todayRecord.date,
        completedTaskIds: completedIds,
        skippedTaskIds: skippedIds,
        cheatUsed: isCheatUsed,
        pomodoroSessionsCompleted: todayRecord.pomodoroSessionsCompleted,
        pomodoroGoal: todayRecord.pomodoroGoal,
      ),
    );

    final updatedRecord = todayRecord.copyWith(
      completedTaskIds: completedIds,
      skippedTaskIds: skippedIds,
      cheatUsed: isCheatUsed,
      completionScore: isCheatUsed ? 0.0 : scoreResult.completionScore,
      visualState: isCheatUsed ? VisualState.cheat : scoreResult.visualState,
    );

    await DatabaseService.instance.createOrUpdateDayRecord(updatedRecord);
  }
}
