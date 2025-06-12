import 'package:flutter/material.dart';

class NutrientDetailCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const NutrientDetailCard({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconForNutrient(),
              size: 18,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForNutrient() {
    // Trả về icon phù hợp với loại chất dinh dưỡng
    switch (label.toLowerCase()) {
      case 'đạm':
      case 'protein':
        return Icons.fitness_center;
      case 'carbs':
      case 'tinh bột':
        return Icons.grain;
      case 'chất béo':
      case 'fat':
        return Icons.opacity;
      default:
        return Icons.category;
    }
  }
} 