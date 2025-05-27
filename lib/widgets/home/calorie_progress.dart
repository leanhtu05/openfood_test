import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'package:provider/provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/user_data_provider.dart';
import '../../screens/food_logging_screen.dart';
import '../../utils/tdee_calculator.dart';

class CalorieProgressSection extends StatelessWidget {
  final int? consumedCalories;
  final int? caloriesGoal;
  final int? exerciseCalories;

  const CalorieProgressSection({
    Key? key,
    this.consumedCalories,
    this.caloriesGoal,
    this.exerciseCalories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get data from providers
    final foodProvider = Provider.of<FoodProvider>(context);
    final exerciseProvider = Provider.of<ExerciseProvider>(context);
    final userDataProvider = Provider.of<UserDataProvider>(context);
    
    // Giảm bớt lượng in debug để tránh nặng hệ thống
    /* Chỉ hiển thị log trong chế độ debug chi tiết
    print('CalorieProgressSection: TDEE values from provider - ' 
        'Calories: ${userDataProvider.tdeeCalories}, '
        'Protein: ${userDataProvider.tdeeProtein}, '
        'Carbs: ${userDataProvider.tdeeCarbs}, '
        'Fat: ${userDataProvider.tdeeFat}');
    
    print('CalorieProgressSection: Nutrition goals from provider - ' 
        'Calories: ${userDataProvider.nutritionGoals["calories"]}, '
        'Protein: ${userDataProvider.nutritionGoals["protein"]}, '
        'Carbs: ${userDataProvider.nutritionGoals["carbs"]}, '
        'Fat: ${userDataProvider.nutritionGoals["fat"]}');
    */
    
    // Sử dụng memo hoặc cache cho các tính toán
    // Thay vì tính toán lại mỗi lần build, sử dụng cached value khi có thể
    
    // Get actual calorie data from providers
    final actualConsumedCalories = consumedCalories ?? 
        foodProvider.getNutritionTotals(date: foodProvider.selectedDate)['calories']?.toInt() ?? 0;
    
    // Luôn sử dụng giá trị từ getConsistentCalorieGoal để đảm bảo tính nhất quán
    final actualCaloriesGoal = userDataProvider.getConsistentCalorieGoal();
    
    // Debug log để xác định nguồn của mục tiêu calo
    String source = "unknown";
    if (userDataProvider.goal == 'Giảm cân' && userDataProvider.nutritionGoals.containsKey('calories') && userDataProvider.nutritionGoals['calories']! > 0) {
      source = "adjusted_nutrition_goals";
    } else if (userDataProvider.tdeeCalories > 0) {
      source = "tdee";
    } else if (userDataProvider.nutritionGoals.containsKey('calories') && userDataProvider.nutritionGoals['calories']! > 0) {
      source = "nutrition_goals";
    } else if (userDataProvider.dailyCalories > 0) {
      source = "daily_calories";
    } else {
      source = "default_value";
    }
    print('CalorieProgressSection: Mục tiêu calo = $actualCaloriesGoal (nguồn: $source)');
        
    // Get exercise calories from exercise provider
    final actualExerciseCalories = exerciseCalories ?? 
        exerciseProvider.totalCalories;
    
    // Calculate remaining calories
    final int remainingCalories = actualCaloriesGoal - actualConsumedCalories + actualExerciseCalories;
    
    // Calculate progress value (capped at 1.0 for progress bar)
    // Ensure actualCaloriesGoal is not zero for division
    final double progressValue = (actualCaloriesGoal > 0)
        ? (actualConsumedCalories / actualCaloriesGoal).clamp(0.0, 1.0)
        : 0.0; // Default to 0.0 if actualCaloriesGoal is 0 or less
    
    // Calculate actual percentage for display (can be over 100%)
    // Ensure actualCaloriesGoal is not zero for division
    final int displayPercentage = (actualCaloriesGoal > 0)
        ? ((actualConsumedCalories / actualCaloriesGoal) * 100).toInt()
        : 0; // Default to 0 if actualCaloriesGoal is 0 or less
    
    // Get nutrition data for macros from provider
    final nutritionTotals = foodProvider.getNutritionTotals(date: foodProvider.selectedDate);
    
    // Get macros values
    final consumedProtein = (nutritionTotals['protein'] ?? 0.0).round();
    final consumedCarbs = (nutritionTotals['carbs'] ?? 0.0).round();
    final consumedFat = (nutritionTotals['fat'] ?? 0.0).round();
    
    // Get macro goals from user data provider
    int tempProteinGoal;
    int tempCarbsGoal;
    int tempFatGoal;
    
    // If user has set nutrition goals, use them, otherwise calculate from TDEE
    if (userDataProvider.nutritionGoals.containsKey('protein') && 
        userDataProvider.nutritionGoals.containsKey('carbs') && 
        userDataProvider.nutritionGoals.containsKey('fat')) {
      tempProteinGoal = userDataProvider.nutritionGoals['protein']!.toInt();
      tempCarbsGoal = userDataProvider.nutritionGoals['carbs']!.toInt();
      tempFatGoal = userDataProvider.nutritionGoals['fat']!.toInt();
    } else {
      // Calculate macro goals from TDEE
      final calculator = TDEECalculator(
        gender: userDataProvider.gender,
        age: userDataProvider.age,
        heightCm: userDataProvider.heightCm,
        weightKg: userDataProvider.weightKg,
        activityLevel: userDataProvider.activityLevel,
        goal: userDataProvider.goal,
        pace: userDataProvider.pace,
      );
      
      final macrosTarget = calculator.calculateMacroDistribution();
      tempProteinGoal = macrosTarget['protein']!.round();
      tempCarbsGoal = macrosTarget['carbs']!.round();
      tempFatGoal = macrosTarget['fat']!.round();
    }

    // Ensure macro goals are not zero to prevent division by zero
    final proteinGoal = (tempProteinGoal == 0 || tempProteinGoal.isNaN || tempProteinGoal.isInfinite) ? 1 : tempProteinGoal;
    final carbsGoal = (tempCarbsGoal == 0 || tempCarbsGoal.isNaN || tempCarbsGoal.isInfinite) ? 1 : tempCarbsGoal;
    final fatGoal = (tempFatGoal == 0 || tempFatGoal.isNaN || tempFatGoal.isInfinite) ? 1 : tempFatGoal;
    
    // Calculate percentages for macro progress
    final proteinPercentage = ((consumedProtein / proteinGoal) * 100).round().clamp(0, 100);
    final carbsPercentage = ((consumedCarbs / carbsGoal) * 100).round().clamp(0, 100);
    final fatPercentage = ((consumedFat / fatGoal) * 100).round().clamp(0, 100);
    
    return Column(
      children: [
        // Original Calorie Progress Card
        GestureDetector(
          onTap: () => _navigateToFoodLogging(context, foodProvider),
          child: Container(
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
                          '$displayPercentage%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                            color: displayPercentage > 100 ? Colors.red : AppColors.food,
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
                          flex: (progressValue * 100).isFinite ? (progressValue * 100).toInt() : 0, // Check for isFinite
                    child: Container(
                      decoration: BoxDecoration(
                              color: displayPercentage > 100 ? Colors.red : AppColors.food,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Remaining calories
                  if (progressValue < 1.0)
                    Flexible(
                      flex: ((1.0 - progressValue) * 100).isFinite ? ((1.0 - progressValue) * 100).toInt() : 100, // Check for isFinite
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
                          value: '$actualCaloriesGoal',
                    icon: Icons.flag_rounded,
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildCalorieCard(
                    label: 'Đã tiêu thụ',
                          value: '$actualConsumedCalories',
                    icon: Icons.restaurant_rounded,
                    color: AppColors.food,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildCalorieCard(
                    label: 'Đã đốt',
                          value: '+$actualExerciseCalories',
                    icon: Icons.directions_run_rounded,
                    color: AppColors.exercise,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
          ),
        ),
        
        SizedBox(height: 8),
        
        // Add Nutrition Card section
        _buildNutritionCard(
          context,
          proteinPercentage,
          consumedProtein,
          proteinGoal,
          carbsPercentage,
          consumedCarbs,
          carbsGoal,
          fatPercentage,
          consumedFat,
          fatGoal,
          foodProvider
        ),
      ],
    );
  }

  // Mở màn hình ghi nhận bữa ăn
  void _navigateToFoodLogging(BuildContext context, FoodProvider foodProvider) async {
    // Lấy ngày đã chọn hiện tại
    final selectedDate = foodProvider.selectedDate;
    
    // Để tránh lag, sử dụng animation mượt mà hơn khi chuyển màn hình
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodLoggingScreen(
          initialDate: selectedDate,
        ),
      ),
    );
    
    // Nếu có dữ liệu trả về, cập nhật provider
    if (result != null && result is Map<String, dynamic>) {
      if (result.containsKey('foodEntriesUpdated') && result['foodEntriesUpdated'] == true) {
        // Chạy cập nhật dữ liệu trong một Future.microtask 
        // để không block UI thread
        Future.microtask(() async {
          // Tải lại dữ liệu thức ăn
          await foodProvider.loadData();
          
          // Xóa cache để đảm bảo dữ liệu được tính toán lại
          foodProvider.clearNutritionCache();
          
          // Nếu có thay đổi ngày được chọn, cũng cập nhật lại
          if (result.containsKey('selectedDate')) {
            final returnedDate = result['selectedDate'] as String?;
            if (returnedDate != null && returnedDate != selectedDate) {
              foodProvider.setSelectedDate(returnedDate);
            }
          }
        });
      }
    }
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
  
  // Nutrition card from NutritionCard widget
  Widget _buildNutritionCard(
    BuildContext context,
    int proteinPercentage,
    int proteinValue,
    int proteinGoal,
    int carbsPercentage,
    int carbsValue,
    int carbsGoal,
    int fatPercentage,
    int fatValue,
    int fatGoal,
    FoodProvider foodProvider
  ) {
    // Sử dụng một widget có hiệu năng cao hơn để hiển thị
    return GestureDetector(
      onTap: () => _navigateToFoodLogging(context, foodProvider),
      child: RepaintBoundary( // Thêm RepaintBoundary để ngăn việc vẽ lại không cần thiết
        child: Container(
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
                // Header biểu đồ tròn và chữ Dinh dưỡng
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFFF3E5F5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pie_chart,
                        color: Colors.purple,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Dinh dưỡng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Sử dụng Row thay vì ListView để tránh overhead không cần thiết
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Protein
                    _buildNutrientCircle(
                      'Protein',
                      proteinPercentage,
                      '$proteinValue/${proteinGoal}g',
                      Color(0xFF2196F3)
                    ),
                    
                    // Carbs
                    _buildNutrientCircle(
                      'Carbs',
                      carbsPercentage,
                      '$carbsValue/${carbsGoal}g',
                      Color(0xFFFF9800)
                    ),
                    
                    // Chất béo
                    _buildNutrientCircle(
                      'Chất béo',
                      fatPercentage,
                      '$fatValue/${fatGoal}g',
                      Color(0xFFFFC107)
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method for building nutrient circles
  Widget _buildNutrientCircle(
    String label,
    int percentage,
    String details,
    Color color
  ) {
    // Extract the values from details for better display
    final parts = details.split('/');
    final currentValue = parts[0].replaceAll(RegExp(r'[^0-9]'), ''); // Remove non-numeric characters
    final goalValue = parts[1].replaceAll(RegExp(r'g'), '').trim(); // Remove 'g' and trim
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 8,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$currentValue / $goalValue${label == "Protein" || label == "Carbs" || label == "Chất béo" ? "g" : " kcal"}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
} 
