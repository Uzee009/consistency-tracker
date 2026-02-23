// lib/services/scoring_service.dart

import 'package:consistancy_tacker_v1/models/day_record_model.dart';
import 'package:consistancy_tacker_v1/models/task_model.dart';

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
          ? ScoreResult(completionScore: 1, visualState: VisualState.lightGreen)
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
    } else if (score < 0.5) {
      return VisualState.lightGreen;
    } else if (score < 1.0) {
      return VisualState.green;
    } else {
      return VisualState.darkGreen;
    }
  }
}

class ScoreResult {
  final double completionScore;
  final VisualState visualState;

  ScoreResult({required this.completionScore, required this.visualState});
}
