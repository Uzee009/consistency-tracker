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
    
    // 2. Forward Pass: Global Totals and Longest Streak
    for (int i = 0; i <= totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final record = recordMap[dateStr];

      bool isSuccess = false;
      bool isCheat = false;
      bool isSkipped = false;

      if (record != null) {
        if (taskId != null) {
          isSuccess = record.completedTaskIds.contains(taskId);
          isSkipped = record.skippedTaskIds.contains(taskId);
        } else {
          isSuccess = record.completionScore >= 0.8;
          // Global totals: completions only
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
        if (tempStreak > longestStreak) longestStreak = tempStreak;
      } else if (isCheat || isSkipped) {
        // Neutral: Streak is preserved (tempStreak stays same), does not reset
      } else {
        // Real Miss
        tempStreak = 0;
      }
    }

    // 3. Current Streak and At-Risk (Backward Pass)
    bool isAtRisk = false;
    bool hasFailedOnce = false;
    bool foundLastActivity = false;

    for (int i = totalDays; i >= 0; i--) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final record = recordMap[dateStr];

      bool isSuccess = false;
      bool isCheat = false;
      bool isSkipped = false;
      if (record != null) {
        if (taskId != null) {
          isSuccess = record.completedTaskIds.contains(taskId);
          isSkipped = record.skippedTaskIds.contains(taskId);
        } else {
          isSuccess = record.completionScore >= 0.8;
        }
        isCheat = record.cheatUsed;
      }

      if (isSuccess) {
        currentStreak++;
        hasFailedOnce = false;
        foundLastActivity = true;
      } else if (isCheat || isSkipped) {
        // Preserve
      } else {
        if (!foundLastActivity && i == totalDays) isAtRisk = true;
        if (hasFailedOnce) break; 
        else {
          hasFailedOnce = true;
          foundLastActivity = true;
        }
      }
    }

    // 4. Rolling Windows: 7-Day Momentum and 30-Day Consistency
    int completionsInLast7 = 0;
    int completionsInLast30 = 0;
    
    // Normalize endDate to today at midnight for accurate rolling window
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    
    // Use the smaller of 30 or days since start for a fair consistency rate
    int daysSinceStart = todayMidnight.difference(startDate).inDays + 1;
    int consistencyDenominator = daysSinceStart < 30 ? daysSinceStart : 30;
    int momentumDenominator = daysSinceStart < 7 ? daysSinceStart : 7;

    for (int i = 0; i < 30; i++) {
      final date = todayMidnight.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final record = recordMap[dateStr];
      
      if (record != null) {
        bool isSuccess;
        if (taskId != null) {
          // Individual: Must be completed, NOT skipped
          isSuccess = record.completedTaskIds.contains(taskId);
        } else {
          // Global: Score >= 80% AND no tasks were skipped (Option B)
          isSuccess = record.completionScore >= 0.8 && record.skippedTaskIds.isEmpty;
        }
        
        if (isSuccess) {
          if (i < 7) completionsInLast7++;
          if (i < 30) completionsInLast30++;
        }
      }
    }

    double momentum7Day = momentumDenominator > 0 ? (completionsInLast7 / momentumDenominator) : 0.0;
    double consistencyRate = consistencyDenominator > 0 ? (completionsInLast30 / consistencyDenominator) : 0.0;

    return AnalyticsResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      momentum7Day: momentum7Day,
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
  final double momentum7Day;
  final bool isAtRisk;
  final int totalDailyCompleted;
  final int totalTempCompleted;
  final double consistencyRate;

  AnalyticsResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.momentum7Day,
    this.isAtRisk = false,
    this.totalDailyCompleted = 0,
    this.totalTempCompleted = 0,
    this.consistencyRate = 0.0,
  });

  factory AnalyticsResult.empty() => AnalyticsResult(
    currentStreak: 0,
    longestStreak: 0,
    momentum7Day: 0.0,
    isAtRisk: false,
  );
}

class ScoreResult {
  final double completionScore;
  final VisualState visualState;

  ScoreResult({required this.completionScore, required this.visualState});
}
