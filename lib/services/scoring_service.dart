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
    if (dayRecord.cheatUsed) {
      return ScoreResult(
        completionScore: 0, // Score is irrelevant on a cheat day
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

    // Star Logic: All daily tasks completed PLUS at least one temporary task
    if (dailyTasks.isNotEmpty && completedDailyTasks == dailyTasks.length && completedTempTasks > 0) {
      return ScoreResult(
        completionScore: 1.0, // Max score for a star day
        visualState: VisualState.star,
      );
    }

    // Substitution Logic
    final dailyBenchmark = dailyTasks.length;
    if (dailyBenchmark == 0) {
      // If there are no daily tasks, any temp task completion is a bonus
      return completedTempTasks > 0
          ? ScoreResult(completionScore: 1, visualState: VisualState.level1)
          : ScoreResult(completionScore: 0, visualState: VisualState.empty);
    }

    final effectiveCompleted = completedDailyTasks + completedTempTasks;
    final score = (effectiveCompleted / dailyBenchmark).clamp(0.0, 1.0);

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
}

class ScoreResult {
  final double completionScore;
  final VisualState visualState;

  ScoreResult({required this.completionScore, required this.visualState});
}
