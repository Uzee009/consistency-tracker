// lib/models/task_model.dart

enum TaskType { daily, temporary }

enum FrequencyType { daily, weekly }

class Task {
  final String sid; // Sync ID (UUID) — unique identity for cross-device
  final String name;
  final TaskType type;
  final int durationDays;
  final bool isPerpetual;
  final DateTime createdAt;
  final bool isActive;
  final FrequencyType frequencyType;
  final int weeklyTarget;
  final int sortOrder;

  // Sync metadata
  final int updatedAt; // Unix timestamp (ms)
  final bool deleted; // Tombstone flag
  final bool dirty; // Locally modified, needs push

  Task({
    required this.sid,
    required this.name,
    required this.type,
    this.durationDays = 0,
    this.isPerpetual = false,
    required this.createdAt,
    this.isActive = true,
    this.frequencyType = FrequencyType.daily,
    this.weeklyTarget = 1,
    this.sortOrder = 0,
    this.updatedAt = 0,
    this.deleted = false,
    this.dirty = false,
  });

  // Convert a Task object into a Map.
  Map<String, dynamic> toMap() {
    return {
      'sid': sid,
      'name': name,
      'type': type.toString().split('.').last,
      'duration_days': durationDays,
      'is_perpetual': isPerpetual ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'frequency_type': frequencyType.toString().split('.').last,
      'weekly_target': weeklyTarget,
      'sort_order': sortOrder,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
      'dirty': dirty ? 1 : 0,
    };
  }

  // Extract a Task object from a Map.
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      sid: map['sid'],
      name: map['name'],
      type: TaskType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => TaskType.daily,
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
      sortOrder: map['sort_order'] ?? 0,
      updatedAt: map['updated_at'] ?? 0,
      deleted: (map['deleted'] ?? 0) == 1,
      dirty: (map['dirty'] ?? 0) == 1,
    );
  }

  Task copyWith({
    String? sid,
    String? name,
    TaskType? type,
    int? durationDays,
    bool? isPerpetual,
    DateTime? createdAt,
    bool? isActive,
    FrequencyType? frequencyType,
    int? weeklyTarget,
    int? sortOrder,
    int? updatedAt,
    bool? deleted,
    bool? dirty,
  }) {
    return Task(
      sid: sid ?? this.sid,
      name: name ?? this.name,
      type: type ?? this.type,
      durationDays: durationDays ?? this.durationDays,
      isPerpetual: isPerpetual ?? this.isPerpetual,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      frequencyType: frequencyType ?? this.frequencyType,
      weeklyTarget: weeklyTarget ?? this.weeklyTarget,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
    );
  }

  @override
  String toString() {
    return 'Task(sid: $sid, name: $name, type: $type, durationDays: $durationDays, isPerpetual: $isPerpetual, createdAt: $createdAt, isActive: $isActive, frequencyType: $frequencyType, weeklyTarget: $weeklyTarget, sortOrder: $sortOrder)';
  }
}
