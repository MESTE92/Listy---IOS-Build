import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../constants/theme_colors.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final Function(Task) onToggle;
  final Function(Task) onDelete;
  final bool isShopping;
  final Function(Task, int)? onQuantityChanged;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.isShopping = false,
    this.onQuantityChanged,
  });

  Color _getPriorityColor() {
    if (task.isCompleted) return PriorityColors.done;
    switch (task.priority) {
      case 'urgent':
        return PriorityColors.urgent;
      case 'medium':
        return PriorityColors.medium;
      case 'low':
        return PriorityColors.low;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDelete(task);
          return true; // Delete
        } else {
          onToggle(task);
          return false; // Don't dismiss, just toggle
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: task.isCompleted ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1,
            ),
            left: BorderSide(
              color: _getPriorityColor(),
              width: 5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: (_) => onToggle(task),
              activeColor: AppColors.lavender,
              checkColor: Colors.white,
            ),
            Expanded(
              child: Text(
                task.name,
                style: TextStyle(
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted ? Colors.grey : null,
                ),
              ),
            ),
            if (isShopping && onQuantityChanged != null)
              _buildQuantityCounter(context),
            
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => onDelete(task),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityCounter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onQuantityChanged!(task, -1),
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.remove, size: 20, color: isDark ? Colors.white : Colors.black),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.center,
            child: Text(
              '${task.quantity}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black
              ),
            ),
          ),
          InkWell(
            onTap: () => onQuantityChanged!(task, 1),
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.add, size: 20, color: isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
