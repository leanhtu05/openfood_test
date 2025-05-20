import 'package:flutter/material.dart';
import '../../models/meal_plan.dart';
import '../../utils/constants.dart';

class MealPlanCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback? onTap;

  const MealPlanCard({
    Key? key,
    required this.meal,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Xác định loại bữa ăn từ context hoặc mặc định
    String mealType = "Bữa ăn";
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal type with icon
              Row(
                children: [
                  Icon(
                    _getMealIcon(mealType),
                    color: _getMealColor(mealType),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    meal.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Meal description
              Text(
                meal.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 12),
              
              // Ingredients
              if (meal.ingredients.isNotEmpty) ...[
                Text(
                  'Nguyên liệu:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: meal.ingredients.map((ingredient) {
                    return Chip(
                      label: Text(
                        ingredient,
                        style: TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.all(0),
                    );
                  }).toList(),
                ),
              ],
              
              SizedBox(height: 12),
              
              // Nutrition summary
              _buildNutritionSummary(meal.nutrition),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNutritionSummary(Map<String, double> nutrition) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNutrientSummary(
            nutrition['calories']?.toStringAsFixed(0) ?? '0',
            'kcal',
            Icons.local_fire_department,
            Colors.orange,
          ),
          _buildNutrientSummary(
            nutrition['protein']?.toStringAsFixed(0) ?? '0',
            'g',
            Icons.fitness_center,
            Colors.blue,
          ),
          _buildNutrientSummary(
            nutrition['carbs']?.toStringAsFixed(0) ?? '0',
            'g',
            Icons.grain,
            Colors.green,
          ),
          _buildNutrientSummary(
            nutrition['fat']?.toStringAsFixed(0) ?? '0',
            'g',
            Icons.opacity,
            Colors.amber,
          ),
        ],
      ),
    );
  }
  
  Widget _buildNutrientInfo(
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: color,
        ),
        SizedBox(width: 4),
        Text(
          '$value $unit',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
  
  Widget _buildNutrientSummary(
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  IconData _getMealIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
      case 'bữa sáng':
        return Icons.wb_sunny_outlined;
      case 'lunch':
      case 'bữa trưa':
        return Icons.wb_cloudy_outlined;
      case 'dinner':
      case 'bữa tối':
        return Icons.nights_stay_outlined;
      case 'snack':
      case 'bữa phụ':
        return Icons.access_time;
      default:
        return Icons.restaurant;
    }
  }
  
  Color _getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
      case 'bữa sáng':
        return Colors.orange;
      case 'lunch':
      case 'bữa trưa':
        return Colors.lightBlue;
      case 'dinner':
      case 'bữa tối':
        return Colors.indigo;
      case 'snack':
      case 'bữa phụ':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }
}

class DayMealPlanCard extends StatelessWidget {
  final DayMealPlan dayPlan;
  final String dayOfWeek;
  final VoidCallback? onRegenerate;
  final Function(Meal)? onMealTap;

  const DayMealPlanCard({
    Key? key,
    required this.dayPlan,
    required this.dayOfWeek,
    this.onRegenerate,
    this.onMealTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  _formatDayOfWeek(dayOfWeek),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                _buildNutrientChip(
                  dayPlan.nutritionSummary['calories']?.toStringAsFixed(0) ?? '0',
                  'kcal',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20),
                  onPressed: onRegenerate,
                  tooltip: 'Tạo lại kế hoạch cho ngày này',
                ),
              ],
            ),
          ),
          
          // Meals list for each meal type
          ...dayPlan.meals.entries.map((entry) {
            final mealType = entry.key;
            final mealsList = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    mealType,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getMealColor(mealType),
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: mealsList.length,
                  itemBuilder: (context, index) {
                    final meal = mealsList[index];
                    return MealPlanCard(
                      meal: meal,
                      onTap: onMealTap != null ? () => onMealTap!(meal) : null,
                    );
                  },
                ),
              ],
            );
          }).toList(),
          
          // Daily nutrition summary
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng dinh dưỡng trong ngày',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                _buildNutritionProgressBars(dayPlan.nutritionSummary),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNutrientChip(
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            '$value $unit',
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
  
  Widget _buildNutritionProgressBars(Map<String, double> nutritionSummary) {
    // Giả sử mục tiêu dinh dưỡng hàng ngày
    final goalCalories = 2000.0;
    final goalProtein = 80.0;
    final goalCarbs = 250.0;
    final goalFat = 70.0;
    
    final calories = nutritionSummary['calories'] ?? 0.0;
    final protein = nutritionSummary['protein'] ?? 0.0;
    final carbs = nutritionSummary['carbs'] ?? 0.0;
    final fat = nutritionSummary['fat'] ?? 0.0;
    
    return Column(
      children: [
        _buildProgressBar('Calo', calories, goalCalories, 'kcal', Colors.orange),
        SizedBox(height: 8),
        _buildProgressBar('Protein', protein, goalProtein, 'g', Colors.blue),
        SizedBox(height: 8),
        _buildProgressBar('Carbs', carbs, goalCarbs, 'g', Colors.green),
        SizedBox(height: 8),
        _buildProgressBar('Chất béo', fat, goalFat, 'g', Colors.amber),
      ],
    );
  }
  
  Widget _buildProgressBar(
    String label,
    double value,
    double goal,
    String unit,
    Color color,
  ) {
    final progress = (value / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toInt()} / ${goal.toInt()} $unit',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Flexible(
                flex: (progress * 100).toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              if (progress < 1.0)
                Flexible(
                  flex: ((1.0 - progress) * 100).toInt(),
                  child: Container(),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _formatDayOfWeek(String dayOfWeek) {
    switch (dayOfWeek.toLowerCase()) {
      case 'monday':
        return 'Thứ hai';
      case 'tuesday':
        return 'Thứ ba';
      case 'wednesday':
        return 'Thứ tư';
      case 'thursday':
        return 'Thứ năm';
      case 'friday':
        return 'Thứ sáu';
      case 'saturday':
        return 'Thứ bảy';
      case 'sunday':
        return 'Chủ nhật';
      default:
        return dayOfWeek;
    }
  }
  
  IconData _getMealIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
      case 'bữa sáng':
        return Icons.wb_sunny_outlined;
      case 'lunch':
      case 'bữa trưa':
        return Icons.wb_cloudy_outlined;
      case 'dinner':
      case 'bữa tối':
        return Icons.nights_stay_outlined;
      case 'snack':
      case 'bữa phụ':
        return Icons.access_time;
      default:
        return Icons.restaurant;
    }
  }
  
  Color _getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
      case 'bữa sáng':
        return Colors.orange;
      case 'lunch':
      case 'bữa trưa':
        return Colors.lightBlue;
      case 'dinner':
      case 'bữa tối':
        return Colors.indigo;
      case 'snack':
      case 'bữa phụ':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }
} 