import '../providers/user_data_provider.dart';

class NutritionCalculator {
  // Calculate daily calorie target based on user data
  static Map<String, double> calculateNutritionTargets(UserDataProvider userData) {
    // Calculate calories target
    double caloriesTarget = userData.tdeeCalories;
    
    // If tdeeCalories is not set, calculate it
    if (caloriesTarget <= 0) {
      double bmr = 0;
      // Mifflin-St Jeor Equation
      if (userData.gender == 'male') {
        bmr = 10 * userData.weightKg + 6.25 * userData.heightCm - 5 * userData.age + 5;
      } else {
        bmr = 10 * userData.weightKg + 6.25 * userData.heightCm - 5 * userData.age - 161;
      }
      
      // Apply activity factor
      double activityFactor = 1.2; // Default: sedentary
      switch (userData.activityLevel) {
        case 'Ít vận động':
          activityFactor = 1.2;
          break;
        case 'Nhẹ nhàng':
          activityFactor = 1.375;
          break;
        case 'Trung bình':
          activityFactor = 1.55;
          break;
        case 'Vận động nhiều':
          activityFactor = 1.725;
          break;
        case 'Vận động rất nhiều':
          activityFactor = 1.9;
          break;
      }
      
      // Apply goal modifier
      double goalModifier = 0;
      switch (userData.goal) {
        case 'Giảm cân':
          goalModifier = -500;
          break;
        case 'Tăng cân':
          goalModifier = 500;
          break;
      }
      
      caloriesTarget = (bmr * activityFactor + goalModifier);
    }
    
    // Calculate macros based on calories
    final double proteinTarget = userData.tdeeProtein > 0
        ? userData.tdeeProtein.toDouble()
        : (caloriesTarget * 0.3 / 4); // 30% of calories from protein
        
    final double fatTarget = userData.tdeeFat > 0
        ? userData.tdeeFat.toDouble()
        : (caloriesTarget * 0.25 / 9); // 25% of calories from fat
        
    final double carbsTarget = userData.tdeeCarbs > 0
        ? userData.tdeeCarbs.toDouble()
        : (caloriesTarget * 0.45 / 4); // 45% of calories from carbs
    
    return {
      'calories': caloriesTarget,
      'protein': proteinTarget,
      'fat': fatTarget,
      'carbs': carbsTarget,
    };
  }
} 