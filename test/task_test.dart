
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_test/models/task_model.dart';

void main() {
  group('Task Model Tests', () {
    test('Task creation defaults', () {
      final task = Task(name: 'Test Task');
      expect(task.name, 'Test Task');
      expect(task.isCompleted, false);
      expect(task.priority, 'medium');
      expect(task.quantity, 1);
      expect(task.id, isNotNull);
    });

    test('Task JSON roundtrip', () {
      final task = Task(
        name: 'Json Task',
        isCompleted: true,
        priority: 'urgent',
        quantity: 5,
        id: '123'
      );

      final json = task.toJson();
      expect(json['name'], 'Json Task');
      expect(json['is_completed'], true);
      expect(json['quantity'], 5);
      expect(json['id'], '123');

      final fromJson = Task.fromJson(json);
      expect(fromJson.name, task.name);
      expect(fromJson.isCompleted, task.isCompleted);
      expect(fromJson.quantity, task.quantity);
      expect(fromJson.id, task.id);
    });
  });
}
