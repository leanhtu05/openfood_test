import 'package:flutter/material.dart';
import 'meal_cards.dart';

class MealNutritionSummary extends StatelessWidget {
  final String mealType;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const MealNutritionSummary({
    Key? key,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với tên bữa ăn và tổng calories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Icon và tên bữa ăn
                Icon(getMealIcon(mealType), color: Colors.grey.shade700, size: 16),
                SizedBox(width: 4),
                Text(
                  mealType,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                
                // Thêm Spacer để đẩy các thông tin dinh dưỡng sang phải
                Spacer(),
                
                // Thông tin dinh dưỡng
                Wrap(
                  spacing: 6,
                  children: [
                    _buildNutrientValue(
                      icon: Icons.local_fire_department,
                      value: '${calories}kcal',
                      color: Colors.red.shade400,
                    ),
                    _buildNutrientValue(
                      icon: Icons.water_drop,
                      value: '${protein}g',
                      color: Colors.blue.shade400,
                    ),
                    _buildNutrientValue(
                      icon: Icons.grain,
                      value: '${carbs}g',
                      color: Colors.orange.shade400,
                    ),
                    _buildNutrientValue(
                      icon: Icons.circle,
                      value: '${fat}g',
                      color: Colors.green.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Danh sách món ăn (nếu cần)
          // ...
        ],
      ),
    );
  }
  
  // Widget hiển thị giá trị dinh dưỡng với biểu tượng
  Widget _buildNutrientValue({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
} 