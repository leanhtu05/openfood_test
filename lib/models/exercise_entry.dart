import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseEntry {
  final String id;
  final String userId;
  final String exerciseId;
  final String name;
  final int calories;
  final int duration; // in minutes
  final String type;
  final DateTime timestamp;
  final DateTime createdAt;

  ExerciseEntry({
    required this.id,
    required this.userId,
    required this.exerciseId,
    required this.name,
    required this.calories,
    required this.duration,
    required this.type,
    required this.timestamp,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseEntry(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      exerciseId: json['exercise_id'] ?? '',
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      duration: json['duration'] ?? 0,
      type: json['type'] ?? '',
      timestamp: json['timestamp'] != null 
        ? (json['timestamp'] is Timestamp 
            ? (json['timestamp'] as Timestamp).toDate() 
            : DateTime.parse(json['timestamp']))
        : DateTime.now(),
      createdAt: json['createdAt'] != null 
        ? (json['createdAt'] is Timestamp 
            ? (json['createdAt'] as Timestamp).toDate() 
            : DateTime.parse(json['createdAt']))
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'exercise_id': exerciseId,
      'name': name,
      'calories': calories,
      'duration': duration,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
