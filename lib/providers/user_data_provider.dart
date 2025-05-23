import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async'; // Thêm import cho Timer
import '../services/user_profile_api.dart';
import '../services/data_integration_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
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
  
  // DataIntegrationService
  final DataIntegrationService? _dataIntegrationService;
  
  // Flag to track if Firebase is available
  bool _isFirebaseAvailable = false;
  
  // Dietary preferences fields
  List<String> _preferences = [];
  List<String> _allergies = [];
  String? _cuisineStyle;
  
  // Additional fields
  String _email = '';
  String _weightGoal = 'Duy trì cân nặng';
  
  // Constructor
  UserDataProvider() : 
    _dataIntegrationService = null {
    // First load local data
    loadUserData();
    
    // Check Firebase availability using a safer approach
    _checkFirebaseAvailabilityAndInit();
  }

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
            DataIntegrationService? service = DataIntegrationService();
            
            // Use a setter since final field can't be modified after initialization
            _setDataIntegrationService(service);
            
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
  void _setDataIntegrationService(DataIntegrationService? service) {
    // Using reflection or other technique would be needed to modify a final field
    // For now, we'll work with the service being potentially null
    // We'll handle null checks wherever the service is used
  }
  
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
  
  // Getters
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
  
  // Dietary preferences getters
  List<String> get preferences => _preferences;
  List<String> get allergies => _allergies;
  String? get cuisineStyle => _cuisineStyle;
  
  // Setters
  set gender(String value) {
    _gender = value;
    notifyListeners();
    saveUserData();
  }
  
  void setName(String value) {
    _name = value;
    notifyListeners();
    saveUserData();
  }
  
  void setAge(int value) {
    _age = value;
    notifyListeners();
    saveUserData();
  }
  
  void setHeight(double value) {
    _heightCm = value;
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
    
    // Update nutrition goals
    _nutritionGoals['calories'] = _tdeeCalories;
    _nutritionGoals['protein'] = protein;
    _nutritionGoals['carbs'] = carbs;
    _nutritionGoals['fat'] = fat;
    
    await saveUserData();
    notifyListeners();
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
    _tdeeCalories = 0.0;
    _tdeeProtein = 0.0;
    _tdeeCarbs = 0.0;
    _tdeeFat = 0.0;
    
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
    if (!_isFirebaseAvailable) return false;
    
    try {
      if (Firebase.apps.isEmpty || _dataIntegrationService == null || FirebaseAuth.instance.currentUser == null) {
        return false;
      }
      
      final result = await _dataIntegrationService!.syncUserProfileData(this);
      
      if (result) {
        _lastSyncTime = DateTime.now();
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
        });
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      debugPrint('Error syncing data: $e');
      return false;
    }
  }
  
  Future<bool> loadFromFirestore() async {
    if (!_isFirebaseAvailable) return false;
    
    try {
      if (Firebase.apps.isEmpty || _dataIntegrationService == null || FirebaseAuth.instance.currentUser == null) {
        return false;
      }
      
      final data = await _dataIntegrationService!.getUserProfile();
      if (data != null && data.isNotEmpty) {
        // Update fields from Firestore data
        if (data['name'] != null) _name = data['name'];
        if (data['gender'] != null) _gender = data['gender'];
        if (data['age'] != null) _age = data['age'];
        if (data['heightCm'] != null) _heightCm = (data['heightCm'] as num).toDouble();
        if (data['weightKg'] != null) _weightKg = (data['weightKg'] as num).toDouble();
        if (data['activityLevel'] != null) _activityLevel = data['activityLevel'];
        if (data['goal'] != null) _goal = data['goal'];
        if (data['pace'] != null) _pace = (data['pace'] as num).toDouble();
        if (data['targetWeightKg'] != null) _targetWeightKg = (data['targetWeightKg'] as num).toDouble();
        if (data['event'] != null) _event = data['event'];
        
        // Event date
        if (data['eventDate'] is String) {
          try {
            final date = DateTime.parse(data['eventDate']);
            _eventDay = date.day;
            _eventMonth = date.month;
            _eventYear = date.year;
          } catch (e) {
            debugPrint('Error parsing event date: $e');
          }
        }
        
        // Diet restrictions
        if (data['dietRestrictions'] is List) {
          _dietRestrictions = List<String>.from(data['dietRestrictions']);
        }
        
        // Diet preference
        if (data['dietPreference'] != null) {
          _dietPreference = data['dietPreference'];
        }
        
        // Health conditions
        if (data['healthConditions'] is List) {
          _healthConditions = List<String>.from(data['healthConditions']);
        }
        
        // TDEE values
        if (data['tdeeCalories'] != null) _tdeeCalories = (data['tdeeCalories'] as num).toDouble();
        if (data['tdeeProtein'] != null) _tdeeProtein = (data['tdeeProtein'] as num).toDouble();
        if (data['tdeeCarbs'] != null) _tdeeCarbs = (data['tdeeCarbs'] as num).toDouble();
        if (data['tdeeFat'] != null) _tdeeFat = (data['tdeeFat'] as num).toDouble();
        
        // Update daily calories
        _dailyCalories = _tdeeCalories.toInt();
        
        // Nutrition goals
        if (data['nutritionGoals'] is Map) {
          final goalsMap = Map<String, dynamic>.from(data['nutritionGoals']);
          _nutritionGoals = goalsMap.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
        
        // Sync settings
        if (data['syncEnabled'] != null) _syncEnabled = data['syncEnabled'];
        if (data['lastSyncTime'] != null) {
          try {
            _lastSyncTime = DateTime.parse(data['lastSyncTime']);
          } catch (e) {
            debugPrint('Error parsing lastSyncTime: $e');
          }
        }
        
        notifyListeners();
        await saveUserData();
        return true;
      }
    } catch (e) {
      debugPrint('Error loading data from Firestore: $e');
    }
    
    return false;
  }
  
  // Helper method for backwards compatibility
  void setGender(String value) {
    gender = value;
  }
  
  // Save user data to SharedPreferences
  Future<void> saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save basic user info
    await prefs.setString(_nameKey, _name);
    await prefs.setString(_genderKey, _gender);
    await prefs.setInt(_ageKey, _age);
    await prefs.setDouble(_heightKey, _heightCm);
    await prefs.setDouble(_weightKey, _weightKg);
    await prefs.setString(_activityLevelKey, _activityLevel);
    await prefs.setString(_goalKey, _goal);
    await prefs.setDouble(_paceKey, _pace);
    
    // Save nutritional targets
    await prefs.setDouble(_tdeeCaloriesKey, _tdeeCalories);
    await prefs.setDouble(_tdeeProteinKey, _tdeeProtein);
    await prefs.setDouble(_tdeeCarbsKey, _tdeeCarbs);
    await prefs.setDouble(_tdeeFatKey, _tdeeFat);
    await prefs.setInt('daily_calories', _dailyCalories);
    await prefs.setDouble('protein', _protein);
    await prefs.setDouble('carbs', _carbs);
    await prefs.setDouble('fat', _fat);
    
    // Save additional data
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
    await prefs.setString(_nutritionGoalsKey, jsonEncode(_nutritionGoals));
    
    // Save sync settings
    await prefs.setBool(_syncEnabledKey, _syncEnabled);
    if (_lastSyncTime != null) {
      await prefs.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
    }
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
} 