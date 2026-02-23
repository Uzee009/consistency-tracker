// lib/models/user_model.dart

class User {
  final int id;
  final String name;
  final DateTime createdAt;
  final int monthlyCheatDays; // Number of cheat days allowed per month

  User({
    required this.id,
    required this.name,
    required this.createdAt,
    this.monthlyCheatDays = 2, // Default value
  });

  // Convert a User object into a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'monthly_cheat_days': monthlyCheatDays,
    };
  }

  // Extract a User object from a Map.
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      monthlyCheatDays: map['monthly_cheat_days'] ?? 2, // Provide default if null
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, createdAt: $createdAt, monthlyCheatDays: $monthlyCheatDays)';
  }
}
