import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../utils/nutrition_calculator.dart';
import '../services/meal_plan_api_service.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import '../models/meal_plan.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import 'food_nutrition_detail_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../providers/food_provider.dart';
import '../providers/user_data_provider.dart';
import '../providers/user_auth_provider.dart';
import '../providers/meal_plan_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart' as main_app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/config.dart' as app_config;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';

// Extension to make text smaller
extension TextScaling on Text {
  Text scaled() {
    final TextStyle? style = this.style;
    final scaleFactor = 0.85; // Scale all text to 85% of original size

    if (style != null) {
      // Scale the existing style's font size
      final double? fontSize = style.fontSize;
      final newFontSize = fontSize != null ? fontSize * scaleFactor : 12.0 * scaleFactor;

      return Text(
        data ?? '',
        style: style.copyWith(fontSize: newFontSize),
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        locale: locale,
      );
    } else {
      // If no style was defined, use a default size
      return Text(
        data ?? '',
        style: TextStyle(fontSize: 12.0 * scaleFactor),
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        locale: locale,
      );
    }
  }
}

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({Key? key}) : super(key: key);

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  int _selectedDayIndex = 0; // Will be set to current day in initState
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  MealPlan? _mealPlan;
  FirestoreService? _firestoreService;
  bool _isFirebaseInitialized = false;

  final List<String> _daysOfWeek = [
    'T.2', 'T.3', 'T.4', 'T.5', 'T.6', 'T.7', 'CN'
  ];

  final List<String> _englishDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  // Stream subscription để lắng nghe thay đổi từ Firestore
  StreamSubscription<Map<String, dynamic>>? _mealPlanSubscription;

  // Stream subscription để lắng nghe thay đổi từ UserDataProvider
  StreamSubscription? _userDataSubscription;

  // Lưu trữ số tuần hiện tại để so sánh khi cần tạo mới kế hoạch
  int? _currentWeekNumber;

  // Lưu trữ thời điểm cập nhật kế hoạch ăn mới nhất
  DateTime? _lastMealPlanUpdateTime;
  bool _isGeneratingPlanInProgress = false; // Thêm biến để theo dõi tiến trình tạo kế hoạch

  @override
  void initState() {
    super.initState();

    // Lấy ngày hiện tại và cập nhật selected day index
    final currentDay = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    _selectedDayIndex = currentDay - 1; // Chuyển sang index 0-6

    // Lưu trữ số tuần hiện tại
    final now = DateTime.now();
    _currentWeekNumber = _getWeekNumber(now);

    // Kiểm tra biến từ main.dart
    if (main_app.isFirebaseInitialized) {
      _isFirebaseInitialized = true;
    }

    // Khởi tạo Firebase và các service trước
    _initializeFirebaseServices();

    // Lắng nghe thay đổi dữ liệu người dùng để tự động cập nhật kế hoạch ăn
    _listenToUserDataChanges();
  }

  @override
  void dispose() {
    // Hủy các subscription khi widget bị hủy
    _mealPlanSubscription?.cancel();
    _userDataSubscription?.cancel();
    super.dispose();
  }

  // Hàm khởi tạo Firebase services
  Future<void> _initializeFirebaseServices() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Kiểm tra nếu Firebase đã được khởi tạo
      Firebase.app();

      // Khởi tạo FirestoreService
      _firestoreService = FirestoreService();
      _isFirebaseInitialized = true;

      // Thiết lập listener cho dữ liệu realtime
      _listenToMealPlanChanges();

      // Tiếp tục tải dữ liệu
      _loadUserProfile();
      _loadMealPlan();
    } catch (e) {
      // Log lỗi chi tiết
      _logFirebaseError(e);

      // Thử khởi tạo Firebase với options tường minh
      try {
        // Thử khởi tạo Firebase với options tường minh

        // Tạo Firebase options tường minh
        const androidApiKey = 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0'; // Thay thế bằng API key thực
        const projectId = 'openfood-test';  // Thay thế bằng project ID thực
        const messagingSenderId = '622073990105';  // Thay thế bằng sender ID thực
        const appId = '1:622073990105:android:7ca0800c7e00e32ec4909d';  // Thay thế bằng App ID thực

        // Lấy package name thực tế
        final packageName = await _getPackageName();

        // Tạo options
        final options = FirebaseOptions(
          apiKey: androidApiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
        );

        // Thử khởi tạo Firebase với options
        await Firebase.initializeApp(options: options);

        // Gán biến toàn cục
        main_app.isFirebaseInitialized = true;
        _isFirebaseInitialized = true;

        // Khởi tạo FirestoreService
        _firestoreService = FirestoreService();

        // Thiết lập listener cho dữ liệu realtime
        _listenToMealPlanChanges();

        // Tiếp tục tải dữ liệu
        _loadUserProfile();
        _loadMealPlan();

        return;
      } catch (initError) {
        // Không thể khởi tạo Firebase với options
        _logFirebaseError(initError);

        // Thử khởi tạo không cần options
        try {
          // Thử khởi tạo Firebase không cần options
          await Firebase.initializeApp();

          // Gán biến toàn cục
          main_app.isFirebaseInitialized = true;
          _isFirebaseInitialized = true;

          // Khởi tạo FirestoreService
          _firestoreService = FirestoreService();

          // Thiết lập listener cho dữ liệu realtime
          _listenToMealPlanChanges();

          // Tiếp tục tải dữ liệu
          _loadUserProfile();
          _loadMealPlan();

          return;
        } catch (noOptionsError) {
          // Không thể khởi tạo Firebase không cần options
          _logFirebaseError(noOptionsError);
        }
      }

      setState(() {
        _isFirebaseInitialized = false;
        _hasError = true;
        _errorMessage = 'Firebase chưa được khởi tạo.\n\nNguyên nhân có thể là:\n'
            '1. Package name không khớp với cấu hình Firebase\n'
            '2. File google-services.json không đúng hoặc bị thiếu\n'
            '3. Các options không đúng\n\n'
            'Chi tiết lỗi: ${_getReadableErrorMessage(e.toString())}';
        _isLoading = false;
      });

      // Tải mock data khi Firebase không khả dụng
      _loadMockData();
    }
  }

  // Ghi log lỗi Firebase chi tiết
  void _logFirebaseError(dynamic error) {
    try {
      final errorString = error.toString();
      final stackTrace = StackTrace.current.toString();

      // Ghi nhận lỗi Firebase (silent logging)

      // Lấy thông tin thiết bị và ứng dụng
      _getPackageName().then((packageName) {
        // End of Firebase error logging
      });

      // Trong thực tế bạn có thể lưu log vào file hoặc gửi lên server
    } catch (e) {
      // Handling log error failure silently
    }
  }

  // Lấy thông báo lỗi dễ đọc
  String _getReadableErrorMessage(String errorString) {
    if (errorString.contains('no Firebase App')) {
      return 'Firebase chưa được khởi tạo';
    } else if (errorString.contains('failed to get project configuration')) {
      return 'Không thể lấy cấu hình Firebase - kiểm tra file google-services.json';
    } else if (errorString.contains('The application\'s package id')) {
      return 'Package name không khớp với cấu hình Firebase';
    } else {
      // Trả về 100 ký tự đầu tiên của lỗi để tránh quá dài
      return errorString.length > 100 ? errorString.substring(0, 100) + '...' : errorString;
    }
  }

  // Tải dữ liệu người dùng từ Firestore
  Future<void> _loadUserProfile() async {
    if (!_isFirebaseInitialized || _firestoreService == null) {
      // Bỏ qua _loadUserProfile vì Firebase chưa được khởi tạo
      return;
    }

    try {
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);

      // Tải dữ liệu từ Firestore
      await userDataProvider.
      loadFromFirestore();

      // Đồng bộ với API nếu được bật
      if (userDataProvider.syncEnabled) {
        userDataProvider.sendToApi();
      }
    } catch (e) {
      // Lỗi khi tải dữ liệu người dùng (silent logging)
    }
  }

  // Hàm lắng nghe thay đổi kế hoạch ăn realtime từ Firestore
  void _listenToMealPlanChanges() {
    // Hủy subscription hiện tại nếu có
    _mealPlanSubscription?.cancel();

    if (!_isFirebaseInitialized || _firestoreService == null) {
      // Không thể lắng nghe thay đổi vì Firebase chưa được khởi tạo
      return;
    }

    try {
      // Bắt đầu lắng nghe thay đổi kế hoạch ăn từ Firestore

      // Đăng ký lắng nghe thay đổi từ Firestore
      _mealPlanSubscription = _firestoreService!.streamWeeklyMealPlan().listen(
        (mealPlanData) {
          if (!mounted) return;

          if (mealPlanData.isNotEmpty) {
            print('✅ Nhận được cập nhật kế hoạch ăn từ Firestore (realtime)');
            setState(() {
              _mealPlan = MealPlan.fromJson(mealPlanData);
              _isLoading = false;
              _hasError = false;
            });
          }
        },
        onError: (error) {
          print('❌ Lỗi khi lắng nghe thay đổi: $error');
        }
      );
    } catch (e) {
      print('❌ Lỗi khi thiết lập listener: $e');
    }
  }

  // Tải kế hoạch ăn từ Firebase
  Future<void> _loadMealPlan() async {
    if (!_isFirebaseInitialized || _firestoreService == null) {
      print('⚠️ Firebase chưa được khởi tạo, chuyển sang dùng mock data');
      _loadMockData();
      return;
    }

    // Bắt đầu loading nếu chưa loading
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    // Kiểm tra cờ useDirectFirestore
    final useDirectFirestore = app_config.useDirectFirestore;
    print('🔍 Kiểm tra useDirectFirestore: $useDirectFirestore');

    try {
      // Kiểm tra xác thực
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('Không xác định được ID người dùng');
      }

      print('🔍 Đang tìm kiếm kế hoạch ăn cho người dùng: $userId');

      // Đọc dữ liệu từ latest_meal_plans trước
      final latestDocSnapshot = await FirebaseFirestore.instance
          .collection('latest_meal_plans')
          .doc(userId)
          .get();

      if (latestDocSnapshot.exists && latestDocSnapshot.data() != null) {
        // Đã tìm thấy dữ liệu trong latest_meal_plans
        final result = latestDocSnapshot.data()!;
        print('✅ Đã tải kế hoạch trực tiếp từ latest_meal_plans');

        if (mounted) {
          setState(() {
            _mealPlan = MealPlan.fromJson(result);
            _isLoading = false;
            _hasError = false;
          });

          // Kiểm tra và tạo kế hoạch ăn mới nếu đã sang tuần mới
          await _checkAndGenerateForNewWeek();
        }
        return; // Đã tìm thấy dữ liệu, không cần kiểm tra thêm
      }

      // Nếu không tìm thấy trong latest_meal_plans, kiểm tra meal_plans
      print('⚠️ Không tìm thấy kế hoạch ăn trong latest_meal_plans, kiểm tra meal_plans');
      final docSnapshot = await FirebaseFirestore.instance
          .collection('meal_plans')
          .doc(userId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        // Đã tìm thấy dữ liệu trong meal_plans
        final result = docSnapshot.data()!;
        print('✅ Đã tải kế hoạch trực tiếp từ meal_plans');

        if (mounted) {
          setState(() {
            _mealPlan = MealPlan.fromJson(result);
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        // Không tìm thấy dữ liệu, cần tạo kế hoạch ăn mới
        print('⚠️ Không tìm thấy kế hoạch ăn trong Firestore, tạo mới');

        // Hiển thị thông báo đang tạo mới
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đang tạo kế hoạch ăn mới...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Lấy mục tiêu dinh dưỡng từ dữ liệu người dùng
        final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
        
        // Get nutrition targets using the utility class
        final nutritionTargets = NutritionCalculator.calculateNutritionTargets(userDataProvider);
        
        final caloriesTarget = nutritionTargets['calories']!;
        final proteinTarget = nutritionTargets['protein']!;
        final fatTarget = nutritionTargets['fat']!;
        final carbsTarget = nutritionTargets['carbs']!;

        try {
          if (useDirectFirestore) {
            try {
              // Sử dụng MealPlanProvider để tạo kế hoạch ăn mới
              print('🔄 Sử dụng MealPlanProvider để tạo kế hoạch ăn mới (useDirectFirestore=true)');
              final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);

              // Lấy cờ isLoading hiện tại của provider
              bool wasLoading = mealPlanProvider.isLoading;

              await mealPlanProvider.generateWeeklyMealPlan(
                userId: userId,
                caloriesGoal: caloriesTarget.toDouble(),
                proteinGoal: proteinTarget.toDouble(),
                fatGoal: fatTarget.toDouble(),
                carbsGoal: carbsTarget.toDouble(),
              );

              // Kiểm tra nếu provider đã từ loading sang không loading
              // tức là đã hoàn thành việc tạo kế hoạch
              if (wasLoading && !mealPlanProvider.isLoading) {
                print('🔔 Provider đã hoàn thành việc tạo kế hoạch');
              }

              // Nếu MealPlanProvider đã tạo kế hoạch ăn, sử dụng kế hoạch đó
              if (mealPlanProvider.currentMealPlan != null) {
                print('✅ Đã tạo kế hoạch ăn mới từ MealPlanProvider');
                setState(() {
                  _mealPlan = mealPlanProvider.currentMealPlan;
                  _isLoading = false;
                  _hasError = false;
                });
                return;
              } else {
                print('⚠️ MealPlanProvider không tạo được kế hoạch ăn, thử phương pháp trực tiếp');
              }
            } catch (providerError) {
              print('❌ Lỗi khi sử dụng MealPlanProvider: $providerError');
            }
          }

          // Nếu không sử dụng useDirectFirestore hoặc MealPlanProvider thất bại, gọi API trực tiếp

          // Kiểm tra nếu đang có tiến trình tạo kế hoạch khác
          if (_isGeneratingPlanInProgress) {
            print('⚠️ _loadMealPlan (API direct): Đang có một tiến trình tạo kế hoạch khác, vui lòng đợi.');
            if (mounted && _isLoading) { // Nếu đang loading, dừng lại
              setState(() { _isLoading = false; });
            }
            return; // Thoát sớm
          }
          if (mounted) { // Đặt cờ nếu widget còn mounted
             setState(() {
               _isGeneratingPlanInProgress = true;
             });
          } else {
              print('⚠️ _loadMealPlan (API direct): Widget không còn mounted, hủy.');
              return;
          }
          print('🔄 Gọi API trực tiếp để tạo kế hoạch ăn mới');

          // Tạo dữ liệu JSON cho body
          final requestData = {
            'user_id': userId,
            'calories_target': caloriesTarget,
            'protein_target': proteinTarget,
            'fat_target': fatTarget,
            'carbs_target': carbsTarget,
            'use_ai': true,
          };

          // Thêm tất cả thông tin từ onboarding
          // Thêm preferences nếu có
          if (userDataProvider.preferences != null && userDataProvider.preferences.isNotEmpty) {
            requestData['preferences'] = userDataProvider.preferences;
          }
          
          // Thêm allergies nếu có
          if (userDataProvider.allergies != null && userDataProvider.allergies.isNotEmpty) {
            requestData['allergies'] = userDataProvider.allergies;
          }
          
          // Thêm cuisine_style nếu có
          if (userDataProvider.cuisineStyle != null && userDataProvider.cuisineStyle!.isNotEmpty) {
            requestData['cuisine_style'] = userDataProvider.cuisineStyle!;
          }
          
          // Thêm diet_restrictions nếu có
          if (userDataProvider.dietRestrictions != null && userDataProvider.dietRestrictions.isNotEmpty) {
            requestData['diet_restrictions'] = userDataProvider.dietRestrictions;
          }
          
          // Thêm diet_preference nếu có
          if (userDataProvider.dietPreference != null && userDataProvider.dietPreference.isNotEmpty) {
            requestData['diet_preference'] = userDataProvider.dietPreference;
          }
          
          // Thêm health_conditions nếu có
          if (userDataProvider.healthConditions != null && userDataProvider.healthConditions.isNotEmpty) {
            requestData['health_conditions'] = userDataProvider.healthConditions;
          }
          
          // Thêm mục tiêu dinh dưỡng chi tiết nếu có
          if (userDataProvider.fiber_target != null) {
            requestData['fiber_target'] = userDataProvider.fiber_target!; // Sử dụng null assertion
          }
          
          if (userDataProvider.sugar_target != null) {
            requestData['sugar_target'] = userDataProvider.sugar_target!; // Sử dụng null assertion
          }
          
          if (userDataProvider.sodium_target != null) {
            requestData['sodium_target'] = userDataProvider.sodium_target!; // Sử dụng null assertion
          }

          // Sử dụng endpoint POST /api/meal-plan/generate để tạo kế hoạch ăn mới
          final headers = await ApiService.getAuthHeaders();
          final generateUrl = Uri.parse('${app_config.apiBaseUrl}${app_config.ApiEndpoints.generateMealPlan}');

          print('🔄 Đang tạo kế hoạch ăn mới từ API: $generateUrl');
          print('📦 Dữ liệu gửi đi: ${jsonEncode(requestData)}');

          final response = await http.post(
            generateUrl,
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestData),
          ).timeout(
            Duration(seconds: 60), // Tăng timeout lên 60 giây vì tạo kế hoạch ăn có thể mất nhiều thời gian
            onTimeout: () {
              print('⏱️ Timeout khi tạo kế hoạch ăn mới');
              return http.Response('{"error": "Timeout"}', 408);
            },
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            print('✅ Đã gửi yêu cầu tạo kế hoạch ăn mới thành công');

            // Hiển thị thông báo thành công
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã gửi yêu cầu tạo kế hoạch ăn mới, đang chờ cập nhật từ Firebase...'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }

            // Đợi một lúc để Firebase cập nhật dữ liệu
            await Future.delayed(Duration(seconds: 2));

            // Đọc lại dữ liệu từ latest_meal_plans trước
            final latestUpdatedDoc = await FirebaseFirestore.instance
                .collection('latest_meal_plans')
                .doc(userId)
                .get();

            if (latestUpdatedDoc.exists && latestUpdatedDoc.data() != null) {
              final result = latestUpdatedDoc.data()!;
              print('✅ Đã tải kế hoạch mới từ latest_meal_plans');

              if (mounted) {
                setState(() {
                  _mealPlan = MealPlan.fromJson(result);
                  _isLoading = false;
                  _hasError = false;
                });
              }
              return;
            }

            // Nếu không tìm thấy trong latest_meal_plans, kiểm tra meal_plans
            print('⚠️ Không tìm thấy kế hoạch ăn trong latest_meal_plans sau khi tạo, kiểm tra meal_plans');
            final updatedDoc = await FirebaseFirestore.instance
                .collection('meal_plans')
                .doc(userId)
                .get();

            if (updatedDoc.exists && updatedDoc.data() != null) {
              final result = updatedDoc.data()!;
              print('✅ Đã tải kế hoạch mới từ meal_plans');

      if (mounted) {
        setState(() {
          _mealPlan = MealPlan.fromJson(result);
          _isLoading = false;
                  _hasError = false;
                });
              }
            } else {
              // Nếu vẫn không có dữ liệu, tạo dữ liệu mẫu
              print('⚠️ Không tìm thấy kế hoạch ăn trong Firestore sau khi tạo, sử dụng dữ liệu mẫu');
              setState(() {
                _isLoading = false;
              });
              _loadMockData();
            }
          } else {
            // Lỗi khi tạo kế hoạch ăn mới
            print('❌ Lỗi khi tạo kế hoạch ăn mới: ${response.statusCode} - ${response.body}');
            throw Exception('Lỗi khi tạo kế hoạch ăn mới: ${response.statusCode}');
          }
        } catch (apiError) {
          print('❌ Lỗi khi gọi API tạo kế hoạch ăn: $apiError');

          // Nếu không thể tạo kế hoạch ăn mới qua API, tạo dữ liệu mẫu
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          _loadMockData();
        } finally {
          if (mounted) {
            setState(() {
              _isGeneratingPlanInProgress = false;
            });
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi khi tải kế hoạch ăn: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Không thể tải kế hoạch ăn: ${e.toString()}';
        });

        // Hiển thị thông báo lỗi cho người dùng
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải kế hoạch ăn: ${e.toString().length > 100 ? e.toString().substring(0, 100) + '...' : e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );

        // Load dữ liệu mẫu nếu có lỗi
        _loadMockData();
      }

      // Tải dữ liệu mẫu khi có lỗi
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _loadMockData();
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPlanInProgress = false;
        });
      }
    }
  }

  // Sync meal plan data with API
  Future<void> _syncMealPlanToAPI(Map<String, dynamic> mealPlanData) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final apiConnected = await ApiService.checkConnection();
        if (apiConnected) {
          // Convert Timestamp objects to ISO strings
          final convertedData = _convertFirestoreTimestamps(mealPlanData);

          // Add user ID to data
          final dataWithUserId = {
            'user_id': userId,
            ...convertedData,
            'updated_at': DateTime.now().toIso8601String(),
          };

          final success = await ApiService.sendMealPlan(dataWithUserId);
          if (success) {
            print('✅ Đã đồng bộ kế hoạch ăn lên API');
          } else {
            print('❌ Không thể đồng bộ kế hoạch ăn lên API');
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi khi đồng bộ kế hoạch ăn lên API: $e');
    }
  }

  // Hàm chuyển đổi Timestamp từ Firestore sang dạng chuỗi ISO
  Map<String, dynamic> _convertFirestoreTimestamps(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    void convertValue(dynamic value, Function(dynamic) convert) {
      if (value is Map<String, dynamic>) {
        value.forEach((key, val) {
          value[key] = convert(val);
        });
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          value[i] = convert(value[i]);
        }
      }
    }

    dynamic convert(dynamic value) {
      if (value == null) {
        return null;
      } else if (value.toString().contains('Timestamp')) {
        // Chuyển đổi Timestamp thành chuỗi ISO
        try {
          // Nếu là Timestamp từ Firestore
          return value.toDate().toIso8601String();
        } catch (e) {
          // Nếu không thể convert, trả về chuỗi
          return value.toString();
        }
      } else if (value is Map) {
        convertValue(value, convert);
      } else if (value is List) {
        convertValue(value, convert);
      }
      return value;
    }

    result.forEach((key, value) {
      result[key] = convert(value);
    });

    return result;
  }

  // Đồng bộ dữ liệu kế hoạch ăn với Firestore
  Future<void> _syncMealPlanData(Map<String, dynamic> mealPlanData) async {
    if (!_isFirebaseInitialized || _firestoreService == null) {
      print('⚠️ Bỏ qua _syncMealPlanData vì Firebase chưa được khởi tạo');
      return;
    }

    // Try API sync first
    await _syncMealPlanToAPI(mealPlanData);

    // Backup to Firestore
    try {
      await _firestoreService!.updateMealPlan(mealPlanData);
      print('✅ Đã đồng bộ kế hoạch ăn lên Firestore (backup)');
    } catch (e) {
      print('❌ Lỗi khi đồng bộ kế hoạch ăn lên Firestore: $e');
    }
  }

  // Load mock data when Firebase is not available
  Future<void> _loadMockData() async {
    try {
      final mockResult = await MealPlanApiService.getMockMealPlan();
      if (mounted) {
        setState(() {
          _mealPlan = MealPlan.fromJson(mockResult);
          _isLoading = false;
        });
      }
    } catch (mockError) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Không thể tải dữ liệu mẫu: $mockError';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply a custom text scale factor to make all text smaller
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: 1.0, // Use default text size scaling
      ),
      child: Scaffold(
        body: SafeArea(
         child: _isLoading
              ? _buildLoadingState()
              : _hasError
                  ? _buildErrorState()
                  : _buildBody(),
        ),

      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 60),
          SizedBox(height: 16),
          Text(
            'Lỗi: $_errorMessage',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.red.shade700),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('Thử lại'),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _errorMessage = '';
              });
              _initializeFirebaseServices(); // Hoặc _loadMealPlan() tùy theo logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Đang tải kế hoạch thực đơn...'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_mealPlan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Không có dữ liệu kế hoạch thực đơn'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateNewMealPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Tạo kế hoạch ăn mới', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }

    // Debug - in thông tin về kế hoạch ăn
    print('🍽️ MealPlan.weeklyPlan có ${_mealPlan!.weeklyPlan.length} ngày');
    print('🍽️ Các ngày có trong kế hoạch: ${_mealPlan!.weeklyPlan.keys.toList()}');

    final selectedDayName = _englishDays[_selectedDayIndex];
    print('🍽️ Ngày đã chọn: $selectedDayName');

    final dayPlan = _mealPlan!.weeklyPlan[selectedDayName];

    if (dayPlan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Không có dữ liệu cho ngày đã chọn'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateNewMealPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: Text('Tạo kế hoạch ăn mới'),
            ),
          ],
        ),
      );
    }

    // Get total nutrition values for the day
    final totalCalories = dayPlan.nutritionSummary['calories']?.round() ?? 0;
    final totalProtein = dayPlan.nutritionSummary['protein']?.round() ?? 0;
    final totalFat = dayPlan.nutritionSummary['fat']?.round() ?? 0;
    final totalCarbs = dayPlan.nutritionSummary['carbs']?.round() ?? 0;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDayTabs(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                    'Kế hoạch dinh dưỡng cân bằng chất',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.blue),
                        onPressed: _loadMealPlan,
                        tooltip: 'Tải lại kế hoạch',
                      ),
                    ],
                  ),
                ),
                _buildNutritionSummary(
                  calories: totalCalories,
                  protein: totalProtein,
                  fat: totalFat,
                  carbs: totalCarbs,
                ),

                // Build each meal type
                ...dayPlan.meals.entries.map((entry) {
                  final mealType = entry.key;
                  final meals = entry.value;

                  if (meals.isEmpty) return SizedBox.shrink();

                  IconData mealIcon;
                  switch (mealType) {
                    case 'Bữa sáng':
                      mealIcon = Icons.wb_sunny_outlined;
                      break;
                    case 'Bữa trưa':
                      mealIcon = Icons.cloud_outlined;
                      break;
                    case 'Bữa tối':
                      mealIcon = Icons.nights_stay_outlined;
                      break;
                    case 'Bữa phụ':
                      mealIcon = Icons.restaurant_menu;
                      break;
                    default:
                      mealIcon = Icons.access_time;
                  }

                  // Use the first meal in the list for this meal type
                  final meal = meals.first;

                  return _buildMealSectionFromMeal(
                    icon: mealIcon,
                    title: mealType,
                    meal: meal,
                  );
                }).toList(),

                // Add button to add a snack if it doesn't exist
                if (!dayPlan.meals.containsKey('Bữa phụ'))
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.restaurant_menu, size: 18, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Bữa phụ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Thêm một bữa ăn nhẹ vào kế hoạch dinh dưỡng của bạn',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _addSnackToMealPlan(),
                            icon: Icon(Icons.add, color: Colors.white, size: 18),
                            label: Text('Thêm bữa phụ', style: TextStyle(color: Colors.white, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: Size(double.infinity, 42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayTabs() {
    return Container(
      height: 40, // Reduced from 50
      margin: EdgeInsets.symmetric(vertical: 6), // Reduced from 8
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _daysOfWeek.length,
        padding: EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDayIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDayIndex = index;
              });
            },
            child: Container(
              width: 50, // Reduced from 70
              margin: EdgeInsets.symmetric(horizontal: 3), // Reduced from 4
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight.withOpacity(0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(15), // Adjusted for smaller size
                border: isSelected 
                    ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5) 
                    : null,
              ),
              child: Center(
                child: Text(
                  _daysOfWeek[index],
                  style: TextStyle(
                    fontSize: 13, // Reduced from 14
                    color: isSelected ? AppColors.primary : Colors.black54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNutritionSummary({
    required int calories,
    required int protein,
    required int fat,
    required int carbs,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 16, color: Colors.blue.shade700),
              SizedBox(width: 6),
              Text(
                'Tổng dinh dưỡng trong ngày',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutrientItem(
                icon: Icons.local_fire_department,
                color: Colors.red.shade600,
                value: calories.toString(),
                unit: 'Calo',
              ),
              _buildNutrientItem(
                icon: Icons.fitness_center,
                color: Colors.blue.shade700,
                value: '${protein}g',
                unit: 'Protein',
              ),
              _buildNutrientItem(
                icon: Icons.water_drop_outlined,
                color: Colors.amber.shade700,
                value: '${fat}g',
                unit: 'Chất béo',
              ),
              _buildNutrientItem(
                icon: Icons.grass,
                color: Colors.green.shade600,
                value: '${carbs}g',
                unit: 'Carbs',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientItem({
    required IconData icon,
    required Color color,
    required String value,
    required String unit,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSectionFromMeal({
    required IconData icon,
    required String title,
    required Meal meal,
  }) {
    // Get nutrition values for the meal
    final calories = meal.nutrition['calories']?.round() ?? 0;
    final protein = meal.nutrition['protein']?.round() ?? 0;
    final fat = meal.nutrition['fat']?.round() ?? 0;
    final carbs = meal.nutrition['carbs']?.round() ?? 0;

    // Apply custom styling for different meal types
    Color mealColor;
    switch (title) {
      case 'Bữa sáng':
        mealColor = Colors.orange;
        break;
      case 'Bữa trưa':
        mealColor = Colors.blue;
        break;
      case 'Bữa tối':
        mealColor = Colors.indigo;
        break;
      case 'Bữa phụ':
        mealColor = Colors.green;
        break;
      default:
        mealColor = AppColors.primary;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with meal type and nutrition values
          Container(
            decoration: BoxDecoration(
              color: mealColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal title
                Row(
                  children: [
                    Icon(icon, size: 18, color: mealColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                // Nutrition values in a separate row with Expanded to avoid overflow
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildMealNutrient(Icons.local_fire_department, calories.toString(), 'kcal', Colors.red),
                    ),
                    Expanded(
                      child: _buildMealNutrient(Icons.adjust_rounded, protein.toString(), 'g', Colors.blue),
                    ),
                    Expanded(
                      child: _buildMealNutrient(Icons.water_drop_outlined, fat.toString(), 'g', Colors.orange),
                    ),
                    Expanded(
                      child: _buildMealNutrient(Icons.grass, carbs.toString(), 'g', Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, thickness: 1, color: AppColors.textLight.withOpacity(0.2)),

          // Meal content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal name
                Row(
                  children: [
                    Icon(Icons.restaurant, size: 16, color: mealColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meal.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // Meal description
                Text(
                  meal.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),

                SizedBox(height: 12),

                // Ingredients
                Text(
                  'Nguyên liệu:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 6),
                for (var ingredient in meal.ingredients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: mealColor)),
                        Expanded(
                          child: _buildFormattedIngredient(ingredient),
                        ),
                      ],
                    ),
                  ),

                // Hướng dẫn nấu ăn (thêm mới)
                SizedBox(height: 12),
                Text(
                  'Hướng dẫn nấu:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 6),
                if (meal.instructions != null && meal.instructions.isNotEmpty)
                  Builder(
                    builder: (context) {
                      // Tách chuỗi thành các bước riêng biệt
                      List<String> steps = [];
                      
                      // Nếu chỉ có 1 item trong instructions và nó chứa "Bước" hoặc "Step"
                      if (meal.instructions.length == 1 && 
                          (meal.instructions[0].contains("Bước") || meal.instructions[0].contains("Step"))) {
                        
                        String fullInstructions = meal.instructions[0];
                        print('🔍 DEBUGGING INSTRUCTIONS: $fullInstructions');
                        
                        // Tìm các bước bằng biểu thức chính quy với nhiều định dạng hơn
                        // Bao gồm: "Bước 1:", "Bước 1.", "Step 1:", "Step 1.", "1.", "1:", "Bước một:", v.v.
                        RegExp stepRegex = RegExp(r'(Bước \d+[:.]|Step \d+[:.]|\d+[:.]\s+|Bước [a-zA-Zà-úÀ-Ú]+[:.])');
                        
                        // In ra tất cả các match tìm được
                        Iterable<Match> testMatches = stepRegex.allMatches(fullInstructions);
                        print('🔍 Số bước tìm thấy: ${testMatches.length}');
                        testMatches.forEach((match) {
                          print('🔍 Tìm thấy bước: "${fullInstructions.substring(match.start, match.end)}" tại vị trí ${match.start}');
                        });
                        
                        // Tìm tất cả các vị trí xuất hiện của "Bước X:" hoặc "Step X:"
                        Iterable<Match> matches = stepRegex.allMatches(fullInstructions);
                        List<int> startPositions = matches.map((m) => m.start).toList();
                        
                        // Nếu không tìm thấy bước theo định dạng trên, thử tách theo dấu chấm và xuống dòng
                        if (startPositions.isEmpty) {
                          print('🔍 Không tìm thấy bước theo định dạng thông thường, thử tách theo dấu chấm và xuống dòng');
                          
                          // Tách theo dấu xuống dòng
                          List<String> lineBreakSteps = fullInstructions.split(RegExp(r'\n+'));
                          if (lineBreakSteps.length > 1) {
                            print('🔍 Tách được ${lineBreakSteps.length} bước theo dấu xuống dòng');
                            steps = lineBreakSteps
                                .where((step) => step.trim().isNotEmpty)
                                .map((step) => step.trim())
                                .toList();
                          } else {
                            // Tách theo dấu chấm kèm khoảng trắng
                            List<String> periodSteps = fullInstructions.split(RegExp(r'\.\s+'));
                            if (periodSteps.length > 1) {
                              print('🔍 Tách được ${periodSteps.length} bước theo dấu chấm');
                              steps = periodSteps
                                  .where((step) => step.trim().isNotEmpty)
                                  .map((step) => step.trim() + ".")
                                  .toList();
                            } else {
                              steps = [fullInstructions];
                            }
                          }
                        } else {
                          // Tách chuỗi dựa vào các vị trí đó
                          print('🔍 Tách chuỗi theo ${startPositions.length} vị trí bắt đầu');
                          for (int i = 0; i < startPositions.length; i++) {
                            int startPos = startPositions[i];
                            int endPos = (i < startPositions.length - 1) ? startPositions[i + 1] : fullInstructions.length;
                            String step = fullInstructions.substring(startPos, endPos).trim();
                            steps.add(step);
                            print('🔍 Bước ${i+1}: $step');
                          }
                        }
                      } else {
                        // Sử dụng instructions như cũ nếu đã là danh sách
                        steps = meal.instructions;
                        print('🔍 Sử dụng instructions có sẵn: ${steps.length} bước');
                      }
                      
                      // In ra số bước cuối cùng đã xử lý
                      print('🔍 Số bước cuối cùng: ${steps.length}');
                      
                      // Hiển thị từng bước
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: steps.asMap().entries.map((entry) {
                          int index = entry.key;
                          String step = entry.value;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: mealColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: mealColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  )
                else
                  Text(
                    'Không có hướng dẫn chi tiết cho món ăn này.',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),

                // Replace and save buttons
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh, size: 16),
                        label: Text(
                          'Thay thế AI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          // Replace this meal with a new suggestion
                          _replaceMeal(title);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mealColor.withOpacity(0.1),
                          foregroundColor: mealColor,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add, size: 16),
                        label: Text(
                          'Ghi lại thực đơn',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          // Add this meal to food log
                          _addMealToFoodLog(meal, title);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mealColor.withOpacity(0.1),
                          foregroundColor: mealColor,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealNutrient(IconData icon, String value, String unit, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 9,
            color: color.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Handle replacing a meal
  Future<void> _replaceMeal(String mealType) async {
    final snackBar = SnackBar(
      content: Text('Đang thay thế $mealType...'),
      duration: Duration(seconds: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      // Check if we're authenticated
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      // Get selected day
      final selectedDay = _englishDays[_selectedDayIndex];
      final selectedDayName = _convertToAPIDay(selectedDay);

      // Get user nutrition goals using the utility class
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      final nutritionTargets = NutritionCalculator.calculateNutritionTargets(userDataProvider);
      
      // Chuyển đổi các giá trị sang double (đã là double từ NutritionCalculator)
      final caloriesTarget = nutritionTargets['calories']!;
      final proteinTarget = nutritionTargets['protein']!;
      final fatTarget = nutritionTargets['fat']!;
      final carbsTarget = nutritionTargets['carbs']!;

      // Lấy thông tin người dùng
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('Không xác định được ID người dùng');
      }

      // User preferences
      final preferences = userDataProvider.preferences;
      final allergies = userDataProvider.allergies;
      final cuisineStyle = userDataProvider.cuisineStyle;

      // Hiển thị thông báo đang xử lý
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang gửi yêu cầu thay thế $mealType đến server...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );

      // Sử dụng endpoint POST /api/meal-plan/replace-meal để thay thế bữa ăn
      final headers = await ApiService.getAuthHeaders();
      final replaceUrl = Uri.parse('${app_config.apiBaseUrl}${app_config.ApiEndpoints.replaceMeal}');

      // Tạo dữ liệu đúng định dạng cho API
      // Đặt các giá trị dinh dưỡng ở cấp cao nhất theo yêu cầu của API
      final requestData = {
        'user_id': userId,
        'day_of_week': selectedDayName,
        'meal_type': mealType,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
        'use_ai': true,
      };

      // In ra thông tin debug về các giá trị dinh dưỡng
      print('📊 Giá trị dinh dưỡng gửi đến API:');
      print('📊 calories_target: $caloriesTarget (${caloriesTarget.runtimeType})');
      print('📊 protein_target: $proteinTarget (${proteinTarget.runtimeType})');
      print('📊 fat_target: $fatTarget (${fatTarget.runtimeType})');
      print('📊 carbs_target: $carbsTarget (${carbsTarget.runtimeType})');

      // Thêm preferences dưới dạng chuỗi nếu có
      if (preferences != null && preferences.isNotEmpty) {
        requestData['preferences'] = preferences;
      }

      // Thêm allergies dưới dạng chuỗi nếu có
      if (allergies != null && allergies.isNotEmpty) {
        requestData['allergies'] = allergies;
      }

      // Thêm cuisine_style nếu có
      if (cuisineStyle != null && cuisineStyle!.isNotEmpty) {
        requestData['cuisine_style'] = cuisineStyle!;
      }
      
      // Thêm diet_restrictions nếu có
      if (userDataProvider.dietRestrictions != null && userDataProvider.dietRestrictions.isNotEmpty) {
        requestData['diet_restrictions'] = userDataProvider.dietRestrictions;
      }
      
      // Thêm diet_preference nếu có
      if (userDataProvider.dietPreference != null && userDataProvider.dietPreference.isNotEmpty) {
        requestData['diet_preference'] = userDataProvider.dietPreference;
      }
      
      // Thêm health_conditions nếu có
      if (userDataProvider.healthConditions != null && userDataProvider.healthConditions.isNotEmpty) {
        requestData['health_conditions'] = userDataProvider.healthConditions;
      }
      
      // Thêm mục tiêu dinh dưỡng chi tiết nếu có
      if (userDataProvider.fiber_target != null) {
        requestData['fiber_target'] = userDataProvider.fiber_target!; // Sử dụng null assertion
      }
      
      if (userDataProvider.sugar_target != null) {
        requestData['sugar_target'] = userDataProvider.sugar_target!; // Sử dụng null assertion
      }
      
      if (userDataProvider.sodium_target != null) {
        requestData['sodium_target'] = userDataProvider.sodium_target!; // Sử dụng null assertion
      }

      print('🔄 Đang thay thế bữa ăn từ API: $replaceUrl');
      print('📦 Dữ liệu gửi đi: ${jsonEncode(requestData)}');

      try {
        // Hiển thị thông báo đang kết nối
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đang kết nối đến máy chủ...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );

        final response = await http.post(
          replaceUrl,
          headers: {
            ...headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestData),
        ).timeout(
          Duration(seconds: 60),  // Tăng timeout lên 60 giây
          onTimeout: () {
            print('⏱️ Timeout khi thay thế bữa ăn');
            return http.Response('{"error": "Timeout"}', 408);
          },
        );

        // In ra toàn bộ thông tin về response
        print('🔍 Response status: ${response.statusCode}');
        print('🔍 Response body: ${response.body}');
        print('🔍 Response headers: ${response.headers}');

        if (response.statusCode == 200) {
        print('✅ Đã gửi yêu cầu thay thế bữa ăn thành công');

        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi yêu cầu thay thế $mealType, đang đợi cập nhật từ Firebase...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );

          // Đợi một lúc để Firebase cập nhật dữ liệu
          await Future.delayed(Duration(seconds: 2));

          // Đọc lại dữ liệu từ latest_meal_plans trước
          final latestDocSnapshot = await FirebaseFirestore.instance
              .collection('latest_meal_plans')
              .doc(userId)
              .get();

          if (latestDocSnapshot.exists && latestDocSnapshot.data() != null) {
            final result = latestDocSnapshot.data()!;
            print('✅ Đã tải kế hoạch ăn cập nhật từ latest_meal_plans');

            setState(() {
              _mealPlan = MealPlan.fromJson(result);
              _isLoading = false;
              _hasError = false;
            });

            // Hiển thị thông báo thành công
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã thay thế $mealType thành công!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }

          // Nếu không tìm thấy trong latest_meal_plans, kiểm tra meal_plans
          print('⚠️ Không tìm thấy kế hoạch ăn trong latest_meal_plans, kiểm tra meal_plans');
          final docSnapshot = await FirebaseFirestore.instance
              .collection('meal_plans')
              .doc(userId)
              .get();

          if (docSnapshot.exists && docSnapshot.data() != null) {
            final result = docSnapshot.data()!;
            print('✅ Đã tải kế hoạch ăn cập nhật từ meal_plans');

            setState(() {
              _mealPlan = MealPlan.fromJson(result);
              _isLoading = false;
              _hasError = false;
            });

              // Hiển thị thông báo thành công
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã thay thế $mealType thành công!'),
                  backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            print('⚠️ Không tìm thấy dữ liệu cập nhật trong Firestore');
            throw Exception('Không tìm thấy dữ liệu cập nhật trong Firestore');
          }
        } else if (response.statusCode == 422) {
          // Lỗi dữ liệu không hợp lệ
          print('❌ Lỗi 422 - Dữ liệu không hợp lệ: ${response.body}');

          // Phân tích lỗi chi tiết
          try {
            final errorData = jsonDecode(response.body);
            print('❌ Chi tiết lỗi JSON: $errorData');

            if (errorData['detail'] is List) {
              for (var error in errorData['detail']) {
                print('❌ Lỗi trường: ${error['loc']}, Loại: ${error['type']}, Thông báo: ${error['msg']}');
              }
            } else {
              print('❌ Chi tiết lỗi: ${errorData['detail']}');
            }

            // Hiển thị thông báo lỗi
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi dữ liệu: ${errorData['detail']}'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          } catch (e) {
            print('Không thể phân tích lỗi: $e');
          }

          throw Exception('Dữ liệu không hợp lệ: Vui lòng kiểm tra lại');
        } else if (response.statusCode == 404) {
          // Không tìm thấy kế hoạch ăn, tạo mới
          print('⚠️ Không tìm thấy kế hoạch ăn, đang tạo kế hoạch mới...');

          // Hiển thị thông báo
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không tìm thấy kế hoạch ăn, đang tạo kế hoạch mới...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );

          // Gọi phương thức tạo kế hoạch ăn mới
          await _generateNewMealPlan();

          // Sau khi tạo mới, thử thay thế bữa ăn lại
          print('🔄 Đang thử lại thay thế bữa ăn sau khi tạo kế hoạch mới...');

          // Đợi một chút để đảm bảo kế hoạch mới đã được lưu
          await Future.delayed(Duration(seconds: 3));

          // Gọi lại API thay thế bữa ăn
          final retryResponse = await http.post(
            replaceUrl,
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestData),
          ).timeout(
            Duration(seconds: 60),
            onTimeout: () {
              print('⏱️ Timeout khi thay thế bữa ăn (lần thử lại)');
              return http.Response('{"error": "Timeout"}', 408);
            },
          );

          if (retryResponse.statusCode == 200) {
            print('✅ Đã thay thế bữa ăn thành công sau khi tạo kế hoạch mới');

              // Hiển thị thông báo thành công
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã thay thế $mealType thành công!'),
                  backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Tải lại dữ liệu từ Firestore
            await _loadMealPlan();
            return;
          } else {
            print('❌ Vẫn không thể thay thế bữa ăn sau khi tạo kế hoạch mới: ${retryResponse.statusCode}');
            throw Exception('Không thể thay thế bữa ăn sau khi tạo kế hoạch mới');
          }
        } else if (response.statusCode == 403) {
          // Lỗi xác thực
          print('❌ Lỗi xác thực: ${response.statusCode} - ${response.body}');
          throw Exception('Lỗi xác thực: Vui lòng đăng nhập lại');
        } else if (response.statusCode == 500) {
          // Lỗi server
          print('❌ Lỗi server: ${response.statusCode} - ${response.body}');

          // Phân tích lỗi chi tiết
          String errorMessage = 'Lỗi server';
          try {
            final errorData = jsonDecode(response.body);
            if (errorData['detail'] != null) {
              errorMessage = errorData['detail'];

              // Kiểm tra nếu là lỗi module 'services'
              if (errorMessage.contains("module 'services' has no attribute")) {
                errorMessage = 'Lỗi cấu hình server: Thiếu module xử lý bữa ăn';
              }
            }
          } catch (e) {
            print('Không thể phân tích lỗi: $e');
          }

          // Hiển thị thông báo lỗi
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi server: $errorMessage\n\nĐang tải lại dữ liệu từ Firebase...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );

          // Thử tải lại dữ liệu từ Firebase thay vì báo lỗi
          print('⚠️ Gặp lỗi server, đang tải lại dữ liệu từ Firebase...');
          await _loadMealPlan();
          return;

          // throw Exception('Lỗi server: $errorMessage'); // Không throw exception nữa
            } else {
          // Lỗi khác
          print('❌ Lỗi khi thay thế bữa ăn: ${response.statusCode} - ${response.body}');
          throw Exception('Lỗi khi thay thế bữa ăn: ${response.statusCode}');
        }
      } catch (e) {
        print('❌❌❌ Lỗi khi gọi API: $e');
        rethrow;
      }
    } catch (e) {
      print('Lỗi khi thay thế bữa ăn: $e');

      // Xử lý lỗi kết nối
      String errorMessage = 'Không thể thay thế bữa ăn';
      Color errorColor = Colors.red;

      // Kiểm tra loại lỗi cụ thể
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra:\n'
            '1. Kết nối mạng của bạn\n'
            '2. Máy chủ API đã được khởi động\n'
            '3. Địa chỉ IP trong cấu hình đã chính xác';
        errorColor = Colors.orange;
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'Kết nối đến máy chủ quá chậm hoặc máy chủ không phản hồi. Vui lòng thử lại sau.';
        errorColor = Colors.orange;
      } else {
        errorMessage = 'Không thể thay thế bữa ăn: ${e.toString()}';
      }

      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: errorColor,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Hàm chuyển đổi định dạng ngày sang định dạng API
  String _convertToAPIDay(String day) {
    // API sử dụng định dạng "Thứ 2", "Thứ 3", v.v.
    switch (day) {
      case 'Monday': return 'Thứ 2';
      case 'Tuesday': return 'Thứ 3';
      case 'Wednesday': return 'Thứ 4';
      case 'Thursday': return 'Thứ 5';
      case 'Friday': return 'Thứ 6';
      case 'Saturday': return 'Thứ 7';
      case 'Sunday': return 'Chủ Nhật';
      default: return day;
    }
  }

  // Hàm chuyển đổi từ định dạng API sang định dạng ứng dụng
  String _convertFromAPIDay(String day) {
    // Chuyển từ tiếng Việt sang tiếng Anh
    switch (day) {
      case 'Thứ 2': return 'Monday';
      case 'Thứ 3': return 'Tuesday';
      case 'Thứ 4': return 'Wednesday';
      case 'Thứ 5': return 'Thursday';
      case 'Thứ 6': return 'Friday';
      case 'Thứ 7': return 'Saturday';
      case 'Chủ Nhật': return 'Sunday';
      default: return day;
    }
  }

  // Handle adding the meal to food log
  void _addMealToFoodLog(Meal meal, String mealType) {
    // Create a FoodItem from the meal data
    final foodItem = FoodItem(
      id: Uuid().v4(),
      name: meal.name,
      calories: meal.nutrition['calories']?.toDouble() ?? 0.0,
      protein: meal.nutrition['protein']?.toDouble() ?? 0.0,
      fat: meal.nutrition['fat']?.toDouble() ?? 0.0,
      carbs: meal.nutrition['carbs']?.toDouble() ?? 0.0,
      fiber: meal.nutrition['fiber']?.toDouble(),
      sugar: meal.nutrition['sugar']?.toDouble(),
      sodium: meal.nutrition['sodium']?.toDouble(),
      servingSize: 1.0,
      servingUnit: 'serving',
      additionalNutrients: Map<String, dynamic>.from(meal.nutrition),
    );

    // Create a FoodEntry with the FoodItem
    final foodEntry = FoodEntry(
      id: Uuid().v4(),
      description: meal.name,
      mealType: mealType,
      dateTime: DateTime.now(),
      nutritionInfo: Map<String, dynamic>.from(meal.nutrition),
      items: [foodItem],
    );

    // Navigate to the FoodNutritionDetailScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: foodEntry,
          onSave: (updatedEntry) {
            // Get the FoodProvider and add the entry
            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
            foodProvider.addFoodEntry(updatedEntry);

            // Show a success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã thêm "${meal.name}" vào nhật ký thực phẩm'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  // Hàm lấy package name (sử dụng package_info_plus)
  Future<String> _getPackageName() async {
    try {
      // Get package info
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      // Print all package information for debugging
      print('📦 App Name: ${packageInfo.appName}');
      print('📦 Package Name: ${packageInfo.packageName}');
      print('📦 Version: ${packageInfo.version}');
      print('📦 Build Number: ${packageInfo.buildNumber}');

      return packageInfo.packageName;
    } catch (e) {
      print('❌ Lỗi khi lấy package info: $e');
      return 'unknown';
    }
  }

  // Hàm kiểm tra dữ liệu Firestore

  // Phương thức kiểm tra và tạo kế hoạch ăn mới khi sang tuần mới
  Future<void> _checkAndGenerateForNewWeek() async {
    try {
      // Chỉ thực hiện kiểm tra khi đã tải được kế hoạch ăn trước đó
      if (_mealPlan == null) return;

      // Lấy ngày hiện tại
      final now = DateTime.now();
      final currentWeekNumber = _getWeekNumber(now);

      // Nếu chưa có số tuần được lưu hoặc đã sang tuần mới
      if (_currentWeekNumber == null || currentWeekNumber != _currentWeekNumber) {
        // Cập nhật số tuần hiện tại
        _currentWeekNumber = currentWeekNumber;

        // Kiểm tra xem đã bao lâu kể từ lần cập nhật cuối
        bool shouldGenerate = true;

        if (_lastMealPlanUpdateTime != null) {
          // Nếu đã cập nhật trong 24 giờ qua, không cần tạo mới
          final hoursSinceLastUpdate = now.difference(_lastMealPlanUpdateTime!).inHours;
          shouldGenerate = hoursSinceLastUpdate > 24;
        }

        if (shouldGenerate) {
          // Hiển thị thông báo cho người dùng
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã phát hiện tuần mới, đang tạo kế hoạch ăn mới...'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 3),
              ),
            );
          }

          // Gọi phương thức tạo kế hoạch ăn mới


          // Cập nhật thời gian tạo kế hoạch ăn mới nhất
          _lastMealPlanUpdateTime = DateTime.now();
        }
      }
    } catch (e) {
      // Ghi log lỗi nhưng không hiển thị lỗi cho người dùng
      // vì đây là chức năng tự động chạy ngầm
    }
  }

  // Phương thức tính số tuần trong năm
  int _getWeekNumber(DateTime date) {
    // Lấy ngày đầu tiên của năm
    final firstDayOfYear = DateTime(date.year, 1, 1);
    // Số ngày từ đầu năm
    final dayOfYear = date.difference(firstDayOfYear).inDays;

    // Tính tuần dựa trên số ngày (tuần đầu tiên là 0, nên cộng 1)
    return ((dayOfYear) / 7).floor() + 1;
  }

  // Phương thức lấy món ăn cho một ngày và loại bữa ăn cụ thể
  Meal? _getMealForDay(MealPlan mealPlan, String day, String mealType) {
    try {
      // Truy cập vào weeklyPlan để lấy ngày
      if (mealPlan.weeklyPlan.containsKey(day)) {
        // Lấy DayMealPlan cho ngày cụ thể
        final dayPlan = mealPlan.weeklyPlan[day];

        // Chuyển đổi tên bữa ăn sang tiếng Việt theo cấu trúc của DayMealPlan
        String mealTypeKey = '';
        switch (mealType) {
          case 'breakfast':
            mealTypeKey = 'Bữa sáng';
            break;
          case 'lunch':
            mealTypeKey = 'Bữa trưa';
            break;
          case 'dinner':
            mealTypeKey = 'Bữa tối';
            break;
          default:
            return null;
        }

        // Kiểm tra và trả về món ăn
        if (dayPlan!.meals.containsKey(mealTypeKey) &&
            dayPlan.meals[mealTypeKey]!.isNotEmpty) {
          return dayPlan.meals[mealTypeKey]!.first;
        }
      }
      return null;
    } catch (e) {
      print('❌ Lỗi khi lấy món ăn cho $day, $mealType: $e');
      return null;
    }
  }

  // Phương thức lắng nghe thay đổi dữ liệu người dùng
  void _listenToUserDataChanges() {
    try {
      // Lấy UserDataProvider để theo dõi thay đổi
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);

      // Lắng nghe thay đổi trong userDataProvider
      userDataProvider.addListener(() {
        // Khi dữ liệu người dùng thay đổi (mục tiêu dinh dưỡng, ưu tiên, dị ứng...)
        // Kiểm tra và tạo kế hoạch ăn mới nếu cần
        if (mounted && _mealPlan != null) {
          // Chỉ tạo kế hoạch mới nếu dữ liệu người dùng đã thay đổi đáng kể
          // và thời gian từ lần cập nhật cuối ít nhất 30 phút
          bool shouldUpdate = true;

          if (_lastMealPlanUpdateTime != null) {
            final minutesSinceLastUpdate =
                DateTime.now().difference(_lastMealPlanUpdateTime!).inMinutes;
            shouldUpdate = minutesSinceLastUpdate > 30;
          }

          if (shouldUpdate) {
            // Hiển thị thông báo cho người dùng
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Dữ liệu người dùng đã thay đổi, đang cập nhật kế hoạch ăn...'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 3),
              ),
            );

            // Gọi phương thức tạo kế hoạch ăn mới


            // Cập nhật thời gian tạo kế hoạch ăn mới nhất
            _lastMealPlanUpdateTime = DateTime.now();
          }
        }
      });
    } catch (e) {
      // Ghi log lỗi nhưng không hiển thị lỗi cho người dùng
    }
  }

  // Hiển thị dialog cấu hình API URL
  void _showApiConfig() {
    // Controller cho text field
    final apiUrlController = TextEditingController(
      text: app_config.apiOverrideUrl.isNotEmpty
          ? app_config.apiOverrideUrl
          : app_config.apiProductionUrl
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cấu hình API'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('URL hiện tại: ${app_config.apiBaseUrl}'),
              SizedBox(height: 16),
              TextField(
                controller: apiUrlController,
                decoration: InputDecoration(
                  labelText: 'API URL',
                  hintText: 'Nhập URL máy chủ API',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Sử dụng URL local
                      apiUrlController.text = app_config.apiLocalUrl;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: Text('Local'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Sử dụng URL production
                      apiUrlController.text = app_config.apiProductionUrl;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text('Production'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Xóa URL (sử dụng mặc định)
                      apiUrlController.text = '';
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: Text('Reset'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text('Buộc dùng dữ liệu mẫu: '),
                  Switch(
                    value: app_config.ApiEndpoints.forceMockData,
                    onChanged: (value) {
                      setState(() {
                        app_config.ApiEndpoints.forceMockData = value;
                      });
                      Navigator.pop(context);
                      _showApiConfig(); // Mở lại dialog để cập nhật trạng thái
                    },
                  ),
                ],
              ),

              // Thêm hướng dẫn API
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hướng dẫn kết nối API',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Chạy FastAPI trên máy tính của bạn'),
                    Text('2. Kiểm tra IP của máy tính (ipconfig hoặc ifconfig)'),
                    Text('3. Cập nhật URL local thành http://YOUR_IP:8000'),
                    Text('4. Đảm bảo máy tính và điện thoại của bạn kết nối cùng một mạng WiFi'),
                    SizedBox(height: 8),
                    Text('API status hiện tại:'),
                    _buildApiStatus(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => _showAvailableEndpoints(),
            child: Text('Kiểm tra Endpoints'),
          ),
          ElevatedButton(
            onPressed: () {
              // Cập nhật URL
              app_config.apiOverrideUrl = apiUrlController.text.trim();
              print('✅ Đã cập nhật API URL thành: ${app_config.apiBaseUrl}');

              // Cập nhật trạng thái kết nối
              _checkApiStatus().then((isConnected) {
                if (isConnected) {
                  print('✅ Đã kết nối đến API thành công');
                } else {
                  print('❌ Không thể kết nối đến API');
                }
              });
            },
            child: Text('Lưu & Tải lại'),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị trạng thái API
  Widget _buildApiStatus() {
    return FutureBuilder<bool>(
      future: _checkApiStatus(), // Hàm kiểm tra trạng thái API
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Đang kiểm tra API...'),
            ],
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == false) {
          return Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Không thể kết nối đến API: ${app_config.apiBaseUrl}',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'API đã kết nối: ${app_config.apiBaseUrl}',
                style: TextStyle(color: Colors.green, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkApiStatus() async {
    try {
      // Cố gắng ping một endpoint đơn giản, ví dụ /api-status hoặc root
      // Đảm bảo endpoint này tồn tại và trả về 200 OK nếu API hoạt động
      final response = await http.get(Uri.parse('${app_config.apiBaseUrl}/api-status'))
          .timeout(Duration(seconds: 5)); // Timeout sau 5 giây
      return response.statusCode == 200;
    } catch (e) {
      print('Lỗi kiểm tra API status: $e');
      return false;
    }
  }

  // Hiển thị danh sách các endpoint có sẵn
  void _showAvailableEndpoints() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('API Endpoints'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Các endpoint cần được cấu hình trên API:'),
              SizedBox(height: 8),

              // API endpoints
              Text('API Endpoints:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildEndpointListItem('/api/meal-plan/generate', 'Tạo kế hoạch ăn uống hàng tuần'),
              _buildEndpointListItem('/api/meal-plan/{user_id}', 'Lấy kế hoạch ăn uống theo người dùng'),
              _buildEndpointListItem('/api/replace-day', 'Thay thế một ngày trong kế hoạch'),
              _buildEndpointListItem('/api/meal-plan/replace-meal', 'Thay thế một bữa ăn cụ thể'),
              _buildEndpointListItem('/api/user-profile', 'Quản lý hồ sơ người dùng'),
              _buildEndpointListItem('/check-ai-availability', 'Kiểm tra tình trạng AI'),
              _buildEndpointListItem('/api-status', 'Kiểm tra trạng thái API'),

              SizedBox(height: 16),

              // Firestore endpoints
              Text('Firestore Endpoints:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildEndpointListItem('/firestore/meal-plans', 'Tạo/Quản lý kế hoạch ăn uống'),
              _buildEndpointListItem('/firestore/meal-plans/{plan_id}', 'Lấy/Xóa kế hoạch ăn uống theo ID'),
              _buildEndpointListItem('/firestore/users/{user_id}/meal-plans/date/{date}', 'Kế hoạch ăn uống theo ngày'),
              _buildEndpointListItem('/firestore/meal-plans/user/{user_id}', 'Kế hoạch ăn uống theo người dùng'),
              _buildEndpointListItem('/firestore/latest-meal-plan/{user_id}', 'Kế hoạch ăn uống mới nhất'),

              SizedBox(height: 16),

              // Other endpoints
              Text('Các endpoint khác:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildEndpointListItem('/generate-weekly-meal-demo', 'Lấy kế hoạch ăn mẫu'),
              _buildEndpointListItem('/usda/search', 'Tìm kiếm thực phẩm'),
              _buildEndpointListItem('/usda/food/{id}', 'Thông tin dinh dưỡng thực phẩm'),

              SizedBox(height: 16),
              Text(
                'Các endpoint trên cần được cấu hình trong FastAPI backend để app hoạt động chính xác.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị một endpoint
  Widget _buildEndpointListItem(String endpoint, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.api, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(endpoint, style: TextStyle(fontWeight: FontWeight.bold)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Phương thức định dạng nguyên liệu từ chuỗi JSON
  Widget _buildFormattedIngredient(dynamic ingredient) {
    try {
      // Nếu ingredient là Map
      if (ingredient is Map) {
        final amount = ingredient['amount'];
        final name = ingredient['name'];
        if (amount != null && name != null) {
          return Text('$amount $name', style: TextStyle(fontSize: 14));
        }
      }

      // Nếu ingredient là String nhưng có định dạng JSON
      else if (ingredient is String) {
        // Kiểm tra nếu là chuỗi JSON dạng {amount: X, name: Y}
        if (ingredient.contains('{') && ingredient.contains('}')) {
          // Trích xuất amount và name từ chuỗi
          final amountRegex = RegExp(r'amount: (.*?)[,}]');
          final nameRegex = RegExp(r'name: (.*?)[,}]');

          final amountMatch = amountRegex.firstMatch(ingredient);
          final nameMatch = nameRegex.firstMatch(ingredient);

          if (amountMatch != null && nameMatch != null) {
            final amount = amountMatch.group(1)?.trim();
            final name = nameMatch.group(1)?.trim();

            if (amount != null && name != null) {
              // Xóa bỏ dấu ngoặc kép nếu có
              final cleanName = name.replaceAll('"', '').replaceAll("'", '');
              return Text('$amount $cleanName', style: TextStyle(fontSize: 14));
            }
          }
        }

        // Nếu là chuỗi thông thường, hiển thị nguyên dạng
        return Text(ingredient, style: TextStyle(fontSize: 14));
      }

      // Trường hợp khác, chuyển đổi sang chuỗi
      return Text(ingredient.toString(), style: TextStyle(fontSize: 14));
    } catch (e) {
      // Nếu có lỗi, hiển thị nguyên liệu gốc
      return Text(ingredient.toString(), style: TextStyle(fontSize: 14));
    }
  }

  // Hàm chuyển đổi sâu từ Map<dynamic, dynamic> sang Map<String, dynamic>
  Map<String, dynamic> _deepConvertMap(dynamic inputMap) {
    // Nếu input là null, trả về map rỗng
    if (inputMap == null) {
      return {};
    }

    // Đảm bảo input là Map
    if (inputMap is! Map) {
      print('⚠️ Đầu vào không phải Map: ${inputMap.runtimeType}');
      return {};
    }

    Map<String, dynamic> result = {};

    inputMap.forEach((key, value) {
      if (value is Map) {
        // Nếu value là Map, đệ quy chuyển đổi nó
        result[key.toString()] = _deepConvertMap(value);
      } else if (value is List) {
        // Nếu value là List, chuyển đổi từng phần tử trong list
        result[key.toString()] = _convertList(value);
      } else {
        // Nếu value là giá trị nguyên thủy, giữ nguyên
        result[key.toString()] = value;
      }
    });

    return result;
  }

  // Hàm chuyển đổi List
  List<dynamic> _convertList(dynamic inputList) {
    // Nếu input không phải List, trả về list rỗng
    if (inputList == null) {
      return [];
    }

    // Đảm bảo input là List
    if (inputList is! List) {
      print('⚠️ Đầu vào không phải List: ${inputList.runtimeType}');
      return [];
    }

    return inputList.map((item) {
      if (item is Map) {
        return _deepConvertMap(item);
      } else if (item is List) {
        return _convertList(item);
      } else {
        return item;
      }
    }).toList();
  }

  // Hàm tạo kế hoạch ăn mới
  Future<void> _generateNewMealPlan() async {
    // Kiểm tra nếu đang có tiến trình tạo kế hoạch khác
    if (_isGeneratingPlanInProgress) {
      print('⚠️ _generateNewMealPlan: Đang có một tiến trình tạo kế hoạch khác, vui lòng đợi.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đang xử lý yêu cầu trước đó, vui lòng đợi.')),
        );
      }
      return; // Thoát sớm
    }

    try {
      if (mounted) { // Đảm bảo widget còn mounted trước khi gọi setState
        setState(() {
          _isGeneratingPlanInProgress = true; // Đặt cờ bắt đầu
          _isLoading = true;
          _hasError = false;
          _errorMessage = '';
        });
      } else {
        // Nếu widget không còn mounted, không nên tiếp tục
        print('⚠️ _generateNewMealPlan: Widget không còn mounted, hủy tạo kế hoạch.');
        return;
      }

      // Kiểm tra xem có đăng nhập không
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      // Lấy thông tin người dùng để xác định mục tiêu dinh dưỡng
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        throw Exception('Không xác định được ID người dùng');
      }

      // Get nutrition targets using the utility class
      final nutritionTargets = NutritionCalculator.calculateNutritionTargets(userDataProvider);
      
      final caloriesTarget = nutritionTargets['calories']!;
      final proteinTarget = nutritionTargets['protein']!;
      final fatTarget = nutritionTargets['fat']!;
      final carbsTarget = nutritionTargets['carbs']!;

      // Hiển thị thông báo đang tạo kế hoạch
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đang tạo kế hoạch ăn mới...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Sử dụng endpoint POST /api/meal-plan/generate để tạo kế hoạch ăn mới
      final headers = await ApiService.getAuthHeaders();

      // Tạo dữ liệu đúng định dạng cho API
      final requestData = {
        'user_id': userId,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
        'use_ai': true,
      };

      // Thêm tất cả thông tin từ onboarding cho prompt chính xác
      // Thêm preferences dưới dạng chuỗi nếu có
      if (userDataProvider.preferences != null && userDataProvider.preferences.isNotEmpty) {
        requestData['preferences'] = userDataProvider.preferences;
      }
      
      // Thêm allergies dưới dạng chuỗi nếu có
      if (userDataProvider.allergies != null && userDataProvider.allergies.isNotEmpty) {
        requestData['allergies'] = userDataProvider.allergies;
      }
      
      // Thêm cuisine_style nếu có
      if (userDataProvider.cuisineStyle != null && userDataProvider.cuisineStyle!.isNotEmpty) {
        requestData['cuisine_style'] = userDataProvider.cuisineStyle!;
      }
      
      // Thêm diet_restrictions nếu có
      if (userDataProvider.dietRestrictions != null && userDataProvider.dietRestrictions.isNotEmpty) {
        requestData['diet_restrictions'] = userDataProvider.dietRestrictions;
      }
      
      // Thêm diet_preference nếu có
      if (userDataProvider.dietPreference != null && userDataProvider.dietPreference.isNotEmpty) {
        requestData['diet_preference'] = userDataProvider.dietPreference;
      }
      
      // Thêm health_conditions nếu có
      if (userDataProvider.healthConditions != null && userDataProvider.healthConditions.isNotEmpty) {
        requestData['health_conditions'] = userDataProvider.healthConditions;
      }
      
      // Thêm mục tiêu dinh dưỡng chi tiết nếu có
      if (userDataProvider.fiber_target != null) {
        requestData['fiber_target'] = userDataProvider.fiber_target!; // Sử dụng null assertion
      }
      
      if (userDataProvider.sugar_target != null) {
        requestData['sugar_target'] = userDataProvider.sugar_target!; // Sử dụng null assertion
      }
      
      if (userDataProvider.sodium_target != null) {
        requestData['sodium_target'] = userDataProvider.sodium_target!; // Sử dụng null assertion
      }

      final generateUrl = Uri.parse('${app_config.apiBaseUrl}${app_config.ApiEndpoints.generateMealPlan}');

      print('🔄 Đang tạo kế hoạch ăn mới từ API: $generateUrl');
      print('📦 Dữ liệu gửi đi: ${jsonEncode(requestData)}');

      final response = await http.post(
        generateUrl,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      ).timeout(
        Duration(seconds: 60),  // Tăng timeout lên 60 giây
        onTimeout: () {
          print('⏱️ Timeout khi tạo kế hoạch ăn mới');
          throw Exception('Timeout khi tạo kế hoạch ăn mới');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Đã gửi yêu cầu tạo kế hoạch ăn mới thành công');

        // Hiển thị thông báo thành công
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã gửi yêu cầu tạo kế hoạch ăn mới, đang chờ cập nhật từ Firebase...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Đợi lâu hơn để đảm bảo Firebase cập nhật dữ liệu
        await Future.delayed(Duration(seconds: 5));

        // Đọc dữ liệu từ latest_meal_plans trước
        final latestDocSnapshot = await FirebaseFirestore.instance
            .collection('latest_meal_plans')
            .doc(userId)
            .get();

        if (latestDocSnapshot.exists && latestDocSnapshot.data() != null) {
          final result = latestDocSnapshot.data()!;
          print('✅ Đã tải kế hoạch mới từ latest_meal_plans');

          setState(() {
            _mealPlan = MealPlan.fromJson(result);
            _isLoading = false;
            _hasError = false;
          });
          return;
        }

        // Nếu không tìm thấy trong latest_meal_plans, kiểm tra meal_plans
        print('⚠️ Không tìm thấy kế hoạch ăn trong latest_meal_plans, kiểm tra meal_plans');
        final docSnapshot = await FirebaseFirestore.instance
            .collection('meal_plans')
            .doc(userId)
            .get();

        if (docSnapshot.exists && docSnapshot.data() != null) {
          final result = docSnapshot.data()!;
          print('✅ Đã tải kế hoạch mới từ meal_plans');

          setState(() {
            _mealPlan = MealPlan.fromJson(result);
            _isLoading = false;
            _hasError = false;
          });
        } else {
          // Nếu không tìm thấy dữ liệu trong Firestore, có thể API đang xử lý
          print('⚠️ Chưa tìm thấy dữ liệu trong Firestore, đợi thêm...');

          // Đợi thêm thời gian (tăng lên 5 giây)
          await Future.delayed(Duration(seconds: 5));

          // Thử lại lần đầu - kiểm tra latest_meal_plans trước
          final latestRetrySnapshot = await FirebaseFirestore.instance
              .collection('latest_meal_plans')
              .doc(userId)
              .get();

          if (latestRetrySnapshot.exists && latestRetrySnapshot.data() != null) {
            final result = latestRetrySnapshot.data()!;
            print('✅ Đã tải kế hoạch mới từ latest_meal_plans sau khi thử lại');

            setState(() {
              _mealPlan = MealPlan.fromJson(result);
              _isLoading = false;
              _hasError = false;
            });
            return;
          }

          // Nếu không tìm thấy trong latest_meal_plans, kiểm tra meal_plans
          final retrySnapshot = await FirebaseFirestore.instance
              .collection('meal_plans')
              .doc(userId)
              .get();

          if (retrySnapshot.exists && retrySnapshot.data() != null) {
            final result = retrySnapshot.data()!;
            print('✅ Đã tải kế hoạch mới từ meal_plans sau khi thử lại');

            setState(() {
              _mealPlan = MealPlan.fromJson(result);
              _isLoading = false;
              _hasError = false;
            });
          } else {
            // Vẫn không tìm thấy, sử dụng dữ liệu mẫu
            print('⚠️ Không tìm thấy dữ liệu trong Firestore sau khi tạo, sử dụng dữ liệu mẫu');
            setState(() {
              _isLoading = false;
            });
            _loadMockData();
          }
        }
      } else if (response.statusCode == 422) {
        // Lỗi dữ liệu không hợp lệ
        print('❌ Lỗi 422 - Dữ liệu không hợp lệ: ${response.body}');

        // Phân tích lỗi chi tiết
        try {
          final errorData = jsonDecode(response.body);
          print('❌ Chi tiết lỗi JSON: $errorData');

          if (errorData['detail'] is List) {
            for (var error in errorData['detail']) {
              print('❌ Lỗi trường: ${error['loc']}, Loại: ${error['type']}, Thông báo: ${error['msg']}');
            }
          } else {
            print('❌ Chi tiết lỗi: ${errorData['detail']}');
          }

          // Hiển thị thông báo lỗi
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi dữ liệu: ${errorData['detail']}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          print('Không thể phân tích lỗi: $e');
        }

        throw Exception('Dữ liệu không hợp lệ: Vui lòng kiểm tra lại');
      } else if (response.statusCode == 500) {
        // Lỗi server
        print('❌ Lỗi server: ${response.statusCode} - ${response.body}');

        // Phân tích lỗi chi tiết
        String errorMessage = 'Lỗi server';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];

            // Kiểm tra nếu là lỗi module 'services'
            if (errorMessage.contains("module 'services' has no attribute")) {
              errorMessage = 'Lỗi cấu hình server: Thiếu module xử lý bữa ăn';
            }
          }
        } catch (e) {
          print('Không thể phân tích lỗi: $e');
        }

        // Hiển thị thông báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi server: $errorMessage\n\nĐang tải dữ liệu mẫu...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );

        // Thay vì gọi lại _loadMealPlan() gây vòng lặp vô tận, tải dữ liệu mẫu
        print('⚠️ Gặp lỗi server, tải dữ liệu mẫu thay vì gọi lại _loadMealPlan()');
        setState(() {
          _isLoading = false;
        });
        _loadMockData();
        return;

        // throw Exception('Lỗi server: $errorMessage'); // Không throw exception nữa
      } else if (response.statusCode == 403) {
        // Lỗi xác thực
        print('❌ Lỗi xác thực: ${response.statusCode} - ${response.body}');
        throw Exception('Lỗi xác thực: Vui lòng đăng nhập lại');
      } else {
        // Lỗi khác
        print('❌ Lỗi khi tạo kế hoạch ăn mới: ${response.statusCode} - ${response.body}');
        throw Exception('Lỗi khi tạo kế hoạch ăn mới: ${response.statusCode}');
      }
    } catch (apiError) {
      print('❌ Lỗi khi gọi API tạo kế hoạch ăn: $apiError');

      // Nếu không thể tạo kế hoạch ăn mới qua API, tạo dữ liệu mẫu
      setState(() {
        _isLoading = false;
        _isGeneratingPlanInProgress = false; // Reset flag để tránh vòng lặp
      });
      _loadMockData();
    } finally {
      // Đảm bảo flag luôn được reset bất kể kết quả thành công hay thất bại
      _isGeneratingPlanInProgress = false;
    }
  }

  // Kiểm tra trùng lặp món ăn trong kế hoạch tuần


  // Tạo kế hoạch mới với tùy chọn đa dạng hóa món ăn

  // New method to add a snack to the meal plan
  Future<void> _addSnackToMealPlan() async {
    try {
      // Check if selected day has a meal plan
      final selectedDayName = _englishDays[_selectedDayIndex];
      print('🍽️ Thêm bữa phụ cho ngày: $selectedDayName');
      
      final dayPlan = _mealPlan?.weeklyPlan[selectedDayName];
      
      if (dayPlan == null) {
        print('❌ Không có dữ liệu kế hoạch cho ngày: $selectedDayName');
        throw Exception('Không có dữ liệu cho ngày đã chọn');
      }
      
      // In ra các bữa ăn hiện có
      print('🍽️ Các bữa ăn hiện có: ${dayPlan.meals.keys.toList()}');
      
      // Kiểm tra nếu bữa phụ đã tồn tại
      if (dayPlan.meals.containsKey('Bữa phụ')) {
        print('⚠️ Bữa phụ đã tồn tại cho ngày: $selectedDayName');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bữa phụ đã tồn tại cho ngày này'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2)
          )
        );
        return;
      }
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang thêm bữa phụ...'), 
          duration: Duration(seconds: 2)
        )
      );

      print('🔄 Bắt đầu thêm bữa phụ bằng cách gọi _replaceMeal("Bữa phụ")');
      // Use the existing replaceMeal functionality but with 'Bữa phụ'
      await _replaceMeal('Bữa phụ');
      
      print('✅ Đã gọi _replaceMeal thành công, đang tải lại kế hoạch');
      // Reload the meal plan to show the new snack
      await _loadMealPlan();
      
      print('✅ Đã hoàn thành việc thêm bữa phụ');
    } catch (e) {
      print('❌ Lỗi khi thêm bữa phụ: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: Không thể thêm bữa phụ - ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3)
        )
      );
    }
  }
}
