import 'package:flutter/material.dart';

class AppColors {
  // Màu chính
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryLight = Color(0xFF81C784);
  static const Color primaryDark = Color(0xFF388E3C);
  
  // Màu phụ
  static const Color secondary = Color(0xFF8BC34A);
  static const Color secondaryLight = Color(0xFF64B5F6);
  static const Color secondaryDark = Color(0xFF1976D2);
  
  // Màu nền
  static const Color background = Colors.white;
  static const Color cardBackground = Color(0xFFF5F5F5);
  static const Color surfaceLight = Color(0xFFF5F5F5);
  
  // Màu text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFF9E9E9E);

  // Các màu theo dõi hoạt động
  static final Color water = Color(0xFF2196F3);
  static final Color waterLight = Color(0xFF64B5F6);
  static final Color exercise = Color(0xFFE91E63);
  static final Color exerciseLight = Color(0xFF81C784);
  static final Color food = Color(0xFFFF9800);
  static final Color foodLight = Color(0xFFFFB74D);
  static const Color danger = Color(0xFFF44336);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFEB3B);
}

class AppTextStyles {
  // Heading styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: 0.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  // Body text styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
  );

  // Button styles
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.4,
  );

  // Specialized styles
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textLight,
    letterSpacing: 0.2,
  );

  static const TextStyle metric = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle metricHighlight(Color color) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: color,
    );
  }

  static const TextStyle headline1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );
}

class AppDecorations {
  static BoxDecoration card = BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration roundedContainer({Color? color, double radius = 12}) {
    return BoxDecoration(
      color: color ?? AppColors.cardBackground,
      borderRadius: BorderRadius.circular(radius),
    );
  }
  
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    elevation: 0,
  );
  
  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.secondary,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    elevation: 0,
  );
}

// Animations
class AppAnimations {
  static Duration short = Duration(milliseconds: 200);
  static Duration medium = Duration(milliseconds: 300);
  static Duration long = Duration(milliseconds: 500);
  
  static Curve standard = Curves.easeInOut;
  static Curve emphasized = Curves.easeOutQuart;
  static Curve decelerate = Curves.easeOutCirc;
}

class AppIcons {
  static const String breakfast = '🍳';
  static const String lunch = '🥗';
  static const String dinner = '🍝';
  static const String snack = '🍌';
}

// API Keys
class ApiKeys {
  // USDA FoodData Central API - https://fdc.nal.usda.gov/api-guide.html
  // Lấy key tại: https://fdc.nal.usda.gov/api-key-signup.html
  static const String usdaApiKey = 'GJRAy2mRHxo2FiejluDsPDBhzPvUL3J8xhihsKh2';
  static const String usdaBaseUrl = 'https://api.nal.usda.gov/fdc/v1';
  
  // Edamam Food API (không còn sử dụng)
  // static const String edamamAppId = '5d75d79e'; 
  // static const String edamamAppKey = 'dba31cdcb3194f2ed9e3b611decfb938';
}

class ApiEndpoints {
  // Thay thế bằng URL thực tế của API của bạn
  static const String baseUrl = 'http://192.168.0.101:8000';
  
  // Meal plan endpoints
  static const String generateWeeklyMeal = '/generate-weekly-meal';
  static const String replaceDay = '/replace-day';
  static const String replaceWeek = '/replace-week';
  static const String mealPlanHistory = '/meal-plan-history';
  static const String deleteMealPlan = '/meal-plan';
  
  // USDA Food API endpoints
  static const String usdaSearch = '/usda/search';
  static const String usdaFood = '/usda/food';
  static const String usdaNutrition = '/usda/nutrition';
  static const String usdaTranslate = '/usda/translate';
  static const String usdaClearCache = '/usda/clear-cache';
  
  // Cấu hình
  static const bool forceMockData = false;
}