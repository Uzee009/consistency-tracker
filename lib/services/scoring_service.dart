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

  static Map<DateTime, int> mapTaskRecordsToHeatmapData(List<DayRecord> records) {
    final Map<DateTime, int> data = {};
    for (var record in records) {
      final date = DateTime.parse(record.date);
      final cleanDate = DateTime(date.year, date.month, date.day);
      // For a single task, it's binary: 5 (Completed) or 0 (Empty)
      data[cleanDate] = 5; 
    }
    return data;
  }

  static AnalyticsResult calculateAnalytics(List<DayRecord> records, {int? taskId}) {
    if (records.isEmpty) return AnalyticsResult.empty();

    // Ensure chronological order
    final sortedRecords = List<DayRecord>.from(records)..sort((a, b) => a.date.compareTo(b.date));
    
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;
    int totalMisses = 0;
    int successfulRecoveries = 0;

    for (int i = 0; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      bool isSuccess;

      if (taskId != null) {
        // Individual Task: Success = Completed
        isSuccess = record.completedTaskIds.contains(taskId);
      } else {
        // Overall: Success = Score > 0.8 OR Cheat Day
        isSuccess = (record.completionScore >= 0.8 || record.cheatUsed);
      }

      if (isSuccess) {
        tempStreak++;
        if (tempStreak > longestStreak) longestStreak = tempStreak;
        
        // Check for recovery: was the previous day a miss?
        if (i > 0) {
          final prevRecord = sortedRecords[i-1];
          bool prevIsMiss;
          if (taskId != null) {
            prevIsMiss = !prevRecord.completedTaskIds.contains(taskId) && !prevRecord.cheatUsed;
          } else {
            prevIsMiss = prevRecord.completionScore < 0.5 && !prevRecord.cheatUsed;
          }

          if (prevIsMiss) {
            successfulRecoveries++;
          }
        }
      } else {
        // If not success AND not a cheat day, it's a miss
        if (!record.cheatUsed) {
          totalMisses++;
          tempStreak = 0;
        }
        // Cheat days keep the streak alive but don't increment it (Standard behavior)
      }
    }

    // Current Streak: Count backwards from latest
    currentStreak = 0;
    for (int i = sortedRecords.length - 1; i >= 0; i--) {
      final record = sortedRecords[i];
      bool isSuccess;
      if (taskId != null) {
        isSuccess = record.completedTaskIds.contains(taskId);
      } else {
        isSuccess = (record.completionScore >= 0.8 || record.cheatUsed);
      }

      if (isSuccess) {
        currentStreak++;
      } else if (!record.cheatUsed) {
        break;
      }
    }

    double recoveryRate = totalMisses > 0 ? (successfulRecoveries / totalMisses) : 1.0;

    return AnalyticsResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      recoveryRate: recoveryRate,
    );
  }
}

class AnalyticsResult {
  final int currentStreak;
  final int longestStreak;
  final double recoveryRate;

  AnalyticsResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.recoveryRate,
  });

  factory AnalyticsResult.empty() => AnalyticsResult(
    currentStreak: 0,
    longestStreak: 0,
    recoveryRate: 1.0,
  );
}

class ScoreResult {
  final double completionScore;
  final VisualState visualState;

  ScoreResult({required this.completionScore, required this.visualState});
}
