import 'package:flutter/material.dart';

/// Công cụ tính TDEE (Total Daily Energy Expenditure) dựa trên thông tin người dùng
class TDEECalculator {
  /// Giới tính người dùng
  final String gender; // 'male' hoặc 'female'
  
  /// Tuổi tính bằng năm
  final int age;
  
  /// Chiều cao tính bằng cm
  final double heightCm;
  
  /// Cân nặng tính bằng kg
  final double weightKg;
  
  /// Mức độ hoạt động
  final String activityLevel;
  
  /// Mục tiêu (tăng cân, giảm cân, duy trì)
  final String goal;
  
  /// Tốc độ tăng/giảm cân (kg/tuần)
  final dynamic pace;

  /// Constructor
  TDEECalculator({
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
    required this.pace,
  });

  /// Tính BMR (Basal Metabolic Rate) dựa trên công thức Mifflin-St Jeor
  double calculateBMR() {
    if (gender == 'male') {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }
  }

  /// Hệ số hoạt động
  double get activityMultiplier {
    switch (activityLevel) {
      case 'Ít vận động':
        return 1.2; // Hoạt động ít
      case 'Hoạt động nhẹ':
        return 1.375; // Tập luyện nhẹ 1-3 lần/tuần
      case 'Hoạt động vừa phải':
        return 1.55; // Tập luyện vừa phải 3-5 lần/tuần
      case 'Rất năng động':
        return 1.725; // Tập luyện mạnh 6-7 lần/tuần
      default:
        return 1.2; // Mặc định là ít vận động
    }
  }

  /// Tính TDEE (Total Daily Energy Expenditure)
  double calculateBaseTDEE() {
    return calculateBMR() * activityMultiplier;
  }

  /// Convert pace to double if it's a string
  double get paceValue {
    if (pace is double) {
      return pace;
    } else if (pace is int) {
      return pace.toDouble();
    } else if (pace is String) {
      switch (pace) {
        case 'Chậm':
          return 0.25;
        case 'Vừa phải':
          return 0.5;
        case 'Nhanh':
          return 0.75;
        default:
          return 0.5;
      }
    }
    return 0.5; // Default value
  }

  /// Tính thặng dư/thâm hụt calo dựa trên mục tiêu
  double calculateCalorieSurplusDeficit() {
    // 1kg mỡ = khoảng 7700 calo
    if (goal == 'Tăng cân') {
      // Thặng dư calo để tăng cân
      return paceValue * 7700 / 7; // Calo thặng dư mỗi ngày
    } else if (goal == 'Giảm cân') {
      // Thâm hụt calo để giảm cân
      return -paceValue * 7700 / 7; // Calo thâm hụt mỗi ngày
    } else {
      // Duy trì cân nặng
      return 0;
    }
  }

  /// Tính tổng lượng calo cần tiêu thụ mỗi ngày
  double calculateDailyCalories() {
    return calculateBaseTDEE() + calculateCalorieSurplusDeficit();
  }

  /// Tính phân chia macros theo khuyến nghị (protein, carbs, fat)
  Map<String, double> calculateMacroDistribution() {
    final dailyCalories = calculateDailyCalories();
    
    // Phân chia macros mặc định (có thể điều chỉnh)
    double proteinPercentage = 0.3; // 30% từ protein
    double fatPercentage = 0.3;     // 30% từ chất béo
    double carbsPercentage = 0.4;   // 40% từ carbs
    
    // Điều chỉnh dựa trên mục tiêu
    if (goal == 'Tăng cân') {
      proteinPercentage = 0.25;
      fatPercentage = 0.30;
      carbsPercentage = 0.45;
    } else if (goal == 'Giảm cân') {
      proteinPercentage = 0.35;
      fatPercentage = 0.30;
      carbsPercentage = 0.35;
    }
    
    // Tính lượng gram dựa trên tỷ lệ phần trăm
    // 1g protein = 4 calo, 1g carbs = 4 calo, 1g fat = 9 calo
    final proteinGrams = (dailyCalories * proteinPercentage) / 4;
    final carbsGrams = (dailyCalories * carbsPercentage) / 4;
    final fatGrams = (dailyCalories * fatPercentage) / 9;
    
    return {
      'protein': proteinGrams,
      'carbs': carbsGrams,
      'fat': fatGrams,
    };
  }

