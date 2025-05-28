import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_helpers.dart';
import 'package:http/http.dart' as http;
import 'food_provider.dart';
import 'exercise_provider.dart';
import 'water_provider.dart';
import '../services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import '../utils/tdee_calculator.dart';

class UserDataProvider with ChangeNotifier {
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
  static const String _nameKey = 'user_name';
  static const String _targetWeightKey = 'user_target_weight_kg';
  static const String _eventKey = 'user_event';
  static const String _eventDateKey = 'user_event_date';
  static const String _dietRestrictionKey = 'user_diet_restriction';
  static const String _dietPreferenceKey = 'user_diet_preference';
  static const String _healthConditionsKey = 'user_health_conditions';
  static const String _syncEnabledKey = 'user_sync_enabled';
  static const String _lastSyncTimeKey = 'user_last_sync_time';

  // User information
  String _name = '';
  String _gender = 'Nam';
  int _age = 25;
  double _heightCm = 170.0;
  double _weightKg = 65.0;
  String _activityLevel = 'Hoạt động vừa phải';
  String _goal = 'Duy trì cân nặng';
  double _pace = 0.5; // Changed to double from string
  
  // Additional fields
  double _targetWeightKg = 0.0;
  String _event = '';
  int _eventDay = 0;
  int _eventMonth = 0;
  int _eventYear = 0;
  List<String> _dietRestrictions = [];
  String _dietPreference = '';
  List<String> _healthConditions = [];
  
  // Nutritional targets
  int _dailyCalories = 2000;
  double _protein = 120;
  double _carbs = 200;
  double _fat = 65;
  
  // TDEE values
  double _tdeeCalories = 0.0;
  double _tdeeProtein = 0.0;
  double _tdeeCarbs = 0.0;
  double _tdeeFat = 0.0;
  
  // Sync status
  bool _syncEnabled = true;
  DateTime? _lastSyncTime;
  Timer? _syncTimer;
  
  // Nutrition goals
  Map<String, double> _nutritionGoals = {
    'calories': 2000.0,
    'protein': 50.0,
    'fat': 70.0,
    'carbs': 310.0,
    'cholesterol': 300.0,
    'fiber': 25.0,
    'sugar': 50.0,
    'water': 2000.0,
  };
  
  // Flag to track if Firebase is available
  bool _isFirebaseAvailable = false;
  
  // Dietary preferences fields
  List<String> _preferences = [];
  List<String> _allergies = [];
  String? _cuisineStyle;
  
  // Additional fields
  String _userId = '';
  String _email = '';
  String _weightGoal = 'Duy trì cân nặng';
  
  // Exercise calories setting
  bool _addExerciseCaloriesToGoal = true;
  
  // Constructor
  UserDataProvider() {
    // First load local data
    loadUserData().then((_) {
      // Đảm bảo TDEE được tính toán sau khi dữ liệu được tải
      if (_tdeeCalories <= 0 || _tdeeCalories == 2000) {
        // Nếu TDEE chưa được tính hoặc đang là giá trị mặc định, tính toán lại
        _initializeTDEE();
      }
      
      // Kiểm tra trạng thái đăng nhập trước khi kiểm tra Firebase
      _checkAuthenticationStatus();
    });
  }
  
