// lib/services/scoring_service.dart

import 'package:consistency_tracker_v1/models/day_record_model.dart';
import 'package:consistency_tracker_v1/models/task_model.dart';

class ScoringService {
  // This class can be expanded with more complex scoring logic.
  // For now, it provides a method to calculate the daily completion score.

  static ScoreResult calculateDayScore({
    required List<Task> allTasks,
    required DayRecord dayRecord,
  }) {
    // If it's a cheat day AND NO tasks were done, return cheat state
    if (dayRecord.cheatUsed && dayRecord.completedTaskIds.isEmpty) {
      return ScoreResult(
        completionScore: 0,
        visualState: VisualState.cheat,
      );
    }

    final dailyTasks = allTasks.where((t) => t.type == TaskType.daily).toList();
    final tempTasks = allTasks.where((t) => t.type == TaskType.temporary).toList();

    if (dailyTasks.isEmpty && tempTasks.isEmpty) {
      return ScoreResult(completionScore: 0, visualState: VisualState.empty);
    }

    final completedDailyTasks = dailyTasks.where((t) => dayRecord.completedTaskIds.contains(t.id)).length;
    final completedTempTasks = tempTasks.where((t) => dayRecord.completedTaskIds.contains(t.id)).length;
    final skippedDailyTasks = dailyTasks.where((t) => dayRecord.skippedTaskIds.contains(t.id)).length;

    // A skip is an "excuse", so we remove it from the required daily benchmark
    // However, we ensure we don't divide by zero
    final dailyBenchmark = (dailyTasks.length - skippedDailyTasks).clamp(1, 999);
    
    // Effective completed score
    final effectiveCompleted = completedDailyTasks + completedTempTasks;
    final score = (effectiveCompleted / dailyBenchmark).clamp(0.0, 1.0);

    // Star Logic: All daily tasks completed PLUS at least one temporary task
    // BUG FIX: Cannot get a star if any task was skipped
    final hasStar = (dailyTasks.isNotEmpty && 
                    completedDailyTasks == (dailyTasks.length - skippedDailyTasks) && 
                    completedTempTasks > 0 && 
                    skippedDailyTasks == 0);

    if (hasStar) {
      return ScoreResult(
        completionScore: 1.0,
        visualState: VisualState.star,
      );
    }

    return ScoreResult(
      completionScore: score,
      visualState: _mapScoreToVisualState(score),
    );
  }

  static VisualState _mapScoreToVisualState(double score) {
    if (score <= 0) {
      return VisualState.empty;
    } else if (score < 0.2) {
      return VisualState.level1;
    } else if (score < 0.4) {
      return VisualState.level2;
    } else if (score < 0.7) {
      return VisualState.level3;
    } else if (score < 1.0) {
      return VisualState.level4;
    } else {
      return VisualState.level5;
    }
  }

  static Map<DateTime, int> mapRecordsToHeatmapData(List<DayRecord> records) {
    final Map<DateTime, int> data = {};
    for (var record in records) {
      final date = DateTime.parse(record.date);
      final cleanDate = DateTime(date.year, date.month, date.day);

      int intensity;

      switch (record.visualState) {
        case VisualState.cheat:
          intensity = -1;
          break;
        case VisualState.star:
          intensity = -2;
          break;
        case VisualState.empty:
          intensity = 0;
          break;
        case VisualState.level1:
          intensity = 1;
          break;
        case VisualState.level2:
          intensity = 2;
          break;
        case VisualState.level3:
          intensity = 3;
          break;
        case VisualState.level4:
          intensity = 4;
          break;
        case VisualState.level5:
          intensity = 5;
          break;
      }

      data[cleanDate] = intensity;
    }
    return data;
  }

  static Map<DateTime, int> mapTaskRecordsToHeatmapData(List<DayRecord> records, int taskId) {
    final Map<DateTime, int> data = {};
    for (var record in records) {
      final date = DateTime.parse(record.date);
      final cleanDate = DateTime(date.year, date.month, date.day);
      
      if (record.completedTaskIds.contains(taskId)) {
        data[cleanDate] = 5; // Success
      } else if (record.cheatUsed) {
        data[cleanDate] = -1; // Cheat Day
      } else {
        data[cleanDate] = 0; // Miss
      }
    }
    return data;
  }