  static Map<String, double> calculateTDEE({
    required double weight,
    required double height,
    required int age,
    required String gender,
    required String activityLevel,
    required String goal,
    double pace = 0.5,
  }) {
    // Log input values for debugging
    print('TDEE Calculator Input - Weight: $weight kg, Height: $height cm, Age: $age, Gender: $gender');
    print('TDEE Calculator Input - Activity Level: $activityLevel, Goal: $goal, Pace: $pace');
    
    if (weight <= 0 || height <= 0 || age <= 0) {
      print('TDEE Calculator Error: Invalid input values (weight, height, or age is zero or negative)');
      return {
        'calories': 0.0,
        'protein': 0.0,
        'fat': 0.0,
        'carbs': 0.0,
      };
    }

    // Calculate BMR using Mifflin-St Jeor equation
    double bmr;
    if (gender == 'Nam') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    // Apply activity multiplier
    double activityMultiplier = _getActivityMultiplier(activityLevel);
    double tdee = bmr * activityMultiplier;
    print('TDEE Calculator - BMR: $bmr, Activity Multiplier: $activityMultiplier, Base TDEE: $tdee');

    // Adjust TDEE based on goal
    double adjustedTDEE = _adjustTDEEForGoal(tdee, goal, pace);

    // Calculate macronutrients
    double protein = weight * _getProteinMultiplier(goal);
    double fat = _calculateFat(adjustedTDEE);
    double carbs = _calculateCarbs(adjustedTDEE, protein, fat);

    // Ensure minimum values
    if (protein < 0) protein = 0;
    if (fat < 0) fat = 0;
    if (carbs < 0) carbs = 0;
    if (adjustedTDEE < 0) adjustedTDEE = 0;

    // Log final calculated values
    print('TDEE Calculator Results - Calories: $adjustedTDEE, Protein: $protein g, Fat: $fat g, Carbs: $carbs g');

    return {
      'calories': adjustedTDEE,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
  }

  // Helper method to get activity multiplier based on activity level
  static double _getActivityMultiplier(String activityLevel) {
    switch (activityLevel) {
      case 'Ít vận động':
        return 1.2; // Hoạt động ít
      case 'Hoạt động nhẹ':
        return 1.375; // Tập luyện nhẹ 1-3 lần/tuần
      case 'Hoạt động vừa phải':
        return 1.55; // Tập luyện vừa phải 3-5 lần/tuần
      case 'Rất năng động':
        return 1.725; // Tập luyện mạnh 6-7 lần/tuần
      case 'Vận động viên':
        return 1.9; // Vận động viên, tập luyện 2 lần/ngày
      default:
        print('Activity level không nhận diện được: "$activityLevel", dùng hệ số mặc định 1.55');
        return 1.55; // Mặc định là hoạt động vừa phải
    }
  }

  // Helper method to adjust TDEE based on goal and pace
  static double _adjustTDEEForGoal(double tdee, String goal, double pace) {
    // 1kg mỡ = khoảng 7700 calo
    double adjustment = 0;
    
    if (goal == 'Tăng cân') {
      // Thặng dư calo để tăng cân
      adjustment = pace * 7700 / 7; // Calo thặng dư mỗi ngày
    } else if (goal == 'Giảm cân') {
      // Thâm hụt calo để giảm cân
      adjustment = -pace * 7700 / 7; // Calo thâm hụt mỗi ngày
    }
    
    print('TDEE Goal Adjustment - Goal: $goal, Pace: $pace, Adjustment: $adjustment calories');
    return tdee + adjustment;
  }

  // Helper method to get protein multiplier based on goal
  static double _getProteinMultiplier(String goal) {
    switch (goal) {
      case 'Tăng cân':
        return 2.0; // 2g protein per kg bodyweight
      case 'Giảm cân':
        return 2.2; // 2.2g protein per kg bodyweight
      default:
        return 1.8; // 1.8g protein per kg bodyweight for maintenance
    }
  }

  // Helper method to calculate fat in grams
  static double _calculateFat(double tdee) {
    // Fat is about 30% of total calories
    double fatCalories = tdee * 0.3;
    // 1g fat = 9 calories
    return fatCalories / 9;
  }

  // Helper method to calculate carbs in grams
  static double _calculateCarbs(double tdee, double protein, double fat) {
    // Calculate remaining calories after protein and fat
    double proteinCalories = protein * 4; // 1g protein = 4 calories
    double fatCalories = fat * 9; // 1g fat = 9 calories
    double remainingCalories = tdee - proteinCalories - fatCalories;
    
    // If remaining calories are negative, return 0 carbs
    if (remainingCalories <= 0) {
      print('TDEE Calculator Warning: Negative remaining calories for carbs: $remainingCalories');
      return 0;
    }
    
    // 1g carbs = 4 calories
    return remainingCalories / 4;
  }
} 