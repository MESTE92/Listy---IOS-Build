import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../constants/theme_colors.dart';

class FilterSegments extends StatelessWidget {
  final String currentFilter;
  final Function(String) onFilterChanged;

  const FilterSegments({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final isShopping = provider.isShopping;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Lavender color for selection
    final selectedColor = AppColors.lavender;
    final unselectedColor = Colors.transparent;
    final borderColor = AppColors.lavender;
    
    // Calculate counts
    Map<String, int> counts = {'urgent': 0, 'medium': 0, 'low': 0, 'done': 0};
    if (!isShopping) {
      for (var t in provider.currentTasks) {
         if (t.isCompleted) {
           counts['done'] = (counts['done'] ?? 0) + 1;
         } else {
           counts[t.priority] = (counts[t.priority] ?? 0) + 1;
         }
      }
    }

    // Helper to build a segment button
    Widget _buildSegment(String value, IconData icon, Color iconColor, String label, {bool isSelected = false, int? count}) {
      return Expanded(
        child: GestureDetector(
          onTap: () => onFilterChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : unselectedColor,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? Colors.white : iconColor, size: 20),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                      fontSize: 12,
                    ),
                  )
                ],
                if (count != null && count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.3) : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black)
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      );
    }

    if (isShopping) {
      return Row(
        children: [
          _buildSegment('open', Icons.list, isDark ? Colors.white : Colors.black, "Offen", isSelected: currentFilter == 'open'),
          _buildSegment('cart', Icons.shopping_cart, isDark ? Colors.white : Colors.black, "Im Warenkorb", isSelected: currentFilter == 'cart'),
        ],
      );
    } else {
      return Row(
        children: [
          _buildSegment('urgent', Icons.circle, Colors.red, "", isSelected: currentFilter == 'urgent', count: counts['urgent']),
          _buildSegment('medium', Icons.circle, Colors.orange, "", isSelected: currentFilter == 'medium', count: counts['medium']),
          _buildSegment('low', Icons.circle, Colors.green, "", isSelected: currentFilter == 'low', count: counts['low']),
          _buildSegment('done', Icons.check_circle, PriorityColors.done, "", isSelected: currentFilter == 'done', count: counts['done']),
        ],
      );
    }
  }
}
