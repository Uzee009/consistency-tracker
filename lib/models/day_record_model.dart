// lib/models/day_record_model.dart

enum VisualState {
  empty,
  lightGreen,
  green,
  darkGreen,
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

  DayRecord({
    required this.date,
    required this.completedTaskIds,
    this.skippedTaskIds = const [],
    this.cheatUsed = false,
    this.completionScore = 0.0,
    this.visualState = VisualState.empty,
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
      completionScore: map['completion_score'] ?? 0.0,
      visualState: VisualState.values.firstWhere(
        (e) => e.toString().split('.').last == map['visual_state'],
        orElse: () => VisualState.empty, // Default value if not found
      ),
    );
  }

  @override
  String toString() {
    return 'DayRecord(date: $date, completedTaskIds: $completedTaskIds, skippedTaskIds: $skippedTaskIds, cheatUsed: $cheatUsed, completionScore: $completionScore, visualState: $visualState)';
  }
}
