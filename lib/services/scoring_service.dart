// lib/services/scoring_service.dart

import '../models/day_record_model.dart';
import 'dart:math'; // For min function

class ScoringService {
  /// Calculates the core daily score based on completed and expected tasks.
  /// Returns a value between 0.0 and 1.0.
  double calculateCoreDailyScore(int completedTasksCount, int totalExpectedTasksCount) {
    if (totalExpectedTasksCount == 0) {
      return 0.0; // No tasks, no score. Or handle as per specific rule.
    }
    return completedTasksCount / totalExpectedTasksCount;
  }

  /// Calculates credit from temporary tasks, capped at 50% of missing daily work.
  double calculateTempTaskCredit(int tempTasksCompleted, int missingDailyTasksCount) {
    if (missingDailyTasksCount <= 0 || tempTasksCompleted <= 0) {
      return 0.0;
    }
    // Temporary tasks can cover at most 50% of missing daily work.
    return min(tempTasksCompleted.toDouble(), missingDailyTasksCount * 0.5);
  }

  /// Determines the visual state for a DayRecord based on score, cheat status, and overachievement.
  VisualState mapScoreToVisualState({
    required double finalScore,
    required bool cheatUsed,
    required bool hasStar,
  }) {
    if (cheatUsed) {
      return VisualState.cheat;
    }
    if (hasStar) {
      return VisualState.star;
    }

    if (finalScore >= 1.0) {
      return VisualState.darkGreen;
    } else if (finalScore >= 0.76) {
      return VisualState.green;
    } else if (finalScore >= 0.51) {
      return VisualState.lightGreen;
    } else if (finalScore >= 0.26) {
      return VisualState.lightGreen; // Example: can differentiate shades later
    } else if (finalScore > 0.0) {
      return VisualState.empty; // Represents minimal effort but not empty
    } else {
      return VisualState.empty;
    }
  }

  /// Calculates the overall completion score for a day.
  /// Combines core daily tasks and temporary task compensation.
  double calculateOverallCompletionScore({
    required int completedDailyTasks,
    required int totalDailyTasks,
    required int completedTemporaryTasks,
  }) {
    if (totalDailyTasks == 0) {
      // If there are no daily tasks, only temporary tasks count towards an "overachievement"
      // or a base score, but the core score cannot be calculated normally.
      // For now, return 0.0, as per the plan's focus on daily tasks.
      // This logic might need refinement based on exact requirements for days with no daily tasks.
      return 0.0;
    }

    final double coreScore = calculateCoreDailyScore(completedDailyTasks, totalDailyTasks);

    int missingDailyTasks = totalDailyTasks - completedDailyTasks;
    double tempCredit = calculateTempTaskCredit(completedTemporaryTasks, missingDailyTasks);

    double effectiveCompleted = completedDailyTasks + tempCredit;
    double adjustedScore = effectiveCompleted / totalDailyTasks;

    // Clamp score to a maximum of 1.0 for regular scoring before star logic
    return min(adjustedScore, 1.0);
  }

  /// Determines if a day qualifies for a "star" visual state.
  bool checkForStarStatus({
    required int completedDailyTasks,
    required int totalDailyTasks,
    required int completedTemporaryTasks,
  }) {
    // Star status if all daily tasks are done AND there are bonus temporary tasks
    return completedDailyTasks >= totalDailyTasks && completedTemporaryTasks > 0;
  }
}
