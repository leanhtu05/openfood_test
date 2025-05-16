import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserDataProvider extends ChangeNotifier {
  // Khai báo các key cho SharedPreferences
  static const String _genderKey = 'user_gender';
  static const String _ageKey = 'user_age';
  static const String _heightKey = 'user_height_cm';
  static const String _weightKey = 'user_weight_kg';
  static const String _activityLevelKey = 'user_activity_level';
  static const String _goalKey = 'user_goal';
  static const String _paceKey = 'user_pace';
  static const String _nutritionGoalsKey = 'user_nutrition_goals';

  // Thông tin cơ bản
  String _gender = 'male';
  int _age = 30;
  double _heightCm = 170;
  double _weightKg = 60;
  String _activityLevel = 'Hoạt động vừa phải';
  String _goal = 'Tăng cân';
  double _pace = 0.5;
  
  // Mục tiêu dinh dưỡng với giá trị mặc định
  Map<String, double> _nutritionGoals = {
    'calories': 2000.0,
    'protein': 50.0,
    'fat': 70.0,
    'carbs': 310.0,
    'cholesterol': 300.0,
    'fiber': 25.0,
    'sugar': 50.0,
    'water': 2000.0,
    'omega3': 1.6,
    'saturatedFat': 20.0,
    'vitaminD': 15.0,
    'vitaminB12': 2.4,
    'caffeine': 400.0,
    'alcohol': 14.0,
  };

  // Constructor - Tải dữ liệu từ SharedPreferences khi khởi tạo
  UserDataProvider() {
    _loadUserData();
  }

  // Getters
  String get gender => _gender;
  int get age => _age;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;
  String get activityLevel => _activityLevel;
  String get goal => _goal;
  double get pace => _pace;
  Map<String, double> get nutritionGoals => _nutritionGoals;

  // Setters
  void setGender(String value) {
    _gender = value;
    notifyListeners();
  }

  void setAge(int value) {
    _age = value;
    notifyListeners();
  }

  void setHeight(double value) {
    _heightCm = value;
    notifyListeners();
  }

  void setWeight(double value) {
    _weightKg = value;
    notifyListeners();
  }

  void setActivityLevel(String value) {
    _activityLevel = value;
    notifyListeners();
  }

  void setGoal(String value) {
    _goal = value;
    notifyListeners();
  }

  void setPace(double value) {
    _pace = value;
    notifyListeners();
  }
  
  // Cập nhật một giá trị dinh dưỡng
  void updateNutritionGoal(String nutrient, double value) {
    _nutritionGoals[nutrient] = value;
    notifyListeners();
    saveUserData();
  }
  
  // Cập nhật nhiều giá trị dinh dưỡng
  void updateNutritionGoals(Map<String, double> updates) {
    _nutritionGoals.addAll(updates);
    notifyListeners();
    saveUserData();
  }

  // Cập nhật nhiều giá trị cùng lúc
  void updateUserData({
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? goal,
    double? pace,
    Map<String, double>? nutritionGoals,
  }) {
    if (gender != null) _gender = gender;
    if (age != null) _age = age;
    if (heightCm != null) _heightCm = heightCm;
    if (weightKg != null) _weightKg = weightKg;
    if (activityLevel != null) _activityLevel = activityLevel;
    if (goal != null) _goal = goal;
    if (pace != null) _pace = pace;
    if (nutritionGoals != null) _nutritionGoals.addAll(nutritionGoals);
    notifyListeners();
    
    // Tự động lưu dữ liệu khi cập nhật
    saveUserData();
  }

  // Reset dữ liệu về mặc định
  void resetData() {
    _gender = 'male';
    _age = 30;
    _heightCm = 170;
    _weightKg = 60;
    _activityLevel = 'Hoạt động vừa phải';
    _goal = 'Tăng cân';
    _pace = 0.5;
    _nutritionGoals = {
      'calories': 2000.0,
      'protein': 50.0,
      'fat': 70.0,
      'carbs': 310.0,
      'cholesterol': 300.0,
      'fiber': 25.0,
      'sugar': 50.0,
      'water': 2000.0,
      'omega3': 1.6,
      'saturatedFat': 20.0,
      'vitaminD': 15.0,
      'vitaminB12': 2.4,
      'caffeine': 400.0,
      'alcohol': 14.0,
    };
    notifyListeners();
    
    // Lưu lại dữ liệu mặc định
    saveUserData();
  }
  
  // Lưu dữ liệu người dùng vào SharedPreferences
  Future<void> saveUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_genderKey, _gender);
      await prefs.setInt(_ageKey, _age);
      await prefs.setDouble(_heightKey, _heightCm);
      await prefs.setDouble(_weightKey, _weightKg);
      await prefs.setString(_activityLevelKey, _activityLevel);
      await prefs.setString(_goalKey, _goal);
      await prefs.setDouble(_paceKey, _pace);
      await prefs.setString(_nutritionGoalsKey, jsonEncode(_nutritionGoals));
    } catch (e) {
      debugPrint('Lỗi khi lưu dữ liệu người dùng: $e');
    }
  }
  
  // Tải dữ liệu người dùng từ SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _gender = prefs.getString(_genderKey) ?? _gender;
      _age = prefs.getInt(_ageKey) ?? _age;
      _heightCm = prefs.getDouble(_heightKey) ?? _heightCm;
      _weightKg = prefs.getDouble(_weightKey) ?? _weightKg;
      _activityLevel = prefs.getString(_activityLevelKey) ?? _activityLevel;
      _goal = prefs.getString(_goalKey) ?? _goal;
      _pace = prefs.getDouble(_paceKey) ?? _pace;
      
      final goalsString = prefs.getString(_nutritionGoalsKey);
      if (goalsString != null) {
        final Map<String, dynamic> goalsJson = jsonDecode(goalsString);
        // Chuyển đổi lại thành Map<String, double>
        goalsJson.forEach((key, value) {
          _nutritionGoals[key] = (value is num) ? value.toDouble() : 0.0;
        });
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi khi tải dữ liệu người dùng: $e');
    }
  }
} 