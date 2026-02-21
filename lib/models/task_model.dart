// lib/models/task_model.dart

enum TaskType { daily, temporary }

class Task {
  final int id; // Unique ID for the task
  final String name;
  final TaskType type;
  final int durationDays; // Applicable for daily tasks
  final DateTime createdAt;
  final bool isActive;

  Task({
    required this.id,
    required this.name,
    required this.type,
    this.durationDays = 0, // Default to 0 for temporary tasks
    required this.createdAt,
    this.isActive = true,
  });

  // Convert a Task object into a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last, // Store enum as string
      'duration_days': durationDays,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0, // Store boolean as integer
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
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] == 1,
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, name: $name, type: $type, durationDays: $durationDays, createdAt: $createdAt, isActive: $isActive)';
  }
}
