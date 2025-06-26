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
import '../services/auth_service.dart';

class UserDataProvider with ChangeNotifier {
  // Hàm log dữ liệu thay thế cho debugPrint để tránh xung đột
  void logUserData(String message) {
    debugPrint(message);
  }

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
  static const String _snakeCaseMigrationKey = 'snakeCaseMigrationDone_v2'; // Thay đổi version nếu có cập nhật logic migration

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
  DateTime? _eventDate;
  String _eventType = '';
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
  
  // Cờ để đánh dấu TDEE đã được tính và tránh tính lại nhiều lần
  bool _tdeeCalculated = false;
  Timer? _debounceTimer;

  // Sync status
  bool _syncEnabled = true;
  DateTime? _lastSyncTime;
  Timer? _syncTimer;
  
  // Auth service reference
  late AuthService _authService;
  
  // Measurement system
  String _measurementSystem = 'metric';

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
  List<String> _dietPreferences = [];
  String? _cuisineStyle;

  // Additional fields
  String _userId = '';
  String _email = '';
  String _weightGoal = 'Duy trì cân nặng';

  // Exercise calories setting
  bool _addExerciseCaloriesToGoal = true;

  // Constructor
  UserDataProvider() {
    // Initialize AuthService
    _authService = AuthService();
    _initializeWithPriority();
    // Thiết lập đồng bộ tự động định kỳ
    _setupPeriodicSync();
  }

  // Thiết lập đồng bộ tự động định kỳ
  void _setupPeriodicSync() {
    // Hủy timer cũ nếu có
    _syncTimer?.cancel();
    
    // Tạo timer mới để đồng bộ định kỳ (mỗi 15 phút)
    if (_syncEnabled) {
      _syncTimer = Timer.periodic(Duration(minutes: 15), (timer) {
        debugPrint('🔄 Tự động đồng bộ định kỳ...');
        // Chỉ đồng bộ nếu đã đăng nhập và có thay đổi
        if (isUserAuthenticated() && isFirebaseAvailable()) {
          syncUserDataCentralized();
        }
      });
      debugPrint('✅ Đã thiết lập đồng bộ tự động định kỳ mỗi 15 phút');
    } else {
      debugPrint('⚠️ Đồng bộ tự động bị tắt');
    }
  }

  // Setter cho syncEnabled để cập nhật timer khi thay đổi
  set syncEnabled(bool value) {
    if (_syncEnabled != value) {
      _syncEnabled = value;
      _setupPeriodicSync(); // Cập nhật timer khi thay đổi trạng thái
      notifyListeners();
      saveUserData();
    }
  }

  // Phương thức đánh dấu dữ liệu đã thay đổi và kích hoạt đồng bộ tự động
  Future<void> _markDataAsChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('data_changed', true);
      await prefs.setString('last_local_update', DateTime.now().toIso8601String());
      debugPrint('🔄 Đã đánh dấu dữ liệu đã thay đổi và cần đồng bộ');
      
