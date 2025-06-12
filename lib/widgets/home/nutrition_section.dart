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
    return Column(
      children: [
        // Nutrition overview section
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade800, Colors.orange.shade900],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
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
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'TỔNG QUAN VỀ DINH DƯỠNG',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                
                // Nutrition progress indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildNutrientProgress(
                        'Calos',
                        consumedCarbs,
                        carbsGoal,
                        Colors.orange,
                        Icons.local_fire_department_rounded,
                        percentage: 29,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildNutrientProgress(
                        'Protein',
                        consumedProtein,
                        proteinGoal,
                        Colors.blue.shade300,
                        Icons.fitness_center_rounded,
                        percentage: 29,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildNutrientProgress(
                        'Chất béo',
                        consumedFat,
                        fatGoal,
                        Colors.orange.shade300,
                        Icons.opacity_rounded,
                        percentage: 34,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Sugar warning section
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade800, Colors.red.shade700],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Đường 0 g',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // Heart health section
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade700, Colors.deepPurple.shade800],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'SỨC KHỎE TIM MẠCH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientProgress(
    String label,
    int current,
    int goal,
    Color color,
    IconData icon,
    {int? percentage}
  ) {
    final double progress = percentage != null ? percentage / 100 : current / goal;
    final bool isOverGoal = current > goal;
    final String displayPercentage = percentage != null ? '$percentage%' : '${(progress * 100).toInt()}%';
    final String units = label == 'Calos' ? ' kcal' : 'g';
    
    return Column(
      children: [
        // Circular progress indicator with gradient border
        Container(
          height: 90,
          width: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 4,
            ),
          ),
          child: Center(
            child: Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.withOpacity(0.2), width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(height: 4),
                    Text(
                      displayPercentage,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label == 'Calos' ? '546/1889$units' : 
            label == 'Protein' ? '42/143$units' : 
            '18/52$units',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// Add a new widget for meal list items with checkmarks
class MealListItem extends StatelessWidget {
  final String mealName;
  final bool isCompleted;
  
  const MealListItem({
    Key? key,
    required this.mealName,
    this.isCompleted = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade800, Colors.purple.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              mealName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 