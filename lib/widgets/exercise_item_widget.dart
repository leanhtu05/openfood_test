import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../utils/constants.dart';

class ExerciseItemWidget extends StatelessWidget {
  final Exercise exercise;
  final Function(bool) onSelectionChanged;
  final Function(int) onMinutesChanged;

  const ExerciseItemWidget({
    Key? key,
    required this.exercise,
    required this.onSelectionChanged,
    required this.onMinutesChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: exercise.isSelected ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Toggle selection when tapped
          onSelectionChanged(!exercise.isSelected);
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              margin: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: exercise.isSelected ? Colors.green.shade100 : Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                _getExerciseIcon(exercise.name),
                color: exercise.isSelected ? Colors.green : Colors.grey.shade700,
                size: 20,
              ),
            ),
            
            SizedBox(width: 8),
            
            // Exercise details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.green,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '-${exercise.calculatedCalories}kcal',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Intensity and time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Vừa phải',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        if (exercise.minutes > 5) {
                          onMinutesChanged(exercise.minutes - 5);
                        }
                      },
                      child: Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      '${exercise.minutes} phút',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 14,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        onMinutesChanged(exercise.minutes + 5);
                      },
                      child: Icon(
                        Icons.arrow_drop_up,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // Phương thức helper để lấy icon phù hợp dựa trên tên bài tập
  IconData _getExerciseIcon(String exerciseName) {
    switch (exerciseName.toLowerCase()) {
      case 'đi bộ':
        return Icons.directions_walk;
      case 'chạy':
        return Icons.directions_run;
      case 'đạp xe':
        return Icons.directions_bike;
      case 'nâng tạ':
        return Icons.fitness_center;
      case 'yoga':
        return Icons.self_improvement;
      case 'bơi lội':
        return Icons.pool;
      case 'máy chạy bộ':
        return Icons.directions_run;
      case 'bài tập tại nhà':
        return Icons.home;
      case 'giãn cơ':
        return Icons.accessibility_new;
      case 'hiit':
        return Icons.flash_on;
      case 'pilates':
        return Icons.psychology;
      case 'quần vợt':
        return Icons.sports_tennis;
      case 'bóng rổ':
        return Icons.sports_basketball;
      case 'bóng đá':
        return Icons.sports_soccer;
      default:
        return Icons.fitness_center;
    }
  }
}