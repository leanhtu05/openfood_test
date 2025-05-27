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
    print('[TDEE DEBUG] gender=$gender, age=$age, heightCm=$heightCm, weightKg=$weightKg, activityLevel=$activityLevel, goal=$goal, pace=$pace');
    if (weightKg <= 0 || heightCm <= 0 || age <= 0) {
      print('[TDEE DEBUG] Lỗi: Thông tin đầu vào không hợp lệ (weight, height, age)');
      return 0.0;
    }
    return calculateBaseTDEE() + calculateCalorieSurplusDeficit();
  }

  /// Tính phân phối macros theo khuyến nghị (protein, carbs, fat)
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

  // Tính TDEE dựa trên các thông số người dùng
  static Map<String, double> calculateTDEE({
    required double weight,
    required double height,
    required int age,
    required String gender,
    required String activityLevel,
    String goal = 'Duy trì cân nặng',
    double pace = 0.5,
  }) {
    // Tính BMR (Basal Metabolic Rate) theo công thức Mifflin-St Jeor
    double bmr;
    if (gender == 'Nam') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    // Nhân hệ số hoạt động để tính TDEE
    double activityMultiplier = getActivityMultiplier(activityLevel);
    double tdee = bmr * activityMultiplier;

    // Làm tròn TDEE
    tdee = double.parse(tdee.toStringAsFixed(1));

    // Tính toán macros dựa trên TDEE
    Map<String, double> macros = calculateMacrosFromTDEE(tdee);

    // Trả về kết quả
    return {
      'calories': tdee,
      'protein': macros['protein']!,
      'carbs': macros['carbs']!,
      'fat': macros['fat']!,
    };
  }

  // Phương thức mới để tính toán calo điều chỉnh theo mục tiêu
  static double calculateAdjustedCalories({
    required double tdee,
    required String goal,
    required double pace,
  }) {
    double adjustedCalories = tdee;
    
    // Nếu mục tiêu là giảm cân, giảm lượng calo
    if (goal == 'Giảm cân') {
      // Giảm calo dựa trên pace (tốc độ giảm cân)
      // Giả sử pace 0.5 tương đương với giảm 500 calo/ngày
      int calorieDeficit = (pace * 1000).toInt();
      adjustedCalories = tdee - calorieDeficit;
      
      // Đảm bảo không giảm quá 50% TDEE để đảm bảo sức khỏe
      if (adjustedCalories < tdee * 0.5) {
        adjustedCalories = tdee * 0.5;
      }
    } 
    // Nếu mục tiêu là tăng cân, tăng lượng calo
    else if (goal == 'Tăng cân') {
      // Tăng calo dựa trên pace (tốc độ tăng cân)
      // Giả sử pace 0.5 tương đương với tăng 500 calo/ngày
      int calorieSurplus = (pace * 1000).toInt();
      adjustedCalories = tdee + calorieSurplus;
    }
    // Nếu mục tiêu là duy trì cân nặng, giữ nguyên TDEE
    
    return adjustedCalories;
  }

  // Tính hệ số hoạt động dựa trên mức độ hoạt động
  static double getActivityMultiplier(String activityLevel) {
    switch (activityLevel) {
      case 'Ít vận động':
        return 1.2;
      case 'Hoạt động nhẹ':
        return 1.375;
      case 'Hoạt động vừa phải':
        return 1.55;
      case 'Hoạt động nhiều':
        return 1.725;
      case 'Hoạt động rất nhiều':
        return 1.9;
      default:
        return 1.55; // Mặc định là hoạt động vừa phải
    }
  }

  // Tính phân phối macros dựa trên TDEE và mục tiêu
  static Map<String, double> calculateMacrosFromTDEE(double tdeeCalories) {
    // Nếu không có TDEE, sử dụng giá trị mặc định
    double calories = tdeeCalories > 0 ? tdeeCalories : 2000;
    
    // Tính toán macros theo tỉ lệ cơ bản: 30% protein, 40% carbs, 30% fat
    double protein = (calories * 0.3) / 4; // 4 calo/gram protein
    double carbs = (calories * 0.4) / 4;   // 4 calo/gram carbs
    double fat = (calories * 0.3) / 9;     // 9 calo/gram fat
    
    // Làm tròn các giá trị
    protein = double.parse(protein.toStringAsFixed(1));
    carbs = double.parse(carbs.toStringAsFixed(1));
    fat = double.parse(fat.toStringAsFixed(1));
    
    return {
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
} 