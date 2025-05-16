import 'package:flutter/material.dart';
import '../../models/food_entry.dart';

class TotalNutritionCard extends StatelessWidget {
  final FoodEntry foodEntry;
  final Map<String, double>? nutritionGoals;
  final double caloriesGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbsGoal;
  
  const TotalNutritionCard({
    Key? key,
    required this.foodEntry,
    this.nutritionGoals,
    this.caloriesGoal = 2000,
    this.proteinGoal = 50,
    this.fatGoal = 70,
    this.carbsGoal = 310,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Lấy dữ liệu dinh dưỡng từ FoodEntry hoặc từ nutritionInfo nếu có
    final Map<String, double> nutritionValues = foodEntry.calculateNutritionFromAPI();
    
    final totalCalories = nutritionValues['calories'] ?? 0.0;
    final totalProtein = nutritionValues['protein'] ?? 0.0; 
    final totalFat = nutritionValues['fat'] ?? 0.0;
    final totalCarbs = nutritionValues['carbs'] ?? 0.0;
    final totalWeight = nutritionValues['totalWeight'] ?? 100.0;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hiển thị thông tin tổng hợp
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Tổng quan về Dinh dưỡng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Hiển thị calo
          Row(
            children: [
              _buildNutritionBadge(
                icon: Icons.local_fire_department_outlined,
                color: Colors.orange,
                value: '${totalCalories.toInt()}',
                unit: 'kcal',
              ),
              SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalCalories / caloriesGoal).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    minHeight: 8,
                  ),
                ),
              ),
              SizedBox(width: 10),
              _buildGoalText(totalCalories, caloriesGoal, 'kcal'),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Hiển thị protein
          Row(
            children: [
              _buildNutritionBadge(
                icon: Icons.fitness_center_outlined,
                color: Colors.blue,
                value: '${totalProtein.toInt()}',
                unit: 'g',
              ),
              SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalProtein / proteinGoal).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 8,
                  ),
                ),
              ),
              SizedBox(width: 10),
              _buildGoalText(totalProtein, proteinGoal, 'g'),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Hiển thị carbs
          Row(
            children: [
              _buildNutritionBadge(
                icon: Icons.grain_outlined,
                color: Colors.green,
                value: '${totalCarbs.toInt()}',
                unit: 'g',
              ),
              SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalCarbs / carbsGoal).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    minHeight: 8,
                  ),
                ),
              ),
              SizedBox(width: 10),
              _buildGoalText(totalCarbs, carbsGoal, 'g'),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Hiển thị fat
          Row(
            children: [
              _buildNutritionBadge(
                icon: Icons.opacity_outlined,
                color: Colors.amber.shade700,
                value: '${totalFat.toInt()}',
                unit: 'g',
              ),
              SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalFat / fatGoal).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade700),
                    minHeight: 8,
                  ),
                ),
              ),
              SizedBox(width: 10),
              _buildGoalText(totalFat, fatGoal, 'g'),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Hiển thị tổng khối lượng
          Row(
            children: [
              Icon(Icons.scale_outlined, color: Colors.grey.shade700, size: 16),
              SizedBox(width: 8),
              Text(
                'Tổng Cộng: ${totalWeight.toInt()}g',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildNutritionBadge({
    required IconData icon,
    required Color color,
    required String value,
    required String unit,
  }) {
    return Container(
      width: 70,
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 4),
          Text(
            '$value$unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalText(double value, double goal, String unit) {
    return Container(
      width: 70,
      alignment: Alignment.centerRight,
      child: Text(
        '${value.toInt()}/${goal.toInt()}$unit',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
} 