      // Tự động đồng bộ dữ liệu sau khi thay đổi (nếu có thể)
      // Thêm debounce để tránh đồng bộ quá thường xuyên
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(seconds: 3), () {
        // Chỉ đồng bộ nếu bật đồng bộ, đã đăng nhập và Firebase khả dụng
        if (_syncEnabled && isUserAuthenticated() && isFirebaseAvailable()) {
          debugPrint('🔄 Tự động đồng bộ sau khi thay đổi dữ liệu...');
          syncUserDataCentralized();
        }
      });
    } catch (e) {
      debugPrint('❌ Lỗi khi đánh dấu dữ liệu đã thay đổi: $e');
    }
  }

  // Check Firebase availability and initialize if possible
  Future<void> _checkFirebaseAvailabilityAndInit() async {
    try {
      // Check if Firebase is already initialized
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseAvailable = true;
        debugPrint('✅ Firebase đã được khởi tạo và sẵn sàng sử dụng');
        
        // Kiểm tra người dùng đã đăng nhập chưa
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          debugPrint('✅ Người dùng đã đăng nhập: ${currentUser.uid}');
          // KHÔNG tự động tải dữ liệu từ Firestore hoặc bắt đầu đồng bộ ở đây
        }
      } else {
        _isFirebaseAvailable = false;
        debugPrint('⚠️ Firebase chưa được khởi tạo');
      }
    } catch (e) {
      _isFirebaseAvailable = false;
      debugPrint('❌ Lỗi khi kiểm tra Firebase: $e');
    }
  }

  // Phương thức khởi tạo với thứ tự ưu tiên rõ ràng
  Future<void> _initializeWithPriority() async {
    try {
      debugPrint('🔄 Bắt đầu khởi tạo UserDataProvider...');

      // Khởi tạo debounce timer
      _debounceTimer = null;

      // 🔧 FIX: Kiểm tra trạng thái đăng nhập để quyết định ưu tiên dữ liệu
      final isLoggedIn = isUserAuthenticated();
      debugPrint('🔍 Trạng thái đăng nhập: $isLoggedIn');

      final prefs = await SharedPreferences.getInstance();

      if (isLoggedIn) {
        // Nếu đã đăng nhập, ưu tiên dữ liệu Firebase
        debugPrint('✅ User đã đăng nhập, ưu tiên dữ liệu Firebase');
        await prefs.setBool('data_loaded_from_firestore', false);
        await prefs.setBool('loading_from_firestore', false);
        await prefs.setBool('use_firebase_data', true); // 🔧 FIX: Ưu tiên Firebase
      } else {
        // Nếu chưa đăng nhập, ưu tiên dữ liệu local
        debugPrint('⚠️ User chưa đăng nhập, ưu tiên dữ liệu local');
        await prefs.setBool('data_loaded_from_firestore', false);
        await prefs.setBool('loading_from_firestore', false);
        await prefs.setBool('use_firebase_data', false);
      }

      // Step 1: Tải dữ liệu từ local storage trước (để có dữ liệu hiển thị ngay)
      debugPrint('🔄 Bước 1: Tải dữ liệu từ local storage');
      await loadUserData();

      // Step 2: Kiểm tra TDEE sau khi tải dữ liệu local
      if (_tdeeCalories <= 0 || (_tdeeCalories - 2000.0).abs() < 0.001) {
        debugPrint('⚠️ TDEE không hợp lệ ($_tdeeCalories), tính toán lại');
        await _initializeTDEEAsync();
        debugPrint('✅ Đã khởi tạo TDEE: $_tdeeCalories calories');
      } else {
        debugPrint('✅ TDEE hợp lệ từ local storage: $_tdeeCalories calories');
      }

      // Step 3: Kiểm tra Firebase & authentication
      bool isAuthenticated = await _checkAuthenticationStatus();

      // THÊM LOGIC MIGRATION Ở ĐÂY
      if (isAuthenticated) {
        debugPrint('✅ Người dùng đã đăng nhập, kiểm tra dữ liệu trên Firestore');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          try {
            final docSnapshot = await docRef.get();

            // Kiểm tra nếu migration chưa hoàn tất
            bool migrationDone = prefs.getBool(_snakeCaseMigrationKey) ?? false;
            if (!migrationDone && docSnapshot.exists) {
              debugPrint('🔄 Bắt đầu di chuyển dữ liệu một lần sang định dạng snake_case...');
              bool success = await forceCompleteMigration();
              if (success) {
                debugPrint('✅ Di chuyển dữ liệu một lần sang định dạng snake_case hoàn tất.');
              } else {
                debugPrint('⚠️ Lỗi trong quá trình di chuyển dữ liệu một lần.');
              }
            }

            if (docSnapshot.exists) {
              // ... (phần còn lại của logic xử lý khi docSnapshot.exists)
            }
          } catch (e) {
            debugPrint('❌ Lỗi khi kiểm tra dữ liệu trên Firestore: $e');
          }
        }
      }

      // Step 4: Nếu đã đăng nhập, thiết lập đồng bộ tự động
      if (isAuthenticated && _isFirebaseAvailable) {
        debugPrint('✅ Người dùng đã đăng nhập, thiết lập đồng bộ tự động');
        
        // Nếu đồng bộ được bật, thiết lập timer
        if (_syncEnabled) {
          _setupPeriodicSync();
          
          // Đồng bộ ngay lần đầu tiên sau khi khởi động (chỉ khi dữ liệu đã ổn định)
          Future.delayed(Duration(seconds: 10), () {
            debugPrint('🔄 Đồng bộ tự động lần đầu sau khi khởi động');
            syncUserDataCentralized();
          });
        }
      } else {
        debugPrint('ℹ️ Người dùng chưa đăng nhập hoặc Firebase không khả dụng, bỏ qua đồng bộ');
      }

      // Step 5: Thông báo UI cập nhật sau khi tất cả dữ liệu đã được tải
      notifyListeners();
      debugPrint('✅ Khởi tạo UserDataProvider hoàn tất');
    } catch (e) {
      debugPrint('❌ Lỗi khởi tạo UserDataProvider: $e');
    }
  }

  // Tải dữ liệu từ Firestore nếu có sẵn
  Future<void> _loadFirestoreDataIfAvailable() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_isFirebaseAvailable) {
        debugPrint('🔄 Đang tải dữ liệu từ Firestore...');
        
        // Tải dữ liệu từ Firestore một cách có kiểm soát
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          // Lưu dữ liệu gốc vào log để debug
          final rawData = docSnapshot.data()!;
          debugPrint('📋 Dữ liệu gốc từ Firestore: ${rawData.keys.join(", ")}');
          
          // Kiểm tra xem dữ liệu Firestore có TDEE hợp lệ không
          double firebaseTdee = 0.0;
          if (rawData.containsKey('tdee_calories')) {
            firebaseTdee = _safeParseDouble(rawData['tdee_calories'], 0.0);
          } else if (rawData.containsKey('tdeeCalories')) {
            firebaseTdee = _safeParseDouble(rawData['tdeeCalories'], 0.0);
          }
          
          // Nếu dữ liệu TDEE từ Firestore không hợp lệ, in log cảnh báo
          if (firebaseTdee <= 0.0) {
            debugPrint('⚠️ TDEE từ Firestore không hợp lệ: $firebaseTdee');
          } else {
            debugPrint('✅ TDEE từ Firestore hợp lệ: $firebaseTdee');
          }
          
          // Đánh dấu bắt đầu quá trình tải dữ liệu
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('loading_from_firestore', true);
          
          // Tải dữ liệu từ Firestore
          await loadFromFirestoreData(rawData);
          
          // Đánh dấu đã tải xong để tránh tính toán lại
          await prefs.setBool('use_firebase_data', true);
          await prefs.setBool('loading_from_firestore', false);
          
          // Ghi nhớ dữ liệu đã được tải từ Firestore gần đây
          await prefs.setString('last_firestore_load_time', DateTime.now().toIso8601String());
          
          debugPrint('✅ Đã tải dữ liệu từ Firestore thành công');
        } else {
          debugPrint('⚠️ Không tìm thấy dữ liệu người dùng trong Firestore');
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi tải dữ liệu từ Firestore: $e');
      
      // Đảm bảo cờ loading_from_firestore được đặt lại khi có lỗi
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('loading_from_firestore', false);
    }
  }

  // Kiểm tra trạng thái đăng nhập trước khi quyết định có tải dữ liệu từ Firestore hay không
  Future<bool> _checkAuthenticationStatus() async {
    try {
      // Kiểm tra xem người dùng đã đăng nhập chưa
      final isAuthenticated = isUserAuthenticated();

      if (isAuthenticated) {
        debugPrint(
            '🔄 Người dùng đã đăng nhập: Kiểm tra Firebase');
        // Nếu đã đăng nhập, kiểm tra Firebase có sẵn sàng không
        await _checkFirebaseAvailabilityAndInit();

        // Đánh dấu để ghi nhớ rằng dữ liệu Firebase sẽ được ưu tiên sử dụng
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('use_firebase_data', true);
      } else {
        debugPrint('🔄 Người dùng chưa đăng nhập: Sử dụng dữ liệu local');
        // Nếu chưa đăng nhập, chỉ sử dụng dữ liệu local đã được tải trước đó
      }

      return isAuthenticated;
    } catch (e) {
      debugPrint('✖ Lỗi khi kiểm tra trạng thái đăng nhập: $e');
      return false;
    }
  }

  // Rename the async version to avoid conflicts
  Future<void> _initializeTDEEAsync() async {
    // Kiểm tra cờ đã tính TDEE chưa
    if (_tdeeCalculated && _tdeeCalories > 0) {
      debugPrint('TDEE đã được tính toán trước đó: $_tdeeCalories, bỏ qua việc tính lại');
      return;
    }

    try {
      // Kiểm tra dữ liệu đầu vào hợp lệ
      if (_weightKg <= 0 || _heightCm <= 0 || _age <= 0) {
        debugPrint('Dữ liệu người dùng không hợp lệ cho việc tính TDEE');
        _tdeeCalories = 2000.0;
        _tdeeProtein = 120.0;
        _tdeeCarbs = 200.0;
        _tdeeFat = 65.0;
        _tdeeCalculated = true; // Đánh dấu đã tính TDEE
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

        // Đánh dấu đã tính TDEE
        _tdeeCalculated = true;

        // Save the calculated values
        saveUserData();

        debugPrint('TDEE initialized: $_tdeeCalories calories');
      } else {
        // If calculation failed, use default values
        _tdeeCalories = _dailyCalories.toDouble();
        _tdeeProtein = _protein;
        _tdeeCarbs = _carbs;
        _tdeeFat = _fat;
        _tdeeCalculated = true; // Đánh dấu đã tính TDEE

        debugPrint('TDEE initialization failed, using defaults: $_tdeeCalories calories');
      }
    } catch (e) {
      // In case of error, use default values
      debugPrint('Error initializing TDEE: $e');
      _tdeeCalories = _dailyCalories.toDouble();
      _tdeeProtein = _protein;
      _tdeeCarbs = _carbs;
      _tdeeFat = _fat;
      _tdeeCalculated = true; // Đánh dấu đã tính TDEE
    }

    // Cập nhật nutrition goals với giá trị TDEE mới
    // Sử dụng phương thức chuyên biệt để điều chỉnh mục tiêu dinh dưỡng dựa trên TDEE
    updateNutritionGoalsByTDEE(notify: false);
    debugPrint('✅ Đã cập nhật mục tiêu dinh dưỡng theo TDEE mới: ${_nutritionGoals['calories']} calories');
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
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

  DateTime? get eventDate => _eventDate;

  String get eventType => _eventType;

  List<String> get dietRestrictions => _dietRestrictions;

  List<String> get dietaryRestrictions =>
      _dietRestrictions; // Alias for dietRestrictions
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
  
  String get measurementSystem => _measurementSystem;

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
    return '${_lastSyncTime!.day.toString().padLeft(2, '0')}/${_lastSyncTime!
        .month.toString().padLeft(2, '0')}/${_lastSyncTime!
        .year} ${_lastSyncTime!.hour.toString().padLeft(
        2, '0')}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}';
  }

  // Setters
  set gender(String value) {
    // Kiểm tra dữ liệu hợp lệ
    if (value != 'Nam' && value != 'Nữ') {
      debugPrint('⚠️ Giá trị giới tính không hợp lệ: $value');
      return;
    }
    
    if (_gender != value) {
    _gender = value;
    saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      // Sử dụng Future.microtask để tránh gọi notifyListeners trong build
      Future.microtask(() {
        notifyListeners();
      });
    recalculateTDEE(); // Recalculate TDEE when gender changes
    }
  }

  void setName(String value) {
    if (_name != value) {
      _name = value;
      // Sử dụng Future.microtask để tránh gọi notifyListeners trong build
      Future.microtask(() {
        notifyListeners();
      });
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
    }
  }

  // Phương thức trung tâm để trigger TDEE recalculation và cập nhật UI
  void _triggerTDEERecalculation() {
    // Nếu đang trong quá trình onboarding, không trigger liên tục
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      bool isOnboarding = prefs.getBool('is_onboarding') ?? true;
      
      if (isOnboarding) {
        debugPrint('⚠️ Đang trong quá trình onboarding, giới hạn việc tính toán TDEE liên tục');
        // Sử dụng debounce để giới hạn số lần tính toán TDEE
        if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
        _debounceTimer = Timer(const Duration(seconds: 3), () {
          recalculateTDEE().then((_) {
            updateNutritionGoalsByTDEE(notify: true);
          });
        });
      } else {
        // Trong trường hợp bình thường, tính TDEE ngay lập tức
        recalculateTDEE().then((_) {
          updateNutritionGoalsByTDEE(notify: true);
        });
      }
    });
  }

  void setAge(int value) {
    // Kiểm tra dữ liệu hợp lệ
    if (value <= 0 || value > 120) {
      debugPrint('⚠️ Giá trị tuổi không hợp lệ: $value');
      return;
    }
    
    if (_age != value) {
      _age = value;
      Future.microtask(() {
        notifyListeners();
      });
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      _triggerTDEERecalculation(); // Sử dụng phương thức trung tâm
    }
  }

  void setHeight(double value) {
    // Kiểm tra dữ liệu hợp lệ
    if (value <= 0 || value > 250) {
      debugPrint('⚠️ Giá trị chiều cao không hợp lệ: $value');
      return;
    }
    
    if (_heightCm != value) {
      _heightCm = value;
      _tdeeCalculated = false; // Reset cờ để tính lại TDEE
      
      // Sử dụng debounce để tránh tính toán quá nhiều lần
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        notifyListeners();
        saveUserData();
        _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
        _triggerTDEERecalculation(); // Sử dụng phương thức trung tâm
      });
    }
  }

  void setWeight(double value) {
    // Kiểm tra dữ liệu hợp lệ
    if (value <= 0 || value > 300) {
      debugPrint('⚠️ Giá trị cân nặng không hợp lệ: $value');
      return;
    }

    if (_weightKg != value) {
      _weightKg = value;

      // Sử dụng debounce để tránh thông báo quá nhiều lần
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        notifyListeners();
        saveUserData();
        _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
        _triggerTDEERecalculation(); // Sử dụng phương thức trung tâm
      });
    }
  }

  void setActivityLevel(String value) {
    // Kiểm tra dữ liệu hợp lệ - danh sách các mức độ hoạt động hợp lệ
    final validLevels = ['Ít vận động', 'Hoạt động nhẹ', 'Hoạt động vừa phải', 'Hoạt động mạnh', 'Hoạt động rất mạnh'];
    if (!validLevels.contains(value)) {
      debugPrint('⚠️ Giá trị mức độ hoạt động không hợp lệ: $value');
      return;
    }
    
    if (_activityLevel != value) {
      _activityLevel = value;
      Future.microtask(() {
        notifyListeners();
      });
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      _triggerTDEERecalculation(); // Sử dụng phương thức trung tâm
    }
  }

  // Phương thức trung tâm để cập nhật mục tiêu dinh dưỡng dựa trên TDEE
  void updateNutritionGoalsByTDEE({bool notify = true}) {
    debugPrint('🔄 updateNutritionGoalsByTDEE được gọi với TDEE: $_tdeeCalories, Goal: $_goal');

    _adjustCaloriesByGoal();
    _calculateMacrosByCalories();
    saveUserData();

    // 🔧 FIX: Log để debug vấn đề calorie target
    debugPrint('✅ Đã cập nhật nutrition goals: calories=${_nutritionGoals['calories']}, protein=${_nutritionGoals['protein']}, carbs=${_nutritionGoals['carbs']}, fat=${_nutritionGoals['fat']}');

    if (notify) {
      // Sử dụng debounce để tránh thông báo quá nhiều lần
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        notifyListeners();
      });
    }
  }

  // Điều chỉnh calories dựa trên mục tiêu
  void _adjustCaloriesByGoal() {
    // Đảm bảo TDEE hợp lệ
    if (_tdeeCalories <= 0) {
      debugPrint('⚠️ TDEE không hợp lệ ($_tdeeCalories), sử dụng giá trị mặc định 2000');
      _tdeeCalories = 2000.0;
    }
    
    if (_goal == 'Duy trì cân nặng') {
      _nutritionGoals['calories'] = _tdeeCalories;
      debugPrint('📋 Mục tiêu calo cho DUY TRÌ: $_tdeeCalories');
    } else if (_goal == 'Giảm cân') {
      // Sử dụng pace để điều chỉnh mức giảm calo
      double deficit = 500 * _pace;
      
      // Đảm bảo deficit hợp lệ
      if (deficit < 300) deficit = 300; // Tối thiểu 300 calo
      if (deficit > 1000) deficit = 1000; // Tối đa 1000 calo
      
      // Tính toán mục tiêu calo giảm cân
      double weightLossCalories = _tdeeCalories - deficit;
      
      // Đảm bảo mục tiêu calo không quá thấp (tối thiểu 1200 cho nữ, 1500 cho nam)
      double minCalories = (_gender == 'Nữ') ? 1200.0 : 1500.0;
      
      if (weightLossCalories < minCalories) {
        debugPrint('⚠️ Mục tiêu calo quá thấp ($weightLossCalories), đặt lại thành $minCalories');
        weightLossCalories = minCalories;
      }
      
      // Kiểm tra lại để đảm bảo mục tiêu luôn thấp hơn TDEE
      if (weightLossCalories >= _tdeeCalories) {
        debugPrint('⚠️ Phát hiện lỗi: Mục tiêu calo giảm cân ($weightLossCalories) >= TDEE ($_tdeeCalories)');
        weightLossCalories = _tdeeCalories - 300; // Giảm tối thiểu 300 calo
        debugPrint('🔧 Đã sửa: Mục tiêu calo giảm cân = $weightLossCalories');
      }
      
      _nutritionGoals['calories'] = weightLossCalories;
      debugPrint('📉 Điều chỉnh mục tiêu calo cho GIẢM CÂN: $_tdeeCalories ↓ $weightLossCalories (giảm $deficit calo)');
    } else if (_goal == 'Tăng cân') {
      // Sử dụng pace để điều chỉnh mức tăng calo
      double surplus = 500 * _pace;
      
      // Đảm bảo surplus hợp lệ
      if (surplus < 300) surplus = 300; // Tối thiểu 300 calo
      if (surplus > 1000) surplus = 1000; // Tối đa 1000 calo
      
      _nutritionGoals['calories'] = _tdeeCalories + surplus;
      debugPrint('📈 Điều chỉnh mục tiêu calo cho TĂNG CÂN: $_tdeeCalories ↑ ${_nutritionGoals['calories']} (tăng $surplus calo)');
    }
  }

  // Tính toán macros dựa trên calories
  void _calculateMacrosByCalories() {
    double calories = _nutritionGoals['calories'] ?? _tdeeCalories;
    
    // Đảm bảo calories là một giá trị hợp lệ
    if (calories <= 0) calories = 2000.0;
    
    // Tính protein dựa trên trọng lượng cơ thể (2.2g/kg)
    _nutritionGoals['protein'] = _weightKg * 2.2;
    
    // Tính chất béo (25% tổng calo)
    _nutritionGoals['fat'] = (calories * 0.25) / 9;
    
    // Tính carbs (phần còn lại của calo)
    _nutritionGoals['carbs'] = (calories - (_nutritionGoals['protein']! * 4) -
        (_nutritionGoals['fat']! * 9)) / 4;
        
    // Kiểm tra nếu carbs bị âm (có thể xảy ra với mục tiêu calo thấp)
    if (_nutritionGoals['carbs']! < 50) {
      // Đảm bảo tối thiểu 50g carbs
      _nutritionGoals['carbs'] = 50.0;
      // Điều chỉnh lại chất béo
      _nutritionGoals['fat'] = (calories - (_nutritionGoals['protein']! * 4) - 
          (_nutritionGoals['carbs']! * 4)) / 9;
    }

    debugPrint(
        '✅ Đã cập nhật macros: P:${_nutritionGoals['protein']!.toStringAsFixed(1)}g, '
            'C:${_nutritionGoals['carbs']!.toStringAsFixed(1)}g, '
            'F:${_nutritionGoals['fat']!.toStringAsFixed(1)}g');
  }

  void setGoal(String value) {
    // Kiểm tra dữ liệu hợp lệ
    final validGoals = ['Giảm cân', 'Duy trì cân nặng', 'Tăng cân'];
    if (!validGoals.contains(value)) {
      debugPrint('⚠️ Giá trị mục tiêu không hợp lệ: $value');
      return;
    }
    
    if (_goal != value) {
      String oldGoal = _goal;
      _goal = value;
      debugPrint('🔄 Mục tiêu thay đổi từ "$oldGoal" thành "$value"');
      
      // Lưu dữ liệu
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      
      // Cập nhật mục tiêu dinh dưỡng dựa trên TDEE và mục tiêu mới
      updateNutritionGoalsByTDEE();
      
      // Thông báo UI
      Future.microtask(() {
        notifyListeners();
      });
      
      // Đồng bộ với Firebase nếu có thể
      if (_isFirebaseAvailable && _syncEnabled) {
        syncUserDataCentralized();
      }
    }
  }

  // For backward compatibility - hỗ trợ cả string và double
  void setPace(dynamic value) {
    double newPace = 0.5; // Giá trị mặc định
    
    if (value is String) {
      // Convert string pace values to double
      newPace = convertPaceStringToDouble(value);
    } else if (value is double) {
      newPace = value;
    } else if (value is int) {
      newPace = value.toDouble();
    }
    
    // Kiểm tra dữ liệu hợp lệ
    if (newPace < 0.1 || newPace > 2.0) {
      debugPrint('⚠️ Giá trị tốc độ không hợp lệ: $newPace');
      return;
    }
    
    if (_pace != newPace) {
      _pace = newPace;
      debugPrint('🔄 Tốc độ thay đổi thành $_pace');
      
      // Cập nhật mục tiêu dinh dưỡng dựa trên pace mới
      updateNutritionGoalsByTDEE();
      
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      
      // Thông báo UI
      Future.microtask(() {
        notifyListeners();
      });
      
      // Đồng bộ với Firebase nếu có thể
      if (_isFirebaseAvailable && _syncEnabled) {
        syncUserDataCentralized();
      }
    }
  }

  // Phương thức chuyển đổi string pace sang double
  double convertPaceStringToDouble(String paceString) {
    switch (paceString) {
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

  // Phương thức chuyển đổi double pace sang string
  String convertPaceDoubleToString(double paceValue) {
    if (paceValue <= 0.25) {
      return 'Chậm';
    } else if (paceValue >= 0.75) {
      return 'Nhanh';
    } else {
      return 'Vừa phải';
    }
  }

  // Additional property setters – sử dụng Future.microtask nhất quán
  set targetWeightKg(double value) {
    if (_targetWeightKg != value) {
      _targetWeightKg = value;
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      Future.microtask(() {
        notifyListeners();
      });
    }
  }
  
  set event(String value) {
    if (_event != value) {
      _event = value;
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      Future.microtask(() {
        notifyListeners();
      });
    }
  }
  
  set eventDay(int value) {
    if (_eventDay != value) {
      _eventDay = value;
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      Future.microtask(() {
        notifyListeners();
      });
    }
  }
  
  set eventMonth(int value) {
    if (_eventMonth != value) {
      _eventMonth = value;
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      Future.microtask(() {
        notifyListeners();
      });
    }
  }
  
  set eventYear(int value) {
    if (_eventYear != value) {
      _eventYear = value;
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  set eventDate(DateTime? value) {
    if (_eventDate != value) {
      _eventDate = value;
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  set eventType(String value) {
    if (_eventType != value) {
      _eventType = value;
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  set dietRestrictions(List<String> value) {
    _dietRestrictions = value;
    notifyListeners();
    saveUserData();
    _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
  }
  
  set dietPreference(String value) {
    _dietPreference = value;
    notifyListeners();
    saveUserData();
    _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
  }
  
  set healthConditions(List<String> value) {
    _healthConditions = value;
    notifyListeners();
    saveUserData();
    _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
  }
  
  // For nutrition goals
  void updateNutritionGoal(String nutrient, double value) {
    _nutritionGoals[nutrient] = value;
    notifyListeners();
    saveUserData();
    _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
  }
  
  void updateNutritionGoals(Map<String, double> updates) {
    _nutritionGoals.addAll(updates);
    notifyListeners();
    saveUserData();
    _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
  }

  // Update TDEE values
  Future<void> updateTDEEValues({
    required dynamic calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    debugPrint('🔄 updateTDEEValues được gọi với calories=$calories, protein=$protein, carbs=$carbs, fat=$fat');
    
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
    
    // Lưu TDEE trực tiếp vào SharedPreferences để đảm bảo dữ liệu được lưu
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_tdeeCaloriesKey, _tdeeCalories);
    await prefs.setDouble(_tdeeProteinKey, _tdeeProtein);
    await prefs.setDouble(_tdeeCarbsKey, _tdeeCarbs);
    await prefs.setDouble(_tdeeFatKey, _tdeeFat);
    
    debugPrint('✅ Lưu trực tiếp TDEE: calories=$_tdeeCalories, protein=$_tdeeProtein, carbs=$_tdeeCarbs, fat=$_tdeeFat');

    // Cập nhật mục tiêu dinh dưỡng dựa trên TDEE mới
    updateNutritionGoalsByTDEE();

    // Lưu giá trị mới
    await saveUserData();

    // Thông báo các widget để cập nhật UI
    notifyListeners();

    // Đồng bộ dữ liệu với API/Firestore nếu có thể
    if (_isFirebaseAvailable && _syncEnabled) {
      await sendToApi();
    }

    debugPrint('TDEE cập nhật: $_tdeeCalories kcal, Mục tiêu điều chỉnh: ${_nutritionGoals['calories']} kcal');
  }

  // Sync control


  void startPeriodicSync() {
    if (!_isFirebaseAvailable) return;

    _syncTimer?.cancel();

    try {
      if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null)
        return;

      _syncTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
        if (FirebaseAuth.instance.currentUser == null) {
          timer.cancel();
          return;
        }

        // Kiểm tra xem dữ liệu người dùng đã tồn tại trên Firestore chưa
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
            final docSnapshot = await docRef.get();
            
            if (docSnapshot.exists) {
              // Dữ liệu đã tồn tại, kiểm tra thời gian cập nhật trước khi đồng bộ
              debugPrint('🔄 Đồng bộ định kỳ: Dữ liệu đã tồn tại, kiểm tra cần đồng bộ không');
              
              // Kiểm tra thời gian cập nhật local
              final prefs = await SharedPreferences.getInstance();
              final lastLocalUpdateStr = prefs.getString('last_local_update');
              
              if (lastLocalUpdateStr != null) {
                try {
                  final lastLocalUpdate = DateTime.parse(lastLocalUpdateStr);
                  final lastSync = _lastSyncTime ?? DateTime.fromMillisecondsSinceEpoch(0);
                  
                  // Chỉ đồng bộ nếu dữ liệu local đã thay đổi sau lần đồng bộ cuối
                  if (lastLocalUpdate.isAfter(lastSync)) {
                    debugPrint('🔄 Đồng bộ định kỳ: Dữ liệu local đã thay đổi, thực hiện đồng bộ');
                    await syncUserDataCentralized();
                  } else {
                    debugPrint('ℹ️ Đồng bộ định kỳ: Không cần đồng bộ, dữ liệu chưa thay đổi');
                  }
                } catch (e) {
                  debugPrint('⚠️ Đồng bộ định kỳ: Lỗi khi phân tích thời gian cập nhật: $e');
                }
              } else {
                debugPrint('⚠️ Đồng bộ định kỳ: Không có thông tin về thời gian cập nhật local');
              }
            } else {
              // Dữ liệu chưa tồn tại, kiểm tra có cần tạo mới không
              final prefs = await SharedPreferences.getInstance();
              final needCreate = prefs.getBool('need_create_firebase_data') ?? false;
              
              if (needCreate) {
                debugPrint('🔄 Đồng bộ định kỳ: Dữ liệu chưa tồn tại, tạo mới trên Firestore');
                await syncUserDataCentralized(forceSync: true);
              } else {
                debugPrint('ℹ️ Đồng bộ định kỳ: Dữ liệu chưa tồn tại và không có yêu cầu tạo mới');
              }
            }
          } catch (e) {
            debugPrint('❌ Đồng bộ định kỳ: Lỗi khi kiểm tra/đồng bộ dữ liệu: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting periodic sync: $e');
    }
  }

  // Reset data - xóa dữ liệu cục bộ khi đăng xuất
  Future<void> resetData() async {
    debugPrint('🗑️ Đang xóa dữ liệu cục bộ...');

    // Gọi phương thức clearLocalUserData để xóa sạch dữ liệu
    await clearLocalUserData();

    debugPrint('✅ Đã xóa dữ liệu cục bộ thành công');
  }

  // API interactions
  Future<bool> sendToApi() async {
    // Sử dụng phương thức đồng bộ tập trung thay vì logic riêng
    return await syncUserDataCentralized();
  }

  // Chuẩn bị dữ liệu người dùng để đồng bộ với Firestore
  Map<String, dynamic> _prepareUserDataForSync() {
    try {
    // Lấy user ID từ Firebase Authentication
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    
    // Luôn đảm bảo có user_id chính xác
    if (uid.isEmpty) {
      debugPrint('⚠️ Không thể đồng bộ: Không có user ID');
      return {};
    }
    
    final userData = {
        'user_id': uid,
      'email': user?.email ?? _email,
      'name': _name,
      'gender': _gender,
      'age': _age,
      'height_cm': _heightCm,
      'weight_kg': _weightKg,
      'activity_level': _activityLevel,
      'goal': _goal,
      'pace': _pace,
      'target_weight_kg': _targetWeightKg,
      'diet_restrictions': _dietRestrictions,
      'health_conditions': _healthConditions,
      'diet_preference': _dietPreference, // Thêm diet_preference vào dữ liệu đồng bộ
      'last_sync_time': DateTime.now().millisecondsSinceEpoch,
      'sync_enabled': _syncEnabled,
      'updated_at': DateTime.now().toIso8601String(),
      'tdee_calories': _tdeeCalories,
      'tdee_protein': _tdeeProtein,
      'tdee_carbs': _tdeeCarbs,
      'tdee_fat': _tdeeFat,
        'measurement_system': _measurementSystem,
    };
    
      // Thêm nutrition_goals
    Map<String, dynamic> nutritionGoals = {};
    _nutritionGoals.forEach((key, value) {
      nutritionGoals[key] = value;
    });
    userData['nutrition_goals'] = nutritionGoals;
    
      // Loại bỏ các giá trị null để tránh lỗi khi đồng bộ
      userData.removeWhere((key, value) => value == null);
    
    return userData;
    } catch (e) {
      debugPrint('❌ Lỗi khi chuẩn bị dữ liệu đồng bộ: $e');
      return {};
    }
  }

  // Kiểm tra Firebase đã khởi tạo chưa
  Future<bool> _isFirebaseInitialized() async {
    try {
      await Firebase.initializeApp();
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khởi tạo Firebase: $e');
      return false;
    }
  }

  // Gửi dữ liệu trực tiếp đến Firebase
  Future<bool> syncToFirebase() async {
    // Sử dụng phương thức đồng bộ tập trung thay vì logic riêng
    return await syncUserDataCentralized(forceSync: true);
  }

  // Load user data from API


  // Lưu dữ liệu người dùng vào SharedPreferences
  Future<bool> saveUserData() async {
    try {
    final prefs = await SharedPreferences.getInstance();
    
      // Convert user data to JSON
      final userData = toJson();
      
      // Đảm bảo lưu từng trường dữ liệu riêng biệt để tránh mất dữ liệu
      await prefs.setString('user_name', name);
      await prefs.setInt('user_age', age);
      await prefs.setDouble('user_height_cm', heightCm);
      await prefs.setDouble('user_weight_kg', weightKg);
      await prefs.setDouble('user_target_weight_kg', targetWeightKg);
      await prefs.setString('user_gender', gender);
      await prefs.setString('user_activity_level', activityLevel);
      await prefs.setString('user_goal', goal);
      await prefs.setDouble('user_pace', pace);
      
      // Lưu danh sách hạn chế chế độ ăn và tình trạng sức khỏe
      await prefs.setStringList('user_dietary_restrictions', dietaryRestrictions);
      await prefs.setStringList('user_health_conditions', healthConditions);
      
      // Lưu cả dạng JSON để đảm bảo dữ liệu được lưu chính xác
      await prefs.setString(_dietRestrictionKey, jsonEncode(_dietRestrictions));
      await prefs.setString(_healthConditionsKey, jsonEncode(_healthConditions));
      await prefs.setString(_dietPreferenceKey, _dietPreference);
      
      // Debug các giá trị đã lưu
      debugPrint('📋 Đã lưu diet_preference vào SharedPreferences: $_dietPreference');
      debugPrint('📋 Đã lưu diet_restrictions vào SharedPreferences: $_dietRestrictions');
      debugPrint('📋 Đã lưu health_conditions vào SharedPreferences: $_healthConditions');
      
      // Lưu trường measurement_system
      await prefs.setString('user_measurement_system', measurementSystem);
      
      // Lưu trường tdeeCalories
      if (tdeeCalories > 0) {
        await prefs.setDouble('user_tdee_calories', tdeeCalories);
        print('✅ Đã lưu TDEE calories: $tdeeCalories');
      } else {
        // Nếu tdeeCalories không hợp lệ, tính lại trước khi lưu
        double calculatedTDEE = await calculateTDEE();
        await prefs.setDouble('user_tdee_calories', calculatedTDEE);
        print('⚠️ TDEE không hợp lệ, đã tự động tính lại và lưu: $calculatedTDEE');
      }
      
      // Lưu macro TDEE
      await prefs.setDouble('user_tdee_protein', tdeeProtein);
      await prefs.setDouble('user_tdee_carbs', tdeeCarbs);
      await prefs.setDouble('user_tdee_fat', tdeeFat);
      
      // Lưu nutrition goals
      if (nutritionGoals.isNotEmpty) {
        for (var key in nutritionGoals.keys) {
          if (nutritionGoals[key] != null) {
            await prefs.setDouble('user_nutrition_goals_$key', nutritionGoals[key]!);
          }
        }
        print('✅ Đã lưu nutrition goals: $nutritionGoals');
      } else {
        print('⚠️ Nutrition goals trống, không lưu');
      }
      
      // Lưu toàn bộ dữ liệu dưới dạng JSON
      await prefs.setString('user_data', jsonEncode(userData));
      
      // Đặt cờ dữ liệu đã thay đổi
      await prefs.setBool('data_changed', true);
      
      // Lưu thời gian cập nhật local
      await prefs.setString('last_local_update', DateTime.now().toIso8601String());
      
      // Đặt cờ data_loaded_from_firestore thành false
      await prefs.setBool('data_loaded_from_firestore', false);
      
      print('✅ Đã lưu dữ liệu người dùng vào SharedPreferences thành công');
      
      // Gọi đồng bộ tự động lên Firebase nếu đã bật
      if (syncEnabled && _authService.isAuthenticated) {
        print('🔄 Tự động đồng bộ lên Firebase sau khi lưu local');
        _syncUserDataToFirebase();
      }
      
      return true;
    } catch (e) {
      print('❌ Lỗi khi lưu dữ liệu người dùng: $e');
      return false;
    }
  }

  // Load user data from SharedPreferences
  Future<void> loadUserData() async {
    try {
    final prefs = await SharedPreferences.getInstance();

      // 🔧 FIX: Không reset cờ use_firebase_data nếu user đã đăng nhập
      final isLoggedIn = isUserAuthenticated();
      if (!isLoggedIn) {
        // Chỉ reset khi user chưa đăng nhập
        await prefs.setBool('data_loaded_from_firestore', false);
        await prefs.setBool('use_firebase_data', false);
        debugPrint('🔄 Tải dữ liệu từ local storage (user chưa đăng nhập)...');
      } else {
        debugPrint('🔄 Tải dữ liệu từ local storage (user đã đăng nhập, sẽ sync Firebase sau)...');
      }

    // Load basic user info
    _name = prefs.getString(_nameKey) ?? '';
    _gender = prefs.getString(_genderKey) ?? 'Nam';
    _age = prefs.getInt(_ageKey) ?? 25;
    _heightCm = prefs.getDouble(_heightKey) ?? 170.0;
    _weightKg = prefs.getDouble(_weightKey) ?? 65.0;
      _activityLevel = prefs.getString(_activityLevelKey) ?? 'moderate';
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
          print('Error parsing event date: $e');
      }
    }

    // Load diet restrictions
    final dietRestrictionsString = prefs.getString(_dietRestrictionKey);
    if (dietRestrictionsString != null) {
      try {
          final List<dynamic> restrictionList = jsonDecode(dietRestrictionsString);
          _dietRestrictions = restrictionList.map((item) => item.toString()).toList();
      } catch (e) {
          print('Error parsing diet restrictions: $e');
      }
    }

    // Load diet preference
    _dietPreference = prefs.getString(_dietPreferenceKey) ?? '';
    debugPrint('📋 Đã tải diet_preference từ SharedPreferences: $_dietPreference');

    // Load health conditions
    final healthConditionsString = prefs.getString(_healthConditionsKey);
    if (healthConditionsString != null) {
      try {
        final List<dynamic> conditionsList = jsonDecode(healthConditionsString);
          _healthConditions = conditionsList.map((item) => item.toString()).toList();
          debugPrint('📋 Đã tải health_conditions từ SharedPreferences: $_healthConditions');
      } catch (e) {
          print('Error parsing health conditions: $e');
      }
    }
    
    // Load diet restrictions
    final dietRestrictionsListRaw = prefs.getStringList('user_dietary_restrictions');
    if (dietRestrictionsListRaw != null && dietRestrictionsListRaw.isNotEmpty) {
      _dietRestrictions = dietRestrictionsListRaw;
      debugPrint('📋 Đã tải diet_restrictions từ SharedPreferences direct list: $_dietRestrictions');
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
          print('Error parsing nutrition goals: $e');
        }
      }

      // Tải trực tiếp từng giá trị dinh dưỡng riêng lẻ (để đảm bảo)
      final caloriesGoal = prefs.getDouble('user_nutrition_goals_calories');
      if (caloriesGoal != null && caloriesGoal > 0) {
        _nutritionGoals['calories'] = caloriesGoal;
      }

      final proteinGoal = prefs.getDouble('user_nutrition_goals_protein');
      if (proteinGoal != null && proteinGoal > 0) {
        _nutritionGoals['protein'] = proteinGoal;
      }

      final carbsGoal = prefs.getDouble('user_nutrition_goals_carbs');
      if (carbsGoal != null && carbsGoal > 0) {
        _nutritionGoals['carbs'] = carbsGoal;
      }

      final fatGoal = prefs.getDouble('user_nutrition_goals_fat');
      if (fatGoal != null && fatGoal > 0) {
        _nutritionGoals['fat'] = fatGoal;
      }

      // Load sync settings
      _syncEnabled = prefs.getBool(_syncEnabledKey) ?? true;
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
    if (_addExerciseCaloriesToGoal != value) {
    _addExerciseCaloriesToGoal = value;
      debugPrint('🔄 Đã cập nhật cài đặt thêm calo từ bài tập: $value');
      
    saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      
      notifyListeners();
      
      // Đồng bộ với Firebase nếu có thể
      if (_isFirebaseAvailable && _syncEnabled) {
        syncUserDataCentralized();
      }
    }
  }

  // Hàm đồng bộ hoặc lấy dữ liệu user sau khi đăng nhập
  Future<void> syncOrFetchUserData(BuildContext context) async {
    debugPrint('🔄 Bắt đầu syncOrFetchUserData...');
    debugPrint('📋 Trước khi đồng bộ: diet_preference=$_dietPreference, diet_restrictions=$_dietRestrictions, health_conditions=$_healthConditions');
    
    // 🔧 FIX: Kiểm tra trạng thái đăng nhập trước khi đồng bộ dữ liệu
    if (!isUserAuthenticated()) {
      debugPrint(
          '⚠️ Người dùng chưa đăng nhập: Ưu tiên dữ liệu từ local, bỏ qua đồng bộ dữ liệu');
      // Đảm bảo dữ liệu local được tải
      await loadUserData();
      debugPrint('📊 Sau khi tải dữ liệu local:');
      debugPrint('📊 diet_restrictions: $_dietRestrictions');
      debugPrint('📊 health_conditions: $_healthConditions');
      debugPrint('📊 diet_preference: $_dietPreference');
      return;
    }

    // 🔧 FIX: Nếu user đã đăng nhập, ưu tiên tải dữ liệu từ Firebase
    debugPrint('✅ User đã đăng nhập, ưu tiên tải dữ liệu từ Firebase');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_firebase_data', true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    try {
      // Kiểm tra xem người dùng đã tồn tại trong Firestore chưa
      DocumentSnapshot? userDoc;
      bool userExists = false;

      try {
        userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
        userExists = userDoc.exists;
        debugPrint('🔍 Kiểm tra người dùng trên Firestore: ${userExists
            ? "Tồn tại"
            : "Không tồn tại"}');
      } catch (e) {
        debugPrint('❌ Lỗi khi kiểm tra người dùng: $e');
      }

      if (!userExists) {
        // Lần đầu đăng nhập: đánh dấu cho người dùng biết đây là người dùng mới
        debugPrint(
            '👤 Người dùng chưa tồn tại trong Firestore, đây là người dùng mới');
        
        // Đánh dấu cần tạo dữ liệu mới trên Firestore (khi người dùng thực hiện thao tác)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('need_create_firebase_data', true);
        
        // Tải dữ liệu local nếu có
        await loadUserData();
      } else if (userDoc != null) {
        // Dữ liệu đã tồn tại, kiểm tra thời gian cập nhật
        final data = userDoc.data();
        if (data != null && data is Map<String, dynamic>) {
          // Lấy thời gian cập nhật server
          DateTime? serverUpdateTime;
          try {
            if (data.containsKey('updated_at')) {
              final updateTime = data['updated_at'];
              if (updateTime != null) {
                if (updateTime is Timestamp) {
                  serverUpdateTime = updateTime.toDate();
                } else if (updateTime is String) {
                  serverUpdateTime = DateTime.parse(updateTime);
                }
              }
            }
          } catch (e) {
            debugPrint('❌ Lỗi khi phân tích thời gian cập nhật: $e');
          }

          // Lấy thời gian cập nhật local
          final prefs = await SharedPreferences.getInstance();
          DateTime? localUpdateTime;
          final localUpdateStr = prefs.getString('last_local_update');
          
          if (localUpdateStr != null) {
            try {
              localUpdateTime = DateTime.parse(localUpdateStr);
            } catch (e) {
              debugPrint('❌ Lỗi khi phân tích thời gian cập nhật local: $e');
            }
          }

          // So sánh thời gian để quyết định nên tải dữ liệu từ đâu
          if (serverUpdateTime != null && localUpdateTime != null) {
            if (serverUpdateTime.isAfter(localUpdateTime)) {
              // Dữ liệu server mới hơn, tải về máy
              debugPrint('🔄 Dữ liệu Firestore mới hơn local, tải về...');
              await _prepareForFirebaseData();
              await loadFromFirestoreData(data as Map<String, dynamic>);
            } else {
              // Dữ liệu local mới hơn
              debugPrint('🔄 Dữ liệu local mới hơn Firestore: ${localUpdateTime.toIso8601String()} > ${serverUpdateTime.toIso8601String()}');
              // Vẫn giữ dữ liệu local, không đồng bộ tự động
            }
          } else {
            // Nếu không có thông tin thời gian, ưu tiên dữ liệu từ server vì đã biết nó tồn tại
            debugPrint(
                '🔄 Không có đủ thông tin thời gian, ưu tiên dữ liệu Firestore...');
            await _prepareForFirebaseData();
            await loadFromFirestoreData(data as Map<String, dynamic>);
          }

          // Cập nhật dữ liệu cho các provider khác
          await _updateOtherProviders(context, uid);
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi sync/fetch user data: $e');
    }
  }

  // Phương thức riêng để cập nhật các provider khác
  Future<void> _updateOtherProviders(BuildContext context, String uid) async {
    try {
      // Cập nhật FoodProvider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      // TODO: Implement API endpoint to get food data

      // Cập nhật ExerciseProvider
      final exerciseProvider = Provider.of<ExerciseProvider>(
          context, listen: false);
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

          debugPrint(
              'TDEE initialized: $_tdeeCalories calories, Adjusted goal: $adjustedCalories calories');
        } else {
          // If calculation failed, use default values
          _tdeeCalories = _dailyCalories.toDouble();
          _tdeeProtein = _protein;
          _tdeeCarbs = _carbs;
          _tdeeFat = _fat;

          debugPrint(
              'TDEE initialization failed, using defaults: $_tdeeCalories calories');
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
      // Nếu dữ liệu đầu vào không hợp lệ, không thực hiện tính toán
      if (_weightKg <= 0 || _heightCm <= 0 || _age <= 0) {
        debugPrint('⚠️ Dữ liệu đầu vào không hợp lệ cho việc tính TDEE');
        return;
      }

      // Nếu chúng ta đang sử dụng debounce, hãy đợi cho timer hoàn thành
      if (_debounceTimer?.isActive ?? false) {
        debugPrint('⚠️ Đang chờ debounce timer để tính TDEE...');
        return;
      }

      // Tính toán TDEE mới
      final tdeeValues = TDEECalculator.calculateTDEE(
        weight: _weightKg,
        height: _heightCm,
        age: _age,
        gender: _gender,
        activityLevel: _activityLevel,
        goal: _goal,
        pace: _pace,
      );

      // Cập nhật giá trị nếu tính toán thành công
      if (tdeeValues['calories']! > 0) {
        // Cập nhật giá trị TDEE
        _tdeeCalories = tdeeValues['calories']!;
        _tdeeProtein = tdeeValues['protein']!;
        _tdeeCarbs = tdeeValues['carbs']!;
        _tdeeFat = tdeeValues['fat']!;
        _tdeeCalculated = true;

        // Lưu trực tiếp vào SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_tdeeCaloriesKey, _tdeeCalories);
        await prefs.setDouble(_tdeeProteinKey, _tdeeProtein);
        await prefs.setDouble(_tdeeCarbsKey, _tdeeCarbs);
        await prefs.setDouble(_tdeeFatKey, _tdeeFat);
        await prefs.setBool('tdee_calculated', true);

        debugPrint('TDEE recalculated: $_tdeeCalories calories, nutrition goals updated');
      } else {
        debugPrint('⚠️ Tính toán TDEE thất bại, giữ nguyên giá trị hiện tại');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tính lại TDEE: $e');
    }
  }

  // Phương thức cập nhật mục tiêu dinh dưỡng dựa trên TDEE và mục tiêu người dùng
  void forceUpdateNutritionGoalsByTDEE() {
    if (_tdeeCalories <= 0) {
      debugPrint(
          '⚠️ Không thể cập nhật nutrition_goals vì TDEE không hợp lệ: $_tdeeCalories');
      return;
    }

    double adjustedCalories = _tdeeCalories;

    // Tính toán mục tiêu calo dựa vào mục tiêu và pace
    if (_goal == 'Giảm cân') {
      // Sử dụng TDEECalculator để tính mục tiêu giảm cân
      adjustedCalories = TDEECalculator.calculateAdjustedCalories(
        tdee: _tdeeCalories,
        goal: _goal,
        pace: _pace,
      );
      debugPrint(
          '🔄 Cập nhật nutrition_goals[calories] cho GIẢM CÂN: $_tdeeCalories → $adjustedCalories');
    } else if (_goal == 'Tăng cân') {
      // Tăng calo dựa trên pace
      int calorieSurplus = (_pace * 1000).toInt();
      adjustedCalories = (_tdeeCalories ?? 0.0) + calorieSurplus;
      debugPrint(
          '🔄 Cập nhật nutrition_goals[calories] cho TĂNG CÂN: $_tdeeCalories → $adjustedCalories');
    } else {
      // Duy trì cân nặng - giữ nguyên TDEE
      debugPrint(
          '🔄 Cập nhật nutrition_goals[calories] cho DUY TRÌ: $_tdeeCalories');
    }

    // Cập nhật nutrition_goals
    _nutritionGoals['calories'] = adjustedCalories;
    _nutritionGoals['protein'] = _tdeeProtein;
    _nutritionGoals['carbs'] = _tdeeCarbs;
    _nutritionGoals['fat'] = _tdeeFat;

    debugPrint(
        '✅ Đã cập nhật nutrition_goals theo TDEE mới: calories=${_nutritionGoals['calories']}');
  }

  // 🔧 FIX: Method để force reload dữ liệu từ Firebase
  Future<void> forceReloadFromFirebase() async {
    try {
      debugPrint('🔄 Force reload dữ liệu từ Firebase...');

      if (!isUserAuthenticated()) {
        debugPrint('⚠️ User chưa đăng nhập, không thể reload từ Firebase');
        return;
      }

      // Reset cờ để ưu tiên dữ liệu từ Firebase
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('data_loaded_from_firestore', false);

      // Load dữ liệu từ Firebase
      await loadFromFirestore();

      // Đảm bảo TDEE được tính toán đúng
      if (_tdeeCalories <= 0) {
        await _initializeTDEEAsync();
      }

      // Cập nhật nutrition goals
      updateNutritionGoalsByTDEE();

      debugPrint('✅ Đã force reload dữ liệu từ Firebase thành công');
      debugPrint('📊 TDEE: $_tdeeCalories, Nutrition Goals Calories: ${_nutritionGoals['calories']}');

    } catch (e) {
      debugPrint('❌ Lỗi khi force reload từ Firebase: $e');
    }
  }

  // Phương thức lấy mục tiêu calo nhất quán dựa trên TDEE và mục tiêu người dùng
  int getConsistentCalorieGoal() {
    // 🔧 FIX: Log để debug
    debugPrint('🔍 getConsistentCalorieGoal - TDEE: $_tdeeCalories, Goal: $_goal, Nutrition Goals Calories: ${_nutritionGoals['calories']}');

    // Nếu có TDEE, ưu tiên tính toán dựa trên mục tiêu người dùng
    if (_tdeeCalories > 0 && (_tdeeCalories - 2000.0).abs() >= 0.001) {
      // Kiểm tra nếu có nutrition_goals
      if (_nutritionGoals.containsKey('calories') &&
          _nutritionGoals['calories']! > 0) {
        double nutritionGoal = _nutritionGoals['calories']!;

        // Kiểm tra tính nhất quán với mục tiêu
        bool needsUpdate = false;

        if (_goal == 'Giảm cân' && nutritionGoal >= _tdeeCalories) {
          needsUpdate = true;
          debugPrint(
              '⚠️ Phát hiện mâu thuẫn: Mục tiêu ($nutritionGoal) >= TDEE ($_tdeeCalories) khi GIẢM CÂN');
        } else if (_goal == 'Tăng cân' && nutritionGoal <= _tdeeCalories) {
          needsUpdate = true;
          debugPrint(
              '⚠️ Phát hiện mâu thuẫn: Mục tiêu ($nutritionGoal) <= TDEE ($_tdeeCalories) khi TĂNG CÂN');
        }

        if (needsUpdate) {
          // Tự động cập nhật nếu phát hiện mâu thuẫn
          forceUpdateNutritionGoalsByTDEE();
          return _nutritionGoals['calories']!.toInt();
        }

        debugPrint('✅ Mục tiêu calo từ nutritionGoals: ${nutritionGoal
            .toInt()} (nhất quán với $_goal)');
        return nutritionGoal.toInt();
      }

      // Nếu không có nutrition_goals, tính dựa trên TDEE
      double adjustedCalories = _tdeeCalories;

      if (_goal == 'Giảm cân') {
        adjustedCalories = TDEECalculator.calculateAdjustedCalories(
          tdee: _tdeeCalories,
          goal: _goal,
          pace: _pace,
        );
        debugPrint(
            '📊 Tính mục tiêu từ TDEE cho GIẢM CÂN: $_tdeeCalories → $adjustedCalories');
      } else if (_goal == 'Tăng cân') {
        int calorieSurplus = (_pace * 1000).toInt();
        adjustedCalories = (_tdeeCalories ?? 0.0) + calorieSurplus;
        debugPrint(
            '📊 Tính mục tiêu từ TDEE cho TĂNG CÂN: $_tdeeCalories → $adjustedCalories');
      } else {
        debugPrint('📊 Sử dụng TDEE làm mục tiêu cho DUY TRÌ: $_tdeeCalories');
      }

      return adjustedCalories.toInt();
    }

    // Nếu không có giá trị nào khả dụng, sử dụng dailyCalories
    if (_dailyCalories > 0 && _dailyCalories != 2000) {
      debugPrint('📊 Sử dụng dailyCalories: $_dailyCalories');
      return _dailyCalories;
    }

    // Giá trị mặc định cuối cùng
    debugPrint('⚠️ Sử dụng giá trị mặc định: 2000');
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

      // DEBUG: In thông tin đầu vào
      debugPrint('🔍 DEBUG TDEE - Thông tin đầu vào:');
      debugPrint('🔍 gender: $_gender (loại: ${_gender.runtimeType})');
      debugPrint('🔍 age: $_age (loại: ${_age.runtimeType})');
      debugPrint('🔍 heightCm: $_heightCm (loại: ${_heightCm.runtimeType})');
      debugPrint('🔍 weightKg: $_weightKg (loại: ${_weightKg.runtimeType})');
      debugPrint('🔍 activityLevel: $_activityLevel (loại: ${_activityLevel.runtimeType})');
      debugPrint('🔍 goal: $_goal (loại: ${_goal.runtimeType})');
      debugPrint('🔍 pace: $_pace (loại: ${_pace.runtimeType})');

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

      // DEBUG: In kết quả tính toán TDEE
      debugPrint('🔍 DEBUG TDEE - Kết quả tính toán:');
      debugPrint('🔍 tdeeValues: $tdeeValues');

      // Cập nhật giá trị TDEE mới
      await updateTDEEValues(
        calories: tdeeValues['calories']!,
        protein: tdeeValues['protein']!,
        carbs: tdeeValues['carbs']!,
        fat: tdeeValues['fat']!,
      );

      // Cập nhật mục tiêu dinh dưỡng dựa trên TDEE mới tính
      updateNutritionGoalsByTDEE();

      debugPrint('TDEE đã được tính toán lại: $_tdeeCalories calories');
      debugPrint('Mục tiêu dinh dưỡng đã được cập nhật: ${_nutritionGoals['calories']} calories');
      return;
    } catch (e) {
      debugPrint('Error recalculating TDEE: $e');
      // Sử dụng giá trị mặc định nếu có lỗi
      await updateTDEEValues(
        calories: 2000.0,
        protein: 120.0,
        carbs: 200.0,
        fat: 65.0,
      );
      
      // Cập nhật mục tiêu dinh dưỡng ngay cả khi sử dụng giá trị mặc định
      updateNutritionGoalsByTDEE();
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
      debugPrint(
          'TDEE đã có sẵn, không cần tính toán lại: $_tdeeCalories calories');
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

        debugPrint(
            'Mục tiêu cập nhật: $_goal, Tốc độ: $_pace, Calo điều chỉnh: $adjustedCalories');
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

  // Phương thức loadFromFirestore để đọc dữ liệu từ Firebase
  Future<void> loadFromFirestore() async {
    try {
      // Kiểm tra trạng thái đăng nhập trước khi tải dữ liệu từ Firestore
      if (!isUserAuthenticated()) {
        debugPrint(
            '⚠️ Người dùng chưa đăng nhập: Ưu tiên dữ liệu từ local, bỏ qua tải dữ liệu từ Firestore');
        return; // Bỏ qua việc tải dữ liệu từ Firestore nếu chưa đăng nhập
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint(
            '🔄 Đang đọc dữ liệu người dùng từ Firebase với ID: ${user.uid}');

        try {
          final firestore = FirebaseFirestore.instance;
          final docSnapshot = await firestore
              .collection('users')
              .doc(user.uid)
              .get();

          if (docSnapshot.exists && docSnapshot.data() != null) {
            debugPrint('✅ Đã đọc dữ liệu người dùng trực tiếp từ Firestore');

            // Đặt cờ để đánh dấu đã sử dụng dữ liệu từ Firebase
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('loaded_from_firebase', true);

            // Xóa dữ liệu cục bộ cũ trước khi tải dữ liệu mới từ Firebase
            // Nhưng không xóa hoàn toàn, chỉ xóa các dữ liệu sẽ được cập nhật từ Firebase
            await _prepareForFirebaseData();

            // Sử dụng phương thức mới để xử lý dữ liệu từ Firestore
            await loadFromFirestoreData(docSnapshot.data()!);
            debugPrint('✅ Đã tải và cập nhật dữ liệu từ Firebase thành công');
          } else {
            debugPrint('⚠️ Không tìm thấy dữ liệu người dùng trong Firestore');
            
            // QUAN TRỌNG: KHÔNG tự động đồng bộ dữ liệu local lên khi không tìm thấy dữ liệu
            // Thay vào đó, ghi log thông báo người dùng mới
            debugPrint('ℹ️ Có vẻ đây là người dùng mới hoặc chưa có dữ liệu trên Firestore');
            // await syncToFirebase(); // Đã bỏ dòng này
            // debugPrint('✅ Đã đồng bộ dữ liệu cục bộ lên Firestore'); // Đã bỏ dòng này
          }
        } catch (e) {
          debugPrint('❌ Lỗi khi đọc dữ liệu từ Firestore: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu từ Firestore: $e');
    }
  }

  // Phương thức để chuẩn bị cho việc tải dữ liệu từ Firebase
  Future<void> _prepareForFirebaseData() async {
    // Xóa các giá trị cụ thể mà sẽ được tải từ Firebase thay vì xóa tất cả
    debugPrint('🔄 Đang chuẩn bị cho việc tải dữ liệu từ Firebase...');
    // Giữ lại các cài đặt hệ thống và cờ
    final prefs = await SharedPreferences.getInstance();
    final useFirebaseData = prefs.getBool('use_firebase_data') ?? true;
    final syncEnabled = prefs.getBool(_syncEnabledKey) ?? true;

    // Xóa các dữ liệu người dùng
    await prefs.remove(_nameKey);
    await prefs.remove(_genderKey);
    await prefs.remove(_ageKey);
    await prefs.remove(_heightKey);
    await prefs.remove(_weightKey);
    await prefs.remove(_activityLevelKey);
    await prefs.remove(_goalKey);
    await prefs.remove(_paceKey);
    await prefs.remove(_nutritionGoalsKey);
    await prefs.remove(_tdeeCaloriesKey);
    await prefs.remove(_tdeeProteinKey);
    await prefs.remove(_tdeeCarbsKey);
    await prefs.remove(_tdeeFatKey);
    await prefs.remove(_targetWeightKey);
    await prefs.remove(_eventKey);
    await prefs.remove(_eventDateKey);
    await prefs.remove(_dietRestrictionKey);
    await prefs.remove(_dietPreferenceKey);
    await prefs.remove(_healthConditionsKey);

    // Lưu lại các cài đặt 
    await prefs.setBool('use_firebase_data', useFirebaseData);
    await prefs.setBool(_syncEnabledKey, syncEnabled);
  }

  // Phương thức mới để xử lý dữ liệu trực tiếp từ Firestore snapshot
  Future<void> loadFromFirestoreData(Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 Đang xử lý dữ liệu từ Firestore snapshot...');
      
      // Lưu dữ liệu gốc vào local storage để debug
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_firestore_data', jsonEncode(data));
      
      // Trước khi tải dữ liệu mới, lưu các giá trị cũ để so sánh
      double oldTdee = _tdeeCalories;
      
      // Chuẩn hóa dữ liệu trước khi xử lý - ưu tiên các trường snake_case
      Map<String, dynamic> standardData = {};
      
      // Sử dụng hàm _getFieldMappings để đảm bảo nhất quán
      final fieldMappings = _getFieldMappings();
      
      // Xử lý từng trường dữ liệu, ưu tiên snake_case
      fieldMappings.forEach((camelCase, snakeCase) {
        if (data.containsKey(snakeCase)) {
          standardData[snakeCase] = data[snakeCase];
        } else if (data.containsKey(camelCase)) {
          standardData[snakeCase] = data[camelCase];
        }
      });
      
      // Thêm các trường khác không trong danh sách mapping
      data.forEach((key, value) {
        if (!fieldMappings.containsKey(key) && !fieldMappings.values.contains(key) && !standardData.containsKey(key)) {
          standardData[key] = value;
        }
      });
      
      // Log để debug
      debugPrint('📋 Dữ liệu đã chuẩn hóa: ${standardData.keys.join(", ")}');
      
      // Bắt đầu cập nhật dữ liệu người dùng từ dữ liệu chuẩn hóa
      debugPrint('🔄 Cập nhật dữ liệu người dùng từ Firestore...');
      
      // Thông tin cơ bản
      _name = standardData['name'] ?? _name;
      _email = standardData['email'] ?? _email;
      _gender = standardData['gender'] ?? _gender;
      _age = _safeParseInt(standardData['age'], _age);
      _heightCm = _safeParseDouble(standardData['height_cm'], _heightCm);
      _weightKg = _safeParseDouble(standardData['weight_kg'], _weightKg);
      _activityLevel = standardData['activity_level'] ?? _activityLevel;
      _goal = standardData['goal'] ?? _goal;
      _pace = _safeParseDouble(standardData['pace'], _pace);
      _targetWeightKg = _safeParseDouble(standardData['target_weight_kg'], _targetWeightKg);
      
      // Xử lý sự kiện
      _event = standardData['event'] ?? _event;
      
      // Xử lý ngày sự kiện
      _eventDay = _safeParseInt(standardData['event_day'], _eventDay);
      _eventMonth = _safeParseInt(standardData['event_month'], _eventMonth);
      _eventYear = _safeParseInt(standardData['event_year'], _eventYear);
      
      // Xử lý các danh sách chế độ ăn và sức khỏe
      if (standardData.containsKey('diet_restrictions') && standardData['diet_restrictions'] != null) {
        if (standardData['diet_restrictions'] is List) {
          _dietRestrictions = List<String>.from(standardData['diet_restrictions']);
          debugPrint('📋 Đã tải diet_restrictions từ Firestore: $_dietRestrictions');
        } else if (standardData['diet_restrictions'] is String) {
          _dietRestrictions = [standardData['diet_restrictions'].toString()];
          debugPrint('📋 Đã tải diet_restrictions (string) từ Firestore: $_dietRestrictions');
        }
      }
      
      if (standardData.containsKey('health_conditions') && standardData['health_conditions'] != null) {
        if (standardData['health_conditions'] is List) {
          _healthConditions = List<String>.from(standardData['health_conditions']);
          debugPrint('📋 Đã tải health_conditions từ Firestore: $_healthConditions');
        } else if (standardData['health_conditions'] is String) {
          _healthConditions = [standardData['health_conditions'].toString()];
          debugPrint('📋 Đã tải health_conditions (string) từ Firestore: $_healthConditions');
        }
      }
      
      // Xử lý diet_preference
      if (standardData.containsKey('diet_preference') && standardData['diet_preference'] != null) {
        _dietPreference = standardData['diet_preference'].toString();
        debugPrint('📋 Đã tải diet_preference từ Firestore: $_dietPreference');
      } else {
        debugPrint('⚠️ Không tìm thấy diet_preference trong dữ liệu Firestore, giữ nguyên giá trị hiện tại: $_dietPreference');
      }
      
      // QUAN TRỌNG: Xử lý TDEE từ Firestore
      double firebaseTdee = _safeParseDouble(standardData['tdee_calories'], 0);
      
      // Debug thông tin TDEE
      debugPrint('📊 TDEE từ Firestore: $firebaseTdee, TDEE hiện tại: $_tdeeCalories');
      
      // Chỉ cập nhật TDEE từ Firestore nếu có giá trị hợp lệ (>0)
      if (firebaseTdee > 0) {
        debugPrint('✅ Tìm thấy TDEE hợp lệ từ Firestore: $firebaseTdee');
        
        // Cập nhật TDEE từ Firestore
        _tdeeCalories = firebaseTdee;
        _tdeeProtein = _safeParseDouble(standardData['tdee_protein'], 0.0);
        _tdeeCarbs = _safeParseDouble(standardData['tdee_carbs'], 0.0);
        _tdeeFat = _safeParseDouble(standardData['tdee_fat'], 0.0);
        
        // Đảm bảo rằng các giá trị macro không bằng 0
        if (_tdeeProtein <= 0) _tdeeProtein = _weightKg * 2.0; // 2g protein per kg body weight
        if (_tdeeCarbs <= 0) _tdeeCarbs = _tdeeCalories * 0.5 / 4; // 50% calories from carbs
        if (_tdeeFat <= 0) _tdeeFat = _tdeeCalories * 0.25 / 9; // 25% calories from fat
        
        debugPrint('📊 TDEE đã cập nhật: Cal=$_tdeeCalories, P=$_tdeeProtein, C=$_tdeeCarbs, F=$_tdeeFat');
      } else {
        debugPrint('⚠️ Không tìm thấy TDEE hợp lệ từ Firestore, giữ nguyên giá trị hiện tại: $_tdeeCalories');
        
        // Nếu TDEE hiện tại cũng không hợp lệ, tính toán mới
        if (_tdeeCalories <= 0 || (_tdeeCalories - 2000.0).abs() < 0.1) {
          debugPrint('⚠️ TDEE hiện tại không hợp lệ ($_tdeeCalories), cần tính toán lại');
          // Đánh dấu để tính toán lại TDEE sau khi tải xong
          await prefs.setBool('need_recalculate_tdee', true);
        }
      }
      
      // Xử lý nutrition_goals
      if (standardData.containsKey('nutrition_goals') && standardData['nutrition_goals'] != null) {
        if (standardData['nutrition_goals'] is Map) {
          // Tạo một bản sao của nutrition_goals hiện tại
          Map<String, double> currentGoals = Map<String, double>.from(_nutritionGoals);
          
          Map<String, dynamic> goalsJson = Map<String, dynamic>.from(standardData['nutrition_goals']);
          
          // Ghi đè các giá trị từ Firestore lên bản sao
          goalsJson.forEach((key, value) {
            if (value != null) {
              currentGoals[key] = _safeParseDouble(value, currentGoals[key] ?? 0.0);
            }
          });
          
          // Kiểm tra tính hợp lệ của mục tiêu calories
          double caloriesGoal = currentGoals['calories'] ?? 0.0;
          if (caloriesGoal > 0) {
            // Nếu mục tiêu là giảm cân, đảm bảo calories < tdee
            if (_goal == 'Giảm cân' && caloriesGoal >= _tdeeCalories && _tdeeCalories > 0) {
              debugPrint('⚠️ Phát hiện mục tiêu calo không hợp lệ cho giảm cân: $caloriesGoal >= $_tdeeCalories');
              // Điều chỉnh lại theo công thức giảm cân
              currentGoals['calories'] = _tdeeCalories - (500 * _pace);
              debugPrint('🔧 Đã điều chỉnh mục tiêu calo: ${currentGoals['calories']}');
            }
          } else if (_tdeeCalories > 0) {
            // Nếu không có mục tiêu calories hợp lệ nhưng có TDEE, tính toán mục tiêu dựa trên TDEE
            debugPrint('⚠️ Không tìm thấy mục tiêu calo hợp lệ, tính toán dựa trên TDEE');
            currentGoals['calories'] = _adjustCaloriesByGoalAndTDEE(_tdeeCalories, _goal, _pace);
            debugPrint('🔧 Đã tính toán mục tiêu calo: ${currentGoals['calories']}');
          }
          
          // Cập nhật _nutritionGoals với các giá trị đã kiểm tra
          _nutritionGoals = currentGoals;
          
          // Log giá trị nutrition goals để debug
          debugPrint('📊 Nutrition goals: Cal=${currentGoals['calories']}, P=${currentGoals['protein']}, C=${currentGoals['carbs']}, F=${currentGoals['fat']}');
        }
      } else if (_tdeeCalories > 0) {
        // Nếu không có nutrition_goals từ Firestore nhưng có TDEE, tạo mục tiêu mới
        debugPrint('⚠️ Không tìm thấy nutrition_goals từ Firestore, tạo mới dựa trên TDEE');
        _nutritionGoals = {
          'calories': _adjustCaloriesByGoalAndTDEE(_tdeeCalories, _goal, _pace),
          'protein': _tdeeProtein,
          'carbs': _tdeeCarbs,
          'fat': _tdeeFat
        };
      }
      
      // Xử lý cài đặt đồng bộ
      _syncEnabled = standardData['sync_enabled'] ?? true;
      
      // Xử lý thời gian đồng bộ
      if (standardData.containsKey('last_sync_time') && standardData['last_sync_time'] != null) {
        var lastSyncValue = standardData['last_sync_time'];
        if (lastSyncValue is int) {
          _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncValue);
        } else if (lastSyncValue is String) {
          try {
            _lastSyncTime = DateTime.parse(lastSyncValue);
          } catch (e) {
            // Ignore parse error
          }
        }
      }
      
      // Xử lý cài đặt thêm calo từ bài tập
      _addExerciseCaloriesToGoal = standardData['add_exercise_calories_to_goal'] ?? true;
      
      // So sánh TDEE trước và sau khi tải để xem có thay đổi không
      if ((oldTdee - _tdeeCalories).abs() > 10) {
        debugPrint('ℹ️ TDEE đã thay đổi sau khi tải: $oldTdee -> $_tdeeCalories');
        // Chỉ cập nhật nutrition goals nếu TDEE thay đổi đáng kể
        updateNutritionGoalsByTDEE();
      }
      
      // Đánh dấu dữ liệu đã được tải từ Firestore
      await prefs.setBool('data_loaded_from_firestore', true);
      
      // Lưu dữ liệu đã tải vào SharedPreferences
      await saveUserData();
      
      // Nếu cần tính toán lại TDEE (đã đánh dấu ở trên)
      if (prefs.getBool('need_recalculate_tdee') == true) {
        debugPrint('🔄 Tính toán lại TDEE sau khi tải dữ liệu');
        await _initializeTDEEAsync();
        await prefs.setBool('need_recalculate_tdee', false);
      }
      
      // Thông báo các widget
      notifyListeners();
      
      debugPrint('✅ Đã tải và xử lý dữ liệu từ Firestore thành công');
    } catch (e) {
      debugPrint('❌ Lỗi khi xử lý dữ liệu từ Firestore: $e');
      // Đảm bảo không bị treo khi có lỗi
      notifyListeners();
    }
  }
  
  // Hàm hỗ trợ điều chỉnh calories dựa trên mục tiêu và TDEE
  double _adjustCaloriesByGoalAndTDEE(double tdee, String goal, double pace) {
    if (goal == 'Giảm cân') {
      // Giảm cân: giảm 500-1000 calo tùy theo pace
      double deficit = 500 * pace;
      if (deficit < 300) deficit = 300;
      if (deficit > 1000) deficit = 1000;
      
      double result = tdee - deficit;
      // Đảm bảo không thấp hơn mức tối thiểu
      if (result < 1200) result = 1200;
      return result;
    } else if (goal == 'Tăng cân') {
      // Tăng cân: tăng 500-1000 calo tùy theo pace
      double surplus = 500 * pace;
      if (surplus < 300) surplus = 300;
      if (surplus > 1000) surplus = 1000;
      return tdee + surplus;
    } else {
      // Duy trì cân nặng: giữ nguyên TDEE
      return tdee;
    }
  }

  // Phương thức để tải dữ liệu trực tiếp từ Firestore snapshot data


  // Phương thức hỗ trợ để xử lý số nguyên an toàn
  int _safeParseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  // Phương thức hỗ trợ để xử lý số thập phân an toàn
  double _safeParseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  // Phương thức hỗ trợ để xử lý số nguyên an toàn


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
          logUserData('❌ Lỗi khi xử lý trường danh sách $field: $e');
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
      _age = (_safeParseDouble(safeData['age'], _age.toDouble())).toInt();
      _heightCm = _safeParseDouble(safeData['height_cm'], _heightCm);

      // Kiểm tra sự thay đổi cân nặng để quyết định có cập nhật TDEE hay không
      double newWeight = _safeParseDouble(safeData['weight_kg'], _weightKg);
      bool needsRecalculation = false;

      if ((_weightKg - newWeight).abs() > 1.0) {
        // Nếu cân nặng thay đổi hơn 1kg, đánh dấu cần tính lại TDEE
        needsRecalculation = true;
      }
      _weightKg = newWeight;

      // Cập nhật các thông số khác
      _activityLevel = safeData['activity_level'] ?? _activityLevel;
      _goal = safeData['goal'] ?? _goal;
      _pace = _safeParseDouble(safeData['pace'], _pace);
      _targetWeightKg =
          _safeParseDouble(safeData['target_weight_kg'], _targetWeightKg);

      // Xử lý các trường TDEE
      if (safeData.containsKey('tdee') && safeData['tdee'] is Map) {
        Map<String, dynamic> tdeeMap = Map<String, dynamic>.from(
            safeData['tdee']);
        if (tdeeMap.containsKey('calories')) {
          _tdeeCalories = _safeParseDouble(tdeeMap['calories'], _tdeeCalories);
        }
        if (tdeeMap.containsKey('protein')) {
          _tdeeProtein = _safeParseDouble(tdeeMap['protein'], _tdeeProtein);
        }
        if (tdeeMap.containsKey('carbs')) {
          _tdeeCarbs = _safeParseDouble(tdeeMap['carbs'], _tdeeCarbs);
        }
        if (tdeeMap.containsKey('fat')) {
          _tdeeFat = _safeParseDouble(tdeeMap['fat'], _tdeeFat);
        }

        // Cập nhật mục tiêu dinh dưỡng dựa trên TDEE
        if (_nutritionGoals.isEmpty) {
          _nutritionGoals = {
            'calories': _tdeeCalories,
            'protein': _tdeeProtein,
            'carbs': _tdeeCarbs,
            'fat': _tdeeFat
          };
        } else {
          _nutritionGoals['calories'] = _tdeeCalories;
          _nutritionGoals['protein'] = _tdeeProtein;
          _nutritionGoals['carbs'] = _tdeeCarbs;
          _nutritionGoals['fat'] = _tdeeFat;
        }
      }

      // Lưu dữ liệu vào SharedPreferences
      saveUserData();

      logUserData('✅ Đã cập nhật dữ liệu người dùng từ JSON');
    } catch (e) {
      logUserData('❌ Lỗi khi cập nhật dữ liệu từ JSON: $e');
    }
  }

  // Phương thức để phân tích cú pháp số an toàn


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
    if (_age <= 0 || _age > 120) {
      debugPrint('⚠️ Tuổi không hợp lệ ($_age), đặt giá trị mặc định 30');
      _age = 30;
    }

    // Đảm bảo giới tính có giá trị hợp lệ
    if (_gender.isEmpty || (_gender != 'Nam' && _gender != 'Nữ')) {
      debugPrint('⚠️ Giới tính không hợp lệ ($_gender), đặt giá trị mặc định "Nam"');
      _gender = 'Nam';
    }

    // Đảm bảo chiều cao có giá trị hợp lệ
    if (_heightCm <= 0 || _heightCm > 250) {
      debugPrint('⚠️ Chiều cao không hợp lệ ($_heightCm), đặt giá trị mặc định 170');
      _heightCm = 170;
    }

    // Đảm bảo cân nặng có giá trị hợp lệ
    if (_weightKg <= 0 || _weightKg > 300) {
      debugPrint('⚠️ Cân nặng không hợp lệ ($_weightKg), đặt giá trị mặc định 60');
      _weightKg = 60;
    }

    // Đảm bảo mục tiêu cân nặng có giá trị hợp lệ
    if (_targetWeightKg <= 0 || _targetWeightKg > 300) {
      debugPrint('⚠️ Mục tiêu cân nặng không hợp lệ ($_targetWeightKg), đặt bằng cân nặng hiện tại');
      _targetWeightKg = _weightKg;
    }

    // Đảm bảo mức độ hoạt động có giá trị hợp lệ
    if (_activityLevel.isEmpty) {
      debugPrint('⚠️ Mức độ hoạt động trống, đặt giá trị mặc định "Ít vận động"');
      _activityLevel = 'Ít vận động';
    }

    // Đảm bảo mục tiêu có giá trị hợp lệ
    if (_goal.isEmpty) {
      debugPrint('⚠️ Mục tiêu trống, đặt giá trị mặc định "Duy trì cân nặng"');
      _goal = 'Duy trì cân nặng';
    }

    // Đảm bảo tốc độ thay đổi cân nặng có giá trị hợp lệ
    if (_pace < 0.1 || _pace > 2.0) {
      debugPrint('⚠️ Tốc độ thay đổi cân nặng không hợp lệ ($_pace), đặt giá trị mặc định 0.5');
      _pace = 0.5;
    }
    
    // Đảm bảo TDEE có giá trị hợp lệ
    if (_tdeeCalories <= 0) {
      debugPrint('⚠️ TDEE không hợp lệ ($_tdeeCalories), sẽ được tính lại');
    }
  }

  // Khi người dùng đăng nhập, gọi phương thức này
  Future<void> onUserLogin(BuildContext context) async {
    // 🔧 FIX: Đặt cờ để ưu tiên dữ liệu Firebase và xóa dữ liệu local cũ
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_firebase_data', true);
    await prefs.setBool('data_loaded_from_firestore', false); // Reset để force reload từ Firebase

    debugPrint('🔄 onUserLogin: Bắt đầu quá trình đăng nhập và tải dữ liệu từ Firebase');

    if (_isFirebaseAvailable && FirebaseAuth.instance.currentUser != null) {
      debugPrint(
          '🔄 onUserLogin: Người dùng đã đăng nhập, FORCE tải dữ liệu từ Firestore');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Kiểm tra xem dữ liệu đã tồn tại trên Firestore chưa
          final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          final docSnapshot = await docRef.get();
          
          if (docSnapshot.exists) {
            // 🔧 FIX: Dữ liệu đã tồn tại, FORCE tải về và ghi đè dữ liệu local
            debugPrint('✅ onUserLogin: Dữ liệu đã tồn tại trên Firestore, FORCE tải về và ghi đè local');

            // Xóa dữ liệu local cũ trước để tránh xung đột
            await _prepareForFirebaseData();
            debugPrint('✅ onUserLogin: Đã xóa dữ liệu local cũ');

            // FORCE tải dữ liệu từ Firestore
            await forceReloadFromFirebase();
            debugPrint('✅ onUserLogin: Đã FORCE reload từ Firebase thành công');
          } else {
            // Dữ liệu chưa tồn tại, đánh dấu cần tạo mới (nhưng chưa tạo ngay)
            debugPrint('⚠️ onUserLogin: Dữ liệu chưa tồn tại trên Firestore, đánh dấu cần tạo mới');
            await prefs.setBool('need_create_firebase_data', true);
            
            // Tải dữ liệu local hiện có (nếu có)
            await loadUserData();
          }
          
          // Bắt đầu đồng bộ định kỳ nếu được bật
          if (_syncEnabled) {
            startPeriodicSync();
          }
          
          // Tự động dọn dẹp dữ liệu trùng lặp sau khi đăng nhập
          try {
            final result = await cleanupDuplicateData(silent: true);
            if (result['success'] == true && result['deleted'] != null &&
                result['deleted'] > 0) {
              debugPrint(
                  '🧹 onUserLogin: Đã tự động xóa ${result['deleted']} bản ghi trùng lặp');
            }
          } catch (e) {
            debugPrint('⚠️ onUserLogin: Lỗi khi dọn dẹp dữ liệu trùng lặp: $e');
          }
        } catch (e) {
          debugPrint('❌ onUserLogin: Lỗi khi kiểm tra/tải dữ liệu Firestore: $e');
          
          // Nếu có lỗi, sử dụng dữ liệu local
          await loadUserData();
        }
      }
    } else {
      debugPrint(
          '⚠️ onUserLogin: Người dùng chưa đăng nhập hoặc Firebase chưa sẵn sàng');
    }
  }

  // Trả về toàn bộ thông tin user dưới dạng Map<String, dynamic> để đồng bộ
  Map<String, dynamic> toJson() {
    // Đảm bảo các map/collection không null trước khi chuyển đổi
    _nutritionGoals ??= {};

    // Khởi tạo các danh sách nếu chưa có
    List<String> dietRestrictions = _dietRestrictions ?? [];
    List<String> healthConditions = _healthConditions ?? [];
    String dietPreference = _dietPreference ?? '';

    // Trả về map đã được kiểm tra an toàn
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
      'event': _event ?? '',
      'eventDay': _eventDay ?? 0,
      'eventMonth': _eventMonth ?? 0,
      'eventYear': _eventYear ?? 0,
      'dietRestrictions': dietRestrictions,
      'dietPreference': dietPreference,
      'healthConditions': healthConditions,
      'nutritionGoals': Map<String, dynamic>.from(_nutritionGoals),
      'dailyCalories': _dailyCalories ?? 0,
      'protein': _protein ?? 0.0,
      'carbs': _carbs ?? 0.0,
      'fat': _fat ?? 0.0,
      'tdeeCalories': _tdeeCalories,
      'tdeeProtein': _tdeeProtein,
      'tdeeCarbs': _tdeeCarbs,
      'tdeeFat': _tdeeFat,
      'syncEnabled': _syncEnabled ?? false,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'preferences': _preferences ?? [],
      'allergies': _allergies ?? [],
      'cuisineStyle': _cuisineStyle ?? '',
      'email': _email ?? '',
      'weightGoal': _weightGoal ?? 'Duy trì',
      'addExerciseCaloriesToGoal': _addExerciseCaloriesToGoal ?? false,
    };
  }

  // Hàm đồng bộ toàn bộ dữ liệu local lên Firestore
  Future<void> syncAllDataToServer(BuildContext context) async {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final exerciseProvider = Provider.of<ExerciseProvider>(
        context, listen: false);
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);

    final foodData = foodProvider.getAllEntriesAsJson();
    final exerciseData = exerciseProvider.getAllExercisesAsJson();
    final waterData = waterProvider.getAllWaterLogsAsJson();

    try {
      // Lấy user ID từ Firebase nếu có
      String? userId = getCurrentUserId();

      if (userId == null) {
        debugPrint('❌ Không thể đồng bộ dữ liệu: Không có ID người dùng');
        return;
      }

      // Sử dụng phương thức đồng bộ tập trung cho dữ liệu người dùng
      bool userDataSynced = await syncUserDataCentralized(forceSync: true);
      if (!userDataSynced) {
        debugPrint('⚠️ Không thể đồng bộ dữ liệu người dùng');
      }

      // Đồng bộ dữ liệu bữa ăn
      try {
        final mealsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('meals');

        // Thêm từng bữa ăn vào Firestore với kiểm tra trùng lặp
        for (var meal in foodData) {
          String mealId = meal['id'] ?? DateTime
              .now()
              .millisecondsSinceEpoch
              .toString();
          await mealsRef.doc(mealId).set(meal, SetOptions(merge: true));
        }

        debugPrint('✅ Đồng bộ dữ liệu bữa ăn lên Firestore thành công!');
      } catch (e) {
        debugPrint('❌ Lỗi khi đồng bộ dữ liệu bữa ăn: $e');
      }

      // Đồng bộ dữ liệu bài tập
      try {
        final exercisesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('exercises');

        // Thêm từng bài tập vào Firestore với kiểm tra trùng lặp
        for (var exercise in exerciseData) {
          String exerciseId = exercise['id'] ?? DateTime
              .now()
              .millisecondsSinceEpoch
              .toString();
          await exercisesRef.doc(exerciseId).set(
              exercise, SetOptions(merge: true));
        }

        debugPrint('✅ Đồng bộ dữ liệu bài tập lên Firestore thành công!');
      } catch (e) {
        debugPrint('❌ Lỗi khi đồng bộ dữ liệu bài tập: $e');
      }

      // Đồng bộ dữ liệu nước uống
      try {
        final waterRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('water_logs');

        // Thêm từng log nước uống vào Firestore với kiểm tra trùng lặp
        for (var waterLog in waterData) {
          String logId = waterLog['id'] ?? DateTime
              .now()
              .millisecondsSinceEpoch
              .toString();
          await waterRef.doc(logId).set(waterLog, SetOptions(merge: true));
        }

        debugPrint('✅ Đồng bộ dữ liệu nước uống lên Firestore thành công!');
      } catch (e) {
        debugPrint('❌ Lỗi khi đồng bộ dữ liệu nước uống: $e');
      }

      // Cập nhật thời gian đồng bộ
      _lastSyncTime = DateTime.now();
      await saveUserData();

      debugPrint('✅ Đã đồng bộ toàn bộ dữ liệu lên Firestore thành công!');
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ dữ liệu: $e');
    }
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

  // Xóa dữ liệu người dùng local khi đăng xuất
  Future<void> clearLocalUserData() async {
    try {
      debugPrint('🔄 Đang xóa dữ liệu local của người dùng...');

      // Xóa cụ thể từng key trong SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Tạo danh sách tất cả các keys cần xóa
      final keysToRemove = [
        _nameKey, _genderKey, _ageKey, _heightKey, _weightKey, 
        _activityLevelKey, _goalKey, _paceKey, _nutritionGoalsKey,
        _tdeeCaloriesKey, _tdeeProteinKey, _tdeeCarbsKey, _tdeeFatKey,
        _targetWeightKey, _eventKey, _eventDateKey, _dietRestrictionKey,
        _dietPreferenceKey, _healthConditionsKey, _syncEnabledKey, _lastSyncTimeKey,
        'daily_calories', 'protein', 'carbs', 'fat', 
        'preferences', 'allergies', 'cuisineStyle', 'email',
        'lastSyncTime', 'tdeeCalories', 'loadedFromFirebase',
        'user_data', 'user_profile', 'water_entries', 'exercise_entries', 
        'food_entries', 'weight_entries', 'data_changed', 'last_local_update',
        'use_local_data', 'user_profile_completed', 'last_firebase_update'
      ];
      
      // Xóa từng key
      for (String key in keysToRemove) {
        await prefs.remove(key);
      }
      
      // Xóa dữ liệu người dùng hoàn toàn
      await prefs.clear(); // Xóa tất cả dữ liệu để đảm bảo không còn dữ liệu nào của người dùng cũ
      
      // Reset các biến trong provider
      _userId = '';
      _email = '';
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
      _preferences = [];
      _allergies = [];
      _dietPreferences = [];
      _cuisineStyle = null;

      // 🔧 FIX: Đảm bảo lần sau khi đăng nhập sẽ ưu tiên dữ liệu từ Firebase
      await prefs.setBool('use_firebase_data', false); // Reset về false để _initializeWithPriority() quyết định
      await prefs.setBool('data_loaded_from_firestore', false); // Reset để force reload từ Firebase

      // Đặt cờ để đảm bảo dữ liệu đã được xóa
      await prefs.setBool('data_cleared', true);
      
      // Hủy timer đồng bộ nếu đang chạy
      _syncTimer?.cancel();
      _syncTimer = null;
      _debounceTimer?.cancel();

      // Reset sync status
      _lastSyncTime = null;
      _syncEnabled = true;

      debugPrint('✅ Đã xóa dữ liệu local của người dùng thành công');
      
      // Thông báo UI cập nhật
      notifyListeners();
      
      return;
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa dữ liệu local: $e');
      throw Exception('Không thể xóa dữ liệu local: $e');
    }
  }

  // Kiểm tra và hiển thị dữ liệu từ Firestore cho mục đích debug
  Future<void> debugFirestoreData() async {
    try {
      if (!_isFirebaseAvailable) {
        debugPrint('❌ Firebase không khả dụng');
        throw Exception('Firebase không khả dụng');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ Người dùng chưa đăng nhập');
        throw Exception('Người dùng chưa đăng nhập');
      }

      // Lấy dữ liệu từ Firestore
      final docRef = FirebaseFirestore.instance.collection('users').doc(
          user.uid);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        debugPrint('❌ Không tìm thấy dữ liệu người dùng trên Firestore');
        throw Exception('Không tìm thấy dữ liệu người dùng');
      }

      // In dữ liệu để debug
      final data = docSnapshot.data() ?? {};
      debugPrint('=== FIRESTORE DATA DEBUG ===');
      data.forEach((key, value) {
        debugPrint('$key: $value');
      });
      debugPrint('==========================');

      return;
    } catch (e) {
      debugPrint('❌ Lỗi khi debug dữ liệu Firestore: $e');
      throw Exception('Lỗi khi debug dữ liệu: $e');
    }
  }

  // Chuẩn hóa dữ liệu trên Firestore
  Future<bool> normalizeFirestoreData() async {
    try {
      if (!_isFirebaseAvailable) {
        debugPrint('❌ Firebase không khả dụng');
        return false;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ Người dùng chưa đăng nhập');
        return false;
      }

      // Lấy dữ liệu hiện tại từ Firestore
      final docRef = FirebaseFirestore.instance.collection('users').doc(
          user.uid);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        debugPrint('❌ Không tìm thấy dữ liệu người dùng trên Firestore');
        return false;
      }

      // Lấy dữ liệu hiện tại
      final currentData = docSnapshot.data() ?? {};

      // Tạo dữ liệu chuẩn hóa từ provider
      final normalizedData = toJson();

      // Cập nhật dữ liệu lên Firestore
      await docRef.set(normalizedData, SetOptions(merge: true));

      debugPrint('✅ Đã chuẩn hóa dữ liệu Firestore thành công');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi chuẩn hóa dữ liệu Firestore: $e');
      return false;
    }
  }

  // CƠ CHẾ ĐỒNG BỘ TẬP TRUNG MỚI
  // Phương thức đồng bộ tập trung duy nhất để tránh trùng lặp dữ liệu
  Future<bool> syncUserDataCentralized({bool forceSync = false}) async {
    if (!isFirebaseAvailable() || !isUserAuthenticated()) {
      debugPrint('⚠️ Không thể đồng bộ: Firebase không khả dụng hoặc chưa đăng nhập');
        return false;
      }

    try {
      // Đồng bộ dữ liệu từ local lên Firestore
      await _syncUserDataToFirebase();
      
      // Đánh dấu thời gian đồng bộ
      _lastSyncTime = DateTime.now();
      
      // Lưu thông tin đồng bộ
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ tập trung: $e');
        return false;
    }
  }
  
  // Kiểm tra xem hai mục tiêu dinh dưỡng có tương tự nhau không
  bool _areNutritionGoalsSimilar(dynamic goals1, dynamic goals2) {
    try {
      if (goals1 is! Map || goals2 is! Map) return false;
      
      Map<String, dynamic> map1 = Map<String, dynamic>.from(goals1);
      Map<String, dynamic> map2 = Map<String, dynamic>.from(goals2);
      
      // Kiểm tra các giá trị quan trọng
      for (var key in ['calories', 'protein', 'carbs', 'fat']) {
        if (!map1.containsKey(key) || !map2.containsKey(key)) continue;
        
        double val1 = _safeParseDouble(map1[key], 0);
        double val2 = _safeParseDouble(map2[key], 0);
        
        // Nếu khác biệt quá 5%, coi là khác nhau
        if (val1 > 0 && ((val1 - val2).abs() / val1) > 0.05) {
          return false;
        }
      }
      
        return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi so sánh mục tiêu dinh dưỡng: $e');
      return false;
    }
  }

  // PHƯƠNG THỨC MỚI: Dọn dẹp dữ liệu trùng lặp
  Future<Map<String, dynamic>> cleanupDuplicateData({bool silent = false}) async {
    if (!_isFirebaseAvailable) {
      if (!silent) debugPrint('⚠️ Firebase không khả dụng, không thể dọn dẹp dữ liệu');
      return {'success': false, 'message': 'Firebase không khả dụng'};
    }

    try {
      if (!silent) debugPrint('🔄 Đang kiểm tra dữ liệu người dùng trùng lặp...');

      final firestore = FirebaseFirestore.instance;
      final usersCollection = await firestore.collection('users').get();

      if (!silent) debugPrint('Tìm thấy ${usersCollection.docs.length} người dùng trong Firestore');

      // Nhóm các tài liệu theo userID và email
      Map<String, List<DocumentSnapshot>> userIdMap = {};
      Map<String, List<DocumentSnapshot>> emailMap = {};
      List<DocumentSnapshot> duplicateDocs = [];

      // Bước 1: Tổ chức dữ liệu theo userID và email
      for (var doc in usersCollection.docs) {
        final data = doc.data();
        final userId = doc.id;
        final userIdField = data['user_id']?.toString() ?? '';
        final email = data['email']?.toString() ?? '';

        // Lưu vào map theo ID
        userIdMap.putIfAbsent(userId, () => []).add(doc);

        // Nếu có trường user_id riêng (khác với doc.id), lưu thêm vào map theo user_id
        if (userIdField.isNotEmpty && userIdField != userId) {
          userIdMap.putIfAbsent(userIdField, () => []).add(doc);
        }

        // Nếu có email, lưu vào map theo email
        if (email.isNotEmpty) {
          emailMap.putIfAbsent(email, () => []).add(doc);
        }
      }

      int idDuplicatesCount = 0;
      int emailDuplicatesCount = 0;

      // PHƯƠNG THỨC HỖ TRỢ: Sắp xếp tài liệu theo thời gian
      void _sortDocumentsByUpdateTime(List<DocumentSnapshot> documents) {
        documents.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          // Thử các trường thời gian khác nhau
          final fieldsToCheck = ['updated_at', 'last_updated', 'last_sync_time', 'timestamp'];

          for (final field in fieldsToCheck) {
            final valueA = dataA[field];
            final valueB = dataB[field];

            if (valueA != null && valueB != null) {
              try {
                DateTime? timeA;
                DateTime? timeB;

                // Xử lý các kiểu dữ liệu thời gian khác nhau
                if (valueA is Timestamp) {
                  timeA = valueA.toDate();
                } else if (valueA is int) {
                  timeA = DateTime.fromMillisecondsSinceEpoch(valueA);
                } else if (valueA is String) {
                  timeA = DateTime.parse(valueA);
                }

                if (valueB is Timestamp) {
                  timeB = valueB.toDate();
                } else if (valueB is int) {
                  timeB = DateTime.fromMillisecondsSinceEpoch(valueB);
                } else if (valueB is String) {
                  timeB = DateTime.parse(valueB);
                }

                if (timeA != null && timeB != null) {
                  // Sort mới nhất lên đầu (B so với A)
                  return timeB.compareTo(timeA);
                }
              } catch (e) {
                // Bỏ qua lỗi và thử trường tiếp theo
              }
            }
          }

          // Nếu không thể so sánh bằng thời gian, giữ nguyên thứ tự
          return 0;
        });
      }

      // Bước 2a: Tìm các bản ghi trùng lặp theo user_id
      for (var entry in userIdMap.entries) {
        if (entry.value.length > 1) {
          idDuplicatesCount++;
          if (!silent) debugPrint('Phát hiện ${entry.value.length} bản ghi trùng user_id: ${entry.key}');

          // Sắp xếp theo thời gian cập nhật (mới nhất đầu tiên)
          _sortDocumentsByUpdateTime(entry.value);

          // Giữ lại bản ghi đầu tiên (mới nhất), đánh dấu các bản ghi còn lại để xóa
          for (int i = 1; i < entry.value.length; i++) {
            if (!duplicateDocs.contains(entry.value[i])) {
              duplicateDocs.add(entry.value[i]);
            }
          }
        }
      }

      // Bước 2b: Tìm các bản ghi trùng lặp theo email
      for (var entry in emailMap.entries) {
        if (entry.value.length > 1) {
          emailDuplicatesCount++;
          if (!silent) debugPrint('Phát hiện ${entry.value.length} bản ghi trùng email: ${entry.key}');

          // Sắp xếp theo thời gian cập nhật (mới nhất đầu tiên)
          _sortDocumentsByUpdateTime(entry.value);

          // Giữ lại bản ghi đầu tiên (mới nhất), đánh dấu các bản ghi còn lại để xóa
          for (int i = 1; i < entry.value.length; i++) {
            if (!duplicateDocs.contains(entry.value[i])) {
              duplicateDocs.add(entry.value[i]);
            }
          }
        }
      }

      // Bước 3: Xóa các bản ghi trùng lặp
      int deletedCount = 0;
      if (duplicateDocs.isNotEmpty) {
        if (!silent) debugPrint('Phát hiện ${duplicateDocs.length} bản ghi trùng lặp cần xóa');

        // Xác nhận và xóa các tài liệu trùng lặp
        for (var doc in duplicateDocs) {
          try {
            await firestore.collection('users').doc(doc.id).delete();
            deletedCount++;
            if (!silent) debugPrint('Đã xóa tài liệu trùng lặp: ${doc.id}');
          } catch (e) {
            if (!silent) debugPrint('Lỗi khi xóa tài liệu ${doc.id}: $e');
          }
        }

        if (!silent) debugPrint('✅ Đã xử lý thành công! ' +
        'Phát hiện $emailDuplicatesCount email trùng lặp, $idDuplicatesCount userId trùng lặp. ' +
        'Đã xóa $deletedCount/${duplicateDocs.length} bản ghi trùng lặp.');

        return {
          'success': true,
          'message': 'Đã xóa $deletedCount bản ghi trùng lặp',
          'email_duplicates': emailDuplicatesCount,
          'id_duplicates': idDuplicatesCount,
          'deleted': deletedCount,
          'total_duplicates': duplicateDocs.length
        };
      } else {
        if (!silent) debugPrint('✅ Không phát hiện dữ liệu trùng lặp');
        return {'success': true, 'message': 'Không phát hiện dữ liệu trùng lặp'};
      }
    } catch (e) {
      if (!silent) debugPrint('❌ Lỗi khi dọn dẹp dữ liệu trùng lặp: $e');
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  Future<bool> removeDuplicateFieldsInFirestore() async {
    try {
      if (!isUserAuthenticated()) {
        debugPrint('Người dùng chưa đăng nhập');
        return false;
      }
      
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      
      // Lấy dữ liệu hiện tại
      final docRef = firestore.collection('users').doc(uid);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return false;
      
      Map<String, dynamic> data = docSnapshot.data()!;
      Map<String, dynamic> cleanedData = {};
      
      // Mở rộng danh sách trường để chuyển đổi (camelCase -> snake_case)
      final fieldMappings = {
        'targetWeightKg': 'target_weight_kg',
        'tdeeCalories': 'tdee_calories',
        'tdeeProtein': 'tdee_protein',
        'tdeeCarbs': 'tdee_carbs',
        'tdeeFat': 'tdee_fat',
        'activityLevel': 'activity_level',
        'heightCm': 'height_cm',
        'weightKg': 'weight_kg',
        'dietRestrictions': 'diet_restrictions',
        'healthConditions': 'health_conditions',
        'syncEnabled': 'sync_enabled',
        'dailyCalories': 'daily_calories',
        'eventDay': 'event_day',
        'eventMonth': 'event_month',
        'eventYear': 'event_year',
        'lastSyncTime': 'last_sync_time',
        'nutritionGoals': 'nutrition_goals',
        'addExerciseCaloriesToGoal': 'add_exercise_calories_to_goal',
        'dietPreference': 'diet_preference',
        'cuisineStyle': 'cuisine_style',
        'userId': 'user_id',
        'weightGoal': 'weight_goal'
      };
      
      // Xử lý tất cả các cặp trường cùng một lúc
      fieldMappings.forEach((camelCase, snakeCase) {
        if (data.containsKey(camelCase) && data.containsKey(snakeCase)) {
          // Nếu cả hai trường tồn tại, ưu tiên giữ trường snake_case
          cleanedData[snakeCase] = data[snakeCase];
          debugPrint('🔄 Giữ lại $snakeCase, xóa $camelCase');
        } else if (data.containsKey(snakeCase)) {
          cleanedData[snakeCase] = data[snakeCase];
        } else if (data.containsKey(camelCase)) {
          cleanedData[snakeCase] = data[camelCase];
          debugPrint('🔄 Chuyển đổi $camelCase -> $snakeCase');
        }
      });
      
      // Giữ lại các trường khác
      data.forEach((key, value) {
        if (!fieldMappings.containsKey(key) && !fieldMappings.values.contains(key)) {
          cleanedData[key] = value;
        }
      });
      
      // Cập nhật lại dữ liệu đã làm sạch
      await docRef.set(cleanedData);
      debugPrint('✅ Đã chuẩn hóa dữ liệu trên Firestore thành công!');
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi làm sạch dữ liệu Firestore: $e');
      return false;
    }
  }

  // Thêm hàm này vào lớp UserDataProvider
  Map<String, dynamic> _standardizeFirestoreData(Map<String, dynamic> data) {
    Map<String, dynamic> standardData = {};
    
    // Danh sách ánh xạ từ snake_case sang camelCase (cho local)
    final fieldMappings = {
      'target_weight_kg': 'targetWeightKg',
      'tdee_calories': 'tdeeCalories',
      'tdee_protein': 'tdeeProtein',
      'tdee_carbs': 'tdeeCarbs',
      'tdee_fat': 'tdeeFat',
      'activity_level': 'activityLevel',
      'height_cm': 'heightCm',
      'weight_kg': 'weightKg',
      'diet_restrictions': 'dietRestrictions',
      'health_conditions': 'healthConditions',
      'sync_enabled': 'syncEnabled',
      'daily_calories': 'dailyCalories'
    };
    
    // Chuyển đổi snake_case sang biến local camelCase
    fieldMappings.forEach((snakeCase, camelCase) {
      if (data.containsKey(snakeCase)) {
        standardData[camelCase] = data[snakeCase];
      }
    });
    
    // Chuyển các trường khác
    data.forEach((key, value) {
      if (!fieldMappings.containsKey(key)) {
        standardData[key] = value;
      }
    });
    
    return standardData;
  }

  Future<bool> synchronizeAllData() async {
    try {
      // 1. Xóa trường trùng lặp trên Firestore (camelCase + snake_case)
      debugPrint('🧹 Bước 1: Xóa các trường trùng lặp camelCase/snake_case');
      bool cleanupResult = await _removeDuplicateCamelCaseFields();
      if (!cleanupResult) {
        debugPrint('⚠️ Không thể xóa trường trùng lặp. Tiếp tục quá trình đồng bộ.');
      }
      
      // 2. Đồng bộ dữ liệu lên Firestore với định dạng nhất quán
      debugPrint('🔄 Bước 2: Đồng bộ dữ liệu với định dạng snake_case nhất quán');
      bool syncResult = await syncUserDataCentralized(forceSync: true);
      if (!syncResult) {
        debugPrint('⚠️ Không thể đồng bộ dữ liệu');
        return false;
      }
      
      // 3. Dọn dẹp các bản ghi trùng lặp
      debugPrint('🧹 Bước 3: Dọn dẹp các bản ghi trùng lặp (nếu có)');
      final cleanupDuplicatesResult = await cleanupDuplicateData(silent: false);
      if (cleanupDuplicatesResult['success'] != true) {
        debugPrint('⚠️ Không thể dọn dẹp bản ghi trùng lặp');
      }
      
      // 4. Cập nhật thời gian đồng bộ
      _lastSyncTime = DateTime.now();
      await saveUserData();
      
      debugPrint('✅ Đã đồng bộ và chuẩn hóa dữ liệu thành công!');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ dữ liệu: $e');
      return false;
    }
  }

  // Xóa các trường trùng lặp camelCase trong Firestore
  Future<bool> _removeDuplicateCamelCaseFields() async {
    try {
      if (!isUserAuthenticated()) {
        debugPrint('⚠️ Không thể xóa trường trùng lặp: Người dùng chưa đăng nhập');
        return false;
      }
      
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      
      // Lấy dữ liệu hiện tại
      final docRef = firestore.collection('users').doc(uid);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return false;
      
      Map<String, dynamic> data = docSnapshot.data()!;
      Map<String, dynamic> cleanedData = {};
      
      // Danh sách đầy đủ các cặp trường cần chuyển đổi (camelCase -> snake_case)
      final fieldMappings = {
        'targetWeightKg': 'target_weight_kg',
        'tdeeCalories': 'tdee_calories',
        'tdeeProtein': 'tdee_protein',
        'tdeeCarbs': 'tdee_carbs',
        'tdeeFat': 'tdee_fat',
        'activityLevel': 'activity_level',
        'heightCm': 'height_cm',
        'weightKg': 'weight_kg',
        'dietRestrictions': 'diet_restrictions',
        'healthConditions': 'health_conditions',
        'syncEnabled': 'sync_enabled',
        'dailyCalories': 'daily_calories',
        'eventDay': 'event_day',
        'eventMonth': 'event_month',
        'eventYear': 'event_year',
        'lastSyncTime': 'last_sync_time',
        'nutritionGoals': 'nutrition_goals',
        'addExerciseCaloriesToGoal': 'add_exercise_calories_to_goal',
        'dietPreference': 'diet_preference',
        'cuisineStyle': 'cuisine_style',
        'userId': 'user_id',
        'weightGoal': 'weight_goal'
      };
      
      // BƯỚC 1: Tạo map các trường cần xóa sử dụng FieldValue.delete()
      Map<String, dynamic> deletions = {};
      
      fieldMappings.forEach((camelCase, snakeCase) {
        if (data.containsKey(camelCase)) {
          // Nếu có trường camelCase, đánh dấu để xóa
          if (data.containsKey(snakeCase)) {
            // Nếu đã có snake_case tương ứng, xóa camelCase
            deletions[camelCase] = FieldValue.delete();
            debugPrint('🗑️ Đánh dấu xóa trường trùng lặp: $camelCase (giữ lại $snakeCase)');
          } else {
            // Nếu chưa có snake_case, sao chép giá trị và sau đó xóa camelCase
            cleanedData[snakeCase] = data[camelCase];
            deletions[camelCase] = FieldValue.delete();
            debugPrint('🔄 Chuyển đổi $camelCase -> $snakeCase và xóa trường cũ');
          }
        }
        // Sao chép trường snake_case nếu tồn tại
        if (data.containsKey(snakeCase)) {
          cleanedData[snakeCase] = data[snakeCase];
        }
      });
      
      // BƯỚC 2: Sao chép các trường khác không cần chuyển đổi
      data.forEach((key, value) {
        if (!fieldMappings.containsKey(key) && !fieldMappings.values.contains(key)) {
          cleanedData[key] = value;
        }
      });
      
      // BƯỚC 3: Thực hiện xóa trường trùng lặp trước
      if (deletions.isNotEmpty) {
        try {
          await docRef.update(deletions);
          debugPrint('✅ Đã xóa ${deletions.length} trường camelCase trùng lặp');
        } catch (e) {
          debugPrint('⚠️ Lỗi khi xóa trường trùng lặp: $e');
          // Tiếp tục để cập nhật dữ liệu làm sạch
        }
      }
      
      // BƯỚC 4: Cập nhật với dữ liệu đã làm sạch
      if (cleanedData.isNotEmpty) {
        await docRef.set(cleanedData, SetOptions(merge: true));
        debugPrint('✅ Đã cập nhật dữ liệu đã làm sạch lên Firestore');
      }
      
      debugPrint('✅ Đã chuẩn hóa dữ liệu trên Firestore thành công!');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi làm sạch dữ liệu Firestore: $e');
      return false;
    }
  }

  // Phương thức đánh dấu dữ liệu đã thay đổi và cần được đồng bộ

  // Khai báo biến Timer cho debounce


  @override
  
  
  // Tự động đồng bộ dữ liệu nếu có thể
  Future<void> autoSyncUserData() async {
    // Chỉ đồng bộ khi:
    // 1. Firebase khả dụng
    // 2. Người dùng đã đăng nhập
    // 3. Tính năng đồng bộ được bật
    if (_isFirebaseAvailable && isUserAuthenticated() && _syncEnabled) {
      try {
        // Đợi một chút để tránh quá nhiều yêu cầu đồng bộ
        await Future.delayed(Duration(milliseconds: 500));
        
        // Kiểm tra dữ liệu hợp lệ trước khi đồng bộ
        _validateData();
        
        // Đảm bảo TDEE được tính toán đúng
        if (_tdeeCalories <= 0) {
          await _initializeTDEEAsync();
        }
        
        // Thực hiện đồng bộ
        final syncResult = await syncUserDataCentralized();
        if (syncResult) {
          debugPrint('✅ Tự động đồng bộ dữ liệu thành công');
        } else {
          debugPrint('⚠️ Tự động đồng bộ dữ liệu không thành công');
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi tự động đồng bộ dữ liệu: $e');
      }
    } else {
      if (!_isFirebaseAvailable) {
        debugPrint('⚠️ Không thể tự động đồng bộ: Firebase không khả dụng');
      } else if (!isUserAuthenticated()) {
        debugPrint('⚠️ Không thể tự động đồng bộ: Người dùng chưa đăng nhập');
      } else if (!_syncEnabled) {
        debugPrint('⚠️ Không thể tự động đồng bộ: Tính năng đồng bộ bị tắt');
      }
    }
  }

  // Kiểm tra và làm sạch dữ liệu trùng lặp trên Firebase
  Future<bool> cleanupDuplicateFieldsOnFirebase() async {
    try {
      if (!isUserAuthenticated()) {
        debugPrint('⚠️ Không thể làm sạch dữ liệu: Người dùng chưa đăng nhập');
        return false;
      }
      
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      
      // Lấy dữ liệu hiện tại
      final docRef = firestore.collection('users').doc(uid);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        debugPrint('⚠️ Không tìm thấy dữ liệu người dùng trên Firebase');
        return false;
      }
      
      Map<String, dynamic> data = docSnapshot.data()!;
      Map<String, dynamic> cleanedData = {};
      Map<String, dynamic> fieldsToDelete = {};
      
      // Danh sách đầy đủ các cặp trường cần chuyển đổi (camelCase -> snake_case)
      final fieldMappings = {
        'targetWeightKg': 'target_weight_kg',
        'tdeeCalories': 'tdee_calories',
        'tdeeProtein': 'tdee_protein',
        'tdeeCarbs': 'tdee_carbs',
        'tdeeFat': 'tdee_fat',
        'activityLevel': 'activity_level',
        'heightCm': 'height_cm',
        'weightKg': 'weight_kg',
        'dietRestrictions': 'diet_restrictions',
        'healthConditions': 'health_conditions',
        'syncEnabled': 'sync_enabled',
        'dailyCalories': 'daily_calories',
        'eventDay': 'event_day',
        'eventMonth': 'event_month',
        'eventYear': 'event_year',
        'lastSyncTime': 'last_sync_time',
        'nutritionGoals': 'nutrition_goals',
        'addExerciseCaloriesToGoal': 'add_exercise_calories_to_goal',
        'dietPreference': 'diet_preference',
        'cuisineStyle': 'cuisine_style',
        'userId': 'user_id',
        'weightGoal': 'weight_goal'
      };
      
      // BƯỚC 1: Xử lý từng cặp trường
      fieldMappings.forEach((camelCase, snakeCase) {
        bool hasCamelCase = data.containsKey(camelCase);
        bool hasSnakeCase = data.containsKey(snakeCase);
        
        if (hasCamelCase && hasSnakeCase) {
          // Nếu cả hai tồn tại, ưu tiên giá trị từ snake_case và xóa camelCase
          cleanedData[snakeCase] = data[snakeCase];
          fieldsToDelete[camelCase] = FieldValue.delete();
          debugPrint('🔄 Giữ $snakeCase, xóa $camelCase');
        } else if (hasCamelCase) {
          // Nếu chỉ có camelCase, chuyển đổi sang snake_case và xóa camelCase
          cleanedData[snakeCase] = data[camelCase];
          fieldsToDelete[camelCase] = FieldValue.delete();
          debugPrint('🔄 Chuyển $camelCase -> $snakeCase');
        } else if (hasSnakeCase) {
          // Nếu chỉ có snake_case, giữ nguyên
          cleanedData[snakeCase] = data[snakeCase];
        }
      });
      
      // BƯỚC 2: Sao chép các trường khác không cần chuyển đổi
      data.forEach((key, value) {
        if (!fieldMappings.containsKey(key) && !fieldMappings.values.contains(key)) {
          cleanedData[key] = value;
        }
      });
      
      // BƯỚC 3: Thực hiện xóa trường trùng lặp
      if (fieldsToDelete.isNotEmpty) {
        try {
          await docRef.update(fieldsToDelete);
          debugPrint('✅ Đã xóa ${fieldsToDelete.length} trường trùng lặp');
        } catch (e) {
          debugPrint('⚠️ Lỗi khi xóa trường trùng lặp: $e');
        }
      }
      
      // BƯỚC 4: Cập nhật với dữ liệu đã làm sạch
      await docRef.set(cleanedData, SetOptions(merge: true));
      debugPrint('✅ Đã cập nhật dữ liệu đã làm sạch lên Firebase');
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi làm sạch dữ liệu: $e');
      return false;
    }
  }

  // Phương thức kiểm tra tính hợp lệ của dữ liệu
  
  // Phương thức làm sạch toàn diện dữ liệu và tiêu chuẩn hóa định dạng
  Future<bool> performCompleteDataCleanup() async {
    try {
      if (!isUserAuthenticated()) {
        debugPrint('⚠️ Không thể làm sạch dữ liệu: Người dùng chưa đăng nhập');
        return false;
      }
      
      debugPrint('🧹 Bắt đầu quy trình làm sạch toàn diện dữ liệu...');
      
      // Đánh dấu đã làm sạch dữ liệu trong SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      // Kiểm tra xem đã làm sạch dữ liệu lần này chưa
      bool alreadyCleaned = prefs.getBool('data_cleaned_${DateTime.now().day}') ?? false;
      
      if (alreadyCleaned) {
        debugPrint('ℹ️ Dữ liệu đã được làm sạch hôm nay, bỏ qua');
        return true;
      }
      
      // 1. Làm sạch dữ liệu trên Firebase (xóa trùng lặp)
      // Sử dụng phương thức mạnh mẽ hơn để xóa các trường trùng lặp
      bool cleanupSuccess = await _forceCompleteCleanup();
      
      if (!cleanupSuccess) {
        debugPrint('⚠️ Không thể làm sạch dữ liệu trên Firebase, thử lại sau');
        return false;
      }
      
      // 2. Đảm bảo các giá trị TDEE và mục tiêu dinh dưỡng đúng
      if (_goal == 'Giảm cân') {
        // Kiểm tra mục tiêu giảm cân
        double targetCalories = _nutritionGoals['calories'] ?? 0;
        if (targetCalories >= _tdeeCalories || targetCalories <= 0) {
          debugPrint('⚠️ Phát hiện vấn đề với mục tiêu calo giảm cân, tính toán lại');
          _adjustCaloriesByGoal();
          _calculateMacrosByCalories();
        }
      }
      
      // 3. Tính toán lại TDEE nếu cần
      if (_tdeeCalories <= 0 || (_tdeeCalories - 2000.0).abs() < 0.001) {
        debugPrint('⚠️ TDEE không hợp lệ, tính toán lại');
        await _initializeTDEEAsync();
      }
      
      // 4. Đồng bộ lại dữ liệu đã làm sạch lên Firebase
      final syncResult = await syncUserDataCentralized(forceSync: true);
      
      // 5. Dọn dẹp dữ liệu trùng lặp trên cấp độ tài liệu
      final cleanupResult = await cleanupDuplicateData(silent: true);
      
      // Đánh dấu đã làm sạch dữ liệu hôm nay
      await prefs.setBool('data_cleaned_${DateTime.now().day}', true);
      
      debugPrint('✅ Đã hoàn thành quy trình làm sạch dữ liệu toàn diện');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi làm sạch dữ liệu toàn diện: $e');
      return false;
    }
  }
  
  // Phương thức buộc làm sạch hoàn toàn dữ liệu Firebase
  Future<bool> _forceCompleteCleanup() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      
      // Lấy dữ liệu hiện tại
      final docRef = firestore.collection('users').doc(uid);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return false;
      
      final data = docSnapshot.data()!;
      
      // Danh sách các cặp trường cần giữ (snake_case) và xóa (camelCase)
      final fieldMappings = {
        'targetWeightKg': 'target_weight_kg',
        'tdeeCalories': 'tdee_calories',
        'tdeeProtein': 'tdee_protein',
        'tdeeCarbs': 'tdee_carbs',
        'tdeeFat': 'tdee_fat',
        'activityLevel': 'activity_level',
        'heightCm': 'height_cm',
        'weightKg': 'weight_kg',
        'dietRestrictions': 'diet_restrictions',
        'healthConditions': 'health_conditions',
        'syncEnabled': 'sync_enabled',
        'dailyCalories': 'daily_calories',
        'eventDay': 'event_day',
        'eventMonth': 'event_month',
        'eventYear': 'event_year',
        'lastSyncTime': 'last_sync_time',
        'nutritionGoals': 'nutrition_goals',
        'addExerciseCaloriesToGoal': 'add_exercise_calories_to_goal',
        'dietPreference': 'diet_preference',
        'cuisineStyle': 'cuisine_style',
        'userId': 'user_id',
        'weightGoal': 'weight_goal'
      };
      
      // Tạo đối tượng chứa dữ liệu chuẩn hóa (chỉ dùng snake_case)
      Map<String, dynamic> cleanedData = {};
      
      // Tạo danh sách các trường cần xóa (camelCase)
      Map<String, dynamic> fieldsToDelete = {};
      
      // Quét tất cả các trường trong dữ liệu
      for (var key in data.keys) {
        // Nếu trường có chứa chữ hoa (camelCase), kiểm tra xem có tương ứng snake_case không
        if (key.contains(RegExp('[A-Z]'))) {
          // Tìm trường snake_case tương ứng
          String? snakeKey;
          for (var entry in fieldMappings.entries) {
            if (entry.key == key) {
              snakeKey = entry.value;
              break;
            }
          }
          
          if (snakeKey != null) {
            // Nếu có trường snake_case tương ứng, kiểm tra xem đã tồn tại chưa
            if (data.containsKey(snakeKey)) {
              // Nếu đã tồn tại, chỉ xóa trường camelCase
              fieldsToDelete[key] = FieldValue.delete();
              debugPrint('🗑️ Đánh dấu xóa trường trùng lặp: $key (đã có $snakeKey)');
            } else {
              // Nếu chưa tồn tại, tạo trường snake_case mới và xóa camelCase
              cleanedData[snakeKey] = data[key];
              fieldsToDelete[key] = FieldValue.delete();
              debugPrint('🔄 Chuyển đổi $key -> $snakeKey');
            }
          } else {
            // Không tìm thấy trong danh sách, xóa để đảm bảo
            fieldsToDelete[key] = FieldValue.delete();
            debugPrint('🗑️ Đánh dấu xóa trường camelCase: $key');
          }
        } else {
          // Đây là trường snake_case, giữ lại
          cleanedData[key] = data[key];
        }
      }
      
      // Lọc bỏ các trường null trong dữ liệu đã làm sạch
      cleanedData.removeWhere((key, value) => value == null);
      
      // Thực hiện xóa các trường camelCase
      if (fieldsToDelete.isNotEmpty) {
        try {
          await docRef.update(fieldsToDelete);
          debugPrint('✅ Đã xóa ${fieldsToDelete.length} trường camelCase trùng lặp');
        } catch (e) {
          debugPrint('⚠️ Lỗi khi xóa trường trùng lặp: $e');
        }
      }
      
      // Cập nhật với dữ liệu đã làm sạch
      await docRef.set(cleanedData, SetOptions(merge: true));
      debugPrint('✅ Đã cập nhật dữ liệu đã làm sạch lên Firebase');
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi buộc làm sạch hoàn toàn: $e');
      return false;
    }
  }

  // Phương thức tạo map chuyển đổi camelCase -> snake_case
  Map<String, String> _getFieldMappings() {
    return {
      'targetWeightKg': 'target_weight_kg',
      'tdeeCalories': 'tdee_calories',
      'tdeeProtein': 'tdee_protein',
      'tdeeCarbs': 'tdee_carbs',
      'tdeeFat': 'tdee_fat',
      'activityLevel': 'activity_level',
      'heightCm': 'height_cm',
      'weightKg': 'weight_kg',
      'dietRestrictions': 'diet_restrictions',
      'healthConditions': 'health_conditions',
      'syncEnabled': 'sync_enabled',
      'dailyCalories': 'daily_calories',
      'eventDay': 'event_day',
      'eventMonth': 'event_month',
      'eventYear': 'event_year',
      'lastSyncTime': 'last_sync_time',
      'nutritionGoals': 'nutrition_goals',
      'addExerciseCaloriesToGoal': 'add_exercise_calories_to_goal',
      'dietPreference': 'diet_preference',
      'cuisineStyle': 'cuisine_style',
      'userId': 'user_id',
      'weightGoal': 'weight_goal',
      'lastLoginAt': 'last_login_at',
      'updatedAt': 'updated_at'
    };
  }
  
  // Chuyển đổi tên trường từ camelCase sang snake_case
  String _camelToSnake(String key) {
    final mappings = _getFieldMappings();
    return mappings[key] ?? key;
  }
  
  // Chuyển đổi tên trường từ snake_case sang camelCase
  String _snakeToCamel(String key) {
    final mappings = _getFieldMappings();
    for (var entry in mappings.entries) {
      if (entry.value == key) {
        return entry.key;
      }
    }
    return key;
  }

  // Phương thức xóa các trường camelCase trùng lặp trên Firestore
  Future<bool> _removeRedundantCamelCaseFields(String uid) async {
    try {
      // Danh sách các trường camelCase cần kiểm tra và xóa nếu có
      final camelCaseFields = _getFieldMappings().keys.toList();
      
      // Tạo map các trường cần xóa
      Map<String, dynamic> deletions = {};
      for (String field in camelCaseFields) {
        deletions[field] = FieldValue.delete();
      }
      
      // Thực hiện xóa các trường trùng lặp
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(deletions);
          
      debugPrint('✅ Đã xóa các trường camelCase trùng lặp trên Firestore');
      return true;
    } catch (e) {
      // Có thể một số trường không tồn tại, bỏ qua lỗi
      debugPrint('ℹ️ Xóa trường trùng lặp: $e');
      return false;
    }
  }

  // Phương thức kiểm tra tính nhất quán của dữ liệu trên Firestore
  Future<bool> checkAndFixFirestoreData() async {
    try {
      if (!isUserAuthenticated()) {
        debugPrint('⚠️ Không thể kiểm tra dữ liệu: Người dùng chưa đăng nhập');
        return false;
      }
      
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      
      // Lấy dữ liệu hiện tại
      final docRef = firestore.collection('users').doc(uid);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        debugPrint('⚠️ Không tìm thấy dữ liệu người dùng trên Firestore');
        return false;
      }
      
      final existingData = docSnapshot.data()!;
      
      // Kiểm tra các trường quan trọng
      bool needsUpdate = false;
      Map<String, dynamic> updatedFields = {};
      
      // 1. Kiểm tra TDEE
      if (!existingData.containsKey('tdee_calories') || 
          _safeParseDouble(existingData['tdee_calories'], 0) <= 0) {
        needsUpdate = true;
        updatedFields['tdee_calories'] = _tdeeCalories;
        updatedFields['tdee_protein'] = _tdeeProtein;
        updatedFields['tdee_carbs'] = _tdeeCarbs;
        updatedFields['tdee_fat'] = _tdeeFat;
        debugPrint('⚠️ Thiếu hoặc không hợp lệ: tdee_calories');
      }
      
      // 2. Kiểm tra mục tiêu dinh dưỡng
      if (!existingData.containsKey('nutrition_goals') || 
          existingData['nutrition_goals'] == null) {
        needsUpdate = true;
        updatedFields['nutrition_goals'] = _nutritionGoals;
        debugPrint('⚠️ Thiếu: nutrition_goals');
      } else {
        // Kiểm tra các giá trị quan trọng trong nutrition_goals
        final goals = existingData['nutrition_goals'];
        if (goals is Map) {
          Map<String, dynamic> goalsMap = Map<String, dynamic>.from(goals);
          
          // Kiểm tra calories
          if (!goalsMap.containsKey('calories') || _safeParseDouble(goalsMap['calories'], 0) <= 0) {
            needsUpdate = true;
            debugPrint('⚠️ Thiếu hoặc không hợp lệ: nutrition_goals.calories');
            
            // Tạo bản sao của mục tiêu dinh dưỡng hiện tại
            Map<String, dynamic> updatedGoals = Map<String, dynamic>.from(goalsMap);
            updatedGoals['calories'] = _nutritionGoals['calories'];
            updatedGoals['protein'] = _nutritionGoals['protein'];
            updatedGoals['carbs'] = _nutritionGoals['carbs'];
            updatedGoals['fat'] = _nutritionGoals['fat'];
            
            updatedFields['nutrition_goals'] = updatedGoals;
          }
        }
      }
      
      // 3. Kiểm tra dữ liệu người dùng cơ bản
      for (var field in ['gender', 'age', 'height_cm', 'weight_kg', 'activity_level', 'goal']) {
        if (!existingData.containsKey(field) || existingData[field] == null) {
          needsUpdate = true;
          debugPrint('⚠️ Thiếu: $field');
          
          // Thêm trường bị thiếu
          switch (field) {
            case 'gender':
              updatedFields[field] = _gender;
              break;
            case 'age':
              updatedFields[field] = _age;
              break;
            case 'height_cm':
              updatedFields[field] = _heightCm;
              break;
            case 'weight_kg':
              updatedFields[field] = _weightKg;
              break;
            case 'activity_level':
              updatedFields[field] = _activityLevel;
              break;
            case 'goal':
              updatedFields[field] = _goal;
              break;
          }
        }
      }
      
      // 4. Nếu cần cập nhật, thực hiện cập nhật
      if (needsUpdate) {
        debugPrint('🔄 Cập nhật ${updatedFields.length} trường dữ liệu thiếu hoặc không hợp lệ');
        
        // Thêm thông tin cập nhật
        updatedFields['updated_at'] = DateTime.now().toIso8601String();
        
        // Thực hiện cập nhật
        await docRef.set(updatedFields, SetOptions(merge: true));
        
        debugPrint('✅ Đã cập nhật dữ liệu thành công');
        return true;
      } else {
        debugPrint('✅ Dữ liệu đã nhất quán, không cần cập nhật');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra và sửa dữ liệu Firestore: $e');
      return false;
    }
  }

  // Tính toán lại TDEE và lưu vào SharedPreferences


  // Method to update user data with specified fields
  Future<bool> updateUserData({
    String? name,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    String? activityLevel,
    String? goal,
    double? pace,
    List<String>? dietaryRestrictions,
    List<String>? healthConditions,
    String? measurementSystem,
    Map<String, double>? nutritionGoals,
    double? tdeeCalories,
    double? tdeeProtein,
    double? tdeeCarbs,
    double? tdeeFat,
  }) async {
    // Implement the logic to update user data with specified fields
    // This is a placeholder implementation
    return false;
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
  
  // Phương thức để reset các cờ đánh dấu dữ liệu
  Future<void> _resetLocalDataFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('data_loaded_from_firestore', false);
      await prefs.setBool('use_firebase_data', false);
      await prefs.setBool('need_recalculate_tdee', true);
      debugPrint('✅ Đã reset các cờ đánh dấu dữ liệu để ưu tiên local storage');
    } catch (e) {
      debugPrint('❌ Lỗi khi reset cờ dữ liệu: $e');
    }
  }
  
  // Phương thức tính toán TDEE
  Future<double> calculateTDEE() async {
    try {
      // Kiểm tra dữ liệu đầu vào hợp lệ
      if (_weightKg <= 0 || _heightCm <= 0 || _age <= 0) {
        debugPrint('⚠️ Dữ liệu người dùng không hợp lệ cho việc tính TDEE');
        return 0.0;
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

      // Return calculated calories
      return tdeeValues['calories'] ?? 0.0;
    } catch (e) {
      debugPrint('❌ Lỗi khi tính toán TDEE: $e');
      return 0.0;
    }
  }
  
  // Phương thức đồng bộ dữ liệu lên Firebase
  Future<void> _syncUserDataToFirebase() async {
    if (!isFirebaseAvailable() || !isUserAuthenticated()) {
      debugPrint('⚠️ Không thể đồng bộ: Firebase không khả dụng hoặc chưa đăng nhập');
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = _prepareUserDataForSync(); // Phương thức này đã trả về snake_case keys

        // Ghi log debug để kiểm tra dữ liệu chế độ ăn được đồng bộ
        debugPrint('📋 Dữ liệu chế độ ăn sẽ được đồng bộ lên Firebase:');
        debugPrint('📋 diet_restrictions: ${userData['diet_restrictions']}');
        debugPrint('📋 health_conditions: ${userData['health_conditions']}');
        debugPrint('📋 diet_preference: ${userData['diet_preference']}');

        if (userData.isNotEmpty) {
          // THAY ĐỔI QUAN TRỌNG: Bỏ SetOptions(merge: true) để ghi đè toàn bộ
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(userData); // Ghi đè toàn bộ tài liệu bằng userData mới (chỉ chứa snake_case)

          _lastSyncTime = DateTime.now();
          debugPrint('✅ Đã đồng bộ (ghi đè hoàn toàn) dữ liệu lên Firebase thành công');

          // Lưu thời gian đồng bộ
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
          
          // Cập nhật lại SharedPreferences với dữ liệu đã đồng bộ
          await prefs.setString(_dietRestrictionKey, jsonEncode(_dietRestrictions));
          await prefs.setString(_healthConditionsKey, jsonEncode(_healthConditions));
          await prefs.setString(_dietPreferenceKey, _dietPreference);
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ (ghi đè hoàn toàn) lên Firebase: $e');
    }
  }

  // 🔧 DEBUG: Method để kiểm tra dữ liệu hiện tại
  void debugCurrentData() {
    debugPrint('=== DEBUG USER DATA ===');
    debugPrint('TDEE Calories: $_tdeeCalories');
    debugPrint('Daily Calories: $_dailyCalories');
    debugPrint('Nutrition Goals Calories: ${_nutritionGoals['calories']}');
    debugPrint('Goal: $_goal');
    debugPrint('Pace: $_pace');
    debugPrint('Weight: $_weightKg kg');
    debugPrint('Height: $_heightCm cm');
    debugPrint('Age: $_age');
    debugPrint('Gender: $_gender');
    debugPrint('Activity Level: $_activityLevel');
    debugPrint('User ID: $_userId');
    debugPrint('Email: $_email');
    debugPrint('======================');
  }

  // Setters for TDEE values
  set tdeeCalories(double value) {
    _tdeeCalories = value;
    notifyListeners();
  }
  
  set tdeeProtein(double value) {
    _tdeeProtein = value;
    notifyListeners();
  }
  
  set tdeeCarbs(double value) {
    _tdeeCarbs = value;
    notifyListeners();
  }
  
  set tdeeFat(double value) {
    _tdeeFat = value;
    notifyListeners();
  }
  
  set measurementSystem(String value) {
    _measurementSystem = value;
    notifyListeners();
  }

  // Phương thức để kiểm tra và in dữ liệu lưu trữ local
  Future<Map<String, dynamic>> debugLocalStorage() async {
    try {
      debugPrint('🔍 Đang kiểm tra dữ liệu lưu trữ cục bộ...');
      final prefs = await SharedPreferences.getInstance();
      
      // Lấy tất cả các khóa
      final keys = prefs.getKeys();
      Map<String, dynamic> localData = {};
      
      // Nhóm dữ liệu theo loại
      Map<String, dynamic> userInfo = {};
      Map<String, dynamic> tdeeData = {};
      Map<String, dynamic> syncData = {};
      Map<String, dynamic> flagsData = {};
      Map<String, dynamic> otherData = {};
      
      // Xử lý từng khóa
      for (var key in keys) {
        // Đọc giá trị
        dynamic value;
        if (prefs.containsKey(key)) {
          if (key.contains('tdee')) {
            value = prefs.getDouble(key);
            tdeeData[key] = value;
          } else if (key.contains('sync') || key.contains('last_sync')) {
            if (key.contains('Time')) {
              value = prefs.getString(key);
            } else {
              value = prefs.getBool(key);
            }
            syncData[key] = value;
          } else if (key.contains('user_')) {
            if (prefs.getDouble(key) != null) {
              value = prefs.getDouble(key);
            } else if (prefs.getInt(key) != null) {
              value = prefs.getInt(key);
            } else if (prefs.getString(key) != null) {
              value = prefs.getString(key);
            } else if (prefs.getBool(key) != null) {
              value = prefs.getBool(key);
            }
            userInfo[key] = value;
          } else if (key.contains('data_') || key.contains('_data') || key.contains('loaded_') || key.contains('need_')) {
            value = prefs.getBool(key);
            flagsData[key] = value;
          } else {
            if (prefs.getDouble(key) != null) {
              value = prefs.getDouble(key);
            } else if (prefs.getInt(key) != null) {
              value = prefs.getInt(key);
            } else if (prefs.getString(key) != null) {
              value = prefs.getString(key);
            } else if (prefs.getBool(key) != null) {
              value = prefs.getBool(key);
            } else if (prefs.getStringList(key) != null) {
              value = prefs.getStringList(key);
            }
            otherData[key] = value;
          }
        }
      }
      
      // Tổng hợp kết quả
      final result = {
        'user_info': userInfo,
        'tdee_data': tdeeData,
        'sync_data': syncData,
        'flags_data': flagsData,
        'other_data': otherData
      };
      
      // In ra log để debug
      debugPrint('=== THÔNG TIN LƯU TRỮ TRONG LOCAL STORAGE ===');
      debugPrint('TDEE DATA: ${tdeeData.toString()}');
      debugPrint('SYNC DATA: ${syncData.toString()}');
      debugPrint('FLAGS DATA: ${flagsData.toString()}');
      debugPrint('USER INFO: ${userInfo.toString()}');
      
      return result;
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra dữ liệu lưu trữ cục bộ: $e');
      return {'error': e.toString()};
    }
  }

  // Phương thức thực hiện di chuyển dữ liệu từ camelCase sang snake_case
  Future<bool> forceCompleteMigration() async {
    try {
      debugPrint('🔄 Bắt đầu quá trình di chuyển dữ liệu từ camelCase sang snake_case');
      final prefs = await SharedPreferences.getInstance();
      
      // Kiểm tra xem đã di chuyển chưa
      bool migrationDone = prefs.getBool(_snakeCaseMigrationKey) ?? false;
      if (migrationDone) {
        debugPrint('ℹ️ Di chuyển dữ liệu đã được thực hiện trước đó');
        return true;
      }
      
      // Kiểm tra người dùng đã đăng nhập chưa
      if (!isUserAuthenticated()) {
        debugPrint('⚠️ Không thể di chuyển dữ liệu: Người dùng chưa đăng nhập');
        return false;
      }
      
      // 1. Dọn dẹp dữ liệu trùng lặp trên Firestore
      debugPrint('🔄 Bước 1: Dọn dẹp dữ liệu trùng lặp trên Firestore');
      bool cleanupSuccess = await _forceCompleteCleanup();
      
      if (!cleanupSuccess) {
        debugPrint('⚠️ Không thể dọn dẹp dữ liệu trùng lặp');
        return false;
      }
      
      // 2. Đồng bộ dữ liệu mới (chỉ chứa snake_case) lên Firestore
      debugPrint('🔄 Bước 2: Đồng bộ dữ liệu mới (chỉ chứa snake_case) lên Firestore');
      
      // Tải lại dữ liệu từ Firestore sau khi đã dọn dẹp để đảm bảo dữ liệu mới nhất
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final refreshedSnapshot = await docRef.get();
        if (refreshedSnapshot.exists) {
           await _loadFirestoreDataIfAvailable();
        }
      }
      
      // Đánh dấu đã hoàn thành di chuyển dữ liệu
      await prefs.setBool(_snakeCaseMigrationKey, true);
      
      debugPrint('✅ Đã hoàn thành quá trình di chuyển dữ liệu sang snake_case');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi di chuyển dữ liệu: $e');
      return false;
    }
  }

  // Phương thức setGender (thêm mới) để làm việc với các trang onboarding
  void setGender(String value) {
    // Chuyển đổi 'male'/'female' sang 'Nam'/'Nữ' nếu cần
    if (value == 'male') value = 'Nam';
    if (value == 'female') value = 'Nữ';
    
    // Kiểm tra dữ liệu hợp lệ
    if (value != 'Nam' && value != 'Nữ') {
      debugPrint('⚠️ Giá trị giới tính không hợp lệ: $value');
      return;
    }
    
    if (_gender != value) {
      _gender = value;
      saveUserData();
      _markDataAsChanged(); // Đánh dấu dữ liệu đã thay đổi
      // Sử dụng Future.microtask để tránh gọi notifyListeners trong build
      Future.microtask(() {
        notifyListeners();
      });
      recalculateTDEE(); // Recalculate TDEE when gender changes
    }
  }

  // Phương thức để tải dữ liệu người dùng từ Map (dùng cho đồng bộ với Firebase)
  void loadUserDataFromMap(Map<String, dynamic> userData) {
    try {
      debugPrint('🔄 Đang tải dữ liệu người dùng từ Map...');
      
      // Tải các thông tin cơ bản nếu có
      _userId = userData['id'] ?? userData['user_id'] ?? _userId;
      _email = userData['email'] ?? _email;
      _name = userData['display_name'] ?? userData['name'] ?? _name;
      
      // Tải các thông số người dùng
      _gender = userData['gender'] ?? _gender;
      _age = userData['age'] != null ? int.tryParse(userData['age'].toString()) ?? _age : _age;
      _heightCm = userData['height_cm'] != null ? double.tryParse(userData['height_cm'].toString()) ?? _heightCm : _heightCm;
      _weightKg = userData['weight_kg'] != null ? double.tryParse(userData['weight_kg'].toString()) ?? _weightKg : _weightKg;
      _activityLevel = userData['activity_level'] ?? _activityLevel;
      debugPrint('📋 Tải activity_level: $_activityLevel');
      
      _goal = userData['goal'] ?? _goal;
      debugPrint('📋 Tải goal: $_goal');
      
      _pace = userData['pace'] != null ? double.tryParse(userData['pace'].toString()) ?? _pace : _pace;
      
      // Tải các thông số bổ sung
      _targetWeightKg = userData['target_weight_kg'] != null ? double.tryParse(userData['target_weight_kg'].toString()) ?? _targetWeightKg : _targetWeightKg;
      _event = userData['event'] ?? _event;
      
      // Tải thông tin về sự kiện (ngày tháng năm)
      if (userData['event_date'] != null) {
        try {
          DateTime eventDate = DateTime.parse(userData['event_date']);
          _eventDay = eventDate.day;
          _eventMonth = eventDate.month;
          _eventYear = eventDate.year;
        } catch (e) {
          debugPrint('⚠️ Lỗi khi phân tích ngày sự kiện: $e');
        }
      }
      
      // Tải các thông tin về chế độ ăn và sức khỏe
      if (userData['diet_restrictions'] != null) {
        debugPrint('📋 diet_restrictions raw data: ${userData['diet_restrictions']}');
        debugPrint('📋 diet_restrictions type: ${userData['diet_restrictions'].runtimeType}');
        
        if (userData['diet_restrictions'] is List) {
          _dietRestrictions = List<String>.from(userData['diet_restrictions']);
          debugPrint('📋 Đã tải diet_restrictions list: $_dietRestrictions');
        } else if (userData['diet_restrictions'] is String) {
          _dietRestrictions = [userData['diet_restrictions']];
          debugPrint('📋 Đã tải diet_restrictions string: $_dietRestrictions');
        }
      } else {
        debugPrint('⚠️ Không tìm thấy trường diet_restrictions trong dữ liệu');
      }
      
      if (userData['diet_preference'] != null) {
        _dietPreference = userData['diet_preference'];
        debugPrint('📋 Đã tải diet_preference: $_dietPreference');
      } else {
        debugPrint('⚠️ Không tìm thấy trường diet_preference trong dữ liệu');
      }
      
      if (userData['health_conditions'] != null) {
        debugPrint('📋 health_conditions raw data: ${userData['health_conditions']}');
        debugPrint('📋 health_conditions type: ${userData['health_conditions'].runtimeType}');
        
        if (userData['health_conditions'] is List) {
          _healthConditions = List<String>.from(userData['health_conditions']);
          debugPrint('📋 Đã tải health_conditions list: $_healthConditions');
        } else if (userData['health_conditions'] is String) {
          _healthConditions = [userData['health_conditions']];
          debugPrint('📋 Đã tải health_conditions string: $_healthConditions');
        }
      } else {
        debugPrint('⚠️ Không tìm thấy trường health_conditions trong dữ liệu');
      }
      
      // Tải các thông số về dinh dưỡng
      _tdeeCalories = userData['tdee_calories'] != null ? double.tryParse(userData['tdee_calories'].toString()) ?? _tdeeCalories : _tdeeCalories;
      _tdeeProtein = userData['tdee_protein'] != null ? double.tryParse(userData['tdee_protein'].toString()) ?? _tdeeProtein : _tdeeProtein;
      _tdeeCarbs = userData['tdee_carbs'] != null ? double.tryParse(userData['tdee_carbs'].toString()) ?? _tdeeCarbs : _tdeeCarbs;
      _tdeeFat = userData['tdee_fat'] != null ? double.tryParse(userData['tdee_fat'].toString()) ?? _tdeeFat : _tdeeFat;
      
      // Nếu TDEE trống, tính toán lại
      if (_tdeeCalories <= 0) {
        recalculateTDEE();
      }
      
      // Cập nhật nutrition goals
      if (userData['nutrition_goals'] != null && userData['nutrition_goals'] is Map) {
        Map<String, dynamic> goalsData = Map<String, dynamic>.from(userData['nutrition_goals']);
        
        // Bổ sung thiết lập trực tiếp cho các thuộc tính của _nutritionGoals
        if (goalsData.containsKey('calories')) {
          _nutritionGoals['calories'] = double.tryParse(goalsData['calories'].toString()) ?? _nutritionGoals['calories'] ?? 0.0;
        }
        if (goalsData.containsKey('protein')) {
          _nutritionGoals['protein'] = double.tryParse(goalsData['protein'].toString()) ?? _nutritionGoals['protein'] ?? 0.0;
        }
        if (goalsData.containsKey('carbs')) {
          _nutritionGoals['carbs'] = double.tryParse(goalsData['carbs'].toString()) ?? _nutritionGoals['carbs'] ?? 0.0;
        }
        if (goalsData.containsKey('fat')) {
          _nutritionGoals['fat'] = double.tryParse(goalsData['fat'].toString()) ?? _nutritionGoals['fat'] ?? 0.0;
        }
        if (goalsData.containsKey('fiber')) {
          _nutritionGoals['fiber'] = double.tryParse(goalsData['fiber'].toString()) ?? _nutritionGoals['fiber'] ?? 0.0;
        }
        if (goalsData.containsKey('sugar')) {
          _nutritionGoals['sugar'] = double.tryParse(goalsData['sugar'].toString()) ?? _nutritionGoals['sugar'] ?? 0.0;
        }
        if (goalsData.containsKey('water')) {
          _nutritionGoals['water'] = double.tryParse(goalsData['water'].toString()) ?? _nutritionGoals['water'] ?? 0.0;
        }
        if (goalsData.containsKey('cholesterol')) {
          _nutritionGoals['cholesterol'] = double.tryParse(goalsData['cholesterol'].toString()) ?? _nutritionGoals['cholesterol'] ?? 0.0;
        }
        
        debugPrint('📋 Đã tải nutrition_goals: calories=${_nutritionGoals['calories']}, protein=${_nutritionGoals['protein']}, carbs=${_nutritionGoals['carbs']}, fat=${_nutritionGoals['fat']}');
      } else {
        // Nếu không có nutrition_goals, cập nhật từ các giá trị riêng lẻ
        debugPrint('⚠️ Không tìm thấy trường nutrition_goals trong dữ liệu, sẽ tính toán lại từ TDEE');
        updateNutritionGoalsByTDEE();
      }
      
      debugPrint('✅ Đã tải thành công dữ liệu người dùng từ Map');
      
      // Lưu dữ liệu đã đồng bộ vào local storage
      saveUserData();
      
      // Thông báo thay đổi
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu người dùng từ Map: $e');
    }
  }

  // Mục tiêu dinh dưỡng chi tiết
  double? fiber_target;
  double? sugar_target;
  double? sodium_target;
}