  // Kiểm tra trạng thái đăng nhập trước khi quyết định có tải dữ liệu từ Firestore hay không
  Future<void> _checkAuthenticationStatus() async {
    try {
      // Kiểm tra xem người dùng đã đăng nhập chưa
      final isAuthenticated = isUserAuthenticated();
      
      if (isAuthenticated) {
        debugPrint('🔄 Người dùng đã đăng nhập: Kiểm tra và tải dữ liệu từ Firebase');
        // Nếu đã đăng nhập, kiểm tra và tải dữ liệu từ Firebase
        await _checkFirebaseAvailabilityAndInit();
      } else {
        debugPrint('🔄 Người dùng chưa đăng nhập: Sử dụng dữ liệu local');
        // Nếu chưa đăng nhập, chỉ sử dụng dữ liệu local đã được tải trước đó
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra trạng thái đăng nhập: $e');
    }
  }
  
  // }

  // Check Firebase availability and initialize if possible
  Future<void> _checkFirebaseAvailabilityAndInit() async {
    try {
      // Check if Firebase is already initialized
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseAvailable = true;
        
        // Initialize DataIntegrationService if Firebase is available
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            // Create DataIntegrationService instance
            // DataIntegrationService? service = DataIntegrationService();
            // Đã bỏ tham chiếu đến DataIntegrationService vì nó không tồn tại
            
            // // Use a setter since final field can't be modified after initialization
            // _setDataIntegrationService(service);
            // Đã bỏ tham chiếu đến service vì nó không tồn tại
            
            // Use loadFromFirestore only if user is authenticated
            await loadFromFirestore();
            
            if (_syncEnabled) {
              startPeriodicSync();
            }
          }
        } catch (e) {
          debugPrint('Firebase auth error: $e');
        }
      } else {
        _isFirebaseAvailable = false;
        debugPrint('Firebase is not initialized');
      }
    } catch (e) {
      _isFirebaseAvailable = false;
      debugPrint('Error checking Firebase availability: $e');
    }
  }
  
  // Helper method to set the DataIntegrationService since it's final
  // void _setDataIntegrationService(DataIntegrationService? service) {
  //   _dataIntegrationService = service;
  // }
  
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
  
  // Getters
  String get userId => _userId;
  String get email => _email;
  String get name => _name;
  String get gender => _gender;
  int get age => _age;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;
  String get activityLevel => _activityLevel;
  String get goal => _goal;
  double get pace => _pace;
  double get targetWeightKg => _targetWeightKg;
  String get event => _event;
  int get eventDay => _eventDay;
  int get eventMonth => _eventMonth;
  int get eventYear => _eventYear;
  List<String> get dietRestrictions => _dietRestrictions;
  List<String> get dietaryRestrictions => _dietRestrictions; // Alias for dietRestrictions
  String get dietPreference => _dietPreference;
  List<String> get healthConditions => _healthConditions;
  Map<String, double> get nutritionGoals => _nutritionGoals;
  int get dailyCalories => _dailyCalories;
  double get protein => _protein;
  double get carbs => _carbs;
  double get fat => _fat;
  double get tdeeCalories => _tdeeCalories;
  double get tdeeProtein => _tdeeProtein;
  double get tdeeCarbs => _tdeeCarbs;
  double get tdeeFat => _tdeeFat;
  bool get syncEnabled => _syncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  // Sử dụng getCurrentUserId() để lấy ID từ Firebase khi cần thiết
  
  // Exercise calories setting
  bool get addExerciseCaloriesToGoal => _addExerciseCaloriesToGoal;
  
  // Dietary preferences getters
  List<String> get preferences => _preferences;
  List<String> get allergies => _allergies;
  String? get cuisineStyle => _cuisineStyle;
  
  // Email đã được định nghĩa ở trên
  
  // Phương thức để lấy thời gian đồng bộ gần nhất theo định dạng chuỗi
  String getFormattedLastSyncTime() {
    if (_lastSyncTime == null) {
      return 'Chưa đồng bộ';
    }
    
    // Format thời gian theo định dạng dd/MM/yyyy HH:mm
    return '${_lastSyncTime!.day.toString().padLeft(2, '0')}/${_lastSyncTime!.month.toString().padLeft(2, '0')}/${_lastSyncTime!.year} ${_lastSyncTime!.hour.toString().padLeft(2, '0')}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}';
  }
  
  // Setters
  set gender(String value) {
    _gender = value;
    notifyListeners();
    saveUserData();
    recalculateTDEE(); // Recalculate TDEE when gender changes
  }
  
  void setName(String value) {
    if (_name != value) {
      _name = value;
      // Sử dụng Future.microtask để tránh gọi notifyListeners trong build
      Future.microtask(() {
        notifyListeners();
      });
      saveUserData();
    }
  }
  
  void setAge(int value) {
    _age = value;
    notifyListeners();
    saveUserData();
    recalculateTDEE(); // Recalculate TDEE when age changes
  }
  
  void setHeight(double value) {
    _heightCm = value;
    notifyListeners();
    saveUserData();
    recalculateTDEE(); // Recalculate TDEE when height changes
  }
  
  void setWeight(double value) {
    _weightKg = value;
    notifyListeners();
    saveUserData();
    recalculateTDEE(); // Recalculate TDEE when weight changes
  }
  
  void setActivityLevel(String value) {
    _activityLevel = value;
    notifyListeners();
    saveUserData();
    recalculateTDEE(); // Recalculate TDEE when activity level changes
  }
  
  void setGoal(String value) {
    _goal = value;
    notifyListeners();
    saveUserData();
    recalculateTDEE(); // Recalculate TDEE when goal changes
  }
  
  // For backward compatibility
  void setPace(dynamic value) {
    if (value is String) {
      // Convert string pace values to double
      switch (value) {
        case 'Chậm':
          _pace = 0.25;
          break;
        case 'Vừa phải':
          _pace = 0.5;
          break;
        case 'Nhanh':
          _pace = 0.75;
          break;
        default:
          _pace = 0.5;
      }
    } else if (value is double) {
      _pace = value;
    } else if (value is int) {
      _pace = value.toDouble();
    }
    notifyListeners();
    saveUserData();
    recalculateTDEE(); // Recalculate TDEE when pace changes
  }
  
  // Additional property setters
  set targetWeightKg(double value) {
    _targetWeightKg = value;
    notifyListeners();
    saveUserData();
  }
  
  set event(String value) {
    _event = value;
    notifyListeners();
    saveUserData();
  }
  
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
  
  set dietRestrictions(List<String> value) {
    _dietRestrictions = value;
    notifyListeners();
    saveUserData();
  }
  
  set dietPreference(String value) {
    _dietPreference = value;
    notifyListeners();
    saveUserData();
  }
  
  set healthConditions(List<String> value) {
    _healthConditions = value;
    notifyListeners();
    saveUserData();
  }
  
  // For nutrition goals
  void updateNutritionGoal(String nutrient, double value) {
    _nutritionGoals[nutrient] = value;
    notifyListeners();
    saveUserData();
  }
  
  void updateNutritionGoals(Map<String, double> updates) {
    _nutritionGoals.addAll(updates);
    notifyListeners();
    saveUserData();
  }
  
  // Update TDEE values
  Future<void> updateTDEEValues({
    required dynamic calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    // Convert calories to int if it's a double
    if (calories is double) {
      _dailyCalories = calories.toInt();
      _tdeeCalories = calories;
    } else if (calories is int) {
      _dailyCalories = calories;
      _tdeeCalories = calories.toDouble();
    }
    
    _protein = protein;
    _carbs = carbs;
    _fat = fat;
    
    _tdeeProtein = protein;
    _tdeeCarbs = carbs;
    _tdeeFat = fat;
    
    // Sử dụng phương thức mới từ TDEECalculator để điều chỉnh mục tiêu calo
    double adjustedCalories = TDEECalculator.calculateAdjustedCalories(
      tdee: _tdeeCalories,
      goal: _goal,
      pace: _pace,
    );
    
    // Update nutrition goals với giá trị mới đã được điều chỉnh
    _nutritionGoals['calories'] = adjustedCalories;
    _nutritionGoals['protein'] = protein;
    _nutritionGoals['carbs'] = carbs;
    _nutritionGoals['fat'] = fat;
    
    // Lưu giá trị mới
    await saveUserData();
    
    // Thông báo các widget để cập nhật UI
    notifyListeners();
    
    // Đồng bộ dữ liệu với API/Firestore nếu có thể
    if (_isFirebaseAvailable && _syncEnabled) {
      await sendToApi();
    }
    
    debugPrint('TDEE cập nhật: $_tdeeCalories kcal, Mục tiêu điều chỉnh: $adjustedCalories kcal');
  }
  
  // Sync control
  set syncEnabled(bool value) {
    _syncEnabled = value;
    notifyListeners();
    
    // Save sync state
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_syncEnabledKey, value);
    });
    
    if (value && _isFirebaseAvailable) {
      try {
        if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
          startPeriodicSync();
          sendToApi();
        }
      } catch (e) {
        debugPrint('Firebase not initialized when enabling sync: $e');
      }
    } else {
      _syncTimer?.cancel();
    }
  }
  
  void startPeriodicSync() {
    if (!_isFirebaseAvailable) return;
    
    _syncTimer?.cancel();
    
    try {
      if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) return;
      
      _syncTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
        if (FirebaseAuth.instance.currentUser == null) {
          timer.cancel();
          return;
        }
        
        sendToApi();
      });
    } catch (e) {
      debugPrint('Error starting periodic sync: $e');
    }
  }
  
  // Reset data
  Future<void> resetData() async {
    _name = '';
    _gender = 'Nam';
    _age = 25;
    _heightCm = 170.0;
    _weightKg = 65.0;
    _activityLevel = 'Hoạt động vừa phải';
    _goal = 'Duy trì cân nặng';
    _pace = 0.5;
    _targetWeightKg = 0.0;
    _event = '';
    _eventDay = 0;
    _eventMonth = 0;
    _eventYear = 0;
    _dietRestrictions = [];
    _dietPreference = '';
    _healthConditions = [];
    _dailyCalories = 2000;
    _protein = 120;
    _carbs = 200;
    _fat = 65;
    _tdeeCalories = 2000.0;
    _tdeeProtein = 120.0;
    _tdeeCarbs = 200.0;
    _tdeeFat = 65.0;
    
    _nutritionGoals = {
      'calories': 2000.0,
      'protein': 50.0,
      'fat': 70.0,
      'carbs': 310.0,
      'cholesterol': 300.0,
      'fiber': 25.0,
      'sugar': 50.0,
      'water': 2000.0,
    };
    
    notifyListeners();
    
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Save default values
    await saveUserData();
  }
  
  // API interactions
  Future<bool> sendToApi() async {
    try {
      // Kiểm tra xem người dùng đã đăng nhập chưa
      final userId = getCurrentUserId();
      if (userId == null) {
        debugPrint('Không thể gửi dữ liệu đến API: Người dùng chưa đăng nhập');
        return false;
      }
      
      // Chuẩn bị đầy đủ dữ liệu người dùng để đồng bộ
      final Map<String, dynamic> fullUserData = _prepareUserDataForSync();
      
      // Sử dụng phương thức mới để đồng bộ đầy đủ dữ liệu
      final result = await ApiService.syncFullUserData(userId, fullUserData);
      
      if (result) {
        // Cập nhật thời gian đồng bộ cuối cùng
        _lastSyncTime = DateTime.now();
        
        // Lưu thời gian đồng bộ vào SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
        
        debugPrint('✅ Đã đồng bộ đầy đủ dữ liệu người dùng thành công');
        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Đồng bộ đầy đủ dữ liệu người dùng thất bại');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi dữ liệu đến API: $e');
      return false;
    }
  }
  
  // Chuẩn bị dữ liệu người dùng để đồng bộ
  Map<String, dynamic> _prepareUserDataForSync() {
    return {
      'name': _name,
      'gender': _gender,
      'age': _age,
      'height_cm': _heightCm,
      'weight_kg': _weightKg,
      'activity_level': _activityLevel,
      'goal': _goal,
      'pace': _pace,
      'target_weight_kg': _targetWeightKg,
      'event': _event,
      'event_date': {
        'day': _eventDay,
        'month': _eventMonth,
        'year': _eventYear,
      },
      'diet_restrictions': _dietRestrictions,
      'diet_preference': _dietPreference,
      'health_conditions': _healthConditions,
      'nutrition_goals': _nutritionGoals,
      'daily_calories': _dailyCalories,
      'tdee': {
        'calories': _tdeeCalories,
        'protein': _tdeeProtein,
        'carbs': _tdeeCarbs,
        'fat': _tdeeFat,
      },
      'preferences': _preferences,
      'allergies': _allergies,
      'cuisine_style': _cuisineStyle,
      'add_exercise_calories_to_goal': _addExerciseCaloriesToGoal,
      'last_sync_time': DateTime.now().toIso8601String(),
    };
  }
  
  // Gửi dữ liệu trực tiếp đến Firebase
  Future<bool> syncToFirebase() async {
    try {
      // Kiểm tra xem người dùng đã đăng nhập chưa
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Không thể gửi dữ liệu đến Firebase: Người dùng chưa đăng nhập');
        return false;
      }
      
      // Chuẩn bị dữ liệu người dùng
      final Map<String, dynamic> userData = _prepareUserDataForSync();
      
      // Thêm các trường cần thiết
      userData['user_id'] = user.uid;
      userData['email'] = user.email ?? '';
      userData['updated_at'] = DateTime.now().toIso8601String();
      
      // Xử lý dữ liệu để đảm bảo tương thích với Firestore
      final preparedData = FirebaseHelpers.prepareDataForFirestore(userData);
      
      debugPrint('🔄 Đang gửi dữ liệu người dùng trực tiếp lên Firebase...');
      
      // Gửi dữ liệu lên Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(preparedData, SetOptions(merge: true));
      
      // Cập nhật thời gian đồng bộ cuối cùng
      _lastSyncTime = DateTime.now();
      
      // Lưu thời gian đồng bộ vào SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
      
      debugPrint('✅ Đã đồng bộ dữ liệu người dùng trực tiếp lên Firebase thành công');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi dữ liệu trực tiếp lên Firebase: $e');
      return false;
    }
  }
  
  // Load user data from API
  Future<bool> loadFromApi() async {
    if (!_isFirebaseAvailable) return false;
    
    try {
      // Kiểm tra xem người dùng đã đăng nhập chưa
      if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
        return false;
      }
      
      final userId = getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ Cannot load user data: No user ID found');
        return false;
      }
      
      // Lấy dữ liệu từ API
      final data = await ApiService.getUserProfile(userId);
      if (data != null && data.isNotEmpty) {
        // Update fields from API data
        if (data['name'] != null) _name = data['name'];
        if (data['gender'] != null) _gender = data['gender'];
        if (data['age'] != null) _age = data['age'];
        if (data['height_cm'] != null) _heightCm = (data['height_cm'] as num).toDouble();
        if (data['weight_kg'] != null) _weightKg = (data['weight_kg'] as num).toDouble();
        if (data['activity_level'] != null) _activityLevel = data['activity_level'];
        if (data['goal'] != null) _goal = data['goal'];
        if (data['pace'] != null) _pace = (data['pace'] as num).toDouble();
        if (data['target_weight_kg'] != null) _targetWeightKg = (data['target_weight_kg'] as num).toDouble();
        if (data['event'] != null) _event = data['event'];
        
        // Event date
        if (data['event_date'] is Map) {
          final eventDate = data['event_date'] as Map<String, dynamic>;
          _eventDay = eventDate['day'] ?? 0;
          _eventMonth = eventDate['month'] ?? 0;
          _eventYear = eventDate['year'] ?? 0;
        }
        
        // Diet restrictions
        if (data['diet_restrictions'] is List) {
          _dietRestrictions = List<String>.from(data['diet_restrictions']);
        }
        
        // Diet preference
        if (data['diet_preference'] != null) {
          _dietPreference = data['diet_preference'];
        }
        
        // Health conditions
        if (data['health_conditions'] is List) {
          _healthConditions = List<String>.from(data['health_conditions']);
        }
        
        // TDEE values
        if (data['tdee'] is Map) {
          final tdee = data['tdee'] as Map<String, dynamic>;
          if (tdee['calories'] != null) _tdeeCalories = (tdee['calories'] as num).toDouble();
          if (tdee['protein'] != null) _tdeeProtein = (tdee['protein'] as num).toDouble();
          if (tdee['carbs'] != null) _tdeeCarbs = (tdee['carbs'] as num).toDouble();
          if (tdee['fat'] != null) _tdeeFat = (tdee['fat'] as num).toDouble();
        }
        
        // Update daily calories
        _dailyCalories = _tdeeCalories.toInt();
        
        // Nutrition goals
        if (data['nutrition_goals'] is Map) {
          final goalsMap = Map<String, dynamic>.from(data['nutrition_goals']);
          _nutritionGoals = goalsMap.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
        
        // Sync settings
        if (data['sync_enabled'] != null) _syncEnabled = data['sync_enabled'];
        if (data['last_sync_time'] != null) {
          try {
            _lastSyncTime = DateTime.parse(data['last_sync_time']);
          } catch (e) {
            debugPrint('Error parsing lastSyncTime: $e');
          }
        }
        
        debugPrint('✅ Loaded user data from API successfully');
        notifyListeners();
        await saveUserData();
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error loading data from API: $e');
    }
    
    return false;
  }
  
  // Helper method for backwards compatibility
  void setGender(String value) {
    if (_gender != value) {
      _gender = value;
      notifyListeners();
      saveUserData();
    }
  }
  
  // Lưu dữ liệu người dùng vào SharedPreferences
  Future<void> saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Lưu thông tin cơ bản
    prefs.setString(_nameKey, _name);
    prefs.setString(_genderKey, _gender);
    prefs.setInt(_ageKey, _age);
    prefs.setDouble(_heightKey, _heightCm);
    prefs.setDouble(_weightKey, _weightKg);
    prefs.setString(_activityLevelKey, _activityLevel);
    prefs.setString(_goalKey, _goal);
    prefs.setDouble(_paceKey, _pace);
    
    // Lưu giá trị TDEE
    prefs.setDouble(_tdeeCaloriesKey, _tdeeCalories);
    prefs.setDouble(_tdeeProteinKey, _tdeeProtein);
    prefs.setDouble(_tdeeCarbsKey, _tdeeCarbs);
    prefs.setDouble(_tdeeFatKey, _tdeeFat);
    
    // Lưu dữ liệu bổ sung
    prefs.setDouble(_targetWeightKey, _targetWeightKg);
    prefs.setString(_eventKey, _event);
    
    // Lưu ngày sự kiện
    if (_eventDay > 0 && _eventMonth > 0 && _eventYear > 0) {
      final eventDateMap = {
        'day': _eventDay,
        'month': _eventMonth,
        'year': _eventYear,
      };
      prefs.setString(_eventDateKey, jsonEncode(eventDateMap));
    }
    
    // Lưu các giới hạn chế và ưu tiên về chế độ ăn
    prefs.setString(_dietRestrictionKey, jsonEncode(_allergies));
    prefs.setString(_dietPreferenceKey, jsonEncode(_preferences));
    
    // Lưu trạng thái đồng bộ
    prefs.setBool(_syncEnabledKey, _syncEnabled);
    if (_lastSyncTime != null) {
      prefs.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
    }
    
    // Đồng bộ lên Firebase nếu có thể
    await syncToFirebase();
    
    notifyListeners();
  }
  
  // Load user data from SharedPreferences
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load basic user info
    _name = prefs.getString(_nameKey) ?? '';
    _gender = prefs.getString(_genderKey) ?? 'Nam';
    _age = prefs.getInt(_ageKey) ?? 25;
    _heightCm = prefs.getDouble(_heightKey) ?? 170.0;
    _weightKg = prefs.getDouble(_weightKey) ?? 65.0;
    _activityLevel = prefs.getString(_activityLevelKey) ?? 'Hoạt động vừa phải';
    _goal = prefs.getString(_goalKey) ?? 'Duy trì cân nặng';
    _pace = prefs.getDouble(_paceKey) ?? 0.5;
    
    // Load TDEE values
    _tdeeCalories = prefs.getDouble(_tdeeCaloriesKey) ?? 0.0;
    _tdeeProtein = prefs.getDouble(_tdeeProteinKey) ?? 0.0;
    _tdeeCarbs = prefs.getDouble(_tdeeCarbsKey) ?? 0.0;
    _tdeeFat = prefs.getDouble(_tdeeFatKey) ?? 0.0;
    
    // Load daily values
    _dailyCalories = prefs.getInt('daily_calories') ?? 2000;
    _protein = prefs.getDouble('protein') ?? 120.0;
    _carbs = prefs.getDouble('carbs') ?? 200.0;
    _fat = prefs.getDouble('fat') ?? 65.0;
    
    // Load additional data
    _targetWeightKg = prefs.getDouble(_targetWeightKey) ?? 0.0;
    _event = prefs.getString(_eventKey) ?? '';
    
    // Load event date
    final eventDateString = prefs.getString(_eventDateKey);
    if (eventDateString != null) {
      try {
        final Map<String, dynamic> eventDateMap = jsonDecode(eventDateString);
        _eventDay = eventDateMap['day'] ?? 0;
        _eventMonth = eventDateMap['month'] ?? 0;
        _eventYear = eventDateMap['year'] ?? 0;
      } catch (e) {
        debugPrint('Error parsing event date: $e');
      }
    }
    
    // Load diet restrictions
    final dietRestrictionsString = prefs.getString(_dietRestrictionKey);
    if (dietRestrictionsString != null) {
      try {
        final List<dynamic> restrictionList = jsonDecode(dietRestrictionsString);
        _dietRestrictions = restrictionList.map((item) => item.toString()).toList();
      } catch (e) {
        debugPrint('Error parsing diet restrictions: $e');
      }
    }
    
    // Load diet preference
    _dietPreference = prefs.getString(_dietPreferenceKey) ?? '';
    
    // Load health conditions
    final healthConditionsString = prefs.getString(_healthConditionsKey);
    if (healthConditionsString != null) {
      try {
        final List<dynamic> conditionsList = jsonDecode(healthConditionsString);
        _healthConditions = conditionsList.map((item) => item.toString()).toList();
      } catch (e) {
        debugPrint('Error parsing health conditions: $e');
      }
    }
    
    // Load nutrition goals
    final goalsString = prefs.getString(_nutritionGoalsKey);
    if (goalsString != null) {
      try {
        final Map<String, dynamic> goalsJson = jsonDecode(goalsString);
        goalsJson.forEach((key, value) {
          _nutritionGoals[key] = (value is num) ? value.toDouble() : 0.0;
        });
      } catch (e) {
        debugPrint('Error parsing nutrition goals: $e');
      }
    }
    
    // Load sync settings
    _syncEnabled = prefs.getBool(_syncEnabledKey) ?? true;
    final lastSyncTimeStr = prefs.getString(_lastSyncTimeKey);
    if (lastSyncTimeStr != null) {
      try {
        _lastSyncTime = DateTime.parse(lastSyncTimeStr);
      } catch (e) {
        debugPrint('Error parsing lastSyncTime: $e');
      }
    }
    
    // Kiểm tra và khởi tạo TDEE nếu cần
    if (_tdeeCalories <= 0) {
      _initializeTDEE();
      debugPrint('TDEE được khởi tạo sau khi tải dữ liệu người dùng');
    } else {
      debugPrint('TDEE đã có sẵn: $_tdeeCalories');
    }
    
    notifyListeners();
  }

  // Các phương thức kiểm tra trạng thái Firebase
  bool isFirebaseAvailable() {
    try {
      return FirebaseAuth.instance.app != null;
    } catch (e) {
      debugPrint('Lỗi kiểm tra Firebase: $e');
      return false;
    }
  }
  
  bool isUserAuthenticated() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      return currentUser != null;
    } catch (e) {
      debugPrint('Lỗi kiểm tra người dùng đăng nhập: $e');
      return false;
    }
  }
  
  String? getCurrentUserId() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      return currentUser?.uid;
    } catch (e) {
      debugPrint('Lỗi lấy ID người dùng: $e');
      return null;
    }
  }

  // Dietary preferences setters
  set preferences(List<String> value) {
    _preferences = value;
    notifyListeners();
    _saveToPrefs();
  }
  
  set allergies(List<String> value) {
    _allergies = value;
    notifyListeners();
    _saveToPrefs();
  }
  
  set cuisineStyle(String? value) {
    _cuisineStyle = value;
    notifyListeners();
    _saveToPrefs();
  }
  
  // Update the dietary preferences
  void updateDietaryPreferences({
    List<String>? preferences,
    List<String>? allergies, 
    String? cuisineStyle
  }) {
    if (preferences != null) _preferences = preferences;
    if (allergies != null) _allergies = allergies;
    if (cuisineStyle != null) _cuisineStyle = cuisineStyle;
    
    notifyListeners();
    _saveToPrefs();
  }

  // Helper method to save dietary preferences to SharedPreferences
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('preferences', _preferences);
    await prefs.setStringList('allergies', _allergies);
    await prefs.setString('cuisineStyle', _cuisineStyle ?? '');
  }

  // Load data from SharedPreferences
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load basic user info
      _name = prefs.getString('name') ?? _name;
      _email = prefs.getString('email') ?? _email;
      _gender = prefs.getString('gender') ?? _gender;
      _age = prefs.getInt('age') ?? _age;
      _heightCm = prefs.getDouble('heightCm') ?? _heightCm;
      _weightKg = prefs.getDouble('weightKg') ?? _weightKg;
      
      // Load activity level and goals
      _activityLevel = prefs.getString('activityLevel') ?? _activityLevel;
      _weightGoal = prefs.getString('weightGoal') ?? _weightGoal;
      
      // Load TDEE values
      _tdeeCalories = prefs.getDouble('tdeeCalories') ?? _tdeeCalories;
      _tdeeProtein = prefs.getDouble('tdeeProtein') ?? _tdeeProtein;
      _tdeeFat = prefs.getDouble('tdeeFat') ?? _tdeeFat;
      _tdeeCarbs = prefs.getDouble('tdeeCarbs') ?? _tdeeCarbs;
      
      // Load sync settings
      _syncEnabled = prefs.getBool('syncEnabled') ?? _syncEnabled;
      final lastSyncStr = prefs.getString('lastSyncTime');
      if (lastSyncStr != null) {
        try {
          _lastSyncTime = DateTime.parse(lastSyncStr);
        } catch (e) {
          print('Could not parse lastSyncTime: $e');
          _lastSyncTime = null;
        }
      }
      
      // Load dietary preferences
      _preferences = prefs.getStringList('preferences') ?? [];
      _allergies = prefs.getStringList('allergies') ?? [];
      _cuisineStyle = prefs.getString('cuisineStyle');
      
      notifyListeners();
      
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  // Exercise calories setting
  void updateAddExerciseCaloriesToGoal(bool value) {
    _addExerciseCaloriesToGoal = value;
    notifyListeners();
    saveUserData();
  }

  // Hàm đồng bộ hoặc lấy dữ liệu user sau khi đăng nhập
  Future<void> syncOrFetchUserData(BuildContext context) async {
    // Kiểm tra trạng thái đăng nhập trước khi đồng bộ dữ liệu
    if (!isUserAuthenticated()) {
      debugPrint('⚠️ Người dùng chưa đăng nhập: Ưu tiên dữ liệu từ local, bỏ qua đồng bộ dữ liệu');
      // Đảm bảo dữ liệu local được tải
      await loadUserData();
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final uid = user.uid;
    try {
      // Kiểm tra xem người dùng đã tồn tại trong Firestore chưa
      final userData = await ApiService.getFirestoreUser(uid);
      
      if (userData == null || userData.isEmpty) {
        // Lần đầu đăng nhập: gửi dữ liệu local lên API
        debugPrint('👤 Người dùng chưa tồn tại trong Firestore, đồng bộ dữ liệu local lên');
        await syncAllDataToServer(context);
      } else {
        // Đăng nhập lại: lấy dữ liệu từ Firestore về local
        debugPrint('👤 Người dùng đã tồn tại trong Firestore, cập nhật dữ liệu local');
        
        // Xử lý các trường thời gian trước khi cập nhật
        final processedData = _makeSafeDataForConsumption(userData);
        
        // Cập nhật dữ liệu từ Firestore
        updateFromJson(processedData);
        
        // Cập nhật dữ liệu cho các provider khác
        await _updateOtherProviders(context, uid);
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi sync/fetch user data: $e');
      
      // Thử sử dụng API endpoint cũ nếu API mới thất bại
      try {
        final checkResponse = await http.get(Uri.parse('${ApiService.baseUrl}/check_user_exists?uid=$uid'));
      if (checkResponse.statusCode == 200) {
        final exists = jsonDecode(checkResponse.body)['exists'] as bool;
        if (!exists) {
          // Lần đầu đăng nhập: gửi dữ liệu local lên FastAPI
          await syncAllDataToServer(context);
        } else {
          // Đăng nhập lại: lấy dữ liệu từ Firestore về local
            final getResponse = await http.get(Uri.parse('${ApiService.baseUrl}/get_user_data?uid=$uid'));
          if (getResponse.statusCode == 200) {
            final data = jsonDecode(getResponse.body);
              // Cập nhật dữ liệu từ API cũ
              if (data['user'] != null) {
                updateFromJson(data['user']);
              }
          }
        }
      }
      } catch (fallbackError) {
        debugPrint('❌ Lỗi khi sử dụng API cũ: $fallbackError');
      }
      }
    }
  
  // Phương thức riêng để cập nhật các provider khác
  Future<void> _updateOtherProviders(BuildContext context, String uid) async {
    try {
      // Cập nhật FoodProvider
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      // TODO: Implement API endpoint to get food data
      
      // Cập nhật ExerciseProvider
    final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      // TODO: Implement API endpoint to get exercise data
      
      // Cập nhật WaterProvider
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      // TODO: Implement API endpoint to get water data
      
      debugPrint('✅ Đã cập nhật dữ liệu cho các provider khác');
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật các provider khác: $e');
    }
  }

  // Initialize TDEE values based on user data
  void _initializeTDEE() {
    // Only calculate if TDEE is not already set
    if (_tdeeCalories <= 0) {
      try {
        // Kiểm tra dữ liệu đầu vào hợp lệ
        if (_weightKg <= 0 || _heightCm <= 0 || _age <= 0) {
          debugPrint('Dữ liệu người dùng không hợp lệ cho việc tính TDEE');
          _tdeeCalories = 2000.0;
          _tdeeProtein = 120.0;
          _tdeeCarbs = 200.0;
          _tdeeFat = 65.0;
          return;
        }
        
        // Use the static method from TDEECalculator
        final tdeeValues = TDEECalculator.calculateTDEE(
          weight: _weightKg,
          height: _heightCm,
          age: _age,
          gender: _gender,
          activityLevel: _activityLevel,
          goal: _goal,
          pace: _pace,
        );
        
        // Update TDEE values if calculation was successful
        if (tdeeValues['calories']! > 0) {
          _tdeeCalories = tdeeValues['calories']!;
          _tdeeProtein = tdeeValues['protein']!;
          _tdeeCarbs = tdeeValues['carbs']!;
          _tdeeFat = tdeeValues['fat']!;
          
          // Also update daily calories
          _dailyCalories = _tdeeCalories.toInt();
          
          // Sử dụng phương thức mới từ TDEECalculator để điều chỉnh mục tiêu calo
          double adjustedCalories = TDEECalculator.calculateAdjustedCalories(
            tdee: _tdeeCalories,
            goal: _goal,
            pace: _pace,
          );
          
          // Save the calculated values
          saveUserData();
          
          debugPrint('TDEE initialized: $_tdeeCalories calories, Adjusted goal: $adjustedCalories calories');
        } else {
          // If calculation failed, use default values
          _tdeeCalories = _dailyCalories.toDouble();
          _tdeeProtein = _protein;
          _tdeeCarbs = _carbs;
          _tdeeFat = _fat;
          
          debugPrint('TDEE initialization failed, using defaults: $_tdeeCalories calories');
        }
      } catch (e) {
        // In case of error, use default values
        debugPrint('Error initializing TDEE: $e');
        _tdeeCalories = _dailyCalories.toDouble();
        _tdeeProtein = _protein;
        _tdeeCarbs = _carbs;
        _tdeeFat = _fat;
      }
      
      // Cập nhật nutrition goals với giá trị TDEE mới
      // Sử dụng phương thức mới từ TDEECalculator để điều chỉnh mục tiêu calo
      double adjustedCalories = TDEECalculator.calculateAdjustedCalories(
        tdee: _tdeeCalories,
        goal: _goal,
        pace: _pace,
      );
      
      _nutritionGoals['calories'] = adjustedCalories;
      _nutritionGoals['protein'] = _tdeeProtein;
      _nutritionGoals['carbs'] = _tdeeCarbs;
      _nutritionGoals['fat'] = _tdeeFat;
    }
  }

  // Recalculate TDEE based on current user data
  Future<void> recalculateTDEE() async {
    try {
      // Use the static method from TDEECalculator
      final tdeeValues = TDEECalculator.calculateTDEE(
        weight: _weightKg,
        height: _heightCm,
        age: _age,
        gender: _gender,
        activityLevel: _activityLevel,
        goal: _goal,
        pace: _pace,
      );
      
      // Update TDEE values
      await updateTDEEValues(
        calories: tdeeValues['calories']!,
        protein: tdeeValues['protein']!,
        carbs: tdeeValues['carbs']!,
        fat: tdeeValues['fat']!,
      );
      
      debugPrint('TDEE recalculated: $_tdeeCalories calories');
    } catch (e) {
      debugPrint('Error recalculating TDEE: $e');
    }
  }

  // Phương thức mới để lấy mục tiêu calo nhất quán dựa trên TDEE và mục tiêu
  int getConsistentCalorieGoal() {
    // Nếu mục tiêu là giảm cân và đã có giá trị trong nutrition goals
    if (_goal == 'Giảm cân' && _nutritionGoals.containsKey('calories') && _nutritionGoals['calories']! > 0) {
      // Trả về giá trị từ nutrition goals (đã được điều chỉnh theo mục tiêu)
      return _nutritionGoals['calories']!.toInt();
    }
    
    // Nếu TDEE đã được tính
    if (_tdeeCalories > 0) {
      // Nếu không phải giảm cân, sử dụng giá trị TDEE
      return _tdeeCalories.toInt();
    }
    
    // Nếu TDEE chưa được tính, kiểm tra nutrition goals
    if (_nutritionGoals.containsKey('calories') && _nutritionGoals['calories']! > 0) {
      return _nutritionGoals['calories']!.toInt();
    }
    
    // Nếu không có giá trị nào khả dụng, sử dụng dailyCalories
    if (_dailyCalories > 0) {
      return _dailyCalories;
    }
    
    // Giá trị mặc định cuối cùng
    return 2000;
  }

  // Force recalculate TDEE and clear old values
  Future<void> forceRecalculateTDEE() async {
    try {
      // Xóa các giá trị TDEE cũ từ SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tdeeCaloriesKey);
      await prefs.remove(_tdeeProteinKey);
      await prefs.remove(_tdeeCarbsKey);
      await prefs.remove(_tdeeFatKey);
      
      // Reset giá trị trong bộ nhớ
      _tdeeCalories = 0.0;
      _tdeeProtein = 0.0;
      _tdeeCarbs = 0.0;
      _tdeeFat = 0.0;
      
      // Tính toán lại TDEE
      final tdeeValues = TDEECalculator.calculateTDEE(
        weight: _weightKg,
        height: _heightCm,
        age: _age,
        gender: _gender,
        activityLevel: _activityLevel,
        goal: _goal,
        pace: _pace,
      );
      
      // Cập nhật giá trị TDEE mới
      await updateTDEEValues(
        calories: tdeeValues['calories']!,
        protein: tdeeValues['protein']!,
        carbs: tdeeValues['carbs']!,
        fat: tdeeValues['fat']!,
      );
      
      debugPrint('TDEE đã được tính toán lại: $_tdeeCalories calories');
      return;
    } catch (e) {
      debugPrint('Lỗi khi tính toán lại TDEE: $e');
      // Sử dụng giá trị mặc định nếu có lỗi
      await updateTDEEValues(
        calories: 2000.0,
        protein: 120.0,
        carbs: 200.0,
        fat: 65.0,
      );
    }
  }

  // Auto calculate TDEE when app starts
  Future<void> autoCalculateTDEE() async {
    // Kiểm tra xem TDEE đã được tính toán chưa
    if (_tdeeCalories <= 0 || _tdeeCalories == 2000) {
      // Nếu chưa được tính hoặc đang là giá trị mặc định, tính toán lại
      await forceRecalculateTDEE();
      debugPrint('TDEE được tính toán tự động: $_tdeeCalories calories');
    } else {
      debugPrint('TDEE đã có sẵn, không cần tính toán lại: $_tdeeCalories calories');
    }
  }

  // Update user goal and pace
  Future<void> updateUserGoal({String? goal, double? pace}) async {
    bool hasChanges = false;
    
    if (goal != null && goal != _goal) {
      _goal = goal;
      hasChanges = true;
    }
    
    if (pace != null && pace != _pace) {
      _pace = pace;
      hasChanges = true;
    }
    
    if (hasChanges) {
      // Tính lại mục tiêu calo dựa trên mục tiêu mới
      if (_tdeeCalories > 0) {
        double adjustedCalories = TDEECalculator.calculateAdjustedCalories(
          tdee: _tdeeCalories,
          goal: _goal,
          pace: _pace,
        );
        
        _nutritionGoals['calories'] = adjustedCalories;
        
        debugPrint('Mục tiêu cập nhật: $_goal, Tốc độ: $_pace, Calo điều chỉnh: $adjustedCalories');
      } else {
        // Nếu chưa có TDEE, tính toán lại
        await recalculateTDEE();
      }
      
      await saveUserData();
      notifyListeners();
      
      // Đồng bộ dữ liệu với API/Firestore nếu có thể
      if (_isFirebaseAvailable && _syncEnabled) {
        await sendToApi();
      }
    }
  }

  // Phương thức loadFromFirestore để đọc dữ liệu từ Firebase thông qua FastAPI
  Future<void> loadFromFirestore() async {
    try {
      // Kiểm tra trạng thái đăng nhập trước khi tải dữ liệu từ Firestore
      if (!isUserAuthenticated()) {
        debugPrint('⚠️ Người dùng chưa đăng nhập: Ưu tiên dữ liệu từ local, bỏ qua tải dữ liệu từ Firestore');
        return; // Bỏ qua việc tải dữ liệu từ Firestore nếu chưa đăng nhập
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🔄 Đang đọc dữ liệu người dùng từ Firebase với ID: ${user.uid}');
        
        try {
          final firestore = FirebaseFirestore.instance;
          final docSnapshot = await firestore.collection('users').doc(user.uid).get();
          
          if (docSnapshot.exists && docSnapshot.data() != null) {
            print('✅ Đã đọc dữ liệu người dùng trực tiếp từ Firestore');
            
            // Bỏ qua các trường có thể gây ra lỗi PigeonUserDetails
            Map<String, dynamic> safeData = {};
            final data = docSnapshot.data()!;
            
            // Chỉ lấy các trường dữ liệu cơ bản, bỏ qua các trường phức tạp
            final basicFields = [
              'name', 'email', 'gender', 'age', 
              'height_cm', 'weight_kg', 'activity_level', 
              'goal', 'pace', 'target_weight_kg', 'event'
            ];
            
            for (final field in basicFields) {
              if (data.containsKey(field) && data[field] != null) {
                safeData[field] = data[field];
              }
            }
            
            // Xử lý các trường đặc biệt - tdee
            try {
              if (data.containsKey('tdee') && data['tdee'] is Map) {
                final tdeeMap = Map<String, dynamic>.from(data['tdee'] as Map);
                
                // Chuyển đổi giá trị sang double
                if (tdeeMap.containsKey('calories')) {
                  safeData['tdee_calories'] = _safeParseDouble(tdeeMap['calories'], 2000.0);
                }
                
                if (tdeeMap.containsKey('protein')) {
                  safeData['tdee_protein'] = _safeParseDouble(tdeeMap['protein'], 120.0);
                }
                
                if (tdeeMap.containsKey('carbs')) {
                  safeData['tdee_carbs'] = _safeParseDouble(tdeeMap['carbs'], 200.0);
                }
                
                if (tdeeMap.containsKey('fat')) {
                  safeData['tdee_fat'] = _safeParseDouble(tdeeMap['fat'], 65.0);
                }
              }
            } catch (e) {
              print('⚠️ Không thể xử lý trường tdee: $e');
            }
            
            // Xử lý an toàn các trường danh sách
            try {
              // Xử lý diet_restrictions
              List<String> dietRestrictionsList = [];
              if (data.containsKey('diet_restrictions')) {
                dynamic restrictions = data['diet_restrictions'];
                if (restrictions is List) {
                  for (var item in restrictions) {
                    if (item != null) {
                      dietRestrictionsList.add(item.toString());
                    }
          }
                } else if (restrictions is String) {
                  dietRestrictionsList.add(restrictions);
                }
              }
              // Lưu vào safeData sau khi đã xử lý an toàn
              safeData['diet_restrictions_safe'] = dietRestrictionsList;
              
              // Xử lý health_conditions
              List<String> healthConditionsList = [];
              if (data.containsKey('health_conditions')) {
                dynamic conditions = data['health_conditions'];
                if (conditions is List) {
                  for (var item in conditions) {
                    if (item != null) {
                      healthConditionsList.add(item.toString());
                    }
                  }
                } else if (conditions is String) {
                  healthConditionsList.add(conditions);
        }
              }
              // Lưu vào safeData sau khi đã xử lý an toàn
              safeData['health_conditions_safe'] = healthConditionsList;
            } catch (e) {
              print('⚠️ Lỗi khi xử lý danh sách đặc biệt: $e');
            }
            
            // Cập nhật từng trường riêng lẻ thay vì gọi updateFromJson/updateFromFirebase
            try {
              _name = safeData['name'] ?? _name;
              _email = safeData['email'] ?? _email;
              
              if (safeData.containsKey('gender')) {
                _gender = safeData['gender'].toString();
              }
              
              if (safeData.containsKey('age')) {
                _age = int.tryParse(safeData['age'].toString()) ?? _age;
              }
              
              if (safeData.containsKey('height_cm')) {
                _heightCm = _safeParseDouble(safeData['height_cm'], _heightCm);
              }
              
              if (safeData.containsKey('weight_kg')) {
                _weightKg = _safeParseDouble(safeData['weight_kg'], _weightKg);
              }
              
              if (safeData.containsKey('activity_level')) {
                _activityLevel = safeData['activity_level'].toString();
              }
              
              if (safeData.containsKey('goal')) {
                _goal = safeData['goal'].toString();
              }
              
              if (safeData.containsKey('pace')) {
                _pace = _safeParseDouble(safeData['pace'], _pace);
              }
              
              if (safeData.containsKey('target_weight_kg')) {
                _targetWeightKg = _safeParseDouble(safeData['target_weight_kg'], _targetWeightKg);
              }
              
              if (safeData.containsKey('tdee_calories')) {
                _tdeeCalories = safeData['tdee_calories'];
                _nutritionGoals['calories'] = _tdeeCalories;
              }
              
              if (safeData.containsKey('tdee_protein')) {
                _tdeeProtein = safeData['tdee_protein'];
                _nutritionGoals['protein'] = _tdeeProtein;
              }
              
              if (safeData.containsKey('tdee_carbs')) {
                _tdeeCarbs = safeData['tdee_carbs'];
                _nutritionGoals['carbs'] = _tdeeCarbs;
              }
              
              if (safeData.containsKey('tdee_fat')) {
                _tdeeFat = safeData['tdee_fat'];
                _nutritionGoals['fat'] = _tdeeFat;
              }
              
              // Cập nhật các trường danh sách đã được xử lý an toàn
              if (safeData.containsKey('diet_restrictions_safe')) {
                _dietRestrictions = safeData['diet_restrictions_safe'];
              }
              
              if (safeData.containsKey('health_conditions_safe')) {
                _healthConditions = safeData['health_conditions_safe'];
              }
              
              print('✅ Đã cập nhật dữ liệu người dùng từ Firestore thành công');
              await saveUserData();
          notifyListeners();
          return;
            } catch (e) {
              print('❌ Lỗi khi cập nhật dữ liệu: $e');
            }
          } else {
            print('⚠️ Không tìm thấy dữ liệu người dùng trực tiếp trên Firestore');
          }
        } catch (firestoreError) {
          print('❌ Lỗi khi đọc dữ liệu trực tiếp từ Firestore: $firestoreError');
        }
      }
      
      print('ℹ️ Không thể đọc dữ liệu người dùng từ Firebase, sử dụng dữ liệu cục bộ');
    } catch (e) {
      print('❌ Lỗi tổng thể khi đọc dữ liệu từ Firebase: $e');
    }
  }
  
  // Phương thức để xử lý dữ liệu một cách an toàn trước khi sử dụng
  Map<String, dynamic> _makeSafeDataForConsumption(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    
    // Danh sách các trường là danh sách cần được xử lý an toàn
    final listFields = [
      'healthConditions', 
      'health_conditions', 
      'dietRestrictions', 
      'diet_restrictions',
      'preferences',
      'allergies',
      'cuisines',
      'tags',
      'meals',
      'exercises'
    ];
    
    // Xử lý tất cả các trường danh sách
    for (final field in listFields) {
      if (result.containsKey(field)) {
        try {
          dynamic value = result[field];
          if (value is List) {
            // Chuyển đổi mọi danh sách thành List<String> an toàn
            List<String> safeList = [];
            for (var item in value) {
              if (item != null) {
                safeList.add(item.toString());
              }
            }
            result[field] = safeList;
          } else if (value is String) {
            result[field] = [value.toString()];
          } else {
            // Nếu không phải List hoặc String, đặt giá trị mặc định là danh sách trống
            result[field] = [];
          }
        } catch (e) {
          print('❌ Lỗi khi xử lý trường danh sách $field: $e');
          result[field] = [];
        }
      }
    }
    
    // Xử lý an toàn cho các trường Timestamp
    final timestampFields = [
      'created_at',
      'updated_at',
      'lastSyncTime',
      'last_login',
      'last_updated',
      'timestamp',
    ];
    
    for (final field in timestampFields) {
      if (result.containsKey(field)) {
        final value = result[field];
        
        try {
          if (value is Timestamp) {
            result[field] = value.toDate().toIso8601String();
          } else if (value is String) {
            // Đã là chuỗi, giữ nguyên
          } else if (value != null) {
            result[field] = value.toString();
          }
          } catch (e) {
          print('❌ Lỗi khi xử lý trường $field: $e');
          result[field] = DateTime.now().toIso8601String();
        }
      }
    }
    
    return result;
  }

  // Phương thức để cập nhật dữ liệu từ JSON
  void updateFromJson(Map<String, dynamic> userData) {
    try {
      // Trước khi cập nhật, đảm bảo dữ liệu an toàn
      final safeData = _makeSafeDataForConsumption(userData);
      
      // Cập nhật thông tin người dùng từ JSON
      _name = safeData['display_name'] ?? safeData['name'] ?? _name;
      _gender = safeData['gender'] ?? _gender;
      _age = safeData['age'] ?? _age;
      
      // Xử lý an toàn cho các giá trị số
      if (safeData.containsKey('height_cm')) {
        _heightCm = _safeParseDouble(safeData['height_cm'], _heightCm);
      } else if (safeData.containsKey('height')) {
        _heightCm = _safeParseDouble(safeData['height'], _heightCm);
      }
      
      if (safeData.containsKey('weight_kg')) {
        _weightKg = _safeParseDouble(safeData['weight_kg'], _weightKg);
      } else if (safeData.containsKey('weight')) {
        _weightKg = _safeParseDouble(safeData['weight'], _weightKg);
      }
      
      _activityLevel = safeData['activity_level'] ?? _activityLevel;
      _goal = safeData['goal'] ?? _goal;
      
      if (safeData.containsKey('pace')) {
        _pace = _safeParseDouble(safeData['pace'], _pace);
      }
      
      // Cập nhật thông tin bổ sung
      if (safeData.containsKey('target_weight_kg')) {
        _targetWeightKg = _safeParseDouble(safeData['target_weight_kg'], _targetWeightKg);
      }
      
      _event = safeData['event'] ?? _event;
      
      // Cập nhật ngày sự kiện nếu có
      if (safeData['event_date'] != null) {
        var eventDate = safeData['event_date'];
        if (eventDate is Map) {
          _eventDay = eventDate['day'] ?? _eventDay;
          _eventMonth = eventDate['month'] ?? _eventMonth;
          _eventYear = eventDate['year'] ?? _eventYear;
        }
      }
      
      // Cập nhật chế độ ăn và sức khỏe - dietRestrictions và healthConditions đã được xử lý an toàn
      if (safeData.containsKey('dietRestrictions')) {
        _dietRestrictions = List<String>.from(safeData['dietRestrictions']);
      } else if (safeData.containsKey('diet_restrictions')) {
        _dietRestrictions = List<String>.from(safeData['diet_restrictions']);
      }
      
      if (safeData.containsKey('dietPreference')) {
        _dietPreference = safeData['dietPreference'].toString();
      } else if (safeData.containsKey('diet_preference')) {
        _dietPreference = safeData['diet_preference'].toString();
      }
      
      if (safeData.containsKey('healthConditions')) {
        _healthConditions = List<String>.from(safeData['healthConditions']);
      } else if (safeData.containsKey('health_conditions')) {
        _healthConditions = List<String>.from(safeData['health_conditions']);
      }
      
      // Xử lý các trường thời gian - đã được xử lý an toàn trong _makeSafeDataForConsumption
      
      // Cập nhật TDEE nếu có
      if (safeData.containsKey('tdee') && safeData['tdee'] is Map) {
        var tdee = safeData['tdee'] as Map;
        if (tdee.containsKey('calories')) {
          _tdeeCalories = _safeParseDouble(tdee['calories'], _tdeeCalories);
        }
        if (tdee.containsKey('protein')) {
          _tdeeProtein = _safeParseDouble(tdee['protein'], _tdeeProtein);
        }
        if (tdee.containsKey('carbs')) {
          _tdeeCarbs = _safeParseDouble(tdee['carbs'], _tdeeCarbs);
        }
        if (tdee.containsKey('fat')) {
          _tdeeFat = _safeParseDouble(tdee['fat'], _tdeeFat);
        }
          
          // Cập nhật mục tiêu dinh dưỡng dựa trên TDEE
          _nutritionGoals['calories'] = _tdeeCalories;
          _nutritionGoals['protein'] = _tdeeProtein;
          _nutritionGoals['carbs'] = _tdeeCarbs;
          _nutritionGoals['fat'] = _tdeeFat;
      }
      
      // Lưu dữ liệu vào SharedPreferences
      saveUserData();
      
      debugPrint('✅ Đã cập nhật dữ liệu người dùng từ JSON');
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật dữ liệu từ JSON: $e');
    }
  }
  
  // Phương thức để phân tích cú pháp số an toàn
  double _safeParseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    
    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      return defaultValue;
    } catch (e) {
      print('❌ Lỗi khi chuyển đổi giá trị $value sang double: $e');
      return defaultValue;
    }
  }

  // Cập nhật dữ liệu từ Firebase
  Future<void> updateFromFirebase(Map<String, dynamic> userData) async {
    try {
      print('🔄 Đang cập nhật dữ liệu từ Firebase');
      
      // Sử dụng phương thức updateFromJson đã được cải tiến để xử lý dữ liệu an toàn
      updateFromJson(userData);
      
      print('✅ Cập nhật dữ liệu từ Firebase thành công');
      notifyListeners();
    } catch (e) {
      print('❌ Lỗi khi cập nhật dữ liệu từ Firebase: $e');
    }
  }

  // Phương thức kiểm tra tính hợp lệ của dữ liệu
  void _validateData() {
    // Đảm bảo tuổi có giá trị hợp lệ
    if (_age <= 0 || _age > 120) _age = 30;
    
    // Đảm bảo giới tính có giá trị hợp lệ
    if (_gender.isEmpty || (_gender != 'Nam' && _gender != 'Nữ')) _gender = 'Nam';
    
    // Đảm bảo chiều cao có giá trị hợp lệ
    if (_heightCm <= 0 || _heightCm > 250) _heightCm = 170;
    
    // Đảm bảo cân nặng có giá trị hợp lệ
    if (_weightKg <= 0 || _weightKg > 300) _weightKg = 60;
    
    // Đảm bảo mục tiêu cân nặng có giá trị hợp lệ
    if (_targetWeightKg <= 0 || _targetWeightKg > 300) _targetWeightKg = _weightKg;
    
    // Đảm bảo mức độ hoạt động có giá trị hợp lệ
    if (_activityLevel.isEmpty) _activityLevel = 'Ít vận động';
    
    // Đảm bảo mục tiêu có giá trị hợp lệ
    if (_goal.isEmpty) _goal = 'Duy trì cân nặng';
    
    // Đảm bảo tốc độ thay đổi cân nặng có giá trị hợp lệ
    if (_pace < 0.1 || _pace > 2.0) _pace = 0.5;
  }

  // Khi người dùng đăng nhập, gọi phương thức này
  Future<void> onUserLogin(BuildContext context) async {
    if (_isFirebaseAvailable && FirebaseAuth.instance.currentUser != null) {
      // Tải dữ liệu từ Firestore
      await loadFromFirestore();
      // Gửi dữ liệu lên API với token mới
      if (_syncEnabled) {
        startPeriodicSync();
        await sendToApi();
      }
    }
    // Gọi hàm syncOrFetchUserData sau khi đăng nhập
    await syncOrFetchUserData(context);
  }

  // Trả về toàn bộ thông tin user dưới dạng Map<String, dynamic> để đồng bộ
  Map<String, dynamic> toJson() {
    return {
      'name': _name,
      'gender': _gender,
      'age': _age,
      'heightCm': _heightCm,
      'weightKg': _weightKg,
      'activityLevel': _activityLevel,
      'goal': _goal,
      'pace': _pace,
      'targetWeightKg': _targetWeightKg,
      'event': _event,
      'eventDay': _eventDay,
      'eventMonth': _eventMonth,
      'eventYear': _eventYear,
      'dietRestrictions': _dietRestrictions,
      'dietPreference': _dietPreference,
      'healthConditions': _healthConditions,
      'nutritionGoals': _nutritionGoals,
      'dailyCalories': _dailyCalories,
      'protein': _protein,
      'carbs': _carbs,
      'fat': _fat,
      'tdeeCalories': _tdeeCalories,
      'tdeeProtein': _tdeeProtein,
      'tdeeCarbs': _tdeeCarbs,
      'tdeeFat': _tdeeFat,
      'syncEnabled': _syncEnabled,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'preferences': _preferences,
      'allergies': _allergies,
      'cuisineStyle': _cuisineStyle,
      'email': _email,
      'weightGoal': _weightGoal,
      'addExerciseCaloriesToGoal': _addExerciseCaloriesToGoal,
    };
  }

  // Hàm đồng bộ toàn bộ dữ liệu local lên Firestore
  Future<void> syncAllDataToServer(BuildContext context) async {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);

    final foodData = foodProvider.getAllEntriesAsJson();
    final userData = userDataProvider.toJson();
    final exerciseData = exerciseProvider.getAllExercisesAsJson();
    final waterData = waterProvider.getAllWaterLogsAsJson();

    try {
      // Lấy user ID từ Firebase nếu có
      String? userId = getCurrentUserId();
      
      if (userId == null) {
        debugPrint('❌ Không thể đồng bộ dữ liệu: Không có ID người dùng');
        return;
      }
      
      // Lưu dữ liệu người dùng trực tiếp vào Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set(userData, SetOptions(merge: true));
        
        debugPrint('✅ Đồng bộ dữ liệu người dùng lên Firestore thành công!');
        
        // Lưu dữ liệu bữa ăn
        final mealsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('meals');
            
        // Xóa dữ liệu cũ trước khi thêm mới (tùy chọn)
        // await _deleteCollection(mealsRef, 10);
        
        // Thêm từng bữa ăn vào Firestore
        for (var meal in foodData) {
          String mealId = meal['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          await mealsRef.doc(mealId).set(meal);
        }
        
        debugPrint('✅ Đồng bộ dữ liệu bữa ăn lên Firestore thành công!');
        
        // Lưu dữ liệu bài tập
        final exercisesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('exercises');
            
        // Thêm từng bài tập vào Firestore
        for (var exercise in exerciseData) {
          String exerciseId = exercise['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          await exercisesRef.doc(exerciseId).set(exercise);
        }
        
        debugPrint('✅ Đồng bộ dữ liệu bài tập lên Firestore thành công!');
        
        // Lưu dữ liệu nước uống
        final waterRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('water_logs');
            
        // Thêm từng log nước uống vào Firestore
        for (var waterLog in waterData) {
          String logId = waterLog['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          await waterRef.doc(logId).set(waterLog);
        }
        
        debugPrint('✅ Đồng bộ dữ liệu nước uống lên Firestore thành công!');
        
        // Cập nhật thời gian đồng bộ
        _lastSyncTime = DateTime.now();
        await saveUserData();
        
        return;
      } catch (firestoreError) {
        debugPrint('❌ Lỗi khi lưu dữ liệu vào Firestore: $firestoreError');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ dữ liệu: $e');
    }
  }
  
  // Phương thức hỗ trợ để xóa collection (sử dụng khi cần)
  Future<void> _deleteCollection(CollectionReference collectionRef, int batchSize) async {
    var query = collectionRef.limit(batchSize);
    int deleted = 0;
    
    while (true) {
      var snapshot = await query.get();
      if (snapshot.size == 0) {
        break;
      }
      
      // Xóa từng document trong batch
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        deleted++;
      }
      
      await batch.commit();
      
      // Nếu số lượng document đã xóa ít hơn batch size, có nghĩa là đã xóa hết
      if (snapshot.size < batchSize) {
        break;
      }
    }
    
    debugPrint('Đã xóa $deleted documents từ collection');
  }

  // Setters for basic user info
  void setUserId(String value) {
    if (_userId != value) {
      _userId = value;
      // Sử dụng Future.microtask để tránh gọi notifyListeners trong build
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  void setEmail(String? value) {
    if (value != null && value.isNotEmpty && _email != value) {
      _email = value;
      // Sử dụng Future.microtask để tránh gọi notifyListeners trong build
      Future.microtask(() {
        notifyListeners();
      });
      saveUserData();
    }
  }

  // setName đã được định nghĩa ở dòng 251
} 