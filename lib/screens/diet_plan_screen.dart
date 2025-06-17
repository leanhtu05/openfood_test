import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thêm import cho HapticFeedback
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
import '../widgets/meal_detail_card.dart';
import '../utils/auth_helper.dart';

// 🎨 Clean & Simple Color Scheme - Inspired by reference image
class DietPlanColors {
  // Màu chính - xanh dương nhẹ nhàng như trong ảnh
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color primaryDark = Color(0xFF1976D2);

  // Màu phụ - xám trung tính
  static const Color secondary = Color(0xFF9E9E9E);
  static const Color secondaryLight = Color(0xFFF5F5F5);
  static const Color background = Color(0xFFFAFAFA);

  // Màu text - đơn giản và dễ đọc
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFF9E9E9E);

  // Màu accent
  static const Color accent = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
}

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
      if (!authProvider.isAuthenticated || FirebaseAuth.instance.currentUser?.isAnonymous == true) {
        // Người dùng chưa đăng nhập, dừng loading và return
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
        return;
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        // Không xác định được ID người dùng, dừng loading và return
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
        return;
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
        
        final caloriesTarget = nutritionTargets['calories']!.round();
        final proteinTarget = nutritionTargets['protein']!.round();
        final fatTarget = nutritionTargets['fat']!.round();
        final carbsTarget = nutritionTargets['carbs']!.round();

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
      if (mounted) {
        setState(() {
          _mealPlan = MealPlan.fromJson(result);
          _isLoading = false;
                  _hasError = false;
                });
              }
            } else {
              // Nếu vẫn không có dữ liệu, tạo dữ liệu mẫu
              setState(() {
                _isLoading = false;
              });
              _loadMockData();
            }
          } else {
            // Lỗi khi tạo kế hoạch ăn mới
            throw Exception('Lỗi khi tạo kế hoạch ăn mới: ${response.statusCode}');
          }
        } catch (apiError) {
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Không thể tải kế hoạch ăn: ${e.toString()}';
        });
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
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: DietPlanColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'DietAI',
                style: TextStyle(
                  color: DietPlanColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(
                Icons.shopping_cart_outlined,
                color: DietPlanColors.textSecondary,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/grocery-list');
              },
              tooltip: 'Danh sách mua sắm',
            ),
            AuthHelper.requireAuthWrapper(
              context: context,
              onTap: _performGenerateNewMealPlan,
              feature: 'tạo kế hoạch ăn',
              title: 'Tạo kế hoạch ăn mới',
              message: 'Mời bạn đăng nhập để trải nghiệm tính năng tạo kế hoạch ăn cá nhân hóa bằng AI',
              child: IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: DietPlanColors.textSecondary,
                ),
                onPressed: () {}, // onPressed sẽ được xử lý bởi wrapper
                tooltip: 'Tạo kế hoạch mới',
              ),
            ),
          ],
        ),
        body: Container(
          color: DietPlanColors.background,
          child: SafeArea(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                    ? _buildErrorState()
                    : _buildBody(),
          ),
        ),

      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: DietPlanColors.error, size: 60),
          SizedBox(height: 16),
          Text(
            'Lỗi: $_errorMessage',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: DietPlanColors.error),
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
              backgroundColor: DietPlanColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DietPlanColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 40,
                color: DietPlanColors.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Kế hoạch ăn cá nhân hóa',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: DietPlanColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Mời bạn đăng nhập để trải nghiệm tính năng tạo kế hoạch ăn cá nhân hóa bằng AI',
              style: TextStyle(
                fontSize: 16,
                color: DietPlanColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              icon: Icon(Icons.login, size: 20),
              label: Text('Đăng nhập ngay', style: TextStyle(fontSize: 16)),
              onPressed: () {
                Navigator.pushNamed(context, '/auth');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DietPlanColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Hiển thị mock data để người dùng có thể xem trước
                _loadMockData();
              },
              child: Text(
                'Xem trước kế hoạch mẫu',
                style: TextStyle(
                  color: DietPlanColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
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
    // Kiểm tra trạng thái đăng nhập trước
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      return _buildLoginPrompt();
    }

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
                backgroundColor: DietPlanColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
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
                backgroundColor: DietPlanColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
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
                // Subtitle with user goal
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giảm cân cân bằng cho Tú',
                        style: TextStyle(
                          fontSize: 14,
                          color: DietPlanColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      GestureDetector(
                        onTap: _replaceDayMealPlan,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: DietPlanColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'AI Thay Thế Ngày',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                    default:
                      mealIcon = Icons.access_time;
                  }

                  // Use the first meal in the list for this meal type
                  final meal = meals.first;

                  return _buildMealSection(context, mealType, meal);
                }).toList(),
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
                color: isSelected ? DietPlanColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(15), // Adjusted for smaller size
                border: isSelected
                    ? Border.all(color: DietPlanColors.primary, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  _daysOfWeek[index],
                  style: TextStyle(
                    fontSize: 13, // Reduced from 14
                    color: isSelected ? DietPlanColors.primary : DietPlanColors.textSecondary,
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
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNutrientItem(
            icon: Icons.local_fire_department,
            color: Colors.red,
            value: '${calories}kcal',
            unit: 'Calo',
          ),
          _buildNutrientItem(
            icon: Icons.water_drop,
            color: Colors.blue,
            value: '${protein}g',
            unit: 'Protein',
          ),
          _buildNutrientItem(
            icon: Icons.circle,
            color: Colors.orange,
            value: '${fat}g',
            unit: 'Chất béo',
          ),
          _buildNutrientItem(
            icon: Icons.eco,
            color: Colors.green,
            value: '${carbs}g',
            unit: 'Carbs',
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
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: DietPlanColors.textPrimary,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            color: DietPlanColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSection(BuildContext context, String title, Meal meal) {
    final mealColor = _getMealColor(title);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với icon và tên bữa ăn
          _buildMealHeader(title, mealColor),

          // Meal detail
          MealDetailCard(
            meal: meal,
            mealType: title,
            dayOfWeek: _englishDays[_selectedDayIndex],
            onReplace: () {
              _replaceMeal(title);
            },
            onLog: () {
              _addMealToFoodLog(meal, title);
            },
            hideTitle: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMealHeader(String title, Color color) {
    Meal? currentMeal = _getCurrentMealByType(title);

    // Get meal icon based on meal type
    IconData mealIcon;
    switch (title) {
      case 'Bữa sáng':
        mealIcon = Icons.wb_sunny;
        break;
      case 'Bữa trưa':
        mealIcon = Icons.wb_cloudy;
        break;
      case 'Bữa tối':
        mealIcon = Icons.nights_stay;
        break;
      default:
        mealIcon = Icons.restaurant;
    }

    if (currentMeal == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(mealIcon, size: 20, color: color),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DietPlanColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal type and name
          Row(
            children: [
              Icon(mealIcon, size: 20, color: color),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DietPlanColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Nutrition summary row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMealNutrient(
                Icons.local_fire_department,
                '${currentMeal.nutrition['calories']}kcal',
                '',
                Colors.red
              ),
              _buildMealNutrient(
                Icons.water_drop,
                '${currentMeal.nutrition['protein']}g',
                '',
                Colors.blue
              ),
              _buildMealNutrient(
                Icons.circle,
                '${currentMeal.nutrition['fat']}g',
                '',
                Colors.orange
              ),
              _buildMealNutrient(
                Icons.eco,
                '${currentMeal.nutrition['carbs']}g',
                '',
                Colors.green
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealNutrient(IconData icon, String value, String unit, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: color,
        ),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        if (unit.isNotEmpty) ...[
          SizedBox(width: 2),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
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
      final caloriesTarget = nutritionTargets['calories']!.round();
      final proteinTarget = nutritionTargets['protein']!.round();
      final fatTarget = nutritionTargets['fat']!.round();
      final carbsTarget = nutritionTargets['carbs']!.round();

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
          backgroundColor: DietPlanColors.warning,
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
            backgroundColor: DietPlanColors.primary,
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
          // Thay vì tự động tạo kế hoạch mới, hiển thị thông báo xác nhận
          print('⚠️ Không tìm thấy kế hoạch ăn: ${response.statusCode} - ${response.body}');
          
          if (mounted) {
            bool shouldCreate = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Không tìm thấy kế hoạch ăn'),
                content: Text('Kế hoạch ăn hiện tại không tồn tại hoặc đã bị xóa. Bạn có muốn tạo kế hoạch ăn mới cho cả tuần không?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Không'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Có'),
                  ),
                ],
              ),
            ) ?? false;
            
            if (shouldCreate) {
              // Nếu người dùng đồng ý, tạo kế hoạch mới
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
            } else {
              // Nếu người dùng không đồng ý, hiển thị thông báo
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Không thể thay thế bữa ăn vì không tìm thấy kế hoạch ăn hiện tại.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
              return; // Thoát khỏi hàm
            }
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
    // Hiển thị dialog chọn món ăn với hiệu ứng ripple
    HapticFeedback.mediumImpact(); // Thêm phản hồi xúc giác nếu có thể
    
    // Hiển thị thông báo nhỏ
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mở màn hình ghi nhận món ăn...'),
        duration: Duration(milliseconds: 500),
        backgroundColor: DietPlanColors.primary,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
    
    // Hiển thị dialog chọn món ăn
    _showDishSelectionDialog(meal, mealType);
  }

  // Hàm hiển thị dialog để người dùng chọn món ăn đã ăn
  void _showDishSelectionDialog(Meal meal, String mealType) {
    // Tạo một map để theo dõi trạng thái được chọn của mỗi món ăn
    // Ban đầu, tất cả các món đều được chọn
    final Map<Dish, bool> selectedDishes = {};
    
    // Kiểm tra xem meal có dishes hay không
    if (meal.dishes.isNotEmpty) {
      for (var dish in meal.dishes) {
        selectedDishes[dish] = true;
      }
    } else {
      // Nếu không có dishes, tạo một dish từ meal
      final singleDish = Dish(
        name: meal.name,
        description: meal.description,
        nutrition: meal.nutrition,
        ingredients: meal.ingredients,
        imageUrl: meal.imageUrl,
        instructions: meal.instructions,
      );
      selectedDishes[singleDish] = true;
    }

    // Sử dụng showModalBottomSheet thay vì showDialog để hiển thị màn hình đẹp hơn
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        // Dùng StatefulBuilder để dialog có thể tự cập nhật trạng thái
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [DietPlanColors.primary, DietPlanColors.primaryDark],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Xác nhận các món đã ăn",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: Icon(Icons.check_circle_outline, color: Colors.white),
                              label: Text("Chọn tất cả", style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                setDialogState(() {
                                  selectedDishes.updateAll((key, value) => true);
                                });
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                            SizedBox(width: 12),
                            TextButton.icon(
                              icon: Icon(Icons.cancel_outlined, color: Colors.white),
                              label: Text("Bỏ chọn tất cả", style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                setDialogState(() {
                                  selectedDishes.updateAll((key, value) => false);
                                });
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Danh sách món ăn
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: selectedDishes.length,
                        itemBuilder: (context, index) {
                          final dish = selectedDishes.keys.elementAt(index);
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.grey.shade50,
                              border: Border.all(
                                color: selectedDishes[dish]! ? DietPlanColors.primary.withOpacity(0.3) : DietPlanColors.secondaryLight,
                                width: 1,
                              ),
                              boxShadow: selectedDishes[dish]! 
                                ? [BoxShadow(color: DietPlanColors.primary.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 2))]
                                : null,
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                dish.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: DietPlanColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${dish.nutrition['calories']?.round() ?? 0} kcal',
                                style: TextStyle(
                                  color: DietPlanColors.textSecondary,
                                ),
                              ),
                              secondary: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: DietPlanColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.restaurant,
                                  color: DietPlanColors.primary,
                                ),
                              ),
                              activeColor: DietPlanColors.primary,
                              checkColor: Colors.white,
                              value: selectedDishes[dish],
                              onChanged: (bool? value) {
                                setDialogState(() {
                                  selectedDishes[dish] = value!;
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // Buttons
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text("Hủy"),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Xử lý logic khi người dùng nhấn Xác nhận
                              _logSelectedDishes(mealType, selectedDishes);
                              Navigator.of(dialogContext).pop(); // Đóng dialog
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DietPlanColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text("Xác nhận"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Hàm xử lý và ghi log các món đã chọn
  void _logSelectedDishes(String mealType, Map<Dish, bool> selectedDishesMap) {
    // 1. Lọc ra danh sách các món ăn thực sự được chọn
    final List<Dish> actuallyEatenDishes = [];
    selectedDishesMap.forEach((dish, isSelected) {
      if (isSelected) {
        actuallyEatenDishes.add(dish);
      }
    });

    // Nếu không chọn món nào, không làm gì cả
    if (actuallyEatenDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Bạn chưa chọn món ăn nào để ghi lại."),
          backgroundColor: DietPlanColors.warning,
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )
      );
      return;
    }

    // 2. Tính toán lại tổng dinh dưỡng
    double totalCalories = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCarbs = 0;
    double totalFiber = 0;
    double totalSugar = 0;
    double totalSodium = 0;
    
    String finalDescription = "";
    List<FoodItem> foodItems = [];

    for (var dish in actuallyEatenDishes) {
      totalCalories += dish.nutrition['calories'] ?? 0;
      totalProtein += dish.nutrition['protein'] ?? 0;
      totalFat += dish.nutrition['fat'] ?? 0;
      totalCarbs += dish.nutrition['carbs'] ?? 0;
      totalFiber += dish.nutrition['fiber'] ?? 0;
      totalSugar += dish.nutrition['sugar'] ?? 0;
      totalSodium += dish.nutrition['sodium'] ?? 0;
      
      // Thêm tên món ăn vào mô tả
      if (finalDescription.isEmpty) {
        finalDescription = dish.name;
      } else {
        finalDescription += ", ${dish.name}";
      }
      
      // Chuyển đổi mỗi Dish thành một FoodItem
      foodItems.add(FoodItem(
        id: Uuid().v4(),
        name: dish.name,
        calories: dish.nutrition['calories']?.toDouble() ?? 0.0,
        protein: dish.nutrition['protein']?.toDouble() ?? 0.0,
        fat: dish.nutrition['fat']?.toDouble() ?? 0.0,
        carbs: dish.nutrition['carbs']?.toDouble() ?? 0.0,
        fiber: dish.nutrition['fiber']?.toDouble() ?? 0.0,
        sugar: dish.nutrition['sugar']?.toDouble() ?? 0.0,
        sodium: dish.nutrition['sodium']?.toDouble() ?? 0.0,
        servingSize: 1.0,
        servingUnit: 'phần',
        additionalNutrients: Map<String, dynamic>.from(dish.nutrition),
      ));
    }

    // 3. Tạo một đối tượng FoodEntry mới và chính xác
    final FoodEntry foodEntry = FoodEntry(
      id: Uuid().v4(),
      description: finalDescription,
      mealType: mealType,
      dateTime: DateTime.now(),
      nutritionInfo: {
        'calories': totalCalories,
        'protein': totalProtein,
        'fat': totalFat,
        'carbs': totalCarbs,
        'fiber': totalFiber,
        'sugar': totalSugar,
        'sodium': totalSodium,
      },
      items: foodItems,
    );

    // Hiển thị thông báo đang chuyển đến màn hình chi tiết
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang chuẩn bị ghi nhận ${foodItems.length} món ăn'),

        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );

    // Thêm trực tiếp vào FoodProvider trước khi điều hướng
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    foodProvider.addFoodEntry(foodEntry);

    // Hiển thị thông báo để người dùng biết đã được thêm vào
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${finalDescription}" vào nhật ký thực phẩm'),

        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Chờ một chút để thông báo hiển thị trước khi chuyển màn hình
    Future.delayed(Duration(milliseconds: 300), () {
      // Sau đó mới điều hướng đến màn hình chi tiết
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodNutritionDetailScreen(
            foodEntry: foodEntry,
            onSave: (updatedEntry) {
              // Cập nhật lại entry trong provider
              foodProvider.updateFoodEntry(updatedEntry);
            },
          ),
        ),
      );
    });
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
                backgroundColor: DietPlanColors.primary,
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
    // Kiểm tra đăng nhập trước khi tạo kế hoạch
    final success = await AuthHelper.requireLogin(
      context,
      onAuthenticated: () => _performGenerateNewMealPlan(),
      title: 'Tạo kế hoạch ăn mới',
      message: 'Mời bạn đăng nhập để trải nghiệm tính năng tạo kế hoạch ăn cá nhân hóa bằng AI',
      feature: 'tạo kế hoạch ăn',
    );

    if (!success) {
      // Người dùng không đăng nhập, hiển thị thông báo
      AuthHelper.showLoginRequiredSnackBar(
        context,
        feature: 'tạo kế hoạch ăn',
      );
    }
  }

  // Thực hiện tạo kế hoạch ăn mới sau khi đã đăng nhập
  Future<void> _performGenerateNewMealPlan() async {
    // Hiển thị hộp thoại xác nhận trước
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tạo kế hoạch ăn mới'),
        content: Text('Bạn có chắc muốn tạo kế hoạch ăn mới cho cả tuần không? Kế hoạch hiện tại sẽ bị thay thế.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Tạo mới'),
            style: TextButton.styleFrom(
              backgroundColor: DietPlanColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) {
      return; // Người dùng đã hủy thao tác
    }

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
      
      final caloriesTarget = nutritionTargets['calories']!.round();
      final proteinTarget = nutritionTargets['protein']!.round();
      final fatTarget = nutritionTargets['fat']!.round();
      final carbsTarget = nutritionTargets['carbs']!.round();

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
              backgroundColor: DietPlanColors.error,
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
            backgroundColor: DietPlanColors.warning,
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
            backgroundColor: DietPlanColors.warning,
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
          backgroundColor: DietPlanColors.error,
          duration: Duration(seconds: 3)
        )
      );
    }
  }

  // Thêm phương thức _getMealColor - sử dụng màu thống nhất
  Color _getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'bữa sáng':
        return DietPlanColors.primary;
      case 'bữa trưa':
        return DietPlanColors.primary;
      case 'bữa tối':
        return DietPlanColors.primary;
      case 'bữa phụ':
        return DietPlanColors.secondary;
      default:
        return DietPlanColors.primary;
    }
  }

  // Thêm phương thức để lấy meal hiện tại theo loại bữa ăn
  Meal? _getCurrentMealByType(String mealType) {
    if (_mealPlan == null) return null;
    
    final selectedDay = _englishDays[_selectedDayIndex];
    if (!_mealPlan!.weeklyPlan.containsKey(selectedDay)) return null;
    
    final dayPlan = _mealPlan!.weeklyPlan[selectedDay]!;
    final normalizedType = _normalizeStringForComparison(mealType);
    
    // Tìm key phù hợp với mealType
    String? matchingKey;
    for (var key in dayPlan.meals.keys) {
      if (_normalizeStringForComparison(key) == normalizedType) {
        matchingKey = key;
        break;
      }
    }
    
    if (matchingKey == null || dayPlan.meals[matchingKey]!.isEmpty) return null;
    
    // Trả về meal đầu tiên trong danh sách
    return dayPlan.meals[matchingKey]![0];
  }
  
  // Hàm chuẩn hóa chuỗi để so sánh không phân biệt hoa thường và dấu
  String _normalizeStringForComparison(String input) {
    return input.toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ả', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ạ', 'a')
      .replaceAll('ă', 'a')
      .replaceAll('ắ', 'a')
      .replaceAll('ằ', 'a')
      .replaceAll('ẳ', 'a')
      .replaceAll('ẵ', 'a')
      .replaceAll('ặ', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ấ', 'a')
      .replaceAll('ầ', 'a')
      .replaceAll('ẩ', 'a')
      .replaceAll('ẫ', 'a')
      .replaceAll('ậ', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ẻ', 'e')
      .replaceAll('ẽ', 'e')
      .replaceAll('ẹ', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ế', 'e')
      .replaceAll('ề', 'e')
      .replaceAll('ể', 'e')
      .replaceAll('ễ', 'e')
      .replaceAll('ệ', 'e')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ỏ', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ọ', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ố', 'o')
      .replaceAll('ồ', 'o')
      .replaceAll('ổ', 'o')
      .replaceAll('ỗ', 'o')
      .replaceAll('ộ', 'o')
      .replaceAll('ơ', 'o')
      .replaceAll('ớ', 'o')
      .replaceAll('ờ', 'o')
      .replaceAll('ở', 'o')
      .replaceAll('ỡ', 'o')
      .replaceAll('ợ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('ủ', 'u')
      .replaceAll('ũ', 'u')
      .replaceAll('ụ', 'u')
      .replaceAll('ư', 'u')
      .replaceAll('ứ', 'u')
      .replaceAll('ừ', 'u')
      .replaceAll('ử', 'u')
      .replaceAll('ữ', 'u')
      .replaceAll('ự', 'u')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('ỉ', 'i')
      .replaceAll('ĩ', 'i')
      .replaceAll('ị', 'i')
      .replaceAll('ý', 'y')
      .replaceAll('ỳ', 'y')
      .replaceAll('ỷ', 'y')
      .replaceAll('ỹ', 'y')
      .replaceAll('ỵ', 'y')
      .replaceAll('đ', 'd');
  }

  // Thêm phương thức thay thế ngày
  Future<void> _replaceDayMealPlan() async {
    // Hiển thị thông báo đang xử lý
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang thay thế kế hoạch ngày...'),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy thông tin dinh dưỡng
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      final nutritionTargets = NutritionCalculator.calculateNutritionTargets(userDataProvider);
      
      // Chuyển đổi các giá trị từ double sang int để phù hợp với API
      final caloriesTarget = nutritionTargets['calories']!.round();
      final proteinTarget = nutritionTargets['protein']!.round();
      final fatTarget = nutritionTargets['fat']!.round();
      final carbsTarget = nutritionTargets['carbs']!.round();

      // Lấy ID người dùng
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('Không xác định được ID người dùng');
      }
      
      // Lấy thông tin về sức khỏe và dị ứng từ UserDataProvider
      List<String> dietRestrictions = userDataProvider.dietRestrictions;
      List<String> healthConditions = userDataProvider.healthConditions;
      String dietPreference = userDataProvider.dietPreference;
      
      // Lấy tên ngày đang chọn
      final selectedDay = _englishDays[_selectedDayIndex];
      final selectedDayName = _convertToAPIDay(selectedDay);

      print('✅ Đính kèm Firebase ID Token vào request');
      
      // Sử dụng endpoint POST /api/replace-day để thay thế ngày
      final headers = await ApiService.getAuthHeaders();
      
      // Tạo dữ liệu cho body request
      final requestData = {
        'user_id': userId,
        'day_of_week': selectedDayName,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
        'diet_restrictions': dietRestrictions,
        'health_conditions': healthConditions,
        'diet_preference': dietPreference,
        // Không đưa use_ai vào body
      };

      // Tạo query params cho URL
      final queryParams = {
        'user_id': userId,
        'use_ai': 'true', // Đưa use_ai vào query parameter
      };
      
      // Thêm dietRestrictions vào query params nếu có
      if (dietRestrictions.isNotEmpty) {
        for (int i = 0; i < dietRestrictions.length; i++) {
          queryParams['preferences[$i]'] = dietRestrictions[i];
        }
      }
      
      // Thêm healthConditions vào query params nếu có
      if (healthConditions.isNotEmpty) {
        for (int i = 0; i < healthConditions.length; i++) {
          queryParams['allergies[$i]'] = healthConditions[i];
        }
      }
      
      // Thêm dietPreference vào query params nếu có
      if (dietPreference.isNotEmpty) {
        queryParams['cuisine_style'] = dietPreference;
      }
      
      // Tạo URI với query parameters
      final replaceDayUrl = Uri.parse('${app_config.apiBaseUrl}${app_config.ApiEndpoints.replaceDay}')
          .replace(queryParameters: queryParams);

      print('🔄 Đang thay thế kế hoạch ngày từ API: $replaceDayUrl');
      print('📦 Dữ liệu gửi đi: $requestData');
      
      // Chuyển đổi sang JSON đảm bảo boolean được xử lý chính xác
      final jsonBody = jsonEncode(requestData);
      print('📦 JSON được gửi đi: $jsonBody');

      final response = await http.post(
        replaceDayUrl,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonBody,
      );

      if (response.statusCode == 200) {
        // Không phân tích dữ liệu từ API, mà chờ cập nhật từ Firebase
        print('✅ Yêu cầu thay thế kế hoạch ngày đã được xử lý thành công');
        print('🔄 Chờ cập nhật từ Firestore...');
        
        // Chờ một chút để Firebase cập nhật
        await Future.delayed(Duration(seconds: 2));
        
        // Tải lại dữ liệu từ Firebase
        await _loadMealPlanData();
        
        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thay thế kế hoạch ngày thành công!'),

            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Lỗi khi thay thế kế hoạch ngày: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Lỗi khi thay thế kế hoạch ngày: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thay thế kế hoạch ngày: $e'),
          backgroundColor: DietPlanColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _removeDiacritics(String input) {
    return input
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ả', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ạ', 'a')
      .replaceAll('ă', 'a')
      .replaceAll('ắ', 'a')
      .replaceAll('ằ', 'a')
      .replaceAll('ẳ', 'a')
      .replaceAll('ẵ', 'a')
      .replaceAll('ặ', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ấ', 'a')
      .replaceAll('ầ', 'a')
      .replaceAll('ẩ', 'a')
      .replaceAll('ẫ', 'a')
      .replaceAll('ậ', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ẻ', 'e')
      .replaceAll('ẽ', 'e')
      .replaceAll('ẹ', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ế', 'e')
      .replaceAll('ề', 'e')
      .replaceAll('ể', 'e')
      .replaceAll('ễ', 'e')
      .replaceAll('ệ', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('ỉ', 'i')
      .replaceAll('ĩ', 'i')
      .replaceAll('ị', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ỏ', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ọ', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ố', 'o')
      .replaceAll('ồ', 'o')
      .replaceAll('ổ', 'o')
      .replaceAll('ỗ', 'o')
      .replaceAll('ộ', 'o')
      .replaceAll('ơ', 'o')
      .replaceAll('ớ', 'o')
      .replaceAll('ờ', 'o')
      .replaceAll('ở', 'o')
      .replaceAll('ỡ', 'o')
      .replaceAll('ợ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('ủ', 'u')
      .replaceAll('ũ', 'u')
      .replaceAll('ụ', 'u')
      .replaceAll('ư', 'u')
      .replaceAll('ứ', 'u')
      .replaceAll('ừ', 'u')
      .replaceAll('ử', 'u')
      .replaceAll('ữ', 'u')
      .replaceAll('ự', 'u')
      .replaceAll('ý', 'y')
      .replaceAll('ỳ', 'y')
      .replaceAll('ỷ', 'y')
      .replaceAll('ỹ', 'y')
      .replaceAll('ỵ', 'y')
      .replaceAll('đ', 'd');
  }
  
  // Thêm phương thức _loadMealPlanData để sửa lỗi
  Future<void> _loadMealPlanData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Gọi _loadMealPlan để tải dữ liệu kế hoạch ăn từ Firebase
      await _loadMealPlan();
      
      // Hiển thị thông báo thành công nếu cần
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Lỗi khi tải dữ liệu kế hoạch ăn: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải dữ liệu kế hoạch ăn: $e'),
            backgroundColor: DietPlanColors.error,
          ),
        );
      }
    }
  }
}
