import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../utils/constants.dart';

class ExerciseSection extends StatelessWidget {
  final List<Exercise> exercises;
  final VoidCallback onAddExercise;
  final VoidCallback onViewHistory;

  const ExerciseSection({
    Key? key,
    required this.exercises,
    required this.onAddExercise,
    required this.onViewHistory,
  }) : super(key: key);

  int get totalExerciseCalories {
    return exercises.fold(0, (sum, exercise) => sum + exercise.calories);
  }
  
  // Phương thức helper để lấy icon phù hợp dựa trên tên bài tập
  IconData _getExerciseIcon(String exerciseName) {
    final name = exerciseName.toLowerCase();
    
    if (name.contains('đi bộ')) return Icons.directions_walk;
    if (name.contains('chạy')) return Icons.directions_run;
    if (name.contains('đạp xe')) return Icons.directions_bike;
    if (name.contains('nâng tạ') || name.contains('tạ')) return Icons.fitness_center;
    if (name.contains('yoga')) return Icons.self_improvement;
    if (name.contains('bơi')) return Icons.pool;
    if (name.contains('máy chạy')) return Icons.directions_run;
    if (name.contains('nhà')) return Icons.home;
    if (name.contains('giãn') || name.contains('dãn')) return Icons.accessibility_new;
    if (name.contains('hiit')) return Icons.flash_on;
    if (name.contains('pilates')) return Icons.psychology;
    if (name.contains('vợt') || name.contains('tennis')) return Icons.sports_tennis;
    if (name.contains('bóng rổ') || name.contains('basketball')) return Icons.sports_basketball;
    if (name.contains('bóng đá') || name.contains('soccer')) return Icons.sports_soccer;
    
    return Icons.fitness_center;
  }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header với icon và title
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.exercise.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_run_rounded,
                    color: AppColors.exercise,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Tập thể dục',
                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                ),
                Spacer(),
                if (totalExerciseCalories > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.exercise.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded, 
                            size: 14, color: AppColors.exercise),
                        SizedBox(width: 4),
                        Text(
                          '${_formatCalories(totalExerciseCalories)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.exercise,
                          ),
                        ),
                        Text(
                          ' kcal',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.exercise,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(width: 8),
                InkWell(
                  onTap: onViewHistory,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          // Phần nội dung
          if (exercises.isEmpty)
            _buildEmptyContent()
          else
            _buildExerciseList(),

          // Nút thêm bài tập
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: onAddExercise,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.exercise,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Thêm bài tập',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyContent() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.exercise.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_run_outlined,
                size: 36,
                color: AppColors.exercise,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Chưa có bài tập nào',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Hãy tập thể dục thường xuyên để có một cơ thể khỏe mạnh',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExerciseList() {
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: exercises.length > 2 ? 2 : exercises.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.grey.shade200,
          ),
          itemBuilder: (context, index) => _buildExerciseItem(exercises[index]),
        ),
        
        if (exercises.length > 2)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: InkWell(
              onTap: onViewHistory,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.exercise.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Xem tất cả ${exercises.length} bài tập',
                    style: TextStyle(
                      color: AppColors.exercise,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildExerciseItem(Exercise exercise) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: null, // Will be implemented for editing exercise
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.exercise.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  _getExerciseIcon(exercise.name),
                  color: AppColors.exercise,
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${exercise.minutes} phút - ${exercise.intensity}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.exercise.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_formatCalories(exercise.calories)} kcal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.exercise,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatCalories(int calories) {
    return calories.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},'
    );
  }
} 