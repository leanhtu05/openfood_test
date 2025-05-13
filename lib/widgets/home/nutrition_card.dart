import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/user_data_provider.dart';
import '../../utils/tdee_calculator.dart';
import '../../utils/constants.dart';
import '../../screens/food_logging_screen.dart';
import '../../providers/exercise_provider.dart';

class NutritionCard extends StatefulWidget {
  const NutritionCard({Key? key}) : super(key: key);

  @override
  _NutritionCardState createState() => _NutritionCardState();
}

class _NutritionCardState extends State<NutritionCard> {
  @override
  void initState() {
    super.initState();
    // Xóa cache khi widget được tạo
    Future.microtask(() {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      foodProvider.refreshNutrition();
    });
  }

  @override
  Widget build(BuildContext context) {
    final foodProvider = Provider.of<FoodProvider>(context);
    final userData = Provider.of<UserDataProvider>(context);
    final exerciseProvider = Provider.of<ExerciseProvider>(context);
    
    // Đảm bảo lấy dữ liệu cho ngày đã chọn
    final selectedDate = foodProvider.selectedDate;
    
    final nutritionTotals = foodProvider.getNutritionTotals(date: selectedDate);
    final consumedCalories = nutritionTotals['calories'].round().toInt();
    final consumedProtein = nutritionTotals['protein'].round().toInt();
    final consumedCarbs = nutritionTotals['carbs'].round().toInt();
    final consumedFat = nutritionTotals['fat'].round().toInt();
    final totalWeight = nutritionTotals['totalWeight']?.round().toInt() ?? 0;
    
    // Tính mục tiêu dinh dưỡng
    final calculator = TDEECalculator(
      gender: userData.gender,
      age: userData.age,
      heightCm: userData.heightCm,
      weightKg: userData.weightKg,
      activityLevel: userData.activityLevel,
      goal: userData.goal,
      pace: userData.pace,
    );
    
    final dailyCalories = calculator.calculateDailyCalories().round().toInt();
    final macrosTarget = calculator.calculateMacroDistribution();
    final proteinGoal = macrosTarget['protein']!.round().toInt();
    final carbsGoal = macrosTarget['carbs']!.round().toInt();
    final fatGoal = macrosTarget['fat']!.round().toInt();
    
    // Lấy calo đã đốt từ bài tập
    final burnedCalories = exerciseProvider.totalCalories;
    
    // Tính toán số calo còn lại và phần trăm
    // Công thức: Calo còn lại = Mục tiêu - Đã tiêu thụ + Đã đốt
    final caloriesLeft = (dailyCalories - consumedCalories + burnedCalories).toInt();
    final caloriePercentage = ((consumedCalories - burnedCalories) / dailyCalories * 100).round().clamp(0, 100).toInt();
    
    // Tính phần trăm cho các chất dinh dưỡng
    final proteinPercentage = ((consumedProtein / proteinGoal) * 100).round().clamp(0, 100).toInt();
    final carbsPercentage = ((consumedCarbs / carbsGoal) * 100).round().clamp(0, 100).toInt();
    final fatPercentage = ((consumedFat / fatGoal) * 100).round().clamp(0, 100).toInt();
    
    return Column(
      children: [
        // Thẻ Calo mới thiết kế giống ảnh
        buildCalorieCard(
          context,
          caloriesLeft,
          dailyCalories,
          consumedCalories,
          caloriePercentage,
          burnedCalories,
          foodProvider
        ),
        
        SizedBox(height: 8),
        
        // Thẻ Dinh dưỡng mới thiết kế giống ảnh
        buildNutritionCard(
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
  
  // Mở màn hình ghi nhận bữa ăn và cập nhật dữ liệu khi quay lại
  void _navigateToFoodLogging(BuildContext context, FoodProvider foodProvider) async {
    // Lấy ngày đã chọn hiện tại
    final selectedDate = foodProvider.selectedDate;
    
    // Chuyển đến màn hình ghi nhận bữa ăn
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodLoggingScreen(
          initialDate: selectedDate,
        ),
      ),
    );
    
    // Nếu có dữ liệu trả về (result != null), cập nhật provider
    if (result != null && result is Map<String, dynamic>) {
      if (result.containsKey('foodEntriesUpdated') && result['foodEntriesUpdated'] == true) {
        // Tải lại dữ liệu thức ăn một lần duy nhất
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
      }
    }
  }
  
  Widget buildCalorieCard(
    BuildContext context,
    int caloriesLeft,
    int caloriesGoal,
    int consumedCalories,
    int percentage,
    int burnedCalories,
    FoodProvider foodProvider
  ) {
    // Tính toán chiều cao dựa trên kích thước màn hình
    final screenWidth = MediaQuery.of(context).size.width;
    final boxSize = (screenWidth - 56) / 3; // 16 padding hai bên, 8 space giữa các box
    
    return GestureDetector(
      onTap: () => _navigateToFoodLogging(context, foodProvider),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
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
              // Header với biểu tượng lửa và phần trăm
              Row(
                children: [
                  // Biểu tượng lửa
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  // Tiêu đề Calo hôm nay
                  Expanded(
                    child: Text(
                      'Calo hôm nay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  
                  // Phần trăm
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Còn lại bao nhiêu calo
              Text(
                'Còn lại $caloriesLeft calo',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Thanh tiến trình
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  minHeight: 10,
                ),
              ),
              
              SizedBox(height: 16),
              
              // Ba ô thông tin: Mục tiêu, Đã tiêu thụ, Đã đốt
              Row(
                children: [
                  // Mục tiêu
                  Expanded(
                    child: Container(
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: Color(0xFFF1F8E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flag, color: Colors.green, size: 20),
                          SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$caloriesGoal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Mục tiêu',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 8),
                  
                  // Đã tiêu thụ
                  Expanded(
                    child: Container(
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant, color: Colors.orange, size: 20),
                          SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$consumedCalories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Đã tiêu thụ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 8),
                  
                  // Đã đốt
                  Expanded(
                    child: Container(
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run, color: Colors.pink, size: 20),
                          SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '+$burnedCalories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.pink,
                              ),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Đã đốt',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget buildNutritionCard(
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
    return GestureDetector(
      onTap: () => _navigateToFoodLogging(context, foodProvider),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
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
              
              // Ba biểu đồ tròn cho protein, carbs, chất béo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Protein
                  buildNutrientCircle(
                    'Protein',
                    proteinPercentage,
                    '$proteinValue/${proteinGoal}g',
                    Color(0xFF2196F3)
                  ),
                  
                  // Carbs
                  buildNutrientCircle(
                    'Carbs',
                    carbsPercentage,
                    '$carbsValue/${carbsGoal}g',
                    Color(0xFFFF9800)
                  ),
                  
                  // Chất béo
                  buildNutrientCircle(
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
    );
  }

  Widget buildNutrientCircle(
    String label,
    int percentage,
    String details,
    Color color
  ) {
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
        SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            details,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
} 