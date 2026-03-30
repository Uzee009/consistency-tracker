// lib/services/scoring_service.dart

import 'package:consistency_tracker_v1/models/day_record_model.dart';
import 'package:consistency_tracker_v1/models/task_model.dart';

class WeeklyProgress {
  final int sessionsCompleted;
  final int sessionsTarget;
  final int daysRemainingInWeek;
  final bool isGoalMet;
  final bool isRequiredToday;

  WeeklyProgress({
    required this.sessionsCompleted,
    required this.sessionsTarget,
    required this.daysRemainingInWeek,
    required this.isGoalMet,
    required this.isRequiredToday,
  });
}

class ScoringService {
  // This class can be expanded with more complex scoring logic.
  // For now, it provides a method to calculate the daily completion score.

  static ScoreResult calculateDayScore({
    required List<Task> allTasks,
    required DayRecord dayRecord,
    List<DayRecord> history = const [], // Optional history for weekly logic
  }) {
    // If it's a cheat day AND NO tasks were done, return cheat state
    if (dayRecord.cheatUsed && dayRecord.completedTaskIds.isEmpty) {
      return ScoreResult(
        completionScore: 0,
        visualState: VisualState.cheat,
      );
    }

    final dailyTasks = allTasks.where((t) => t.type == TaskType.daily && t.frequencyType == FrequencyType.daily).toList();
    final tempTasks = allTasks.where((t) => t.type == TaskType.temporary).toList();
    final weeklyTasks = allTasks.where((t) => t.type == TaskType.daily && t.frequencyType == FrequencyType.weekly).toList();

    if (dailyTasks.isEmpty && tempTasks.isEmpty && weeklyTasks.isEmpty) {
      return ScoreResult(completionScore: 0, visualState: VisualState.empty);
    }

    final completedDailyCount = dailyTasks.where((t) => dayRecord.completedTaskIds.contains(t.id)).length;
    final completedTempCount = tempTasks.where((t) => dayRecord.completedTaskIds.contains(t.id)).length;
    final completedWeeklyCount = weeklyTasks.where((t) => dayRecord.completedTaskIds.contains(t.id)).length;
    
    final skippedDailyIds = dailyTasks.where((t) => dayRecord.skippedTaskIds.contains(t.id)).map((t) => t.id).toList();

    // Weekly Requirement Logic
    int requiredWeeklyCount = 0;
    DateTime today = DateTime.parse(dayRecord.date);

    for (var task in weeklyTasks) {
      final progress = getWeeklyProgress(task, today, history);
      if (progress.isRequiredToday && !dayRecord.skippedTaskIds.contains(task.id)) {
        requiredWeeklyCount++;
      }
    }

    // A skip is an "excuse", so we remove it from the required daily benchmark.
    final activeDailyCount = dailyTasks.length - skippedDailyIds.length;
    
    // Total Benchmark (Denominator)
    // Only includes Daily tasks and Weekly tasks that are strictly required today.
    final totalBenchmark = (activeDailyCount + requiredWeeklyCount).clamp(1, 999);
    
    // Effective completed score (Numerator)
    // Includes all completions (even optional ones).
    final effectiveCompleted = completedDailyCount + completedTempCount + completedWeeklyCount;
    final score = (effectiveCompleted / totalBenchmark).clamp(0.0, 1.0);

    // V8 FIX: If all required tasks were skipped AND no tasks were done, it's an "Excused/Empty" day.
    if (activeDailyCount + requiredWeeklyCount <= 0 && effectiveCompleted == 0) {
      return ScoreResult(
        completionScore: 0,
        visualState: dayRecord.cheatUsed ? VisualState.cheat : VisualState.empty,
      );
    }

    // Star Logic: All required tasks completed PLUS at least one extra task
    // or exceeding requirements.
    final hasStar = (effectiveCompleted > totalBenchmark && totalBenchmark > 0);

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

  /// Calculates the "Anniversary Week" progress for a task.
  /// Staggered week starts on task.createdAt.weekday.
  static WeeklyProgress getWeeklyProgress(Task task, DateTime targetDate, List<DayRecord> history) {
    if (task.frequencyType == FrequencyType.daily) {
      return WeeklyProgress(
        sessionsCompleted: 0, 
        sessionsTarget: 1, 
        daysRemainingInWeek: 0, 
        isGoalMet: false, 
        isRequiredToday: true
      );
    }

    // 1. Calculate the start of the current "Anniversary Week"
    // We normalize everything to midnight.
    final DateTime created = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
    final DateTime today = DateTime(targetDate.year, targetDate.month, targetDate.day);
    
    final int daysSinceCreation = today.difference(created).inDays;
    final int weekNumber = daysSinceCreation ~/ 7;
    final DateTime weekStart = created.add(Duration(days: weekNumber * 7));
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    
    final int daysRemaining = weekEnd.difference(today).inDays; // 0 to 6

    // 2. Count completions in this window [weekStart, today]
    // Note: We include 'today' in the count if it's already recorded as completed in history 
    // OR passed in the current record (but this function usually looks at past records).
    int completions = 0;
    for (var record in history) {
      final recordDate = DateTime.parse(record.date);
      if (recordDate.isAtSameMomentAs(weekStart) || (recordDate.isAfter(weekStart) && recordDate.isBefore(today.add(const Duration(seconds: 1))))) {
        if (record.completedTaskIds.contains(task.id)) {
          completions++;
        }
      }
    }

    final int sessionsNeeded = (task.weeklyTarget - completions).clamp(0, task.weeklyTarget);
    final bool isGoalMet = sessionsNeeded <= 0;
    
    // 3. Is it required today?
    // Logic: If sessions needed >= days remaining + 1 (including today)
    // Example: 2 sessions needed, 2 days left (Today + Tomorrow). 
    // If I don't do it today, I'll have 1 day left to do 2 sessions -> Impossible.
    // So if sessionsNeeded >= (daysRemaining + 1), it is REQUIRED.
    final bool isRequiredToday = !isGoalMet && (sessionsNeeded >= (daysRemaining + 1));

    return WeeklyProgress(
      sessionsCompleted: completions,
      sessionsTarget: task.weeklyTarget,
      daysRemainingInWeek: daysRemaining,
      isGoalMet: isGoalMet,
      isRequiredToday: isRequiredToday,
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

  static AnalyticsResult calculateAnalytics(List<DayRecord> records, {int? taskId, Map<int, TaskType>? taskTypeMap, DateTime? taskCreatedAt}) {
    if (records.isEmpty) return AnalyticsResult.empty();

    // 1. Sort and find the date range
    final sortedRecords = List<DayRecord>.from(records)..sort((a, b) => a.date.compareTo(b.date));
    final Map<String, DayRecord> recordMap = {for (var r in sortedRecords) r.date: r};
    
    // START DATE: If taskCreatedAt is provided, use it as the baseline for this specific habit.
    // Otherwise, use the earliest record date.
    DateTime startDate = DateTime.parse(sortedRecords.first.date);
    if (taskCreatedAt != null) {
      // Normalize to midnight
      startDate = DateTime(taskCreatedAt.year, taskCreatedAt.month, taskCreatedAt.day);
    }
    
    final DateTime endDate = DateTime.now(); // Calculate up to today
    final int totalDays = endDate.difference(startDate).inDays;

    int currentStreak = 0;
    int longestStreak = 0;
    DateTime? longestStreakStart;
    DateTime? longestStreakEnd;
    DateTime? lastActivityDate;
    int tempStreak = 0;
    DateTime? tempStreakStart;
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
              if (taskTypeMap[id] == TaskType.daily) {
                totalDailyCompleted++;
              } else if (taskTypeMap[id] == TaskType.temporary) {
                totalTempCompleted++;
              }
            }
          }
        }
        isCheat = record.cheatUsed;
      }

