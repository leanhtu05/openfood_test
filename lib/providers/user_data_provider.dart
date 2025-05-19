import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/user_profile_api.dart';

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
  static const String _tdeeCaloriesKey = 'user_tdee_calories';
  static const String _tdeeProteinKey = 'user_tdee_protein';
  static const String _tdeeCarbsKey = 'user_tdee_carbs';
  static const String _tdeeFatKey = 'user_tdee_fat';
  // Thêm key cho các thuộc tính mới
  static const String _targetWeightKey = 'user_target_weight_kg';
  static const String _eventKey = 'user_event';
  static const String _eventDateKey = 'user_event_date';
  static const String _dietRestrictionKey = 'user_diet_restriction';
  static const String _dietPreferenceKey = 'user_diet_preference';
  static const String _healthConditionsKey = 'user_health_conditions';

  // Thông tin cơ bản
  String _gender = 'Nam';
  int _age = 30;
  double _heightCm = 170;
  double _weightKg = 60;
  String _activityLevel = 'Hoạt động vừa phải';
  String _goal = 'Tăng cân';
  double _pace = 0.5;
  
  // Các giá trị TDEE đã tính
  double _tdeeCalories = 0.0;
  double _tdeeProtein = 0.0;
  double _tdeeCarbs = 0.0;
  double _tdeeFat = 0.0;
  
  // Thêm các thuộc tính mới
  double _targetWeightKg = 0.0;
  String _event = '';
  int _eventDay = 0;
  int _eventMonth = 0;
  int _eventYear = 0;
  List<String> _dietRestrictions = [];
  String _dietPreference = '';
  List<String> _healthConditions = [];
  
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
  
  // Getters cho các thuộc tính mới
  double get targetWeightKg => _targetWeightKg;
  String get event => _event;
  int get eventDay => _eventDay;
  int get eventMonth => _eventMonth;
  int get eventYear => _eventYear;
  List<String> get dietRestrictions => _dietRestrictions;
  String get dietPreference => _dietPreference;
  List<String> get healthConditions => _healthConditions;
  
  // Getters cho TDEE
  double get tdeeCalories => _tdeeCalories;
  double get tdeeProtein => _tdeeProtein;
  double get tdeeCarbs => _tdeeCarbs;
  double get tdeeFat => _tdeeFat;

  // Setters
  set gender(String value) {
    _gender = value;
    notifyListeners();
    saveUserData();
  }

  void setGender(String value) {
    _gender = value;
    notifyListeners();
    saveUserData();
  }

  void setAge(int value) {
    _age = value;
    notifyListeners();
    saveUserData();
  }

  // Setter cho heightCm
  set heightCm(double value) {
    _heightCm = value;
    notifyListeners();
    saveUserData();
  }

  void setHeight(double value) {
    _heightCm = value;
    notifyListeners();
    saveUserData();
  }

  // Setter cho weightKg
  set weightKg(double value) {
    _weightKg = value;
    notifyListeners();
    saveUserData();
  }

  void setWeight(double value) {
    _weightKg = value;
    notifyListeners();
    saveUserData();
  }

  void setActivityLevel(String value) {
    _activityLevel = value;
    notifyListeners();
    saveUserData();
  }

  void setGoal(String value) {
    _goal = value;
    notifyListeners();
    saveUserData();
  }

  void setPace(double value) {
    _pace = value;
    notifyListeners();
    saveUserData();
  }
  
  // Setter cho targetWeightKg
  set targetWeightKg(double value) {
    _targetWeightKg = value;
    notifyListeners();
    saveUserData();
  }
  
  // Setter cho event
  set event(String value) {
    _event = value;
    notifyListeners();
    saveUserData();
  }
  
  // Setters cho eventDate
  set eventDay(int value) {
    _eventDay = value;
    notifyListeners();
    saveUserData();
  }
  
  set eventMonth(int value) {
    _eventMonth = value;
    notifyListeners();
    saveUserData();
  }
  
  set eventYear(int value) {
    _eventYear = value;
    notifyListeners();
    saveUserData();
  }
  
  // Setter cho dietRestrictions
  set dietRestrictions(List<String> value) {
    _dietRestrictions = value;
    notifyListeners();
    saveUserData();
  }
  
  // Setter cho dietPreference
  set dietPreference(String value) {
    _dietPreference = value;
    notifyListeners();
    saveUserData();
  }
  
  // Setter cho healthConditions
  set healthConditions(List<String> value) {
    _healthConditions = value;
    notifyListeners();
    saveUserData();
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
    double? targetWeightKg,
    String? event,
    int? eventDay,
    int? eventMonth,
    int? eventYear,
    List<String>? dietRestrictions,
    String? dietPreference,
    List<String>? healthConditions,
  }) {
    if (gender != null) _gender = gender;
    if (age != null) _age = age;
    if (heightCm != null) _heightCm = heightCm;
    if (weightKg != null) _weightKg = weightKg;
    if (activityLevel != null) _activityLevel = activityLevel;
    if (goal != null) _goal = goal;
    if (pace != null) _pace = pace;
    if (nutritionGoals != null) _nutritionGoals.addAll(nutritionGoals);
    
    // Cập nhật các thuộc tính mới
    if (targetWeightKg != null) _targetWeightKg = targetWeightKg;
    if (event != null) _event = event;
    if (eventDay != null) _eventDay = eventDay;
    if (eventMonth != null) _eventMonth = eventMonth;
    if (eventYear != null) _eventYear = eventYear;
    if (dietRestrictions != null) _dietRestrictions = dietRestrictions;
    if (dietPreference != null) _dietPreference = dietPreference;
    if (healthConditions != null) _healthConditions = healthConditions;
    
    notifyListeners();
    
    // Tự động lưu dữ liệu khi cập nhật
    saveUserData();
  }

  // Reset dữ liệu về mặc định
  Future<void> resetData() async {
    _gender = 'Nam';
    _age = 30;
    _heightCm = 170;
    _weightKg = 60;
    _activityLevel = 'Hoạt động vừa phải';
    _goal = 'Tăng cân';
    _pace = 0.5;
    _targetWeightKg = 0.0;
    _event = '';
    _eventDay = 0;
    _eventMonth = 0;
    _eventYear = 0;
    _dietRestrictions = [];
    _dietPreference = '';
    _healthConditions = [];
    
    // Reset TDEE values
    _tdeeCalories = 0.0;
    _tdeeProtein = 0.0;
    _tdeeCarbs = 0.0;
    _tdeeFat = 0.0;
    
    // Reset nutrition goals
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
    
    // Clear SharedPreferences and save default data
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all user-related data
      await prefs.remove(_genderKey);
      await prefs.remove(_ageKey);
      await prefs.remove(_heightKey);
      await prefs.remove(_weightKey);
      await prefs.remove(_activityLevelKey);
      await prefs.remove(_goalKey);
      await prefs.remove(_paceKey);
      await prefs.remove(_nutritionGoalsKey);
      
      // Clear TDEE values
      await prefs.remove(_tdeeCaloriesKey);
      await prefs.remove(_tdeeProteinKey);
      await prefs.remove(_tdeeCarbsKey);
      await prefs.remove(_tdeeFatKey);
      
      // Clear additional data
      await prefs.remove(_targetWeightKey);
      await prefs.remove(_eventKey);
      await prefs.remove(_eventDateKey);
      await prefs.remove(_dietRestrictionKey);
      await prefs.remove(_dietPreferenceKey);
      await prefs.remove(_healthConditionsKey);
      
      print('Đã xóa toàn bộ dữ liệu người dùng từ SharedPreferences');
      
      // Lưu lại dữ liệu mặc định
      await saveUserData();
      print('Đã lưu lại dữ liệu mặc định');
    } catch (e) {
      debugPrint('Lỗi khi reset dữ liệu người dùng: $e');
    }
  }
  
  // Cập nhật giá trị TDEE
  Future<void> updateTDEEValues({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    _tdeeCalories = calories;
    _tdeeProtein = protein;
    _tdeeCarbs = carbs;
    _tdeeFat = fat;
    
    // Cập nhật cả trong nutrition goals
    _nutritionGoals['calories'] = calories;
    _nutritionGoals['protein'] = protein;
    _nutritionGoals['carbs'] = carbs;
    _nutritionGoals['fat'] = fat;
    
    notifyListeners();
    await saveUserData();
    
    print('UserDataProvider: TDEE values saved - Calories: $_tdeeCalories, Protein: $_tdeeProtein, Carbs: $_tdeeCarbs, Fat: $_tdeeFat');
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
      
      // Lưu giá trị TDEE
      await prefs.setDouble(_tdeeCaloriesKey, _tdeeCalories);
      await prefs.setDouble(_tdeeProteinKey, _tdeeProtein);
      await prefs.setDouble(_tdeeCarbsKey, _tdeeCarbs);
      await prefs.setDouble(_tdeeFatKey, _tdeeFat);
      
      // Lưu các giá trị mới
      await prefs.setDouble(_targetWeightKey, _targetWeightKg);
      await prefs.setString(_eventKey, _event);
      await prefs.setString(_eventDateKey, jsonEncode({
        'day': _eventDay,
        'month': _eventMonth,
        'year': _eventYear
      }));
      await prefs.setString(_dietRestrictionKey, jsonEncode(_dietRestrictions));
      await prefs.setString(_dietPreferenceKey, _dietPreference);
      await prefs.setString(_healthConditionsKey, jsonEncode(_healthConditions));
      
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
      
      // Tải giá trị TDEE
      _tdeeCalories = prefs.getDouble(_tdeeCaloriesKey) ?? _tdeeCalories;
      _tdeeProtein = prefs.getDouble(_tdeeProteinKey) ?? _tdeeProtein;
      _tdeeCarbs = prefs.getDouble(_tdeeCarbsKey) ?? _tdeeCarbs;
      _tdeeFat = prefs.getDouble(_tdeeFatKey) ?? _tdeeFat;
      
      // Tải giá trị mới
      _targetWeightKg = prefs.getDouble(_targetWeightKey) ?? _targetWeightKg;
      _event = prefs.getString(_eventKey) ?? _event;
      _dietPreference = prefs.getString(_dietPreferenceKey) ?? _dietPreference;
      
      // Tải event date
      final eventDateString = prefs.getString(_eventDateKey);
      if (eventDateString != null) {
        final Map<String, dynamic> eventDateMap = jsonDecode(eventDateString);
        _eventDay = eventDateMap['day'] ?? 0;
        _eventMonth = eventDateMap['month'] ?? 0;
        _eventYear = eventDateMap['year'] ?? 0;
      }
      
      // Tải dietRestrictions
      final dietRestrictionsString = prefs.getString(_dietRestrictionKey);
      if (dietRestrictionsString != null) {
        final List<dynamic> restrictionList = jsonDecode(dietRestrictionsString);
        _dietRestrictions = restrictionList.map((item) => item.toString()).toList();
      }
      
      // Tải healthConditions
      final healthConditionsString = prefs.getString(_healthConditionsKey);
      if (healthConditionsString != null) {
        final List<dynamic> conditionsList = jsonDecode(healthConditionsString);
        _healthConditions = conditionsList.map((item) => item.toString()).toList();
      }
      
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

  // Gửi dữ liệu người dùng đến API
  Future<bool> sendToApi() async {
    try {
      final result = await UserProfileApi.sendUserProfile(this);
      if (result) {
        debugPrint('Đã gửi dữ liệu người dùng thành công đến API');
      } else {
        debugPrint('Gửi dữ liệu người dùng đến API thất bại');
      }
      return result;
    } catch (e) {
      debugPrint('Lỗi khi gửi dữ liệu người dùng đến API: $e');
      return false;
    }
  }
} 