  static AnalyticsResult calculateAnalytics(List<DayRecord> records, {int? taskId, Map<int, TaskType>? taskTypeMap}) {
    if (records.isEmpty) return AnalyticsResult.empty();

    // 1. Sort and find the date range
    final sortedRecords = List<DayRecord>.from(records)..sort((a, b) => a.date.compareTo(b.date));
    final Map<String, DayRecord> recordMap = {for (var r in sortedRecords) r.date: r};
    
    final DateTime startDate = DateTime.parse(sortedRecords.first.date);
    final DateTime endDate = DateTime.now(); // Calculate up to today
    final int totalDays = endDate.difference(startDate).inDays;

    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;
    int totalDailyCompleted = 0;
    int totalTempCompleted = 0;
    int taskSuccessCount = 0;
    
    // Recovery stats logic
    int totalMisses = 0;
    int successfulRecoveries = 0;
    bool lastWasMiss = false;

    // 2. Iterate through every single CALENDAR day to find gaps
    for (int i = 0; i <= totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final record = recordMap[dateStr];

      bool isSuccess = false;
      bool isCheat = false;

      if (record != null) {
        if (taskId != null) {
          isSuccess = record.completedTaskIds.contains(taskId);
        } else {
          isSuccess = record.completionScore >= 0.8;
          // Count global totals only when record exists
          if (taskTypeMap != null) {
            for (var id in record.completedTaskIds) {
              if (taskTypeMap[id] == TaskType.daily) totalDailyCompleted++;
              else if (taskTypeMap[id] == TaskType.temporary) totalTempCompleted++;
            }
          }
        }
        isCheat = record.cheatUsed;
      }

      if (isSuccess) {
        tempStreak++;
        if (taskId != null) taskSuccessCount++;
        if (tempStreak > longestStreak) longestStreak = tempStreak;
        
        if (lastWasMiss) {
          successfulRecoveries++;
          lastWasMiss = false;
        }
      } else if (isCheat) {
        // Cheat Day: Streak is preserved (tempStreak stays same)
        lastWasMiss = false; 
      } else {
        // Real Miss (or missing data gap)
        tempStreak = 0;
        totalMisses++;
        lastWasMiss = true;
      }
    }

    // 3. Current Streak (Count backwards from today)
    currentStreak = 0;
    bool isAtRisk = false;
    // For current streak, we only look at the tempStreak from the end of our loop 
    // IF the loop reached today.
    currentStreak = tempStreak;

    // Determine "At Risk" (Binary version): 
    // If today is not done yet, but yesterday was, it's "At Risk"
    final todayStr = endDate.toIso8601String().split('T')[0];
    final todayRecord = recordMap[todayStr];
    bool todayDone = false;
    if (todayRecord != null) {
      todayDone = taskId != null ? todayRecord.completedTaskIds.contains(taskId) : todayRecord.completionScore >= 0.8;
    }

    if (!todayDone) {
      // If we haven't finished today, the currentStreak we have is actually from yesterday
      // So we show it as "At Risk"
      if (currentStreak > 0) {
        isAtRisk = true;
      }
    }

    double recoveryRate = totalMisses > 0 ? (successfulRecoveries / totalMisses) : 1.0;
    
    // 4. Rolling 30-Day Consistency Rate
    int completionsInLast30 = 0;
    int daysToCheck = totalDays + 1 < 30 ? totalDays + 1 : 30;
    
    for (int i = 0; i < daysToCheck; i++) {
      final date = endDate.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final record = recordMap[dateStr];
      if (record != null) {
        bool isSuccess = taskId != null 
            ? record.completedTaskIds.contains(taskId) 
            : record.completionScore >= 0.8;
        if (isSuccess) completionsInLast30++;
      }
    }
    double consistencyRate = completionsInLast30 / daysToCheck;

    return AnalyticsResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      recoveryRate: recoveryRate,
      isAtRisk: isAtRisk,
      totalDailyCompleted: totalDailyCompleted,
      totalTempCompleted: totalTempCompleted,
      consistencyRate: consistencyRate,
    );
  }
}

class AnalyticsResult {
  final int currentStreak;
  final int longestStreak;
  final double recoveryRate;
  final bool isAtRisk;
  final int totalDailyCompleted;
  final int totalTempCompleted;
  final double consistencyRate;

  AnalyticsResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.recoveryRate,
    this.isAtRisk = false,
    this.totalDailyCompleted = 0,
    this.totalTempCompleted = 0,
    this.consistencyRate = 0.0,
  });

  factory AnalyticsResult.empty() => AnalyticsResult(
    currentStreak: 0,
    longestStreak: 0,
    recoveryRate: 1.0,
    isAtRisk: false,
  );
}

class ScoreResult {
  final double completionScore;
  final VisualState visualState;

  ScoreResult({required this.completionScore, required this.visualState});
}
