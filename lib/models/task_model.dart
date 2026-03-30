// lib/models/task_model.dart

enum TaskType { daily, temporary }

enum FrequencyType { daily, weekly }

class Task {
  final int id; // Unique ID for the task
  final String name;
  final TaskType type;
  final int durationDays; // Applicable for daily tasks, ignored if isPerpetual
  final bool isPerpetual; // True for tasks that never expire
  final DateTime createdAt;
  final bool isActive;
  
  // Weekly Frequency Fields
  final FrequencyType frequencyType;
  final int weeklyTarget; // e.g., 3 sessions per week

  Task({
    required this.id,
    required this.name,
    required this.type,
    this.durationDays = 0,
    this.isPerpetual = false,
    required this.createdAt,
    this.isActive = true,
    this.frequencyType = FrequencyType.daily,
    this.weeklyTarget = 1,
  });

  // Convert a Task object into a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last, // Store enum as string
      'duration_days': durationDays,
      'is_perpetual': isPerpetual ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0, // Store boolean as integer
      'frequency_type': frequencyType.toString().split('.').last,
      'weekly_target': weeklyTarget,
    };
  }

  // Extract a Task object from a Map.
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      name: map['name'],
      type: TaskType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => TaskType.daily, // Default value if not found
      ),
      durationDays: map['duration_days'],
      isPerpetual: map['is_perpetual'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] == 1,
      frequencyType: FrequencyType.values.firstWhere(
        (e) => e.toString().split('.').last == (map['frequency_type'] ?? 'daily'),
        orElse: () => FrequencyType.daily,
      ),
      weeklyTarget: map['weekly_target'] ?? 1,
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, name: $name, type: $type, durationDays: $durationDays, isPerpetual: $isPerpetual, createdAt: $createdAt, isActive: $isActive, frequencyType: $frequencyType, weeklyTarget: $weeklyTarget)';
  }
}
