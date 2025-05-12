import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class NutritionSection extends StatelessWidget {
  final int consumedProtein;
  final int proteinGoal;
  final int consumedFat;
  final int fatGoal;
  final int consumedCarbs;
  final int carbsGoal;

  const NutritionSection({
    Key? key,
    required this.consumedProtein,
    required this.proteinGoal,
    required this.consumedFat,
    required this.fatGoal,
    required this.consumedCarbs,
    required this.carbsGoal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with nutrition icon
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: Colors.purple,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Dinh dưỡng',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Nutrition progress indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildNutrientProgress(
                    'Protein',
                    consumedProtein,
                    proteinGoal,
                    Colors.blue,
                    Icons.fitness_center_rounded,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildNutrientProgress(
                    'Carbs',
                    consumedCarbs,
                    carbsGoal,
                    Colors.orange,
                    Icons.grain_rounded,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildNutrientProgress(
                    'Chất béo',
                    consumedFat,
                    fatGoal,
                    Colors.yellow.shade700,
                    Icons.opacity_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientProgress(
    String label,
    int current,
    int goal,
    Color color,
    IconData icon,
  ) {
    final double progress = current / goal;
    final bool isOverGoal = current > goal;
    
    return Column(
      children: [
        // Circular progress indicator
        Stack(
          alignment: Alignment.center,
          children: [
            // Circular progress
            SizedBox(
              height: 70,
              width: 70,
              child: CircularProgressIndicator(
                value: progress > 1.0 ? 1.0 : progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverGoal ? Colors.red : color,
                ),
                strokeWidth: 6,
              ),
            ),
            // Center content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isOverGoal ? Colors.red : color,
                  size: 16,
                ),
                SizedBox(height: 4),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOverGoal ? Colors.red : color,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          '$current/${goal}g',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
} 