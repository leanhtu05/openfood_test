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
  final double pace;

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
  double calculateTDEE() {
    return calculateBMR() * activityMultiplier;
  }

  /// Tính thặng dư/thâm hụt calo dựa trên mục tiêu
  double calculateCalorieSurplusDeficit() {
    // 1kg mỡ = khoảng 7700 calo
    if (goal == 'Tăng cân') {
      // Thặng dư calo để tăng cân
      return pace * 7700 / 7; // Calo thặng dư mỗi ngày
    } else if (goal == 'Giảm cân') {
      // Thâm hụt calo để giảm cân
      return -pace * 7700 / 7; // Calo thâm hụt mỗi ngày
    } else {
      // Duy trì cân nặng
      return 0;
    }
  }

  /// Tính tổng lượng calo cần tiêu thụ mỗi ngày
  double calculateDailyCalories() {
    return calculateTDEE() + calculateCalorieSurplusDeficit();
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
} 