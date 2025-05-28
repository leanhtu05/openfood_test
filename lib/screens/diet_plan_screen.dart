import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
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
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart' as main_app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/config.dart' as app_config;
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  int _selectedDayIndex = 0; // T.2 selected by default (thứ 2 = Monday = index 0)
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

  @override
  void initState() {
    super.initState();
    
    // Kiểm tra biến từ main.dart
    if (main_app.isFirebaseInitialized) {
      print('✅ main.dart: Firebase đã được khởi tạo');
      _isFirebaseInitialized = true;
    } else {
      print('❌ main.dart: Firebase chưa được khởi tạo');
    }
    
    // Khởi tạo Firebase và các service trước
    _initializeFirebaseServices();
  }
  
  @override
  void dispose() {
    // Hủy subscription khi widget bị hủy
    _mealPlanSubscription?.cancel();
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
      print('✅ Firebase đã được khởi tạo');
      
      // Khởi tạo FirestoreService
      _firestoreService = FirestoreService();
      _isFirebaseInitialized = true;
      
      // Thiết lập listener cho dữ liệu realtime
      _listenToMealPlanChanges();
      
      // Tiếp tục tải dữ liệu
      _loadUserProfile();
      _loadMealPlan();
    } catch (e) {
      print('❌ Firebase chưa được khởi tạo: $e');
      
      // Log lỗi chi tiết
      _logFirebaseError(e);
      
      // Thử khởi tạo Firebase với options tường minh
      try {
        print('🔄 Đang thử khởi tạo Firebase với options tường minh...');
        
        // Tạo Firebase options tường minh
        const androidApiKey = 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0'; // Thay thế bằng API key thực
        const projectId = 'openfood-test';  // Thay thế bằng project ID thực
        const messagingSenderId = '622073990105';  // Thay thế bằng sender ID thực
        const appId = '1:622073990105:android:7ca0800c7e00e32ec4909d';  // Thay thế bằng App ID thực
        
        // Lấy package name thực tế
        final packageName = await _getPackageName();
        print('📱 Package name từ getPackageName: $packageName');
        
        // Tạo options
        final options = FirebaseOptions(
          apiKey: androidApiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
        );
        
        // In ra options để debug
        print('🔥 Khởi tạo Firebase với options: $options');
        
        // Thử khởi tạo Firebase với options
        await Firebase.initializeApp(options: options);
        
        print('✅ Đã khởi tạo Firebase thành công từ DietPlanScreen');
        
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
        print('❌ Không thể khởi tạo Firebase: $initError');
        _logFirebaseError(initError);
        
        // Thử khởi tạo không cần options
        try {
          print('🔄 Đang thử khởi tạo Firebase không cần options...');
          await Firebase.initializeApp();
          print('✅ Đã khởi tạo Firebase thành công không cần options');
          
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
          print('❌ Không thể khởi tạo Firebase không cần options: $noOptionsError');
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
      
      print('🔴 === FIREBASE ERROR LOG ===');
      print('🔴 Error: $errorString');
      print('🔴 Stack trace: $stackTrace');
      
      // Lấy thông tin thiết bị và ứng dụng
      _getPackageName().then((packageName) {
        print('🔴 Package Name: $packageName');
        print('🔴 === END ERROR LOG ===');
      });
      
      // Trong thực tế bạn có thể lưu log vào file hoặc gửi lên server
    } catch (e) {
      print('Không thể ghi log lỗi: $e');
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
      print('⚠️ Bỏ qua _loadUserProfile vì Firebase chưa được khởi tạo');
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
      debugPrint('Lỗi khi tải dữ liệu người dùng: $e');
    }
  }
  
  // Hàm lắng nghe thay đổi kế hoạch ăn realtime từ Firestore
  void _listenToMealPlanChanges() {
    // Hủy subscription hiện tại nếu có
    _mealPlanSubscription?.cancel();
    
    if (!_isFirebaseInitialized || _firestoreService == null) {
      print('⚠️ Không thể lắng nghe thay đổi vì Firebase chưa được khởi tạo');
      return;
    }
    
    try {
      print('🔄 Bắt đầu lắng nghe thay đổi kế hoạch ăn từ Firestore');
      
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
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
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
          
          // Kiểm tra trùng lặp món ăn và tự động tạo mới nếu cần
          _autoGenerateIfDuplicated();
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
          
          // Kiểm tra trùng lặp món ăn và tự động tạo mới nếu cần
          _autoGenerateIfDuplicated();
        }
      } else {
        // Không tìm thấy dữ liệu, cần tạo kế hoạch ăn mới thông qua API
        print('⚠️ Không tìm thấy kế hoạch ăn trong Firestore, tạo mới qua API');
        
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
            final caloriesTarget = userDataProvider.tdeeCalories > 0 
                ? userDataProvider.tdeeCalories 
            : app_config.defaultCaloriesTarget;
            final proteinTarget = userDataProvider.tdeeProtein > 0 
                ? userDataProvider.tdeeProtein 
            : app_config.defaultProteinTarget;
            final fatTarget = userDataProvider.tdeeFat > 0 
                ? userDataProvider.tdeeFat 
            : app_config.defaultFatTarget;
            final carbsTarget = userDataProvider.tdeeCarbs > 0 
                ? userDataProvider.tdeeCarbs
            : app_config.defaultCarbsTarget;
        
        // Gọi API để tạo kế hoạch ăn mới
        try {
          // Tạo dữ liệu JSON cho body
          final requestData = {
            'user_id': userId,
            'calories_target': caloriesTarget,
            'protein_target': proteinTarget,
            'fat_target': fatTarget,
            'carbs_target': carbsTarget,
            'use_ai': true,
          };
          
          // Thêm preferences nếu có
          if (userDataProvider.preferences != null && userDataProvider.preferences.isNotEmpty) {
            requestData['preferences'] = userDataProvider.preferences;
          }
          if (userDataProvider.allergies != null && userDataProvider.allergies.isNotEmpty) {
            requestData['allergies'] = userDataProvider.allergies;
          }
          if (userDataProvider.cuisineStyle != null && userDataProvider.cuisineStyle!.isNotEmpty) {
            requestData['cuisine_style'] = userDataProvider.cuisineStyle!;
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
          _loadMockData();
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
      }
      
      // Tải dữ liệu mẫu khi có lỗi
      _loadMockData();
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
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "configApi",
              onPressed: _showApiConfig,
              backgroundColor: Colors.purple,
              mini: true,
              child: Icon(Icons.settings),
              tooltip: 'Cấu hình API',
            ),
            SizedBox(height: 8),
            FloatingActionButton(
              heroTag: "checkFirestore",
              onPressed: _checkFirestoreData,
              backgroundColor: Colors.blue,
              mini: true,
              child: Icon(Icons.data_usage),
              tooltip: 'Kiểm tra dữ liệu Firebase',
            ),
            SizedBox(height: 8),
            FloatingActionButton(
              heroTag: "reload",
              onPressed: _loadMealPlan,
              backgroundColor: Colors.green,
              child: Icon(Icons.refresh),
              tooltip: 'Tải lại',
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
  
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(_errorMessage, textAlign: TextAlign.center),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _loadMealPlan,
                child: Text('Thử lại'),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: _checkFirebaseConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                ),
                child: Text('Kiểm tra Firebase'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _checkPackageName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                ),
                child: Text('Kiểm tra Package Name'),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: _checkFirestoreData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Text('Kiểm tra dữ liệu Firestore'),
              ),
            ],
          ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayTabs() {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _daysOfWeek.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDayIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDayIndex = index;
              });
            },
            child: Container(
              width: 70,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight.withOpacity(0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  _daysOfWeek[index],
                  style: TextStyle(
                    fontSize: 14,
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
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
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
            value: calories.toString(),
            unit: 'Calo',
          ),
          _buildNutrientItem(
            icon: Icons.adjust_rounded,
            color: Colors.blue,
            value: '${protein}g',
            unit: 'Protein',
          ),
          _buildNutrientItem(
            icon: Icons.water_drop_outlined,
            color: Colors.orange,
            value: '${fat}g',
            unit: 'Chất béo',
          ),
          _buildNutrientItem(
            icon: Icons.grass,
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
        Icon(icon, color: color, size: 22),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
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
    
    // Debug information about cooking instructions
    print('📝 Meal instructions for ${meal.name}: ${meal.instructions}');
    print('📝 Meal instructions length: ${meal.instructions.length}');
    print('📝 Meal instructions isEmpty: ${meal.instructions.isEmpty}');
    
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal title
                Row(
                children: [
                  Icon(icon, size: 18),
                  SizedBox(width: 8),
                    Expanded(
                      child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
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
          Divider(height: 1, thickness: 1, color: AppColors.textLight.withOpacity(0.3)),

          // Meal content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal name
                Row(
                  children: [
                    Icon(Icons.restaurant, size: 16, color: Colors.grey.shade700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meal.name,
                        style: TextStyle(
                          fontSize: 18,
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

                SizedBox(height: 16),

                // Ingredients
                Text(
                  'Nguyên liệu:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                for (var ingredient in meal.ingredients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: _buildFormattedIngredient(ingredient),
                        ),
                      ],
                    ),
                  ),
                
                // Hướng dẫn nấu ăn (thêm mới)
                SizedBox(height: 16),
                Text(
                  'Hướng dẫn nấu:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                if (meal.instructions != null && meal.instructions.isNotEmpty)
                  for (var i = 0; i < meal.instructions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              meal.instructions[i],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
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
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
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
      
      // Get user nutrition goals or use defaults
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      final caloriesTarget = userDataProvider.tdeeCalories > 0 
          ? userDataProvider.tdeeCalories 
          : 2000.0;
      final proteinTarget = userDataProvider.tdeeProtein > 0 
          ? userDataProvider.tdeeProtein 
          : 120.0;
      final fatTarget = userDataProvider.tdeeFat > 0 
          ? userDataProvider.tdeeFat 
          : 65.0;
      final carbsTarget = userDataProvider.tdeeCarbs > 0 
          ? userDataProvider.tdeeCarbs
          : 250.0;
      
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

  // Hàm kiểm tra package name
  Future<void> _checkPackageName() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      
      // In ra thông tin package name và các thông tin quan trọng khác
      print('🔍 Đang kiểm tra thông tin ứng dụng...');
      
      // Lấy package name từ nhiều nguồn khác nhau để so sánh
      final packageInfoPackageName = await _getPackageName();
      print('📱 Package Name từ PackageInfo: $packageInfoPackageName');
      
      // Lấy package name từ toString() của context
      final contextPackageName = context.toString().contains('package:') 
          ? context.toString().split('package:')[1].split('/')[0]
          : 'không xác định';
      print('📱 Package Name từ context: $contextPackageName');
      
      // So sánh các package name
      final packageNameMismatch = packageInfoPackageName != contextPackageName && 
                                 packageInfoPackageName != 'unknown' && 
                                 contextPackageName != 'không xác định';
      
      if (packageNameMismatch) {
        print('⚠️ CẢNH BÁO: Phát hiện có nhiều package name khác nhau!');
        print('⚠️ Điều này có thể gây lỗi khi khởi tạo Firebase.');
      }
      
      // Kiểm tra Firebase
      try {
        final app = Firebase.app();
        print('🔥 Firebase app name: ${app.name}');
        print('🔥 Firebase options: ${app.options}');
        print('🔥 Firebase project ID: ${app.options.projectId}');
        print('🔥 Firebase Google app ID: ${app.options.appId}');
        
        // Kiểm tra xem options đã đúng chưa
        final String firebaseAppId = app.options.appId;
        final String firebaseProjectId = app.options.projectId;
        
        final bool isCorrectConfig = firebaseAppId.contains('622073990105') && 
                                    (firebaseProjectId == 'openfood-test' || 
                                     firebaseProjectId == 'openfood-test-d26ae');
        
        // Hiển thị thông tin
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Package Name: $packageInfoPackageName\n'
              'Context Package: $contextPackageName\n'
              'Firebase cấu hình: ${isCorrectConfig ? 'Đúng ✅' : 'Sai ❌'}\n'
              'Project ID: ${app.options.projectId}',
            ),
            backgroundColor: isCorrectConfig ? Colors.green : Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        print('❌ Firebase chưa được khởi tạo: $e');
        
        // Tạo Firebase options tường minh
        const androidApiKey = 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0';
        const projectId = 'openfood-test';
        const messagingSenderId = '622073990105';
        const appId = '1:622073990105:android:7ca0800c7e00e32ec4909d';
        
        // Tạo options với package name đúng
        final options = FirebaseOptions(
          apiKey: androidApiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          // Fix package name nếu cần
          androidClientId: packageInfoPackageName.isEmpty || packageInfoPackageName == 'unknown' 
              ? null 
              : '${packageInfoPackageName}.android_client',
        );
        
        // Hiển thị options sẽ sử dụng
        print('🔥 Sẽ khởi tạo Firebase với options: $options');
        
        // Try initialize Firebase
        try {
          await Firebase.initializeApp(options: options);
          print('✅ Đã khởi tạo Firebase thành công với options tường minh!');
          
          // Reload everything
          _initializeFirebaseServices();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã khởi tạo Firebase thành công!\nĐang tải lại dữ liệu...'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (initError) {
          print('❌ Không thể khởi tạo Firebase với options: $initError');
          
          // Thử khởi tạo không cần options
          try {
            await Firebase.initializeApp();
            print('✅ Đã khởi tạo Firebase thành công không cần options!');
            
            // Reload everything
            _initializeFirebaseServices();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã khởi tạo Firebase thành công!\nĐang tải lại dữ liệu...'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (noOptionsError) {
            print('❌ Không thể khởi tạo Firebase không cần options: $noOptionsError');
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Package Name: $packageInfoPackageName\n'
                  'Context Package: $contextPackageName\n'
                  'Lỗi: Không thể khởi tạo Firebase\n'
                  'Lỗi cụ thể: ${_getReadableErrorMessage(noOptionsError.toString())}',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 10),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi khi kiểm tra package name: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi kiểm tra: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  // Hàm kiểm tra kết nối Firebase và API
  Future<void> _checkFirebaseConnection() async {
    try {
      // Hiển thị thông báo đang kiểm tra
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang kiểm tra kết nối...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Kiểm tra kết nối API
      bool apiConnected = false;
      String apiStatus = 'Không thể kết nối';
      try {
        apiConnected = await ApiService.checkConnection();
        apiStatus = apiConnected ? 'Kết nối thành công' : 'Không thể kết nối';
        print('🌐 API Status: $apiStatus');
      } catch (apiError) {
        print('❌ Lỗi khi kiểm tra API: $apiError');
        apiStatus = 'Lỗi: ${apiError.toString()}';
      }
      
      // Kiểm tra lại xem Firebase đã được khởi tạo chưa
      bool firebaseConnected = false;
      String firebaseStatus = 'Chưa khởi tạo';
      try {
        Firebase.app();
        print('✅ Firebase.app() hoạt động');
        
        if (_firestoreService == null) {
          _firestoreService = FirestoreService();
          _isFirebaseInitialized = true;
          print('✅ Đã khởi tạo FirestoreService');
        }
        
        // Thử gọi một phương thức của FirestoreService để kiểm tra kết nối
        try {
          final userProfile = await _firestoreService!.getUserProfile();
          print('✅ Đã kết nối thành công với Firebase');
          print('Firebase user profile: ${userProfile.toString()}');
          
          firebaseConnected = true;
          firebaseStatus = 'Kết nối thành công';
          
          setState(() {
            _hasError = false;
            _isLoading = false;
          });
        } catch (e) {
          print('❌ Lỗi khi lấy thông tin người dùng: $e');
          firebaseStatus = 'Lỗi: ${e.toString()}';
          throw e;
        }
      } catch (e) {
        print('❌ Firebase chưa được khởi tạo hoặc cấu hình chưa đúng: $e');
        firebaseStatus = 'Lỗi: ${e.toString()}';
        
        // Thử khởi tạo lại Firebase
        try {
          print('🔄 Đang thử khởi tạo lại Firebase...');
          await Firebase.initializeApp();
          print('✅ Đã khởi tạo Firebase thành công');
          
          // Gán biến toàn cục
          main_app.isFirebaseInitialized = true;
          _isFirebaseInitialized = true;
          
          // Khởi tạo FirestoreService
          _firestoreService = FirestoreService();
          
          firebaseConnected = true;
          firebaseStatus = 'Đã khởi tạo thành công';
        } catch (initError) {
          print('❌ Không thể khởi tạo Firebase: $initError');
          firebaseStatus = 'Không thể khởi tạo: ${initError.toString()}';
          throw initError;
        }
      }
      
      // Hiển thị kết quả kiểm tra
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Kết quả kiểm tra kết nối'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // API Status
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: apiConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'API: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(apiStatus),
                  ),
                ],
              ),
              SizedBox(height: 8),
              
              // Firebase Status
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: firebaseConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Firebase: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(firebaseStatus),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // API URL
              Text(
                'API URL: ${app_config.apiBaseUrl}',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadMealPlan();
              },
              child: Text('Tải lại dữ liệu'),
            ),
          ],
        ),
      );
      
      // Tải lại dữ liệu nếu kiểm tra thành công
      if (firebaseConnected || apiConnected) {
        _loadMealPlan();
      }
    } catch (e) {
      print('❌ Lỗi kết nối: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Không thể kết nối: ${_getReadableErrorMessage(e.toString())}';
        _isLoading = false;
      });
      
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Hàm kiểm tra dữ liệu Firestore
  Future<void> _checkFirestoreData() async {
    try {
      // Kiểm tra xem Firebase đã được khởi tạo chưa
      try {
        final app = Firebase.app();
        print('✅ Firebase.app() hoạt động, app name: ${app.name}');
        
        if (_firestoreService == null) {
          _firestoreService = FirestoreService();
          _isFirebaseInitialized = true;
          print('✅ Đã khởi tạo FirestoreService');
        }
        
        // Kiểm tra trạng thái đăng nhập
        final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
        final isLoggedIn = authProvider.isAuthenticated;
        print('👤 Trạng thái đăng nhập: ${isLoggedIn ? "Đã đăng nhập" : "Chưa đăng nhập"}');
        
        // Kiểm tra nếu đã đăng nhập thì thử lấy dữ liệu người dùng
        Map<String, dynamic> userData = {};
        if (isLoggedIn) {
          try {
            userData = await _firestoreService!.getUserProfile();
            print('✅ Đã lấy được dữ liệu người dùng từ Firestore');
            print('Dữ liệu: ${userData.toString()}');
          } catch (e) {
            print('❌ Lỗi khi lấy dữ liệu người dùng: $e');
            userData = {'error': e.toString()};
          }
        }
        
        // Thử lấy dữ liệu kế hoạch ăn
        Map<String, dynamic> mealPlanData = {};
        try {
          if (isLoggedIn) {
            mealPlanData = await _firestoreService!.getWeeklyMealPlan();
            print('✅ Đã lấy được dữ liệu kế hoạch ăn từ Firestore');
            print('Dữ liệu: ${mealPlanData.toString().substring(0, mealPlanData.toString().length > 200 ? 200 : mealPlanData.toString().length)}...');
          } else {
            mealPlanData = {'error': 'Chưa đăng nhập nên không thể lấy kế hoạch ăn'};
          }
        } catch (e) {
          print('❌ Lỗi khi lấy dữ liệu kế hoạch ăn: $e');
          mealPlanData = {'error': e.toString()};
        }
        
        // Hiển thị kết quả
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Trạng thái dữ liệu Firebase'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Firebase đã khởi tạo: ${_isFirebaseInitialized ? "✅" : "❌"}'),
                  SizedBox(height: 8),
                  Text('Đã đăng nhập: ${isLoggedIn ? "✅" : "❌"}'),
                  SizedBox(height: 16),
                  
                  Text('Dữ liệu người dùng:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (userData.isEmpty)
                    Text('Không có dữ liệu', style: TextStyle(color: Colors.red))
                  else if (userData.containsKey('error'))
                    Text('Lỗi: ${userData['error']}', style: TextStyle(color: Colors.red))
                  else
                    ...userData.entries.take(5).map((e) => Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                      child: Text('${e.key}: ${e.value}'),
                    )),
                    
                  SizedBox(height: 16),
                  Text('Dữ liệu kế hoạch ăn:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (mealPlanData.isEmpty)
                    Text('Không có dữ liệu', style: TextStyle(color: Colors.red))
                  else if (mealPlanData.containsKey('error'))
                    Text('Lỗi: ${mealPlanData['error']}', style: TextStyle(color: Colors.red))
                  else
                    Text('Đã nhận được dữ liệu kế hoạch ăn từ Firebase', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Đóng'),
              ),
              if (isLoggedIn && (_mealPlan == null || mealPlanData.isNotEmpty))
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _loadMealPlan();
                  },
                  child: Text('Tải kế hoạch ăn'),
                ),
            ],
          ),
        );
      } catch (e) {
        print('❌ Firebase chưa được khởi tạo: $e');
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Lỗi Firebase'),
            content: Text('Firebase chưa được khởi tạo hoặc có lỗi: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Đóng'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _checkFirebaseConnection();
                },
                child: Text('Kiểm tra kết nối'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Lỗi chung khi kiểm tra dữ liệu Firestore: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi kiểm tra: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              
              // Thông báo
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã cập nhật API URL thành: ${app_config.apiBaseUrl}'),
                  backgroundColor: Colors.green,
                ),
              );
              
              Navigator.of(context).pop();
              
              // Tải lại dữ liệu sau khi cập nhật URL
              _loadMealPlan();
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
      future: ApiService.checkConnection(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              SizedBox(
                width: 16, 
                height: 16, 
                child: CircularProgressIndicator(strokeWidth: 2)
              ),
              SizedBox(width: 8),
              Text('Đang kiểm tra kết nối...'),
            ],
          );
        }
        
        final isConnected = snapshot.data ?? false;
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(width: 8),
            Text(
              isConnected 
                  ? 'Kết nối thành công' 
                  : 'Không thể kết nối',
              style: TextStyle(
                color: isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
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
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
      
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
      
      // Lấy mục tiêu dinh dưỡng hoặc sử dụng giá trị mặc định
      final caloriesTarget = userDataProvider.tdeeCalories > 0 
          ? userDataProvider.tdeeCalories 
          : app_config.defaultCaloriesTarget;
      final proteinTarget = userDataProvider.tdeeProtein > 0 
          ? userDataProvider.tdeeProtein 
          : app_config.defaultProteinTarget;
      final fatTarget = userDataProvider.tdeeFat > 0 
          ? userDataProvider.tdeeFat 
          : app_config.defaultFatTarget;
      final carbsTarget = userDataProvider.tdeeCarbs > 0 
          ? userDataProvider.tdeeCarbs
          : app_config.defaultCarbsTarget;
      
      // Hiển thị thông báo đang tạo kế hoạch
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang tạo kế hoạch ăn mới...'),
          duration: Duration(seconds: 2),
        ),
      );
      
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
      
      final generateUrl = Uri.parse('${app_config.apiBaseUrl}${app_config.ApiEndpoints.generateMealPlan}');
      
      print('🔄 Đang tạo kế hoạch ăn mới từ API: $generateUrl');
      print('📦 Dữ liệu gửi đi: ${jsonEncode(requestData)}');
      
      try {
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
        
        // In ra toàn bộ thông tin về response
        print('🔍 Response status: ${response.statusCode}');
        print('🔍 Response body: ${response.body}');
        print('🔍 Response headers: ${response.headers}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          print('✅ Đã gửi yêu cầu tạo kế hoạch ăn mới thành công');
          
          // Hiển thị thông báo thành công
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã gửi yêu cầu tạo kế hoạch ăn mới, đang chờ cập nhật từ Firebase...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
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
              // Vẫn không tìm thấy, thử lại lần thứ hai
              print('⚠️ Không tìm thấy dữ liệu trong Firestore sau lần thử đầu, thử lần cuối...');
              
              // Đợi thêm thời gian (tăng lên 8 giây)
              await Future.delayed(Duration(seconds: 8));
              
              // Thử lại lần cuối - kiểm tra latest_meal_plans trước
              final latestFinalRetrySnapshot = await FirebaseFirestore.instance
                  .collection('latest_meal_plans')
                  .doc(userId)
                  .get();
                  
              if (latestFinalRetrySnapshot.exists && latestFinalRetrySnapshot.data() != null) {
                final result = latestFinalRetrySnapshot.data()!;
                print('✅ Đã tải kế hoạch mới từ latest_meal_plans sau lần thử cuối');
                
                setState(() {
                  _mealPlan = MealPlan.fromJson(result);
                  _isLoading = false;
                  _hasError = false;
                });
                return;
              }
              
              // Nếu không tìm thấy trong latest_meal_plans, kiểm tra meal_plans
              final finalRetrySnapshot = await FirebaseFirestore.instance
                  .collection('meal_plans')
                  .doc(userId)
                  .get();
                  
              if (finalRetrySnapshot.exists && finalRetrySnapshot.data() != null) {
                final result = finalRetrySnapshot.data()!;
                print('✅ Đã tải kế hoạch mới từ meal_plans sau lần thử cuối');
                
                setState(() {
                  _mealPlan = MealPlan.fromJson(result);
                  _isLoading = false;
                  _hasError = false;
                });
              } else {
                // Vẫn không tìm thấy, sử dụng dữ liệu mẫu
                print('⚠️ Không tìm thấy dữ liệu trong Firestore sau nhiều lần thử, sử dụng dữ liệu mẫu');
                _loadMockData();
              }
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
                
                // Hiển thị thông báo hướng dẫn cho developer
                print('⚠️ LỖI BACKEND: Cần kiểm tra file services.py và thêm hàm generate_meal');
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
          
          // Thử tải lại dữ liệu từ Firebase
          print('⚠️ Đang tải lại dữ liệu từ Firebase sau lỗi server...');
          await _loadMealPlan();
          
          // Nếu không tìm thấy dữ liệu trong Firebase, sử dụng dữ liệu mẫu
          if (_mealPlan == null) {
            print('⚠️ Không tìm thấy dữ liệu trong Firebase, đang tải dữ liệu mẫu...');
            _loadMockData();
          }
          
          return; // Không throw exception nữa
        } else if (response.statusCode == 403) {
          // Lỗi xác thực
          print('❌ Lỗi xác thực: ${response.statusCode} - ${response.body}');
          throw Exception('Lỗi xác thực: Vui lòng đăng nhập lại');
        } else {
          // Lỗi khác
          print('❌ Lỗi khi tạo kế hoạch ăn mới: ${response.statusCode} - ${response.body}');
          throw Exception('Lỗi khi tạo kế hoạch ăn mới: ${response.statusCode}');
        }
      } catch (e) {
        print('❌❌❌ Lỗi khi gọi API: $e');
        
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Không thể tạo kế hoạch ăn mới: ${e.toString()}';
        });
        
        // Hiển thị thông báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tạo kế hoạch ăn mới: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ Lỗi khi tạo kế hoạch ăn mới: $e');
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Không thể tạo kế hoạch ăn mới: ${e.toString()}';
      });
      
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tạo kế hoạch ăn mới: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Kiểm tra trùng lặp món ăn trong kế hoạch tuần
  Future<bool> _checkDuplicateMeals() async {
    if (_mealPlan == null || _mealPlan!.weeklyPlan.isEmpty) {
      return false;
    }
    
    print('🔍 Đang kiểm tra trùng lặp món ăn trong kế hoạch tuần...');
    
    // Lưu trữ tên món ăn theo loại bữa
    Map<String, Set<String>> mealsByType = {
      'Bữa sáng': {},
      'Bữa trưa': {},
      'Bữa tối': {},
    };
    
    // Đếm số lượng trùng lặp
    int duplicateCount = 0;
    int totalMeals = 0;
    
    // Kiểm tra từng ngày
    for (String day in _mealPlan!.weeklyPlan.keys) {
      final dayPlan = _mealPlan!.weeklyPlan[day];
      if (dayPlan == null) continue;
      
      // Kiểm tra từng loại bữa
      for (String mealType in dayPlan.meals.keys) {
        final meals = dayPlan.meals[mealType];
        if (meals == null || meals.isEmpty) continue;
        
        // Lấy món ăn đầu tiên trong danh sách
        final meal = meals.first;
        totalMeals++;
        
        // Kiểm tra nếu món ăn đã tồn tại trong set
        if (mealsByType.containsKey(mealType) && 
            mealsByType[mealType]!.contains(meal.name)) {
          duplicateCount++;
        } else if (mealsByType.containsKey(mealType)) {
          // Thêm món ăn vào set nếu chưa tồn tại
          mealsByType[mealType]!.add(meal.name);
        }
      }
    }
    
    // Tính tỷ lệ trùng lặp
    double duplicateRate = totalMeals > 0 ? duplicateCount / totalMeals : 0;
    print('📊 Tỷ lệ trùng lặp món ăn: ${(duplicateRate * 100).toStringAsFixed(1)}% ($duplicateCount/$totalMeals)');
    
    // Nếu tỷ lệ trùng lặp > 30%, cần tạo kế hoạch mới
    return duplicateRate > 0.3;
  }
  
  // Tự động tạo kế hoạch mới nếu phát hiện trùng lặp
  Future<void> _autoGenerateIfDuplicated() async {
    try {
      bool hasDuplicates = await _checkDuplicateMeals();
      
      if (hasDuplicates) {
        print('⚠️ Phát hiện nhiều món ăn trùng lặp trong kế hoạch tuần');
        
        // Hiển thị thông báo
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phát hiện nhiều món ăn trùng lặp, đang tạo kế hoạch đa dạng hơn...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // Tạo kế hoạch mới với tham số đặc biệt để tránh trùng lặp
        await _generateNewMealPlanWithDiversityOption();
      }
    } catch (e) {
      print('❌ Lỗi khi kiểm tra trùng lặp món ăn: $e');
    }
  }
  
  // Tạo kế hoạch mới với tùy chọn đa dạng hóa món ăn
  Future<void> _generateNewMealPlanWithDiversityOption() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
      
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
      
      // Lấy mục tiêu dinh dưỡng hoặc sử dụng giá trị mặc định
      final caloriesTarget = userDataProvider.tdeeCalories > 0 
          ? userDataProvider.tdeeCalories 
          : app_config.defaultCaloriesTarget;
      final proteinTarget = userDataProvider.tdeeProtein > 0 
          ? userDataProvider.tdeeProtein 
          : app_config.defaultProteinTarget;
      final fatTarget = userDataProvider.tdeeFat > 0 
          ? userDataProvider.tdeeFat 
          : app_config.defaultFatTarget;
      final carbsTarget = userDataProvider.tdeeCarbs > 0 
          ? userDataProvider.tdeeCarbs
          : app_config.defaultCarbsTarget;
      
      // Hiển thị thông báo đang tạo kế hoạch
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đang tạo kế hoạch ăn đa dạng hơn...'),
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
        'ensure_diversity': true, // Thêm tham số đặc biệt để tránh trùng lặp
      };
      
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
      
      final generateUrl = Uri.parse('${app_config.apiBaseUrl}${app_config.ApiEndpoints.generateMealPlan}');
      
      print('🔄 Đang tạo kế hoạch ăn đa dạng từ API: $generateUrl');
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
        print('✅ Đã gửi yêu cầu tạo kế hoạch ăn đa dạng thành công');
        
        // Hiển thị thông báo thành công
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo kế hoạch ăn đa dạng, đang chờ cập nhật...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // Đợi một lúc để Firebase cập nhật dữ liệu
        await Future.delayed(Duration(seconds: 5));
        
        // Tải lại dữ liệu từ Firestore
        await _loadMealPlan();
        
      } else {
        print('❌ Lỗi khi tạo kế hoạch ăn đa dạng: ${response.statusCode}');
        throw Exception('Lỗi khi tạo kế hoạch ăn đa dạng: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi tạo kế hoạch ăn đa dạng: $e');
      
      // Xử lý lỗi kết nối
      String errorMessage = 'Không thể tạo kế hoạch ăn đa dạng';
      Color errorColor = Colors.red;
      
      // Kiểm tra loại lỗi cụ thể
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng hoặc liên hệ hỗ trợ.';
        errorColor = Colors.orange;
      } else {
        errorMessage = 'Không thể tạo kế hoạch ăn đa dạng: ${e.toString()}';
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = errorMessage;
        });
        
        // Hiển thị thông báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 