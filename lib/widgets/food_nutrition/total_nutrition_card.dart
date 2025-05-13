import 'package:flutter/material.dart';
import 'nutrition_circle_detail.dart';
import 'package:provider/provider.dart';
import '../../providers/food_provider.dart';

class TotalNutritionCard extends StatelessWidget {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double caloriesGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;

  const TotalNutritionCard({
    Key? key,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.caloriesGoal = 2000,
    this.proteinGoal = 100,
    this.carbsGoal = 250,
    this.fatGoal = 70,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tạo các key duy nhất cho mỗi NutritionCircleDetail
    final caloriesKey = UniqueKey();
    final fatKey = UniqueKey();
    final proteinKey = UniqueKey();
    final carbsKey = UniqueKey();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng hợp dinh dưỡng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          
          // Nutrition circles in a row
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                NutritionCircleDetail(
                  circleKey: caloriesKey,
                  value: totalCalories.round().toString(),
                  total: "/${caloriesGoal.round()}",
                  progress: totalCalories / caloriesGoal,
                  color: Colors.amber.shade600,
                  remaining: "Calo",
                ),
                NutritionCircleDetail(
                  circleKey: fatKey,
                  value: totalFat.round().toString(),
                  total: "/${fatGoal.round()}g",
                  progress: totalFat / fatGoal,
                  color: Colors.green.shade600,
                  remaining: "Chất béo",
                ),
                NutritionCircleDetail(
                  circleKey: proteinKey,
                  value: totalProtein.round().toString(),
                  total: "/${proteinGoal.round()}g",
                  progress: totalProtein / proteinGoal,
                  color: Colors.blue.shade600,
                  remaining: "Protein",
                ),
                NutritionCircleDetail(
                  circleKey: carbsKey,
                  value: totalCarbs.round().toString(),
                  total: "/${carbsGoal.round()}g",
                  progress: totalCarbs / carbsGoal,
                  color: Colors.orange.shade600,
                  remaining: "Carbs",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 