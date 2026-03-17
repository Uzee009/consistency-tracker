// lib/models/day_record_model.dart

enum VisualState {
  empty,
  level1,
  level2,
  level3,
  level4,
  level5,
  cheat,
  star,
}

class DayRecord {
  final String date; // YYYY-MM-DD format for easy storage and retrieval
  final List<int> completedTaskIds; // IDs of tasks completed on this day
  final List<int> skippedTaskIds; // IDs of tasks skipped on this day
  final bool cheatUsed;
  final double completionScore; // 0.0 to 1.0
  final VisualState visualState;
  
  // V8: Pomodoro focus sessions
  final int pomodoroSessionsCompleted;
  final int pomodoroGoal;

  DayRecord({
    required this.date,
    required this.completedTaskIds,
    this.skippedTaskIds = const [],
    this.cheatUsed = false,
    this.completionScore = 0.0,
    this.visualState = VisualState.empty,
    this.pomodoroSessionsCompleted = 0,
    this.pomodoroGoal = 4,
  });

  // Convert a DayRecord object into a Map.
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'completed_task_ids': completedTaskIds.join(','), // Store as comma-separated string
      'skipped_task_ids': skippedTaskIds.join(','), // Store as comma-separated string
      'cheat_used': cheatUsed ? 1 : 0,
      'completion_score': completionScore,
      'visual_state': visualState.toString().split('.').last, // Store enum as string
      'pomodoro_sessions': pomodoroSessionsCompleted,
      'pomodoro_goal': pomodoroGoal,
    };
  }

  // Extract a DayRecord object from a Map.
  factory DayRecord.fromMap(Map<String, dynamic> map) {
    return DayRecord(
      date: map['date'],
      completedTaskIds: map['completed_task_ids'] != null && map['completed_task_ids'].toString().isNotEmpty
          ? List<int>.from(map['completed_task_ids'].toString().split(',').map((id) => int.parse(id)))
          : [],
      skippedTaskIds: map['skipped_task_ids'] != null && map['skipped_task_ids'].toString().isNotEmpty
          ? List<int>.from(map['skipped_task_ids'].toString().split(',').map((id) => int.parse(id)))
          : [],
      cheatUsed: map['cheat_used'] == 1,
      completionScore: (map['completion_score'] is int) 
          ? (map['completion_score'] as int).toDouble() 
          : (map['completion_score'] ?? 0.0),
      visualState: _mapStringToVisualState(map['visual_state']),
      pomodoroSessionsCompleted: map['pomodoro_sessions'] ?? 0,
      pomodoroGoal: map['pomodoro_goal'] ?? 4,
    );
  }

  static VisualState _mapStringToVisualState(String? stateStr) {
    if (stateStr == null) return VisualState.empty;

    // Legacy mapping
    if (stateStr == 'lightGreen') return VisualState.level1;
    if (stateStr == 'green') return VisualState.level3;
    if (stateStr == 'darkGreen') return VisualState.level5;

    return VisualState.values.firstWhere(
      (e) => e.toString().split('.').last == stateStr,
      orElse: () => VisualState.empty,
    );
  }

  @override
  String toString() {
    return 'DayRecord(date: $date, completedTaskIds: $completedTaskIds, skippedTaskIds: $skippedTaskIds, cheatUsed: $cheatUsed, completionScore: $completionScore, visualState: $visualState, pomodoro: $pomodoroSessionsCompleted/$pomodoroGoal)';
  }

  DayRecord copyWith({
    String? date,
    List<int>? completedTaskIds,
    List<int>? skippedTaskIds,
    bool? cheatUsed,
    double? completionScore,
    VisualState? visualState,
    int? pomodoroSessionsCompleted,
    int? pomodoroGoal,
  }) {
    return DayRecord(
      date: date ?? this.date,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      skippedTaskIds: skippedTaskIds ?? this.skippedTaskIds,
      cheatUsed: cheatUsed ?? this.cheatUsed,
      completionScore: completionScore ?? this.completionScore,
      visualState: visualState ?? this.visualState,
      pomodoroSessionsCompleted: pomodoroSessionsCompleted ?? this.pomodoroSessionsCompleted,
      pomodoroGoal: pomodoroGoal ?? this.pomodoroGoal,
    );
  }
}
