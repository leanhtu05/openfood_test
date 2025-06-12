import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:math';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../services/food_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../adapters/food_data_adapter.dart';
import 'dart:async'; // Added for Timer
import '../providers/user_data_provider.dart' as udp;
import '../utils/tdee_calculator.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FoodProvider with ChangeNotifier {
  final FoodDatabaseService _databaseService = FoodDatabaseService();
  final _uuid = Uuid();
  final Random _random = Random(); // Biến ngẫu nhiên để sử dụng trong demo mode
  
  List<FoodEntry> _foodEntries = [];
  List<FoodItem> _favoriteItems = [];
  List<FoodItem> _recentItems = [];
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  bool _isLoading = false;
  bool _isDuplicateCheckEnabled = true; // Biến kiểm soát việc kiểm tra trùng lặp
  
  Map<String, dynamic>? _dailyNutritionSummary;
  List<FoodEntry> _dailyMeals = [];
  bool _isLoadingSummary = false;
  bool _isLoadingMeals = false;

  // Cache for daily summary and meals
  final Map<String, Map<String, dynamic>> _dailySummaryCache = {};
  final Map<String, List<FoodEntry>> _dailyMealsCache = {};
  
  // Key cho SharedPreferences
  static const String _foodEntriesKey = 'food_entries_data';
  static const String _favoriteItemsKey = 'favorite_food_items';
  static const String _recentItemsKey = 'recent_food_items';
  
  final FirebaseAuth _authService;
  
  // Constructor
  FoodProvider({FirebaseAuth? authService}) 
      : _authService = authService ?? FirebaseAuth.instance {
    _loadFoodEntriesFromPrefs();
    
    // Listen for auth state changes
    _authService.authStateChanges().listen((User? user) {
      if (user != null) {
        // User logged in, sync data from Firebase
        syncFromFirebase();
      } else {
        // User logged out, clear data
        clearDataOnLogout();
      }
    });
  }
  
  // Method to clear data when user logs out
  Future<void> clearDataOnLogout() async {
    try {
      debugPrint('🧹 FoodProvider: Clearing data on logout...');
      
      // Clear all food entries
      _foodEntries = [];
      
      // Clear caches
      _calculationCache.clear();
      _dailySummaryCache.clear();
      _dailyMealsCache.clear();
      
      // Reset nutritional data
      _dailyNutritionSummary = null;
      _dailyMeals = [];
      
      // Update SharedPreferences
      await _saveFoodEntriesToPrefs();
      
      // Notify UI to update
      notifyListeners();
      
      debugPrint('✅ FoodProvider: Data cleared successfully on logout');
    } catch (e) {
      debugPrint('❌ FoodProvider: Error clearing data on logout: $e');
    }
  }
  
  // Getters
  List<FoodEntry> get allFoodEntries => _foodEntries;
  List<FoodEntry> get todayEntries {
    final entries = _foodEntries.where((entry) {
      // Lấy ngày từ entry
      final entryDate = entry.dateTime.toIso8601String().split('T')[0];
      
      // So sánh với ngày đã chọn
      final match = entryDate == _selectedDate;
      
      // Debug log để theo dõi
      if (match) {
        print('DEBUG PROVIDER: Entry khớp với ngày $_selectedDate: ${entry.description}');
      }
      
      return match;
    }).toList();
    
    // Thêm debug log
    print('DEBUG PROVIDER: todayEntries gọi với ngày $_selectedDate, tìm thấy ${entries.length} mục');
    for (var entry in entries) {
      final entryDate = entry.dateTime.toIso8601String().split('T')[0]; 
      print('DEBUG PROVIDER: - ${entry.description} (${entry.mealType}) - ngày: $entryDate');
    }
    
    return entries;
  }
  List<FoodItem> get favoriteItems => _favoriteItems;
  List<FoodItem> get recentItems => _recentItems;
  String get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  
  // For compatibility with existing code
  List<FoodEntry> get entries => _foodEntries;
  List<FoodEntry> get favoriteEntries => _foodEntries.where((entry) => entry.isFavorite).toList();
  
  // Getters for new data and loading states
  Map<String, dynamic>? get dailyNutritionSummary => _dailyNutritionSummary;
  List<FoodEntry> get dailyMeals => _dailyMeals;
  bool get isLoadingSummary => _isLoadingSummary;
  bool get isLoadingMeals => _isLoadingMeals;
  
  // Thêm biến cache để lưu kết quả tính toán
  final Map<String, Map<String, dynamic>> _calculationCache = {};

  // Xóa cache dinh dưỡng để đảm bảo tính toán lại
  void clearNutritionCache() {
    _calculationCache.clear();
    _dailySummaryCache.clear();
    _dailyMealsCache.clear();
      notifyListeners();
    print('FoodProvider: Đã xóa cache dinh dưỡng');
  }
  
  // Phương thức để làm mới dữ liệu dinh dưỡng
  Future<void> refreshNutrition() async {
    // Xóa cache để đảm bảo dữ liệu được tính toán lại
    _calculationCache.clear();
    _dailySummaryCache.clear();
    _dailyMealsCache.clear();
    
    // Đảm bảo tất cả các entry đã được cập nhật đúng cách
    for (int i = 0; i < _foodEntries.length; i++) {
      final entry = _foodEntries[i];
      
      // Đảm bảo thông tin dinh dưỡng được tính toán lại từ các item nếu cần
      if (entry.items.isNotEmpty) {
        if (entry.nutritionInfo == null || entry.nutritionInfo!.isEmpty) {
          // Tính toán giá trị mới từ các item
          final nutritionValues = entry.calculateNutritionFromAPI();
          
          // Tạo thông tin dinh dưỡng mới
          final updatedNutritionInfo = {
            'calories': nutritionValues['calories'],
            'protein': nutritionValues['protein'],
            'fat': nutritionValues['fat'],
            'carbs': nutritionValues['carbs'],
            'fiber': nutritionValues['fiber'],
            'sugar': nutritionValues['sugar'],
            'sodium': nutritionValues['sodium'],
            'servingSize': entry.items.first.servingSize,
            'totalWeight': entry.items.first.servingSize * 100,
          };
          
          // Cập nhật entry
          _foodEntries[i] = entry.copyWith(nutritionInfo: updatedNutritionInfo);
        } 
        else {
          // Đảm bảo các khóa snake_case và camelCase đều được cập nhật
          final servingSize = entry.items.first.servingSize;
          final updatedNutritionInfo = Map<String, dynamic>.from(entry.nutritionInfo!);
          
          // Đảm bảo các khóa cơ bản luôn tồn tại
          updatedNutritionInfo['servingSize'] = servingSize;
          updatedNutritionInfo['totalWeight'] = servingSize * 100;
          
          // Đảm bảo tất cả các vi chất dinh dưỡng có cả camelCase và snake_case
          _syncNutrientKeys(updatedNutritionInfo);
          
          // Cập nhật entry
          _foodEntries[i] = entry.copyWith(nutritionInfo: updatedNutritionInfo);
        }
      }
    }
    
    // Đánh dấu rằng dữ liệu đã thay đổi, cần cập nhật UI
    notifyListeners();
    
    // Đảm bảo dữ liệu được lưu
    await _saveData();
    
    // Log để debug
    print('FoodProvider: Đã làm mới dữ liệu dinh dưỡng, UI sẽ được cập nhật');
  }
  
  // Hàm đồng bộ khóa dinh dưỡng giữa camelCase và snake_case
  void _syncNutrientKeys(Map<String, dynamic> nutritionInfo) {
    // Danh sách các khóa cần đồng bộ: snake_case -> camelCase và ngược lại
    final keyMappings = {
      'vitamin_a': 'vitaminA',
      'vitamin_b12': 'vitaminB12',
      'vitamin_c': 'vitaminC',
      'vitamin_d': 'vitaminD',
      'vitamin_e': 'vitaminE',
      'vitamin_k': 'vitaminK',
      'vitamin_b9': 'vitaminB9',
      'vitamin_b': 'vitaminB',
      'saturated_fat': 'saturatedFat',
      'trans_fat': 'transFat',
      // Thêm các khóa còn thiếu
      'cholesterol': 'cholesterol',
      'omega3': 'omega3',
      'fiber': 'fiber',
      'water': 'water',
      'sugar': 'sugar',
      'caffeine': 'caffeine',
      'alcohol': 'alcohol',
      'iron': 'iron',
      'calcium': 'calcium',
      'magnesium': 'magnesium',
      'potassium': 'potassium',
      'zinc': 'zinc',
      'phosphorus': 'phosphorus',
      'selenium': 'selenium',
      'copper': 'copper',
      'manganese': 'manganese',
      'thiamin': 'thiamin',
      'riboflavin': 'riboflavin',
      'niacin': 'niacin',
    };
    
    // Đồng bộ từ snake_case sang camelCase và ngược lại
    keyMappings.forEach((snakeKey, camelKey) {
      // Từ snake_case sang camelCase
      if (nutritionInfo.containsKey(snakeKey) && nutritionInfo[snakeKey] != null) {
        nutritionInfo[camelKey] = nutritionInfo[snakeKey];
      }
      // Từ camelCase sang snake_case
      else if (nutritionInfo.containsKey(camelKey) && nutritionInfo[camelKey] != null) {
        nutritionInfo[snakeKey] = nutritionInfo[camelKey];
      }
    });
  }
  
  // Hiển thị thông báo khi thêm mới bữa ăn
  void showFoodAddedToast(BuildContext context, FoodEntry entry) {
    // Tạo thông báo hiển thị ở dưới màn hình
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.clearSnackBars();
    
    scaffold.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã thêm vào nhật ký!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${entry.description} - ${entry.totalCalories} kcal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.green[800],
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'XEM',
          textColor: Colors.white,
          onPressed: () {
            // Chuyển tới màn hình lịch sử bữa ăn
            Navigator.of(context).pushNamed('/food-history');
          },
        ),
      ),
    );
  }
  
  // Cập nhật giao diện Home
  void updateHomeScreenWithNewEntry(BuildContext context, FoodEntry entry) {
    // Thêm vào danh sách các entry nếu chưa có
    if (!_foodEntries.any((e) => e.id == entry.id)) {
      _foodEntries.add(entry);
    }
    
    // Lưu dữ liệu
    _saveData();
    
    // Xóa cache để đảm bảo dữ liệu được tính toán lại
    clearNutritionCache();
    
    // Làm mới dữ liệu dinh dưỡng
    refreshNutrition();
    
    // Lấy ngày của entry để log
    final entryDate = entry.dateTime.toIso8601String().split('T')[0];
    
    // Đảm bảo UI được cập nhật
    notifyListeners();
    
    // Hiển thị thông báo với thông tin chi tiết về bữa ăn
    showFoodAddedToast(context, entry);
    
    // Log hoạt động 
    print('Đã thêm bữa ăn: ${entry.description} - ${entry.mealType}');
    print('Tổng calories: ${entry.totalCalories} kcal');
    print('Tổng protein: ${entry.totalProtein}g');
    print('Tổng carbs: ${entry.totalCarbs}g');
    print('Tổng chất béo: ${entry.totalFat}g');
    print('Đã làm mới dữ liệu dinh dưỡng và bữa ăn cho ngày $entryDate');
  }
  
  // Đặt ngày hiện tại
  void setToday() {
    _selectedDate = DateTime.now().toIso8601String().split('T')[0];
    notifyListeners();
  }
  
  // Lấy danh sách bữa ăn theo ngày
  List<FoodEntry> getEntriesByDate(String date) {
    return _foodEntries.where((entry) => 
      entry.dateTime.toIso8601String().split('T')[0] == date).toList();
  }
  
  // Thêm FoodEntry vào ngày cụ thể
  Future<FoodEntry> addFoodEntryForDate({
    required String date,
    required String description,
    required String mealType,
    List<FoodItem>? items,
    File? image,
  }) async {
    // Chuyển đổi date từ chuỗi sang DateTime
    final dateParts = date.split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    
    // Lấy thời gian hiện tại để thêm vào ngày được chọn
    final now = DateTime.now();
    final timestamp = DateTime(
      year, 
      month, 
      day,
      now.hour,  // Thêm giờ hiện tại
      now.minute, // Thêm phút hiện tại
      now.second  // Thêm giây hiện tại
    );
    
    final entry = FoodEntry(
      id: _uuid.v4(),
      description: description,
      imagePath: image?.path,
      mealType: mealType,
      dateTime: timestamp,
      items: items ?? [],
    );
    
    _foodEntries.add(entry);
    
    // Cập nhật danh sách các món ăn gần đây
    if (items != null && items.isNotEmpty) {
      for (var item in items) {
        _addToRecentItems(item);
      }
    }
    
    notifyListeners();
    _saveData();
    
    // In ra log để debug
    print('Đã tạo bữa ăn mới vào ngày ${timestamp.toString()}');
    
    return entry;
  }
  
  // Xóa tất cả bữa ăn theo ngày
  Future<void> clearDateEntries(String date) async {
    _foodEntries.removeWhere((entry) => 
      entry.dateTime.toIso8601String().split('T')[0] == date);
    
    notifyListeners();
    _saveData();
  }
  
  // Simulate AI food recognition with demo data
  List<String> _recognizeWithDemoMode(File image) {
    // In demo mode, return some mock data
    final demoFoods = [
      'Cơm tấm sườn',
      'Phở bò',
      'Bún chả',
      'Bánh mì thịt',
      'Gỏi cuốn',
      'Cháo',
      'Mì xào hải sản',
      'Cơm chiên dương châu',
      'Bánh xèo',
      'Canh chua',
      'Rau muống xào tỏi',
      'Thịt kho tàu',
      'Cà ri gà',
      'Cơm gà',
      'Hủ tiếu',
      'Cơm rang',
      'Salad',
      'Mì gói',
      'Khoai tây chiên',
      'Hamburger',
      'Pizza',
      'Sushi',
    ];
    
    // Choose 1-3 random foods
    final numberOfFoods = 1 + _random.nextInt(2); // 1 to 2 items
    final selectedFoods = <String>[];
    
    for (int i = 0; i < numberOfFoods; i++) {
      final randomIndex = _random.nextInt(demoFoods.length);
      final food = demoFoods[randomIndex];
      if (!selectedFoods.contains(food)) {
        selectedFoods.add(food);
      }
    }
    
    print('Demo Recognition: Identified ${selectedFoods.join(", ")}');
    return selectedFoods;
  }
  
  // Lấy FoodEntry theo ID
  FoodEntry? getFoodEntryById(String id) {
    try {
      print('getFoodEntryById: Tìm entry với ID: $id');
      print('getFoodEntryById: Tổng số entries: ${_foodEntries.length}');
      
      final entries = _foodEntries.where((entry) => entry.id == id).toList();
      if (entries.isEmpty) {
        print('getFoodEntryById: Không tìm thấy entry với ID: $id');
        return null;
      }
      
      final original = entries.first;
      final entryDate = original.dateTime.toIso8601String().split('T')[0];
      print('getFoodEntryById: Đã tìm thấy entry với ID: $id, Ngày: $entryDate');
      
      return original; // Có thể tạo bản sao mới ở đây nếu cần
    } catch (e) {
      print('Không tìm thấy FoodEntry với ID: $id, Lỗi: $e');
      return null;
    }
  }
  
  // Thêm phương thức đồng bộ dữ liệu dinh dưỡng để đảm bảo thông tin nhất quán từ API đến UI khi thay đổi khẩu phần
  Future<void> synchronizeNutrition({
    required String entryId, 
    required double servingSize,
    bool notifyChange = true
  }) async {
    // Tìm và cập nhật RIÊNG LẺ FoodEntry theo ID
    final entryIndex = _foodEntries.indexWhere((entry) => entry.id == entryId);
    if (entryIndex == -1) {
      print('Không tìm thấy entry với ID $entryId để đồng bộ');
      return;
    }
    
    // Lấy entry cần cập nhật
    final entry = _foodEntries[entryIndex];
    
    // Cập nhật các items trong entry
    if (entry.items.isNotEmpty) {
      // Lấy khẩu phần cũ để tính tỷ lệ
      final oldServingSize = entry.items.first.servingSize;
      final ratio = servingSize / oldServingSize;
      
      // Cập nhật từng item với servingSize mới và cập nhật calories
      final updatedItems = entry.items.map((item) {
        // Tính toán lại calories dựa trên kích thước khẩu phần mới
        double updatedCalories = item.calories * ratio;
        double updatedProtein = item.protein * ratio;
        double updatedFat = item.fat * ratio;
        double updatedCarbs = item.carbs * ratio;
        
        // Cập nhật các giá trị dinh dưỡng bổ sung nếu có
        double? updatedFiber = item.fiber != null ? item.fiber! * ratio : null;
        double? updatedSugar = item.sugar != null ? item.sugar! * ratio : null;
        double? updatedSodium = item.sodium != null ? item.sodium! * ratio : null;
        
        // Tạo bản sao của item với servingSize và các giá trị dinh dưỡng mới
        return item.copyWith(
          servingSize: servingSize,
          calories: updatedCalories,
          protein: updatedProtein,
          fat: updatedFat,
          carbs: updatedCarbs,
          fiber: updatedFiber,
          sugar: updatedSugar,
          sodium: updatedSodium,
        );
      }).toList();
      
      // Cập nhật thông tin dinh dưỡng
      Map<String, dynamic>? updatedNutritionInfo;
      
      if (entry.nutritionInfo != null) {
        updatedNutritionInfo = Map<String, dynamic>.from(entry.nutritionInfo!);
        
        // Cập nhật khẩu phần
        updatedNutritionInfo['servingSize'] = servingSize;
        
        // Cập nhật tổng khối lượng - đảm bảo luôn có totalWeight
        final oldTotalWeight = updatedNutritionInfo['totalWeight'] ?? (oldServingSize * 100);
        updatedNutritionInfo['totalWeight'] = (oldTotalWeight * ratio).toDouble();
        
        // Cập nhật các giá trị dinh dưỡng chính theo tỷ lệ
        for (var nutrient in ['calories', 'protein', 'fat', 'carbs', 'fiber', 'sugar', 'sodium']) {
          if (updatedNutritionInfo.containsKey(nutrient) && updatedNutritionInfo[nutrient] is num) {
            updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
          }
        }
        
        // Cập nhật các vi chất dinh dưỡng theo tỷ lệ
        final micronutrients = [
          // Danh sách vi chất cũ
          'cholesterol', 'omega3', 'vitaminD', 'vitaminB12', 'vitaminC', 
          'calcium', 'iron', 'potassium', 'magnesium',
          
          // Thêm các khóa snake_case để đảm bảo dữ liệu được cập nhật đúng cách
          'vitamin_d', 'vitamin_b12', 'vitamin_c', 'vitamin_a', 'vitamin_e', 'vitamin_k',
          'vitamin_b9', 'vitamin_b', 'saturated_fat', 'trans_fat', 'phosphorus', 'selenium',
          'copper', 'manganese', 'thiamin', 'riboflavin', 'niacin', 'water',
          
          // Các khóa camelCase bổ sung cũng để đảm bảo tương thích ngược
          'vitaminA', 'vitaminE', 'vitaminK', 'vitaminB9', 'vitaminB', 'saturatedFat', 'transFat',
          'zinc', 'caffeine', 'alcohol', 'phosphorus', 'selenium', 'copper', 
          'manganese', 'thiamin', 'riboflavin', 'niacin'
        ];
        
        for (var nutrient in micronutrients) {
          if (updatedNutritionInfo.containsKey(nutrient) && updatedNutritionInfo[nutrient] is num) {
            updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
          }
        }
        
        // Đảm bảo đồng bộ khóa giữa snake_case và camelCase
        _syncNutrientKeys(updatedNutritionInfo);
        
        // In ra log để debug
        print("synchronizeNutrition: Đã cập nhật các khóa: ${updatedNutritionInfo.keys.toList()}");
        
        // Kiểm tra và in ra giá trị Vitamin D - chỉ để debug
        print("synchronizeNutrition: Vitamin D = ${updatedNutritionInfo['vitamin_d']}, VitaminD = ${updatedNutritionInfo['vitaminD']}");
      } else {
        // Nếu không có nutritionInfo, tạo mới với totalWeight
        updatedNutritionInfo = {
          'servingSize': servingSize,
          'totalWeight': servingSize * 100,
          'calories': updatedItems.fold(0.0, (sum, item) => sum + item.calories),
          'protein': updatedItems.fold(0.0, (sum, item) => sum + item.protein),
          'fat': updatedItems.fold(0.0, (sum, item) => sum + item.fat),
          'carbs': updatedItems.fold(0.0, (sum, item) => sum + item.carbs),
        };
        
        // Đảm bảo đồng bộ khóa dinh dưỡng ngay từ đầu
        _syncNutrientKeys(updatedNutritionInfo);
      }
      
      // Tạo FoodEntry mới với items và thông tin dinh dưỡng đã cập nhật
      final updatedEntry = FoodEntry(
        id: entry.id,
        description: entry.description,
        imagePath: entry.imagePath,
        audioPath: entry.audioPath,
        dateTime: entry.dateTime,
        isFavorite: entry.isFavorite,
        barcode: entry.barcode,
        calories: updatedItems.fold(0.0, (sum, item) => sum + item.calories),
        nutritionInfo: updatedNutritionInfo,
        mealType: entry.mealType,
        items: updatedItems,
      );
      
      // Cập nhật entry trong danh sách
      _foodEntries[entryIndex] = updatedEntry;
      
      // Xóa cache để tính toán lại các giá trị dinh dưỡng
      _calculationCache.clear();
      
      // Thông báo cho UI cập nhật
      if (notifyChange) {
        // Sử dụng Future.microtask để tránh gọi notifyListeners trong quá trình build
        Future.microtask(() {
          print("FoodProvider: Đã làm mới dữ liệu dinh dưỡng, UI sẽ được cập nhật");
          notifyListeners();
        });
      }
      
      // Lưu dữ liệu
      await _saveData();
    }
  }
  
  // Hàm hỗ trợ cập nhật các giá trị dinh dưỡng bổ sung theo tỷ lệ
  Map<String, dynamic> _updateAdditionalNutrients(Map<String, dynamic> nutrients, double ratio) {
    final result = Map<String, dynamic>.from(nutrients);
    
    result.forEach((key, value) {
      if (value is num) {
        result[key] = (value * ratio).toDouble();
      }
    });
    
    return result;
  }

  // Thêm mục nhập thực phẩm mới
  Future<bool> addFoodEntry(FoodEntry entry) async {
    try {
      debugPrint('🔄 addFoodEntry: Đang thêm mục nhập thực phẩm "${entry.description}" với ID ${entry.id}');
      
      // Kiểm tra và xóa các món trùng lặp trước khi thêm mới
      await removeDuplicateFoodEntries();
      
      // Kiểm tra xem có món ăn tương tự không (cùng ngày, cùng loại, cùng mô tả)
      final similarEntries = _foodEntries.where((existingEntry) => 
        existingEntry.description == entry.description &&
        existingEntry.mealType == entry.mealType &&
        existingEntry.dateTime.toIso8601String().split('T')[0] == entry.dateTime.toIso8601String().split('T')[0]
      ).toList();
      
      if (similarEntries.isNotEmpty) {
        debugPrint('⚠️ addFoodEntry: Phát hiện món ăn tương tự. Sẽ cập nhật món ăn này thay vì tạo mới');
        final existingEntry = similarEntries.first;
        return await updateFoodEntry(entry.copyWith(id: existingEntry.id));
      }
      
      // Thêm vào danh sách local
      _foodEntries.add(entry);
      notifyListeners();
      
      // Lưu vào SharedPreferences
      await _saveFoodEntriesToPrefs();
      debugPrint('💾 addFoodEntry: Đã lưu mục nhập thực phẩm vào SharedPreferences');
      
      // Gửi đến API
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          debugPrint('🔄 addFoodEntry: Bắt đầu gửi mục nhập thực phẩm "${entry.description}" lên collection food_records...');
          
          final result = await ApiService.sendFoodEntry(entry, userId);
          if (result) {
            debugPrint('✅ addFoodEntry: Đã gửi mục nhập thực phẩm đến collection food_records thành công');
          } else {
            debugPrint('⚠️ addFoodEntry: Không thể gửi mục nhập thực phẩm đến collection food_records');
          }
          return result;
        } catch (e) {
          debugPrint('❌ addFoodEntry: Lỗi khi gửi mục nhập thực phẩm đến collection food_records: $e');
          return false;
        }
      } else {
        debugPrint('⚠️ addFoodEntry: Không thể gửi mục nhập thực phẩm: Người dùng chưa đăng nhập');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ addFoodEntry: Lỗi khi thêm mục nhập thực phẩm: $e');
      return false;
    }
  }

  // Kiểm tra xem chế độ demo có được bật không
  Future<bool> _isDemoModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Mặc định là true để có dữ liệu demo khi mới cài đặt ứng dụng
      return prefs.getBool('demo_mode_enabled') ?? true;
    } catch (e) {
      print('Lỗi khi kiểm tra chế độ demo: $e');
      return false;
    }
  }
  
  // Thêm dữ liệu demo cho ngày hiện tại
  Future<void> _addDemoFoodEntries() async {
    try {
      // Tạo datetime cho hôm nay với giờ phù hợp
      final today = DateTime.parse('${_selectedDate}T00:00:00Z');
      

      // Thêm vào danh sách


      // Lưu vào bộ nhớ
      await _saveData();

      // Thông báo thay đổi
      notifyListeners();
      
      print('DEBUG PROVIDER: Đã thêm 3 mục demo cho ngày $_selectedDate');
    } catch (e) {
      print('Lỗi khi thêm dữ liệu demo: $e');
    }
  }

  // Đồng bộ một food item cụ thể sang các entry khác sử dụng item đó
  void _syncItemToOtherEntries(FoodItem updatedItem, String sourceEntryId) {
    // Không thực hiện đồng bộ giữa các entry
    return;
  }
  
  // Thêm món ăn vào bữa ăn
  Future<void> addFoodItemToEntry({
    required String entryId,
    required FoodItem foodItem
  }) async {
    final entryIndex = _foodEntries.indexWhere((entry) => entry.id == entryId);
    if (entryIndex == -1) return;
    
    final entry = _foodEntries[entryIndex];
    
    // Tạo bản sao của foodItem với ID mới để tránh đồng bộ giữa các bữa ăn khác nhau
    final newFoodItem = foodItem.copyWith(
      id: Uuid().v4(),  // Tạo ID mới để đảm bảo độc lập
    );
    
    final updatedItems = [...entry.items, newFoodItem];
    
    _foodEntries[entryIndex] = entry.copyWith(items: updatedItems);
    
    // Xóa cache để tính toán lại các giá trị dinh dưỡng
    _calculationCache.clear();
    
    // Thông báo cho UI cập nhật
    notifyListeners();
    
    // Lưu dữ liệu
    await _saveData();
  }

  // Create a TRULY DEEP copy of a FoodEntry with totally new IDs
  FoodEntry createDeepCopy(FoodEntry original) {
    // Tạo bản sao của tất cả các items với ID hoàn toàn mới
    final newItems = original.items.map((item) {
      // Tạo một nutritionInfo mới nếu có
      Map<String, dynamic>? newAdditionalNutrients;
      if (item.additionalNutrients != null) {
        newAdditionalNutrients = Map<String, dynamic>.from(item.additionalNutrients!);
      }
      
      return FoodItem(
        id: _uuid.v4(), // Tạo ID hoàn toàn mới
        name: item.name,
        brand: item.brand,
        calories: item.calories,
        protein: item.protein,
        fat: item.fat,
        carbs: item.carbs,
        servingSize: item.servingSize,
        servingUnit: item.servingUnit,
        fiber: item.fiber,
        sugar: item.sugar,
        sodium: item.sodium,
        imageUrl: item.imageUrl,
        additionalNutrients: newAdditionalNutrients,
      );
    }).toList();
    
    // Tạo bản sao MỚI HOÀN TOÀN của nutritionInfo nếu có
    Map<String, dynamic>? newNutritionInfo;
    if (original.nutritionInfo != null) {
      newNutritionInfo = Map<String, dynamic>.from(original.nutritionInfo!);
    }
    
    // Tạo FoodEntry mới với ID mới và dữ liệu mới
    return FoodEntry(
      id: _uuid.v4(), // Tạo ID hoàn toàn mới
      description: original.description,
      imagePath: original.imagePath,
      audioPath: original.audioPath,
      dateTime: original.dateTime,
      isFavorite: original.isFavorite,
      barcode: original.barcode,
      calories: original.calories,
      nutritionInfo: newNutritionInfo,
      mealType: original.mealType,
      items: newItems,
    );
  }

  // Khi thêm FoodEntry từ màn hình tìm kiếm vào nhật ký
  Future<FoodEntry> addCopiedFoodEntry(FoodEntry originalEntry, String mealType, DateTime dateTime) async {
  // Tạo bản sao hoàn toàn mới
  final newEntry = createDeepCopy(originalEntry);
  
  // Cập nhật mealType và dateTime
  final updatedEntry = newEntry.copyWith(
    mealType: mealType,
    dateTime: dateTime,
    id: FirebaseFirestore.instance.collection('food_entries').doc().id, // Tạo ID mới cho entry
  );
  
  // Thêm vào danh sách local
  _foodEntries.add(updatedEntry);
  notifyListeners();
  await _saveData();
  
  // Lưu vào Firestore nếu người dùng đã đăng nhập
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && ApiService.useDirectFirestore) {
    try {
      debugPrint('🔄 Đang lưu thông tin đầy đủ của bữa ăn vào Firestore...');
      
      // Chuẩn bị dữ liệu để lưu vào Firestore
      final date = dateTime.toIso8601String().split('T')[0];
      final entryData = {
        ...updatedEntry.toJson(),
        'user_id': user.uid,
        'date': date, // Thêm trường date để dễ truy vấn
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'id': updatedEntry.id,
        'description': updatedEntry.description,
        'dateTime': dateTime.toIso8601String(),
        'mealType': mealType,
      };
      
      // In ra dữ liệu để kiểm tra
      debugPrint('   📝 Dữ liệu đầy đủ sẽ lưu vào Firestore:');
      entryData.forEach((key, value) {
        if (value is Map || value is List) {
          debugPrint('      - $key: [Dữ liệu phức tạp]');
        } else {
          debugPrint('      - $key: $value');
        }
      });
      
      // Sử dụng set với merge: true thay vì update để tránh lỗi NOT_FOUND
      await FirebaseFirestore.instance
        .collection('food_entries')
        .doc(updatedEntry.id)
        .set(entryData, SetOptions(merge: true));
      
      debugPrint('✅ Đã lưu thông tin đầy đủ bữa ăn vào Firestore thành công');
      
      // Kiểm tra collection có tồn tại không
      final countQuery = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      debugPrint('   - Tổng số mục nhập thực phẩm của người dùng: ${countQuery.docs.length}');
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu dữ liệu vào Firestore: $e');
      
      // Thử phương pháp 2: Sử dụng ApiService
      try {
        final success = await ApiService.sendFoodEntry(updatedEntry, user.uid);
        if (success) {
          debugPrint('✅ Đã lưu thông tin bữa ăn vào Firestore thành công qua ApiService');
        } else {
          debugPrint('❌ Không thể lưu thông tin bữa ăn vào Firestore qua ApiService');
        }
      } catch (apiError) {
        debugPrint('❌ Lỗi khi gọi ApiService.sendFoodEntry: $apiError');
      }
    }
  }
  
  return updatedEntry;
}  

  Future<void> updateServingSize(String entryId, double newServingSize) async {
    final entryIndex = _foodEntries.indexWhere((entry) => entry.id == entryId);
    if (entryIndex == -1) return;
    
    final entry = _foodEntries[entryIndex];
    FoodEntry updatedEntry;
    
    if (entry.nutritionInfo != null) {
      // Cập nhật nutritionInfo
      final updatedNutritionInfo = Map<String, dynamic>.from(entry.nutritionInfo!);
      
      // Đảm bảo cập nhật cả servingSize và totalWeight
      updatedNutritionInfo['servingSize'] = newServingSize;
      updatedNutritionInfo['totalWeight'] = newServingSize * 100;
      
      // Cập nhật entry
      updatedEntry = entry.copyWith(
        nutritionInfo: updatedNutritionInfo,
      );
      
      // Cập nhật vào danh sách local
      _foodEntries[entryIndex] = updatedEntry;
      
      // Đảm bảo cập nhật lại các items nếu cần
      await synchronizeNutrition(
        entryId: entryId,
        servingSize: newServingSize,
      );
      
      // Lưu vào Firestore nếu người dùng đã đăng nhập
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && ApiService.useDirectFirestore) {
        try {
          debugPrint('🔄 Đang cập nhật khẩu phần ăn trên Firestore...');
          
          // Chuẩn bị dữ liệu để cập nhật
          final date = updatedEntry.dateTime.toIso8601String().split('T')[0];
          final updateData = {
            'nutritionInfo': updatedEntry.nutritionInfo,
            'updated_at': DateTime.now().toIso8601String(),
            'date': date, // Đảm bảo trường date được cập nhật
          };
          
          // Sử dụng set với merge: true thay vì update để tránh lỗi NOT_FOUND
          await FirebaseFirestore.instance
            .collection('food_entries')
            .doc(entryId)
            .set(updateData, SetOptions(merge: true));
          
          debugPrint('✅ Đã cập nhật khẩu phần ăn trên Firestore thành công');
        } catch (e) {
          debugPrint('❌ Lỗi khi cập nhật khẩu phần ăn trên Firestore: $e');
          
          // Thử phương pháp 2: Sử dụng ApiService
          try {
            final success = await ApiService.updateFoodEntry(updatedEntry, user.uid);
            if (success) {
              debugPrint('✅ Đã cập nhật khẩu phần ăn qua ApiService thành công');
            } else {
              debugPrint('❌ Không thể cập nhật khẩu phần ăn qua ApiService');
            }
          } catch (apiError) {
            debugPrint('❌ Lỗi khi gọi ApiService.updateFoodEntry: $apiError');
          }
        }
      }
    }
    
    notifyListeners();
    await _saveData();
  }

  // Tính toán và tổng hợp giá trị dinh dưỡng cho một ngày
  Future<void> fetchDailyNutritionSummary(String date, [BuildContext? context]) async {
    // Kiểm tra cache trước tiên
    if (_dailySummaryCache.containsKey(date)) {
      _dailyNutritionSummary = _dailySummaryCache[date];
      notifyListeners();
      return;
    }

    _isLoadingSummary = true;
    notifyListeners();

    // Simulate API call
    await Future.delayed(Duration(milliseconds: 800)); // Simulate network delay

    // Get the actual nutrition values for the selected date
    final nutritionValues = getNutritionTotals(date: date);

    // Synchronize with TDEE goals if context is provided
    Map<String, dynamic> nutritionGoals = {};
    if (context != null) {
      try {
        // Get UserDataProvider
        final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);

        // Ưu tiên sử dụng mục tiêu dinh dưỡng từ UserDataProvider
        if (userDataProvider.nutritionGoals.isNotEmpty) {
          nutritionGoals = Map<String, dynamic>.from(userDataProvider.nutritionGoals);
          print('Using direct nutrition goals from UserDataProvider');
        } else {
          // Create TDEE calculator
          final calculator = TDEECalculator(
            gender: userDataProvider.gender,
            age: userDataProvider.age,
            heightCm: userDataProvider.heightCm,
            weightKg: userDataProvider.weightKg,
            activityLevel: userDataProvider.activityLevel,
            goal: userDataProvider.goal,
            pace: userDataProvider.pace,
          );

          // Get daily calories goal
          final dailyCalories = calculator.calculateDailyCalories();

          // Get macros distribution
          final macros = calculator.calculateMacroDistribution();

          // Set goals from TDEE calculations
          nutritionGoals = {
            "calories": dailyCalories,
            "protein": macros['protein'] ?? 0,
            "carbs": macros['carbs'] ?? 0,
            "fat": macros['fat'] ?? 0,
            // Keep default values for other nutrients
            "cholesterol": 300,
            "omega3": 1600,
            "fiber": 38,
            "water": 2000,
            "sugar": 69,
            "saturated_fat": 20,
            "caffeine": 400,
            "alcohol": 30,
            "vitamin_d": 15,
            "vitamin_b12": 2.4,
            "vitamin_c": 90,
            "vitamin_b9": 400,
            "iron": 8.0,
            "calcium": 1000,
            "magnesium": 400,
            "zinc": 11
          };

          print('Synchronized nutrition goals with TDEE: Calories=${nutritionGoals["calories"]}, Protein=${nutritionGoals["protein"]}, Carbs=${nutritionGoals["carbs"]}, Fat=${nutritionGoals["fat"]}');
        }
      } catch (e) {
        print('Error synchronizing with TDEE goals: $e');
        // Fall back to default values if there's an error
      }
    }

    // If we couldn't get goals from TDEE, use default values
    if (nutritionGoals.isEmpty) {
      nutritionGoals = {
        "calories": 2782,
        "protein": 208,
        "fat": 92,
        "carbs": 278,
        "cholesterol": 300,
        "omega3": 1600,
        "fiber": 38,
        "water": 2000,
        "sugar": 69,
        "saturated_fat": 20,
        "caffeine": 400,
        "alcohol": 30,
        "vitamin_d": 15,
        "vitamin_b12": 2.4,
        "vitamin_c": 90,
        "vitamin_b9": 400,
        "iron": 8.0,
        "calcium": 1000,
        "magnesium": 400,
        "zinc": 11
      };
    }

    // Construct the daily nutrition summary with actual values and goals
    _dailyNutritionSummary = {
      "calories": {"value": nutritionValues['calories'] ?? 0, "goal": nutritionGoals["calories"]},
      "protein": {"value": nutritionValues['protein'] ?? 0, "goal": nutritionGoals["protein"]},
      "fat": {"value": nutritionValues['fat'] ?? 0, "goal": nutritionGoals["fat"]},
      "carbs": {"value": nutritionValues['carbs'] ?? 0, "goal": nutritionGoals["carbs"]},
      "cholesterol": {"value": nutritionValues['cholesterol'] ?? 0, "goal": nutritionGoals["cholesterol"]},
      "omega3": {"value": nutritionValues['omega3'] ?? 0, "goal": nutritionGoals["omega3"]},
      "fiber": {"value": nutritionValues['fiber'] ?? 0, "goal": nutritionGoals["fiber"]},
      "water": {"value": nutritionValues['water'] ?? 0, "goal": nutritionGoals["water"]},
      "sugar": {"value": nutritionValues['sugar'] ?? 0, "goal": nutritionGoals["sugar"]},
      "saturated_fat": {"value": nutritionValues['saturated_fat'] ?? 0, "goal": nutritionGoals["saturated_fat"]},
      "caffeine": {"value": nutritionValues['caffeine'] ?? 0, "goal": nutritionGoals["caffeine"]},
      "alcohol": {"value": nutritionValues['alcohol'] ?? 0, "goal": nutritionGoals["alcohol"]},
      "vitamin_d": {"value": nutritionValues['vitamin_d'] ?? 0, "goal": nutritionGoals["vitamin_d"]},
      "vitamin_b12": {"value": nutritionValues['vitamin_b12'] ?? 0, "goal": nutritionGoals["vitamin_b12"]},
      "vitamin_c": {"value": nutritionValues['vitamin_c'] ?? 0, "goal": nutritionGoals["vitamin_c"]},
      "vitamin_b9": {"value": nutritionValues['vitamin_b9'] ?? 0, "goal": nutritionGoals["vitamin_b9"]},
      "iron": {"value": nutritionValues['iron'] ?? 0, "goal": nutritionGoals["iron"]},
      "calcium": {"value": nutritionValues['calcium'] ?? 0, "goal": nutritionGoals["calcium"]},
      "magnesium": {"value": nutritionValues['magnesium'] ?? 0, "goal": nutritionGoals["magnesium"]},
      "zinc": {"value": nutritionValues['zinc'] ?? 0, "goal": nutritionGoals["zinc"]}
    };

    _dailySummaryCache[date] = _dailyNutritionSummary!;
    _isLoadingSummary = false;
    notifyListeners();
  }

  Future<void> fetchDailyMeals(String date) async {
    if (_dailyMealsCache.containsKey(date)) {
      _dailyMeals = _dailyMealsCache[date]!;
      notifyListeners();
      return;
    }

    _isLoadingMeals = true;
    notifyListeners();

    // Simulate API call
    await Future.delayed(Duration(milliseconds: 1200));

    // Khởi tạo một danh sách rỗng thay vì tạo dữ liệu mẫu
    _dailyMeals = [];
    _dailyMealsCache[date] = _dailyMeals;
    
    _isLoadingMeals = false;
    notifyListeners();
  }

  // Đồng bộ dữ liệu cho một food item cụ thể dựa trên ID và kích thước khẩu phần
  Future<void> synchronizeNutritionData(String itemId, double servingSize) async {
    try {
      // Tìm item trong tất cả các food entries
      FoodItem? foundItem;
      FoodEntry? parentEntry;
      
      for (var entry in _foodEntries) {
        for (var item in entry.items) {
          if (item.id == itemId) {
            foundItem = item;
            parentEntry = entry;
            break;
          }
        }
        if (foundItem != null) break;
      }
      
      if (foundItem == null || parentEntry == null) {
        print('Không tìm thấy item với ID $itemId để đồng bộ');
        return;
      }
      
      // Sau điểm này, chúng ta chắc chắn rằng foundItem và parentEntry không null
      // Đánh dấu các biến là non-nullable để Dart compiler hiểu
      final FoodItem nonNullItem = foundItem;
      final FoodEntry nonNullEntry = parentEntry;
      
      // Tính toán tỷ lệ giữa kích thước khẩu phần mới và cũ
      final oldServingSize = nonNullItem.servingSize;
      final ratio = servingSize / oldServingSize;
      
      // Tạo item mới với kích thước khẩu phần được cập nhật
      final updatedItem = FoodItem(
        id: nonNullItem.id,
        name: nonNullItem.name,
        brand: nonNullItem.brand,
        calories: nonNullItem.calories * ratio,
        protein: nonNullItem.protein * ratio,
        fat: nonNullItem.fat * ratio,
        carbs: nonNullItem.carbs * ratio,
        servingSize: servingSize,
        servingUnit: nonNullItem.servingUnit,
        fiber: nonNullItem.fiber != null ? nonNullItem.fiber! * ratio : null,
        sugar: nonNullItem.sugar != null ? nonNullItem.sugar! * ratio : null,
        sodium: nonNullItem.sodium != null ? nonNullItem.sodium! * ratio : null,
        imageUrl: nonNullItem.imageUrl,
        additionalNutrients: nonNullItem.additionalNutrients != null 
            ? _updateAdditionalNutrients(nonNullItem.additionalNutrients!, ratio) 
            : null,
      );
      
      // Cập nhật item trong danh sách items của entry
      final updatedItems = nonNullEntry.items.map((item) {
        if (item.id == itemId) {
          return updatedItem;
        }
        return item;
      }).toList();
      
      // Cập nhật nutritionInfo của entry nếu có
      Map<String, dynamic>? updatedNutritionInfo;
      if (nonNullEntry.nutritionInfo != null) {
        updatedNutritionInfo = Map<String, dynamic>.from(nonNullEntry.nutritionInfo!);
        
        // Nếu đây là item duy nhất hoặc item đầu tiên, cập nhật servingSize và totalWeight
        if (nonNullEntry.items.isNotEmpty && nonNullEntry.items.first.id == itemId) {
          updatedNutritionInfo['servingSize'] = servingSize;
          updatedNutritionInfo['totalWeight'] = servingSize * 100;
        }
      }
      
      // Tạo entry mới với items đã cập nhật
      final updatedEntry = FoodEntry(
        id: nonNullEntry.id,
        description: nonNullEntry.description,
        imagePath: nonNullEntry.imagePath,
        audioPath: nonNullEntry.audioPath,
        dateTime: nonNullEntry.dateTime,
        isFavorite: nonNullEntry.isFavorite,
        barcode: nonNullEntry.barcode,
        calories: nonNullEntry.calories,
        nutritionInfo: updatedNutritionInfo,
        mealType: nonNullEntry.mealType,
        items: updatedItems,
      );
      
      // Cập nhật entry trong danh sách
      final entryIndex = _foodEntries.indexWhere((entry) => entry.id == nonNullEntry.id);
      if (entryIndex != -1) {
        _foodEntries[entryIndex] = updatedEntry;
      }
      
      // Xóa cache để tính toán lại các giá trị dinh dưỡng
      _calculationCache.clear();
      
      // Tránh setState trong quá trình build bằng cách sử dụng Future.microtask
      Future.microtask(() {
        print("FoodProvider.synchronizeNutritionData: Đã cập nhật item ${nonNullItem.name} với servingSize mới: $servingSize");
        notifyListeners();
      });
      
      // Lưu dữ liệu
      await _saveData();
    } catch (e) {
      print('Lỗi khi đồng bộ dữ liệu dinh dưỡng cho item: $e');
    }
  }

  // Add a method to explicitly clear the nutrition summary cache
  void clearNutritionSummaryCache() {
    _dailySummaryCache.clear();
    notifyListeners();
  }

  // Thiết lập ngày đã chọn
  void setSelectedDate(String date) {
    if (_selectedDate != date) {
      _selectedDate = date;
      print('FoodProvider: Đã đặt ngày thành $date');
      
      // Clear any cached data for the selected date
      _calculationCache.clear();
      
      // Clear the daily summary cache for this date to ensure fresh data
      _dailySummaryCache.remove(date);
      _dailyMealsCache.remove(date);
      
      // Notify listeners about the date change
      notifyListeners();
      
      // Automatically reload data for the new date
      loadData();
    } else {
      print('FoodProvider: Ngày đã được đặt là $date, không cần thay đổi');
    }
  }
  
  // Tải dữ liệu
  Future<void> loadData() async {
    // Kiểm tra xem có người dùng đang đăng nhập không
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ Không có người dùng đăng nhập, không thể tải dữ liệu từ Firestore');
      return;
    }
    
    // Xóa các món trùng lặp trước khi tải dữ liệu mới
    await removeDuplicateFoodEntries();
    
    // Kiểm tra xem đã có dữ liệu cho ngày được chọn chưa
    final hasDataForSelectedDate = _foodEntries.any((entry) => 
        entry.dateTime.toIso8601String().split('T')[0] == _selectedDate);
    
    // Nếu đã có dữ liệu cho ngày được chọn, không cần tải lại
    if (hasDataForSelectedDate) {
      debugPrint('ℹ️ Đã có dữ liệu cho ngày $_selectedDate, không cần tải lại');
      return;
    }
    
    try {
      if (ApiService.useDirectFirestore) {
        // Ưu tiên lấy dữ liệu từ Firestore trực tiếp
        try {
          final firestore = FirebaseFirestore.instance;
          debugPrint('🔄 Truy vấn trực tiếp vào Firestore cho thực phẩm ngày $_selectedDate...');
          
          // Thử truy vấn trực tiếp bằng trường date
          debugPrint('   🔍 Thử truy vấn với trường date="$_selectedDate"');
          final directQuery = await firestore
              .collection('food_entries')
              .where('user_id', isEqualTo: user.uid)
              .where('date', isEqualTo: _selectedDate)
              .get();
          
          if (directQuery.docs.isNotEmpty) {
            debugPrint('   ✅ Tìm thấy ${directQuery.docs.length} mục thực phẩm bằng truy vấn trực tiếp');
            
            // Xóa các mục nhập cũ cho ngày được chọn
            _foodEntries.removeWhere((entry) => 
                entry.dateTime.toIso8601String().split('T')[0] == _selectedDate);
            
            // Chuyển đổi dữ liệu từ Firestore sang FoodEntry
            final directEntries = <FoodEntry>[];
            for (var doc in directQuery.docs) {
              try {
                final data = doc.data();
                final entry = FoodEntry.fromJson(data);
                directEntries.add(entry);
                debugPrint('   ✅ Đã tải mục nhập: ${entry.description}');
              } catch (e) {
                debugPrint('   ⚠️ Lỗi khi chuyển đổi dữ liệu: $e');
              }
            }
            
            // Thêm các mục nhập vào danh sách
            _foodEntries.addAll(directEntries);
            debugPrint('✅ Đã tải ${directEntries.length} mục nhập thực phẩm từ Firestore cho ngày $_selectedDate');
            
            // Lưu dữ liệu vào bộ nhớ cục bộ
            await _saveData();
            notifyListeners();
            return;
          }
          
          // Nếu không tìm thấy bằng truy vấn trực tiếp, thử lấy tất cả và lọc
          debugPrint('   ⚠️ Không tìm thấy mục nào bằng truy vấn trực tiếp, thử lấy tất cả và lọc');
          final allQuery = await firestore
              .collection('food_entries')
              .where('user_id', isEqualTo: user.uid)
              .get();
              
          debugPrint('   ℹ️ Tìm thấy ${allQuery.docs.length} mục thực phẩm tổng cộng, đang lọc theo ngày $_selectedDate');
          
          if (allQuery.docs.isNotEmpty) {
            // Xóa các mục nhập cũ cho ngày được chọn
            _foodEntries.removeWhere((entry) => 
                entry.dateTime.toIso8601String().split('T')[0] == _selectedDate);
            
            // Lọc các mục nhập theo ngày được chọn
            final filteredEntries = <FoodEntry>[];
            
            for (var doc in allQuery.docs) {
              try {
                final data = doc.data();
                String? entryDate;
                
                // In dữ liệu gốc để kiểm tra
                debugPrint('   📄 Dữ liệu gốc: ${data.toString().substring(0, min(100, data.toString().length))}...');
                
                // Thử lấy trường date trước
                if (data.containsKey('date') && data['date'] != null) {
                  entryDate = data['date'];
                  debugPrint('   🔍 Tìm thấy trường date: $entryDate');
                } else if (data.containsKey('dateTime') && data['dateTime'] != null) {
                  // Nếu không có trường date, thử lấy từ dateTime
                  String dateTimeStr = data['dateTime'];
                  if (dateTimeStr.contains('T')) {
                    entryDate = dateTimeStr.split('T')[0];
                  } else {
                    entryDate = dateTimeStr;
                  }
                  debugPrint('   🔍 Lấy ngày từ trường dateTime: $entryDate');
                }
                
                // Nếu ngày khớp với ngày được chọn, thêm vào danh sách
                if (entryDate == _selectedDate) {
                  final entry = FoodEntry.fromJson(data);
                  filteredEntries.add(entry);
                  debugPrint('   ✅ Đã tìm thấy mục nhập thực phẩm cho ngày $_selectedDate: ${entry.description}');
                }
              } catch (e) {
                debugPrint('   ⚠️ Lỗi khi xử lý mục nhập thực phẩm: $e');
              }
            }
            
            // Thêm các mục nhập đã lọc vào danh sách
            _foodEntries.addAll(filteredEntries);
            debugPrint('✅ Đã tải ${filteredEntries.length} mục nhập thực phẩm từ Firestore cho ngày $_selectedDate');
            
            // Lưu dữ liệu vào bộ nhớ cục bộ
            await _saveData();
            notifyListeners();
            return;
          } else {
            debugPrint('   ⚠️ Không tìm thấy mục nhập thực phẩm nào cho người dùng ${user.uid}');
          }
        } catch (firestoreError) {
          debugPrint('⚠️ Lỗi khi lấy dữ liệu từ Firestore trực tiếp: $firestoreError');
        }
        
        // Nếu không thể lấy từ Firestore trực tiếp, thử lấy từ API
        try {
          final firebaseEntries = await ApiService.getFoodEntriesFromFirebase(user.uid, _selectedDate);
          
          if (firebaseEntries != null && firebaseEntries.isNotEmpty) {
            // Chỉ cập nhật entries cho ngày được chọn
            _foodEntries.removeWhere((entry) => 
                entry.dateTime.toIso8601String().split('T')[0] == _selectedDate);
            _foodEntries.addAll(firebaseEntries);
            debugPrint('✅ Đã tải ${firebaseEntries.length} mục nhập thực phẩm từ API');
            
            // Lưu dữ liệu vào bộ nhớ cục bộ
            await _saveData();
            notifyListeners();
            return;
          }
        } catch (apiError) {
          debugPrint('❌ Lỗi khi tải dữ liệu từ API: $apiError');
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu: $e');
    }
    
    // Nếu không thể tải từ Firebase hoặc API, sử dụng dữ liệu cục bộ
    debugPrint('ℹ️ Sử dụng dữ liệu cục bộ cho ngày $_selectedDate');
    notifyListeners();
  }

  // Để đồng bộ dữ liệu sau khi thay đổi
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Chuyển các food entries thành JSON
      final entriesJson = _foodEntries
          .map((entry) => entry.toJson())
          .toList();
      await prefs.setString(_foodEntriesKey, json.encode(entriesJson));
      
      // Chuyển các favorite items thành JSON
      final favoritesJson = _favoriteItems
          .map((item) => item.toJson())
          .toList();
      await prefs.setString(_favoriteItemsKey, json.encode(favoritesJson));
      
      // Chuyển các recent items thành JSON
      final recentJson = _recentItems
          .map((item) => item.toJson())
          .toList();
      await prefs.setString(_recentItemsKey, json.encode(recentJson));
      
      print('FoodProvider: Đã lưu ${_foodEntries.length} food entries vào SharedPreferences');
    } catch (e) {
      print('FoodProvider: Lỗi khi lưu dữ liệu: $e');
    }
  }
  
  // Cập nhật mục nhập thực phẩm - PHIÊN BẢN CŨ ĐÃ COMMENT ĐỂ TRÁNH TRÙNG LẬP
  // Future<bool> updateFoodEntry(FoodEntry updatedEntry) async {
  //   try {
  //     // Tìm và cập nhật trong danh sách local
  //   final index = _foodEntries.indexWhere((entry) => entry.id == updatedEntry.id);
  //   if (index != -1) {
  //     _foodEntries[index] = updatedEntry;
  //     notifyListeners();
  //       
  //       // Lưu vào SharedPreferences
  //       await _saveFoodEntriesToPrefs();
  //       
  //       // Gửi đến API
  //       final userId = _authService.currentUser?.uid;
  //       if (userId != null) {
  //         try {
  //           final result = await ApiService.updateFoodEntry(updatedEntry, userId);
  //           if (result) {
  //             debugPrint('✅ Đã cập nhật mục nhập thực phẩm trên API thành công');
  //           } else {
  //             debugPrint('⚠️ Không thể cập nhật mục nhập thực phẩm trên API');
  //           }
  //           return result;
  //         } catch (e) {
  //           debugPrint('❌ Lỗi khi cập nhật mục nhập thực phẩm trên API: $e');
  //           return false;
  //         }
  //       }
  //       
  //       return true;
  //     }
  //     return false;
  //   } catch (e) {
  //     debugPrint('❌ Lỗi khi cập nhật mục nhập thực phẩm: $e');
  //     return false;
  //   }
  // }
  
  // Xóa mục nhập thực phẩm - PHIÊN BẢN CŨ ĐÃ COMMENT ĐỂ TRÁNH TRÙNG LẬP
  // Future<bool> deleteFoodEntry(String entryId) async {
  //   try {
  //     // Xóa khỏi danh sách local
  //     _foodEntries.removeWhere((entry) => entry.id == entryId);
  //     notifyListeners();
  //     
  //     // Lưu vào SharedPreferences
  //     await _saveFoodEntriesToPrefs();
  //     
  //     // Xóa trên API
  //     final userId = _authService.currentUser?.uid;
  //     if (userId != null) {
  //       try {
  //         final result = await ApiService.deleteFoodEntry(entryId, userId);
  //         if (result) {
  //           debugPrint('✅ Đã xóa mục nhập thực phẩm trên API thành công');
  //         } else {
  //           debugPrint('⚠️ Không thể xóa mục nhập thực phẩm trên API');
  //         }
  //         return result;
  //       } catch (e) {
  //         debugPrint('❌ Lỗi khi xóa mục nhập thực phẩm trên API: $e');
  //         return false;
  //       }
  //     }
  //     
  //     return true;
  //   } catch (e) {
  //     debugPrint('❌ Lỗi khi xóa mục nhập thực phẩm: $e');
  //     return false;
  //   }
  // }
  
  // Tính tổng dinh dưỡng
  Map<String, double> getNutritionTotals({required String date}) {
    print('FoodProvider: getNutritionTotals được gọi cho ngày $date');
    
    // Get entries for the specified date
    final dateEntries = _foodEntries.where((entry) => 
      entry.dateTime.toIso8601String().split('T')[0] == date).toList();
    
    // Initialize totals
    Map<String, double> totals = {
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'sodium': 0.0,
    };
    
    // If no entries found, return zeros
    if (dateEntries.isEmpty) {
      print('FoodProvider: Không tìm thấy bữa ăn nào cho ngày $date');
      return totals;
    }
    
    // Sum up nutrition from all entries
    for (var entry in dateEntries) {
      // Use nutritionInfo if available
      if (entry.nutritionInfo != null && entry.nutritionInfo!.isNotEmpty) {
        // Add basic nutrients
        if (entry.nutritionInfo!['calories'] != null) {
          totals['calories'] = (totals['calories'] ?? 0.0) + (entry.nutritionInfo!['calories'] as num).toDouble();
        }
        if (entry.nutritionInfo!['protein'] != null) {
          totals['protein'] = (totals['protein'] ?? 0.0) + (entry.nutritionInfo!['protein'] as num).toDouble();
        }
        if (entry.nutritionInfo!['fat'] != null) {
          totals['fat'] = (totals['fat'] ?? 0.0) + (entry.nutritionInfo!['fat'] as num).toDouble();
        }
        if (entry.nutritionInfo!['carbs'] != null) {
          totals['carbs'] = (totals['carbs'] ?? 0.0) + (entry.nutritionInfo!['carbs'] as num).toDouble();
        }
        
        // Add optional nutrients if available
        if (entry.nutritionInfo!['fiber'] != null) {
          totals['fiber'] = (totals['fiber'] ?? 0.0) + (entry.nutritionInfo!['fiber'] as num).toDouble();
        }
        if (entry.nutritionInfo!['sugar'] != null) {
          totals['sugar'] = (totals['sugar'] ?? 0.0) + (entry.nutritionInfo!['sugar'] as num).toDouble();
        }
        if (entry.nutritionInfo!['sodium'] != null) {
          totals['sodium'] = (totals['sodium'] ?? 0.0) + (entry.nutritionInfo!['sodium'] as num).toDouble();
        }
      } 
      // Fallback to individual items
      else if (entry.items.isNotEmpty) {
        for (var item in entry.items) {
          totals['calories'] = (totals['calories'] ?? 0.0) + item.calories;
          totals['protein'] = (totals['protein'] ?? 0.0) + item.protein;
          totals['carbs'] = (totals['carbs'] ?? 0.0) + item.carbs;
          totals['fat'] = (totals['fat'] ?? 0.0) + item.fat;
          
          if (item.fiber != null) {
            totals['fiber'] = (totals['fiber'] ?? 0.0) + item.fiber!;
          }
          if (item.sugar != null) {
            totals['sugar'] = (totals['sugar'] ?? 0.0) + item.sugar!;
          }
          if (item.sodium != null) {
            totals['sodium'] = (totals['sodium'] ?? 0.0) + item.sodium!;
          }
        }
      }
    }
    
    print('FoodProvider: Tính toán giá trị dinh dưỡng cho ${dateEntries.length} bữa ăn - calories: ${totals['calories']?.round()}');
    
    return totals;
  }
  
  // Thêm vào danh sách items gần đây - PHIÊN BẢN CŨ ĐƯỢC GIỮ CHỈ ĐỂ TƯƠNG THÍCH
  // void _addToRecentItems(FoodItem item) {
  //   // Triển khai tối thiểu
  //   print('FoodProvider: _addToRecentItems được gọi với ${item.name}');
  //   // Triển khai thực tế sẽ thêm vào danh sách _recentItems
  // }
  
  // Thêm bữa ăn thủ công - PHIÊN BẢN CŨ ĐƯỢC COMMENT ĐỂ TRÁNH TRÙNG LẬP
  // Future<FoodEntry> addFoodEntryManual({
  //   required String description,
  //   required String mealType,
  //   DateTime? dateTime,
  //   List<FoodItem>? items,
  //   File? image,
  // }) async {
  //   print('FoodProvider: addFoodEntryManual được gọi');
  //   
  //   final entry = FoodEntry(
  //     id: _uuid.v4(),
  //     description: description,
  //     imagePath: image?.path,
  //     dateTime: dateTime ?? DateTime.now(),
  //     mealType: mealType,
  //     items: items ?? [],
  //   );
  //   
  //   _foodEntries.add(entry);
  //   notifyListeners();
  //   await _saveData();
  //   
  //   return entry;
  // }
  
  // Thêm bữa ăn bằng AI - PHIÊN BẢN CŨ ĐƯỢC COMMENT ĐỂ TRÁNH TRÙNG LẬP
  // Future<FoodEntry?> addFoodEntryWithAI({
  //   required File image,
  //   required String description,
  //   required String mealType,
  //   String? date,
  // }) async {
  //   print('FoodProvider: addFoodEntryWithAI được gọi');
  //   
  //   // Tạo entry mẫu để tránh lỗi biên dịch
  //   final entry = FoodEntry(
  //     id: _uuid.v4(),
  //     description: description,
  //     imagePath: image.path,
  //     dateTime: DateTime.now(),
  //     mealType: mealType,
  //     items: [],
  //   );
  //   
  //   _foodEntries.add(entry);
  //   notifyListeners();
  //   await _saveData();
  //   
  //   return entry;
  // }
  
  // Đánh dấu yêu thích
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final index = _foodEntries.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      _foodEntries[index] = _foodEntries[index].copyWith(isFavorite: isFavorite);
      notifyListeners();
    }
    print('FoodProvider: toggleFavorite được gọi cho $id: $isFavorite');
    await _saveData();
  }
  
  // Phương thức cũ để tải food entries - ĐÃ COMMENT ĐỂ TRÁNH TRÙNG LẬP
  // Future<void> loadFoodEntries() async {
  //   await loadData();
  // }
  
  // Phương thức cũ để tải favorite food entries
  Future<void> loadFavoriteFoodEntries() async {
    // Đã được xử lý trong loadData
    print('FoodProvider: loadFavoriteFoodEntries được gọi');
  }
  
  // Cập nhật food entry trong danh sách - ĐÃ COMMENT ĐỂ TRÁNH TRÙNG LẬP
  // Future<void> updateFoodEntryInList(FoodEntry updatedEntry) async {
  //   await updateFoodEntry(updatedEntry);
  // }

  /// Cập nhật thông tin dinh dưỡng cho một FoodEntry từ API
  Future<FoodEntry> updateNutritionFromAPI(FoodEntry entry) async {
    try {
      // Hiển thị log
      print('Đang cập nhật thông tin dinh dưỡng từ API cho: ${entry.description}');
      
      // Gọi API để lấy dữ liệu dinh dưỡng
      final nutritionData = await FoodDataAdapter.fetchNutritionInfo(entry.description);
      
      if (nutritionData != null) {
        // Cập nhật FoodEntry với dữ liệu dinh dưỡng mới
        final updatedEntry = FoodDataAdapter.updateWithNutritionInfo(
          entry: entry,
          nutritionInfo: nutritionData,
          fromAPI: true,
        );
        
        // Cập nhật trong bộ nhớ
        final index = _foodEntries.indexWhere((e) => e.id == updatedEntry.id);
        if (index >= 0) {
          _foodEntries[index] = updatedEntry;
          notifyListeners();
        }
        
        // Lưu dữ liệu vào persistent storage
        await _saveData();
        
        return updatedEntry;
      }
      
      // Nếu không lấy được dữ liệu mới, trả về entry gốc
      return entry;
    } catch (e) {
      print('Lỗi khi cập nhật thông tin dinh dưỡng: $e');
      return entry;
    }
  }

  // Lấy mục tiêu dinh dưỡng từ UserDataProvider hoặc tính toán từ TDEE
  Map<String, dynamic> getNutritionGoals(BuildContext context) {
    try {
      final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
      
      // Ưu tiên sử dụng mục tiêu dinh dưỡng trực tiếp từ UserDataProvider
      if (userDataProvider.nutritionGoals.isNotEmpty) {
        // Chuyển đổi thành Map<String, dynamic>
        final goals = Map<String, dynamic>.from(userDataProvider.nutritionGoals);
        print('Using direct nutrition goals from UserDataProvider');
        return goals;
      }
      
      // Nếu không có sẵn, tính toán từ TDEE
      final calculator = TDEECalculator(
        gender: userDataProvider.gender,
        age: userDataProvider.age,
        heightCm: userDataProvider.heightCm,
        weightKg: userDataProvider.weightKg,
        activityLevel: userDataProvider.activityLevel,
        goal: userDataProvider.goal,
        pace: userDataProvider.pace,
      );

      final dailyCalories = calculator.calculateDailyCalories();
      final macros = calculator.calculateMacroDistribution();

      return {
        "calories": dailyCalories,
        "protein": macros['protein'] ?? 0,
        "carbs": macros['carbs'] ?? 0,
        "fat": macros['fat'] ?? 0,
        "cholesterol": 300,
        "omega3": 1600,
        "fiber": 38,
        "water": 2000,
        "sugar": 69,
        "saturated_fat": 20,
        "caffeine": 400,
        "alcohol": 30,
        "vitamin_d": 15,
        "vitamin_b12": 2.4,
        "vitamin_c": 90,
        "vitamin_b9": 400,
        "iron": 8.0,
        "calcium": 1000,
        "magnesium": 400,
        "zinc": 11
      };
    } catch (e) {
      print('Error getting nutrition goals: $e');
      // Giá trị mặc định
      return {
        "calories": 2782,
        "protein": 208,
        "fat": 92,
        "carbs": 278,
        "cholesterol": 300,
        "omega3": 1600,
        "fiber": 38,
        "water": 2000,
        "sugar": 69,
        "saturated_fat": 20,
        "caffeine": 400,
        "alcohol": 30,
        "vitamin_d": 15,
        "vitamin_b12": 2.4,
        "vitamin_c": 90,
        "vitamin_b9": 400,
        "iron": 8.0,
        "calcium": 1000,
        "magnesium": 400,
        "zinc": 11
      };
    }
  }

  // Trả về toàn bộ food entries dưới dạng List<Map<String, dynamic>> để đồng bộ
  List<Map<String, dynamic>> getAllEntriesAsJson() {
    return _foodEntries.map((e) => e.toJson()).toList();
  }

  // Lưu dữ liệu thực phẩm vào SharedPreferences
  Future<void> _saveFoodEntriesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> entriesJson = _foodEntries.map((entry) => entry.toJson()).toList();
      await prefs.setString('food_entries', jsonEncode(entriesJson));
      debugPrint('✅ Đã lưu dữ liệu thực phẩm vào SharedPreferences');
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu dữ liệu thực phẩm vào SharedPreferences: $e');
    }
  }
  
  // Tải dữ liệu thực phẩm từ SharedPreferences
  Future<void> _loadFoodEntriesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? entriesJson = prefs.getString('food_entries');
      if (entriesJson != null) {
        final List<dynamic> decoded = jsonDecode(entriesJson);
        _foodEntries = decoded.map((json) => FoodEntry.fromJson(json)).toList();
        debugPrint('✅ Đã tải ${_foodEntries.length} mục nhập thực phẩm từ SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu thực phẩm từ SharedPreferences: $e');
    }
  }

  // Xóa mục nhập thực phẩm (alias cho deleteFoodEntry để tương thích với code cũ)
  Future<bool> removeFoodEntry(String entryId) async {
    return await deleteFoodEntry(entryId);
  }
  
  // Đồng bộ dữ liệu từ Firebase khi đăng nhập lại
  Future<void> syncFromFirebase() async {
    final user = _authService.currentUser;
    if (user == null) return;
    
    try {
      debugPrint('🔄 Đang đồng bộ dữ liệu bữa ăn từ Firebase...');
      
      // Lấy dữ liệu từ collection food_entries thay vì subcollection trong users
      final snapshot = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('user_id', isEqualTo: user.uid) // Lọc theo user_id
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        // Chuyển đổi dữ liệu từ Firestore sang FoodEntry
        final List<FoodEntry> firestoreEntries = snapshot.docs
            .map((doc) => FoodEntry.fromJson(doc.data()))
            .toList();
        
        // Ghi đè dữ liệu local bằng dữ liệu từ Firebase
        _foodEntries = firestoreEntries;
        
        // Cập nhật SharedPreferences
        await _saveFoodEntriesToPrefs();
        
        // Thông báo UI cập nhật
        notifyListeners();
        
        debugPrint('✅ Đã đồng bộ ${firestoreEntries.length} bữa ăn từ Firebase');
      } else {
        debugPrint('ℹ️ Không có dữ liệu bữa ăn trên Firebase');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ dữ liệu bữa ăn từ Firebase: $e');
    }
  }

  // Kiểm tra dữ liệu thực phẩm trong Firebase
  Future<void> checkFoodEntriesInFirebase() async {
    final user = _authService.currentUser;
    if (user == null) {
      debugPrint('⚠️ Không thể kiểm tra dữ liệu thực phẩm: Người dùng chưa đăng nhập');
      return;
    }
    
    try {
      debugPrint('🔍 Đang kiểm tra dữ liệu thực phẩm trong Firebase...');
      
      // Lấy dữ liệu từ collection food_entries
      final snapshot = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      // Hiển thị số lượng mục và thông tin chi tiết
      debugPrint('📊 Tìm thấy ${snapshot.docs.length} mục thực phẩm trong Firebase');
      
      if (snapshot.docs.isNotEmpty) {
        // Hiển thị thông tin chi tiết về 5 mục đầu tiên
        int count = 0;
        for (var doc in snapshot.docs) {
          if (count < 5) {
            final data = doc.data();
            debugPrint('📝 Mục #${count + 1}: ID=${doc.id}, Tên=${data['name'] ?? data['description'] ?? 'Không có tên'}, Ngày=${data['date'] ?? 'Không có ngày'}');
          }
          count++;
        }
        
        if (count > 5) {
          debugPrint('... và ${count - 5} mục khác');
        }
      } else {
        debugPrint('⚠️ Không tìm thấy dữ liệu thực phẩm nào trong Firebase');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra dữ liệu thực phẩm trong Firebase: $e');
    }
  }
  
  // Tải dữ liệu thực phẩm
  Future<void> loadFoodEntries() async {
    if (_selectedDate.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      debugPrint('🔄 Đang tải mục thực phẩm cho ngày $_selectedDate từ Firestore/API...');
      
      // Kiểm tra trong Firestore trực tiếp
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('food_entries')
            .where('user_id', isEqualTo: user.uid)
            .get();
        
        debugPrint('💾 Đã tìm thấy ${querySnapshot.docs.length} mục trong Firestore');
        
        // Lọc theo ngày được chọn
        final List<FoodEntry> firebaseEntries = [];
        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            final entry = FoodEntry.fromJson(data);
            
            // Kiểm tra xem ngày của entry có khớp với ngày được chọn không
            final entryDate = entry.dateTime.toIso8601String().split('T')[0];
            if (entryDate == _selectedDate) {
              firebaseEntries.add(entry);
              debugPrint('✅ Tìm thấy food entry trong Firestore: ${entry.id}, ${entry.description}, date=${entryDate}');
            }
          } catch (conversionError) {
            debugPrint('⚠️ Lỗi khi chuyển đổi dữ liệu từ Firestore: $conversionError');
          }
        }
        
        if (firebaseEntries.isNotEmpty) {
          debugPrint('✅ Đã tải ${firebaseEntries.length} mục thực phẩm trực tiếp từ Firestore cho ngày $_selectedDate');
          _foodEntries = firebaseEntries;
          _isLoading = false;
          notifyListeners();
          return;
        } else {
          debugPrint('ℹ️ Không tìm thấy dữ liệu trực tiếp trong Firestore, thử qua API');
        }
      } catch (firestoreError) {
        debugPrint('⚠️ Lỗi khi tải từ Firestore trực tiếp: $firestoreError');
      }
      
      // Thử lấy dữ liệu trực tiếp từ Firestore một lần nữa với cách khác
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('food_entries')
            .where('user_id', isEqualTo: user.uid)
            .where('date', isEqualTo: _selectedDate)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final List<FoodEntry> entries = querySnapshot.docs
              .map((doc) => FoodEntry.fromJson(doc.data()))
              .toList();
          
          _foodEntries = entries;
          debugPrint('✅ Đã tải ${entries.length} mục thực phẩm trực tiếp từ Firestore cho ngày $_selectedDate');
        } else {
          _foodEntries = [];
          debugPrint('ℹ️ Không có mục thực phẩm nào cho ngày $_selectedDate trong Firestore');
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi truy vấn dữ liệu thực phẩm từ Firestore: $e');
        _foodEntries = [];
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu thực phẩm: $e');
      _foodEntries = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }  
  }
  
  // Cập nhật mục nhập thực phẩm
  Future<bool> updateFoodEntry(FoodEntry updatedEntry) async {
    try {
      debugPrint('📝 updateFoodEntry: Bắt đầu cập nhật food entry với ID ${updatedEntry.id}');
      
      // Tìm vị trí của mục cần cập nhật
      final index = _foodEntries.indexWhere((entry) => entry.id == updatedEntry.id);
      
      if (index != -1) {
        // Cập nhật mục trong danh sách local
        _foodEntries[index] = updatedEntry;
        
        // Xóa cache để tính toán lại các giá trị dinh dưỡng
        _calculationCache.clear();
        _dailySummaryCache.clear();
        _dailyMealsCache.clear();
        
        // Thông báo cho UI cập nhật
        notifyListeners();
        
        // Lưu vào SharedPreferences
        await _saveFoodEntriesToPrefs();
        
        // Gửi đến API
        final userId = _authService.currentUser?.uid;
        if (userId != null) {
          try {
            debugPrint('🔄 Đang gửi cập nhật mục nhập thực phẩm đến collection food_records...');
            
            // Thử kiểm tra xem bản ghi có tồn tại trong collection mới chưa
            bool result = await ApiService.updateFoodEntry(updatedEntry, userId);
            
            // Nếu cập nhật không thành công, thử tạo mới bản ghi
            if (!result) {
              debugPrint('⚠️ Không tìm thấy bản ghi trong collection food_records, thử tạo mới...');
              result = await ApiService.sendFoodEntry(updatedEntry, userId);
              
              if (result) {
                debugPrint('✅ updateFoodEntry: Đã tạo mới mục nhập thực phẩm trong collection food_records thành công');
              } else {
                debugPrint('❌ updateFoodEntry: Không thể tạo mới mục nhập thực phẩm trong collection food_records');
              }
            } else {
              debugPrint('✅ updateFoodEntry: Đã cập nhật mục nhập thực phẩm trong collection food_records thành công');
            }
            
            // Xóa các món trùng lặp sau khi cập nhật
            await removeDuplicateFoodEntries();
            
            return result;
          } catch (e) {
            debugPrint('❌ updateFoodEntry: Lỗi khi cập nhật mục nhập thực phẩm: $e');
            return false;
          }
        } else {
          debugPrint('⚠️ updateFoodEntry: Không thể cập nhật mục nhập thực phẩm: Người dùng chưa đăng nhập');
          
          // Xóa các món trùng lặp sau khi cập nhật
          await removeDuplicateFoodEntries();
          
          return false;
        }
      } else {
        // QUAN TRỌNG: Nếu không tìm thấy trong danh sách, kiểm tra xem có món ăn tương tự không
        // Để tránh việc tạo các bản sao trùng lặp
        final similarEntries = _foodEntries.where((entry) => 
          entry.description == updatedEntry.description &&
          entry.mealType == updatedEntry.mealType &&
          entry.dateTime.toIso8601String().split('T')[0] == updatedEntry.dateTime.toIso8601String().split('T')[0]
        ).toList();
        
        if (similarEntries.isNotEmpty) {
          debugPrint('⚠️ updateFoodEntry: Phát hiện món ăn tương tự. Sẽ cập nhật món ăn này thay vì tạo mới');
          
          // Cập nhật món ăn tương tự với ID mới
          final originalEntry = similarEntries.first;
          final mergedEntry = updatedEntry.copyWith(id: originalEntry.id);
          
          // Gọi lại updateFoodEntry với entry đã hợp nhất ID
          return await updateFoodEntry(mergedEntry);
        }
        
        // Nếu thực sự không tìm thấy món ăn nào tương tự, thêm mới
        debugPrint('⚠️ updateFoodEntry: Không tìm thấy mục nhập thực phẩm với ID ${updatedEntry.id}, thêm mới');
        
        // Thông báo log chi tiết để debug
        debugPrint('📋 Thông tin chi tiết trong danh sách (_foodEntries.length=${_foodEntries.length}):');
        for (var i = 0; i < min(5, _foodEntries.length); i++) {
          final entry = _foodEntries[i];
          debugPrint('   - Entry #$i: ID=${entry.id}, Mô tả=${entry.description}, Ngày=${entry.dateTime.toIso8601String().split('T')[0]}');
        }
        
        debugPrint('🔄 updateFoodEntry: Chuyển qua phương thức addFoodEntry để thêm mới');
        
        // Trước khi thêm mới, kiểm tra một lần nữa để tránh trùng lặp
        await removeDuplicateFoodEntries();
        
        return await addFoodEntry(updatedEntry);
      }
    } catch (e) {
      debugPrint('❌ updateFoodEntry: Lỗi khi cập nhật mục nhập thực phẩm: $e');
      return false;
    }
  }
  
  // Cập nhật mục nhập thực phẩm trong danh sách (không gửi lên API)
  void updateFoodEntryInList(FoodEntry updatedEntry) {
    final index = _foodEntries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index != -1) {
      _foodEntries[index] = updatedEntry;
      notifyListeners();
      _saveFoodEntriesToPrefs();
    }
  }
  
  // Xóa mục nhập thực phẩm
  Future<bool> deleteFoodEntry(String entryId) async {
    try {
      // Tìm vị trí của mục cần xóa
      final index = _foodEntries.indexWhere((entry) => entry.id == entryId);
      
      if (index != -1) {
        // Lưu tham chiếu đến entry trước khi xóa để sử dụng khi xóa trên Firestore
        final entryToDelete = _foodEntries[index];
        
        // Xóa khỏi danh sách local
        _foodEntries.removeAt(index);
        notifyListeners();
        
        // Lưu vào SharedPreferences
        await _saveFoodEntriesToPrefs();
        
        // Xóa trên Firestore nếu đã đăng nhập và đã cấu hình trực tiếp
        final user = _authService.currentUser;
        if (user != null && ApiService.useDirectFirestore) {
          try {
            debugPrint('🔄 Đang xóa mục nhập thực phẩm trực tiếp từ Firestore...');
            
            await FirebaseFirestore.instance
              .collection('food_entries')
              .doc(entryId)
              .delete();
            
            debugPrint('✅ Đã xóa mục nhập thực phẩm khỏi Firestore thành công');
            return true;
          } catch (e) {
            debugPrint('❌ Lỗi khi xóa mục nhập thực phẩm khỏi Firestore: $e');
            
            // Thử xóa qua ApiService nếu xóa trực tiếp thất bại
            try {
              final userId = user.uid;
              final result = await ApiService.deleteFoodEntry(entryId, userId);
              if (result) {
                debugPrint('✅ Đã xóa mục nhập thực phẩm trên API thành công');
              } else {
                debugPrint('⚠️ Không thể xóa mục nhập thực phẩm trên API');
              }
              return result;
            } catch (apiError) {
              debugPrint('❌ Lỗi khi xóa mục nhập thực phẩm qua ApiService: $apiError');
              return false;
            }
          }
        } 
        // Xóa qua ApiService nếu không sử dụng Firestore trực tiếp
        else if (user != null) {
          try {
            final userId = user.uid;
            final result = await ApiService.deleteFoodEntry(entryId, userId);
            if (result) {
              debugPrint('✅ Đã xóa mục nhập thực phẩm trên API thành công');
            } else {
              debugPrint('⚠️ Không thể xóa mục nhập thực phẩm trên API');
            }
            return result;
          } catch (e) {
            debugPrint('❌ Lỗi khi xóa mục nhập thực phẩm trên API: $e');
            return false;
          }
        }
        
        // Nếu không có kết nối, vẫn trả về true vì đã xóa thành công ở local
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa mục nhập thực phẩm: $e');
      return false;
    }
  }
  
  // Thêm mục nhập thực phẩm bằng AI
  Future<FoodEntry?> addFoodEntryWithAI(String description, String mealType) async {
    try {
      // Tạo mục nhập mới
      final entry = FoodEntry(
        id: _uuid.v4(),
        description: description,
        mealType: mealType,
        items: [],
        needsNutritionAnalysis: true,
        dateTime: DateTime.now(), // Sử dụng thời gian hiện tại
      );
      
      // Thêm vào danh sách
      _foodEntries.add(entry);
      notifyListeners();
      
      // Lưu vào SharedPreferences
      await _saveFoodEntriesToPrefs();
      
      // Gửi lên API hoặc Firestore trực tiếp
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          final result = await ApiService.sendFoodEntry(entry, userId);
          if (result) {
            debugPrint('✅ Đã gửi mục nhập thực phẩm lên API thành công');
          } else {
            debugPrint('⚠️ Không thể gửi mục nhập thực phẩm lên API');
          }
        } catch (e) {
          debugPrint('❌ Lỗi khi gửi mục nhập thực phẩm lên API: $e');
        }
      }
      
      return entry;
    } catch (e) {
      debugPrint('❌ Lỗi khi thêm mục nhập thực phẩm bằng AI: $e');
      return null;
    }
  }
  
  // Thêm mục nhập thực phẩm thủ công
  Future<FoodEntry?> addFoodEntryManual(String description, String mealType, List<FoodItem> items) async {
    try {
      // Xóa các món trùng lặp trước khi thêm mới
      await removeDuplicateFoodEntries();
      
      // Kiểm tra xem có món ăn tương tự không
      final entryDate = DateTime.now().toIso8601String().split('T')[0];
      final similarEntries = _foodEntries.where((existingEntry) => 
        existingEntry.description == description &&
        existingEntry.mealType == mealType &&
        existingEntry.dateTime.toIso8601String().split('T')[0] == entryDate
      ).toList();
      
      // Nếu có món ăn tương tự, cập nhật món ăn đó thay vì tạo mới
      if (similarEntries.isNotEmpty) {
        debugPrint('⚠️ addFoodEntryManual: Phát hiện món ăn tương tự. Sẽ cập nhật món ăn này thay vì tạo mới');
        
        // Lấy món ăn đầu tiên tìm thấy để cập nhật
        final existingEntry = similarEntries.first;
        
        // Tính toán giá trị dinh dưỡng từ các item mới
        final calories = items.fold(0.0, (sum, item) => sum + (item.calories * item.servingSize));
        
        // Tạo món ăn cập nhật với các item mới
        final updatedEntry = existingEntry.copyWith(
          items: items,
          calories: calories,
        );
        
        // Cập nhật món ăn
        await updateFoodEntry(updatedEntry);
        
        // Thêm các item vào danh sách gần đây
        for (var item in items) {
          _addToRecentItems(item);
        }
        
        return updatedEntry;
      }
      
      // Tính toán giá trị dinh dưỡng từ các item
      final calories = items.fold(0.0, (sum, item) => sum + (item.calories * item.servingSize));
      
      // Tạo thời gian hiện tại và đảm bảo định dạng phù hợp
      final now = DateTime.now();
      debugPrint('🕒 Tạo food entry với thời gian: ${now.toIso8601String()}');
      
      // Tạo mục nhập mới với ID duy nhất
      final String entryId = _uuid.v4();
      debugPrint('🆔 ID mới cho food entry: $entryId');
      
      final entry = FoodEntry(
        id: entryId,
        description: description,
        mealType: mealType,
        items: items,
        calories: calories,
        dateTime: now, // Sử dụng thời gian hiện tại
      );
      
      // Thêm vào danh sách
      _foodEntries.add(entry);
      notifyListeners();
      
      // Lưu vào SharedPreferences
      await _saveFoodEntriesToPrefs();
      
      // Gửi lên API hoặc Firestore trực tiếp
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          debugPrint('🔄 addFoodEntryManual: Bắt đầu gửi food entry lên collection food_records với ID: ${entry.id}');
          debugPrint('📝 addFoodEntryManual: Chi tiết food entry: Mô tả="${entry.description}", Bữa ăn="${entry.mealType}", Calo=${entry.calories}');
          debugPrint('📅 addFoodEntryManual: Ngày của food entry: ${entry.dateTime.toIso8601String()}');
          
          final result = await ApiService.sendFoodEntry(entry, userId);
          if (result) {
            debugPrint('✅ addFoodEntryManual: Đã gửi food entry lên collection food_records thành công');
            
            // Kiểm tra xem dữ liệu đã được lưu vào Firestore chưa
            await checkFoodEntriesInFirebase();
            
            // Tải lại dữ liệu từ Firestore để đảm bảo hiển thị mới nhất
            if (_selectedDate.isNotEmpty) {
              final today = DateTime.now().toIso8601String().split('T')[0];
              if (_selectedDate == today) {
                debugPrint('🔄 addFoodEntryManual: Tải lại dữ liệu cho ngày hiện tại: $_selectedDate');
                await loadFoodEntries();
              }
            }
          } else {
            debugPrint('⚠️ addFoodEntryManual: Không thể gửi food entry lên collection food_records');
          }
        } catch (e) {
          debugPrint('❌ addFoodEntryManual: Lỗi khi gửi food entry lên collection food_records: $e');
        }
      } else {
        debugPrint('⚠️ addFoodEntryManual: Không thể gửi food entry lên collection food_records: Người dùng chưa đăng nhập');
      }
      
      // Thêm các item vào danh sách gần đây
      for (var item in items) {
        _addToRecentItems(item);
      }
      
      return entry;
    } catch (e) {
      debugPrint('❌ Lỗi khi thêm mục nhập thực phẩm thủ công: $e');
      return null;
    }
  }
  
  // Thêm item vào danh sách gần đây
  void _addToRecentItems(FoodItem item) {
    // Kiểm tra xem item đã tồn tại trong danh sách chưa
    final index = _recentItems.indexWhere((i) => i.id == item.id);
    
    if (index != -1) {
      // Nếu đã tồn tại, xóa khỏi vị trí cũ
      _recentItems.removeAt(index);
    }
    
    // Thêm vào đầu danh sách
    _recentItems.insert(0, item);
    
    // Giới hạn số lượng item trong danh sách
    if (_recentItems.length > 20) {
      _recentItems = _recentItems.sublist(0, 20);
    }
    
    notifyListeners();
  }

  // Phương thức mới để xóa các món ăn trùng lặp
  Future<void> removeDuplicateFoodEntries() async {
    debugPrint('🧹 Bắt đầu xóa các món ăn trùng lặp...');
    
    // Danh sách tạm để lưu trữ những món đã kiểm tra
    final Map<String, FoodEntry> uniqueEntries = {};
    final List<FoodEntry> duplicates = [];
    
    // Tạo khóa duy nhất cho mỗi bữa ăn dựa trên ngày, loại bữa và mô tả
    for (final entry in _foodEntries) {
      final entryDate = entry.dateTime.toIso8601String().split('T')[0];
      final key = '$entryDate|${entry.mealType}|${entry.description}';
      
      if (uniqueEntries.containsKey(key)) {
        // Đã tìm thấy món trùng lặp
        duplicates.add(entry);
        debugPrint('🔍 Phát hiện món trùng lặp: ${entry.description} (ID: ${entry.id})');
      } else {
        // Thêm món vào danh sách các món duy nhất
        uniqueEntries[key] = entry;
      }
    }
    
    // Xóa các món trùng lặp
    if (duplicates.isNotEmpty) {
      for (final duplicate in duplicates) {
        _foodEntries.removeWhere((entry) => entry.id == duplicate.id);
        debugPrint('🗑️ Đã xóa món trùng lặp: ${duplicate.description} (ID: ${duplicate.id})');
      }
      
      // Lưu danh sách mới vào SharedPreferences
      await _saveFoodEntriesToPrefs();
      
      // Thông báo cho UI cập nhật
      notifyListeners();
      
      debugPrint('✅ Đã xóa ${duplicates.length} món trùng lặp. Tổng số món ăn còn lại: ${_foodEntries.length}');
    } else {
      debugPrint('✅ Không tìm thấy món trùng lặp');
    }
  }

  // Phương thức đồng bộ dữ liệu với Firebase
  Future<bool> synchronizeWithFirebase() async {
    try {
      debugPrint('🔄 Bắt đầu đồng bộ dữ liệu với Firebase...');
      
      // Kiểm tra xem người dùng đã đăng nhập chưa
      final user = _authService.currentUser;
      if (user == null) {
        debugPrint('⚠️ Không thể đồng bộ với Firebase vì người dùng chưa đăng nhập');
        return false;
      }
      
      // Kiểm tra có cấu hình trực tiếp với Firestore không
      if (!ApiService.useDirectFirestore) {
        debugPrint('⚠️ Đồng bộ trực tiếp với Firestore đã bị tắt trong cấu hình');
        return false;
      }
      
      // Lấy danh sách các mục nhập thực phẩm cho ngày đã chọn
      final entriesForSelectedDate = _foodEntries.where((entry) {
        final entryDate = entry.dateTime.toIso8601String().split('T')[0];
        return entryDate == _selectedDate;
      }).toList();
      
      debugPrint('📊 Tìm thấy ${entriesForSelectedDate.length} mục nhập thực phẩm cho ngày $_selectedDate');
      
      // Chuẩn bị dữ liệu để đồng bộ với Firestore
      for (final entry in entriesForSelectedDate) {
        try {
          // Chuyển đổi dữ liệu thành định dạng JSON
          final entryData = {
            ...entry.toJson(),
            'user_id': user.uid,
            'date': _selectedDate, // Thêm trường date để dễ truy vấn
            'updated_at': DateTime.now().toIso8601String(),
            'id': entry.id,
            'description': entry.description,
            'dateTime': entry.dateTime.toIso8601String(),
            'mealType': entry.mealType,
            'imageUrl': entry.imageUrl,
            'imagePath': entry.imagePath,
          };
          
          // Ghi log cho mục đang đồng bộ
          debugPrint('📋 Đồng bộ mục ${entry.id} - ${entry.description}');
          debugPrint('   📷 imageUrl: ${entry.imageUrl}');
          debugPrint('   📷 imagePath: ${entry.imagePath}');
          
          // Lưu dữ liệu lên Firestore
          await FirebaseFirestore.instance
            .collection('food_entries')
            .doc(entry.id)
            .set(entryData, SetOptions(merge: true));
            
          debugPrint('✅ Đã đồng bộ thành công mục ${entry.id}');
        } catch (e) {
          debugPrint('❌ Lỗi khi đồng bộ mục ${entry.id}: $e');
        }
      }
      
      debugPrint('✅ Đã đồng bộ (ghi đè hoàn toàn) dữ liệu lên Firebase thành công');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ dữ liệu với Firebase: $e');
      return false;
    }
  }
} 