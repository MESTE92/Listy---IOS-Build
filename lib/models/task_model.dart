import 'package:uuid/uuid.dart';

class Task {
  final String id;
  String name;
  bool isCompleted;
  String priority; // urgent, medium, low
  int quantity;

  Task({
    required this.name,
    this.isCompleted = false,
    this.priority = 'medium',
    this.quantity = 1,
    String? id,
  }) : id = id ?? const Uuid().v4();

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      name: json['name'],
      isCompleted: json['is_completed'] ?? false,
      priority: json['priority'] ?? 'medium',
      quantity: json['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_completed': isCompleted,
      'priority': priority,
      'quantity': quantity,
    };
  }
}
