import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../services/meal_plan_api_service.dart';
import '../services/firestore_service.dart';
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
  int _selectedDayIndex = 5; // T.7 selected by default
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
      await userDataProvider.loadFromFirestore();
      
      // Đồng bộ với API nếu được bật
      if (userDataProvider.syncEnabled) {
        userDataProvider.sendToApi();
      }
    } catch (e) {
      debugPrint('Lỗi khi tải dữ liệu người dùng: $e');
    }
  }
  
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
      Map<String, dynamic> result;
      
      // Check if we're authenticated
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      // Lấy dữ liệu từ Firestore
      try {
        result = await _firestoreService!.getWeeklyMealPlan();
        print('Đã tải kế hoạch từ Firestore');
        
        // Đồng bộ kế hoạch ăn đã lấy được với API và Firestore
        _syncMealPlanData(result);
      } catch (firestoreError) {
        print('Lỗi Firestore: $firestoreError - Chuyển sang dùng API');
        
        // Nếu không thể lấy từ Firestore, thử lấy từ API
        try {
          // Kiểm tra kết nối API
          final isConnected = await MealPlanApiService.checkApiConnection();
          
          if (isConnected) {
            // Kiểm tra tình trạng AI
            final aiStatus = await MealPlanApiService.checkAIAvailability();
            final useAI = aiStatus['ai_available'] ?? false;
            
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
            
            // Lấy các tùy chọn dinh dưỡng cá nhân
            final preferences = userDataProvider.preferences;
            final allergies = userDataProvider.allergies;
            final cuisineStyle = userDataProvider.cuisineStyle;
            
            // Sử dụng demo API endpoint để tránh tác động đến API chính
            result = await MealPlanApiService.generateWeeklyMealPlan(
              caloriesTarget: caloriesTarget,
              proteinTarget: proteinTarget,
              fatTarget: fatTarget,
              carbsTarget: carbsTarget,
              useAI: useAI,
            );
            
            // Đồng bộ kế hoạch ăn mới với Firestore
            _syncMealPlanData(result);
          } else {
            // Use mock data
            result = await MealPlanApiService.getMockMealPlan();
          }
        } catch (apiError) {
          throw Exception('Không thể lấy dữ liệu từ API: $apiError');
        }
      }
      
      if (mounted) {
        setState(() {
          _mealPlan = MealPlan.fromJson(result);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading meal plan: $e');
      
      // Try to load mock data as fallback
      _loadMockData();
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
  
  // Đồng bộ dữ liệu kế hoạch ăn với Firestore
  Future<void> _syncMealPlanData(Map<String, dynamic> mealPlanData) async {
    if (!_isFirebaseInitialized || _firestoreService == null) {
      print('⚠️ Bỏ qua _syncMealPlanData vì Firebase chưa được khởi tạo');
      return;
    }
    
    try {
      await _firestoreService!.updateMealPlan(mealPlanData);
      print('✅ Đã đồng bộ kế hoạch ăn lên Firestore');
    } catch (e) {
      print('❌ Lỗi khi đồng bộ kế hoạch ăn lên Firestore: $e');
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
        ],
      ),
    );
  }
  
  Widget _buildBody() {
    if (_mealPlan == null) {
      return Center(child: Text('Không có dữ liệu kế hoạch thực đơn'));
    }
    
    final selectedDayName = _englishDays[_selectedDayIndex];
    final dayPlan = _mealPlan!.weeklyPlan[selectedDayName];
    
    if (dayPlan == null) {
      return Center(child: Text('Không có dữ liệu cho ngày đã chọn'));
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
                  child: Text(
                    'Kế hoạch dinh dưỡng cân bằng chất',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 16),
                  _buildMealNutrient(Icons.local_fire_department, calories.toString(), 'kcal', Colors.red),
                  SizedBox(width: 6),
                  _buildMealNutrient(Icons.adjust_rounded, protein.toString(), 'g', Colors.blue),
                  SizedBox(width: 6),
                  _buildMealNutrient(Icons.water_drop_outlined, fat.toString(), 'g', Colors.orange),
                  SizedBox(width: 6),
                  _buildMealNutrient(Icons.grass, carbs.toString(), 'g', Colors.green),
                ],
              ),
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
                        Expanded(child: Text(ingredient)),
                      ],
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
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        SizedBox(width: 2),
        Text(
          '$value$unit',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
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
      
      // Lấy ngày đang chọn
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
      
      // Chuẩn bị request data
      final replaceRequest = {
        'day_of_week': selectedDayName,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      // Kiểm tra tình trạng AI
      final aiStatus = await MealPlanApiService.checkAIAvailability();
      final useAI = aiStatus['ai_available'] ?? false;
      
      // Các tùy chọn cá nhân
      final preferences = userDataProvider.preferences;
      final allergies = userDataProvider.allergies;
      final cuisineStyle = userDataProvider.cuisineStyle;
      
      // Sử dụng phương thức replaceDayMealPlan thay vì replaceDay
      final response = await MealPlanApiService.replaceDayMealPlan(
        day: selectedDayName,
        caloriesTarget: caloriesTarget,
        proteinTarget: proteinTarget,
        fatTarget: fatTarget,
        carbsTarget: carbsTarget,
      );
      
      if (response != null && response.containsKey('day_meal_plan')) {
        // Cập nhật meal plan trong Firestore
        if (_mealPlan != null) {
          final updatedPlan = Map<String, dynamic>.from(_mealPlan!.toJson());
          updatedPlan['weekly_plan'][selectedDay] = response['day_meal_plan'];
          
          // Cập nhật Firestore
          await _firestoreService!.updateMealPlan(updatedPlan);
          
          // Cập nhật UI
          setState(() {
            _mealPlan = MealPlan.fromJson(updatedPlan);
          });
        }
        
        // Thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thay thế $mealType thành công${useAI ? " với AI" : ""}!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Không nhận được dữ liệu thay thế hợp lệ');
      }
    } catch (e) {
      print('Lỗi khi thay thế bữa ăn: $e');
      
      // Hiển thị lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể thay thế bữa ăn: ${e.toString()}'),
          backgroundColor: Colors.red,
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

  // Hàm kiểm tra kết nối Firebase
  Future<void> _checkFirebaseConnection() async {
    try {
      // Kiểm tra lại xem Firebase đã được khởi tạo chưa
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
          
          setState(() {
            _hasError = false;
            _isLoading = false;
          });
          
          // Tải lại dữ liệu nếu kiểm tra thành công
          _loadMealPlan();
        } catch (e) {
          print('❌ Lỗi khi lấy thông tin người dùng: $e');
          
          // Thử kiểm tra cấu hình Firebase
          try {
            await _checkPackageName();
          } catch (checkError) {
            print('❌ Lỗi khi kiểm tra package name: $checkError');
          }
          
          throw e;
        }
      } catch (e) {
        print('❌ Firebase chưa được khởi tạo hoặc cấu hình chưa đúng: $e');
        
        // Thử khởi tạo lại Firebase
        try {
          print('🔄 Đang thử khởi tạo lại Firebase...');
          await Firebase.initializeApp();
          print('✅ Đã khởi tạo Firebase thành công');
          
          // Gán biến toàn cục
          main_app.isFirebaseInitialized = true;
          _isFirebaseInitialized = true;
          
          // Khởi tạo FirestoreService và tải lại dữ liệu
          _firestoreService = FirestoreService();
          _loadMealPlan();
          
          setState(() {
            _hasError = false;
            _isLoading = false;
          });
          
          return;
        } catch (initError) {
          print('❌ Không thể khởi tạo Firebase: $initError');
          throw initError;
        }
      }
    } catch (e) {
      print('❌ Lỗi kết nối Firebase: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Không thể kết nối với Firebase: ${_getReadableErrorMessage(e.toString())}';
        _isLoading = false;
      });
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
} 