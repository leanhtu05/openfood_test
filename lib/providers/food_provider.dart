import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../services/food_database_service.dart';
import '../services/food_recognition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../adapters/food_data_adapter.dart';
import 'dart:async'; // Added for Timer
import '../providers/user_data_provider.dart';
import '../utils/tdee_calculator.dart';
import 'package:provider/provider.dart';

class FoodProvider with ChangeNotifier {
  final FoodDatabaseService _databaseService = FoodDatabaseService();
  final FoodRecognitionService _recognitionService = FoodRecognitionService();
  final _uuid = Uuid();
  final Random _random = Random(); // Biến ngẫu nhiên để sử dụng trong demo mode
  
  List<FoodEntry> _foodEntries = [];
  List<FoodItem> _favoriteItems = [];
  List<FoodItem> _recentItems = [];
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  
  Map<String, dynamic>? _dailyNutritionSummary;
  List<FoodEntry> _dailyMeals = [];
  bool _isLoadingSummary = false;
  bool _isLoadingMeals = false;

  // Cache for daily summary and meals
  final Map<String, Map<String, dynamic>> _dailySummaryCache = {};
  final Map<String, List<FoodEntry>> _dailyMealsCache = {};
  
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
        behavior: SnackBarBehavior.floating,
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

  // Add a complete FoodEntry directly
  void addFoodEntry(FoodEntry entry) {
    _foodEntries.add(entry);
    
    // If there are items, add them to recent items
    if (entry.items.isNotEmpty) {
      for (var item in entry.items) {
        _addToRecentItems(item);
      }
    }
    
    // Xóa cache để đảm bảo dữ liệu được tính toán lại
    clearNutritionCache();
    
    notifyListeners();
    _saveData();
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
    );
    
    // Thêm vào danh sách
    _foodEntries.add(updatedEntry);
    notifyListeners();
    _saveData();
    
    return updatedEntry;
  }

  Future<void> updateServingSize(String entryId, double newServingSize) async {
    final entryIndex = _foodEntries.indexWhere((entry) => entry.id == entryId);
    if (entryIndex == -1) return;
    
    final entry = _foodEntries[entryIndex];
    if (entry.nutritionInfo != null) {
      // Cập nhật nutritionInfo
      final updatedNutritionInfo = Map<String, dynamic>.from(entry.nutritionInfo!);
      
      // Đảm bảo cập nhật cả servingSize và totalWeight
      updatedNutritionInfo['servingSize'] = newServingSize;
      updatedNutritionInfo['totalWeight'] = newServingSize * 100;
      
      // Cập nhật entry
      _foodEntries[entryIndex] = entry.copyWith(
        nutritionInfo: updatedNutritionInfo,
      );
      
      // Đảm bảo cập nhật lại các items nếu cần
      await synchronizeNutrition(
        entryId: entryId,
        servingSize: newServingSize,
      );
    }
    
    notifyListeners();
    _saveData();
  }

  Future<void> fetchDailyNutritionSummary(String date, {BuildContext? context}) async {
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
        final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
        
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
} 