      if (isSuccess) {
        if (tempStreak == 0) tempStreakStart = date;
        tempStreak++;
        lastActivityDate = date;
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
          longestStreakStart = tempStreakStart;
          longestStreakEnd = date;
        }
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
          // GLOBAL SKIP: If ANY task was skipped today, treat the day as neutrally skipped globally
          // to preserve the global streak (consistent with the 'Anti-Burnout' philosophy).
          isSkipped = record.skippedTaskIds.isNotEmpty;
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
        if (!foundLastActivity && i == totalDays) {
          isAtRisk = true;
        }
        if (hasFailedOnce) {
          break; 
        } else {
          hasFailedOnce = true;
          foundLastActivity = true;
        }
      }
    }

    // 4. Rolling Windows: 7-Day Momentum and 30-Day Consistency
    int completionsInLast7 = 0;
    int completionsInLast30 = 0;
    int validDaysInLast7 = 0;
    int validDaysInLast30 = 0;
    
    // Normalize endDate to today at midnight for accurate rolling window
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    
    // We will calculate a dynamic denominator for the last 30/7 days 
    // that respects the task start date AND ignores skipped/neutral days.
    
    for (int i = 0; i < 30; i++) {
      final date = todayMidnight.subtract(Duration(days: i));
      if (date.isBefore(startDate)) break; // Don't count days before the habit existed

      final dateStr = date.toIso8601String().split('T')[0];
      final record = recordMap[dateStr];
      
      bool isSuccess = false;
      bool isNeutral = false;

      if (record != null) {
        if (taskId != null) {
          isSuccess = record.completedTaskIds.contains(taskId);
          isNeutral = record.skippedTaskIds.contains(taskId) || record.cheatUsed;
        } else {
          isSuccess = record.completionScore >= 0.8;
          isNeutral = record.skippedTaskIds.isNotEmpty || record.cheatUsed;
        }
      } else {
        // If no record exists for a date within the habit's lifetime, it's a "Miss" (not neutral)
        isSuccess = false;
        isNeutral = false;
      }
      
      if (!isNeutral) {
        if (i < 7) {
          validDaysInLast7++;
          if (isSuccess) completionsInLast7++;
        }
        if (i < 30) {
          validDaysInLast30++;
          if (isSuccess) completionsInLast30++;
        }
      }
    }

    double momentum7Day = validDaysInLast7 > 0 ? (completionsInLast7 / validDaysInLast7) : 0.0;
    double consistencyRate = validDaysInLast30 > 0 ? (completionsInLast30 / validDaysInLast30) : 0.0;

    return AnalyticsResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      longestStreakStart: longestStreakStart,
      longestStreakEnd: longestStreakEnd,
      lastActivityDate: lastActivityDate,
      momentum7Day: momentum7Day,
      isAtRisk: isAtRisk,
      totalDailyCompleted: totalDailyCompleted,
      totalTempCompleted: totalTempCompleted,
      consistencyRate: consistencyRate,
    );
  }

  // --- Graph Data Generation ---

  static List<MomentumPoint> calculateMomentumData(
    List<DayRecord> records, 
    String range, {
    int? taskId,
  }) {
    if (records.isEmpty) return [];

    final sortedRecords = List<DayRecord>.from(records)..sort((a, b) => a.date.compareTo(b.date));
    final Map<String, DayRecord> recordMap = {for (var r in sortedRecords) r.date: r};
    
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    
    int daysToFetch;
    switch (range) {
      case '1M': daysToFetch = 30; break;
      case '3M': daysToFetch = 90; break;
      case '6M': daysToFetch = 180; break;
      case '1Y': daysToFetch = 365; break;
      default: daysToFetch = 30;
    }

    final startDate = todayMidnight.subtract(Duration(days: daysToFetch));
    List<MomentumPoint> rawPoints = [];
    double currentMomentum = 0.0;
    const double alpha = 0.15; // Smoothing factor

    // Generate daily points with EMA from the very beginning of records to normalize
    final DateTime firstEverDate = DateTime.parse(sortedRecords.first.date);
    final int daysSinceBeginning = todayMidnight.difference(firstEverDate).inDays;

    for (int i = 0; i <= daysSinceBeginning; i++) {
      final date = firstEverDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final record = recordMap[dateStr];

      double dailyPerformance = 0.0;
      if (record != null) {
        if (taskId != null) {
          dailyPerformance = record.completedTaskIds.contains(taskId) ? 1.0 : 0.0;
        } else {
          dailyPerformance = record.completionScore;
        }
        
        // If cheat day, treat performance as current momentum (stays flat)
        if (record.cheatUsed && dailyPerformance < currentMomentum) {
          dailyPerformance = currentMomentum;
        }
      }

      currentMomentum = currentMomentum + alpha * (dailyPerformance - currentMomentum);
      
      if (date.isAfter(startDate.subtract(const Duration(days: 1)))) {
        rawPoints.add(MomentumPoint(date: date, value: currentMomentum));
      }
    }

    return _bucketPoints(rawPoints, range);
  }

  static List<VolumePoint> calculateVolumeData(
    List<DayRecord> records, 
    String range,
    Map<int, TaskType> taskTypeMap,
  ) {
    if (records.isEmpty) return [];

    final sortedRecords = List<DayRecord>.from(records)..sort((a, b) => a.date.compareTo(b.date));
    final Map<String, DayRecord> recordMap = {for (var r in sortedRecords) r.date: r};
    
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    
    int daysToFetch;
    switch (range) {
      case '1M': daysToFetch = 30; break;
      case '3M': daysToFetch = 90; break;
      case '6M': daysToFetch = 180; break;
      case '1Y': daysToFetch = 365; break;
      default: daysToFetch = 30;
    }

    final startDate = todayMidnight.subtract(Duration(days: daysToFetch));
    List<VolumePoint> rawPoints = [];

    for (int i = 0; i <= daysToFetch; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final record = recordMap[dateStr];

      int tempCompleted = 0;
      if (record != null) {
        for (var id in record.completedTaskIds) {
          if (taskTypeMap[id] == TaskType.temporary) tempCompleted++;
        }
      }
      rawPoints.add(VolumePoint(date: date, count: tempCompleted));
    }

    return _bucketVolume(rawPoints, range);
  }

  static List<MomentumPoint> _bucketPoints(List<MomentumPoint> points, String range) {
    if (range == '1M') return points;
    
    List<MomentumPoint> bucketed = [];
    int bucketSize = (range == '1Y') ? 30 : 7; // Monthly for 1Y, Weekly for 3M/6M

    for (int i = 0; i < points.length; i += bucketSize) {
      int end = (i + bucketSize < points.length) ? i + bucketSize : points.length;
      double avg = 0;
      for (int j = i; j < end; j++) {
        avg += points[j].value;
      }
      bucketed.add(MomentumPoint(date: points[i].date, value: avg / (end - i)));
    }
    return bucketed;
  }

  static List<VolumePoint> _bucketVolume(List<VolumePoint> points, String range) {
    if (range == '1M') {
      return points;
    }
    
    List<VolumePoint> bucketed = [];
    int bucketSize = (range == '1Y') ? 30 : 7;

    for (int i = 0; i < points.length; i += bucketSize) {
      int end = (i + bucketSize < points.length) ? i + bucketSize : points.length;
      int total = 0;
      for (int j = i; j < end; j++) {
        total += points[j].count;
      }
      bucketed.add(VolumePoint(date: points[i].date, count: total));
    }
    return bucketed;
  }
}

class MomentumPoint {
  final DateTime date;
  final double value;
  MomentumPoint({required this.date, required this.value});
}

class VolumePoint {
  final DateTime date;
  final int count;
  VolumePoint({required this.date, required this.count});
}

class AnalyticsResult {
  final int currentStreak;
  final int longestStreak;
  final DateTime? longestStreakStart;
  final DateTime? longestStreakEnd;
  final DateTime? lastActivityDate;
  final double momentum7Day;
  final bool isAtRisk;
  final int totalDailyCompleted;
  final int totalTempCompleted;
  final double consistencyRate;

  AnalyticsResult({
    required this.currentStreak,
    required this.longestStreak,
    this.longestStreakStart,
    this.longestStreakEnd,
    this.lastActivityDate,
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
