import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class CalorieProgressSection extends StatelessWidget {
  final int consumedCalories;
  final int caloriesGoal;
  final int exerciseCalories;

  const CalorieProgressSection({
    Key? key,
    required this.consumedCalories,
    required this.caloriesGoal,
    required this.exerciseCalories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tính giá trị cho thanh tiến độ
    final int remainingCalories = caloriesGoal - consumedCalories + exerciseCalories;
    final double progressValue = consumedCalories / caloriesGoal;
    
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
            // Header with calorie icon
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.food.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.food,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calo hôm nay',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      remainingCalories > 0 
                          ? 'Còn lại $remainingCalories calo'
                          : 'Đã vượt ${-remainingCalories} calo',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: remainingCalories > 0 ? AppColors.textSecondary : Colors.red,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.food.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    progressValue < 1.0 
                        ? '${(progressValue * 100).toInt()}%'
                        : '${((consumedCalories / caloriesGoal) * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: progressValue > 1.0 ? Colors.red : AppColors.food,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Calorie progress bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  // Consumed calories
                  Flexible(
                    flex: (progressValue * 100).toInt().clamp(0, 100),
                    child: Container(
                      decoration: BoxDecoration(
                        color: progressValue > 1.0 ? Colors.red : AppColors.food,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Remaining calories
                  if (progressValue < 1.0)
                    Flexible(
                      flex: ((1.0 - progressValue) * 100).toInt(),
                      child: Container(color: Colors.transparent),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Calorie details in cards
            Row(
              children: [
                Expanded(
                  child: _buildCalorieCard(
                    label: 'Mục tiêu',
                    value: '$caloriesGoal',
                    icon: Icons.flag_rounded,
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildCalorieCard(
                    label: 'Đã tiêu thụ',
                    value: '$consumedCalories',
                    icon: Icons.restaurant_rounded,
                    color: AppColors.food,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildCalorieCard(
                    label: 'Đã đốt',
                    value: '+$exerciseCalories',
                    icon: Icons.directions_run_rounded,
                    color: AppColors.exercise,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 