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

class FoodProvider with ChangeNotifier {
  final FoodDatabaseService _databaseService = FoodDatabaseService();
  final FoodRecognitionService _recognitionService = FoodRecognitionService();
  final _uuid = Uuid();
  final Random _random = Random(); // Biến ngẫu nhiên để sử dụng trong demo mode
  
  List<FoodEntry> _foodEntries = [];
  List<FoodItem> _favoriteItems = [];
  List<FoodItem> _recentItems = [];
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  
  // Getters
  List<FoodEntry> get allFoodEntries => _foodEntries;
  List<FoodEntry> get todayEntries => _foodEntries.where((entry) => 
    entry.dateTime.toIso8601String().split('T')[0] == _selectedDate).toList();
  List<FoodItem> get favoriteItems => _favoriteItems;
  List<FoodItem> get recentItems => _recentItems;
  String get selectedDate => _selectedDate;
  
  // For compatibility with existing code
  List<FoodEntry> get entries => _foodEntries;
  List<FoodEntry> get favoriteEntries => _foodEntries.where((entry) => entry.isFavorite).toList();
  
  // Load food entries (for compatibility)
  Future<void> loadFoodEntries() async {
    await loadData();
  }
  
  // Load favorite food entries (for compatibility)
  Future<void> loadFavoriteFoodEntries() async {
    await loadData();
  }
  
  // Toggle favorite status (for compatibility)
  Future<bool> toggleFavorite(String id, bool isFavorite) async {
    final index = _foodEntries.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      final updatedEntry = _foodEntries[index].copyWith(isFavorite: isFavorite);
      _foodEntries[index] = updatedEntry;
      notifyListeners();
      _saveData();
      return true;
    }
    return false;
  }
  
  // Update food entry in list (for compatibility)
  void updateFoodEntryInList(FoodEntry updatedEntry) {
    updateFoodEntry(updatedEntry);
  }
  
  // Remove food entry (for compatibility)
  void removeFoodEntry(String id) {
    deleteFoodEntry(id);
  }
  
  // Đặt ngày đã chọn
  void setSelectedDate(String date) {
    _selectedDate = date;
    print('FoodProvider: Đã cập nhật ngày được chọn thành: $_selectedDate');
    notifyListeners();
  }
  
  // Lấy thông tin dinh dưỡng từ API
  Future<Map<String, dynamic>?> fetchNutritionDataFromAPI(String foodName) async {
    try {
      // Đánh dấu đang tải dữ liệu
      _isLoadingNutritionData = true;
      notifyListeners();
      
      // Gọi API thông qua adapter
      final nutritionData = await FoodDataAdapter.fetchNutritionInfo(foodName);
      
      // Cập nhật trạng thái
      _isLoadingNutritionData = false;
      
      if (nutritionData != null) {
        // Lưu vào cache nếu cần
        _nutritionDataCache[foodName.toLowerCase()] = nutritionData;
      }
      
      notifyListeners();
      return nutritionData;
      
    } catch (e) {
      print('Lỗi khi lấy dữ liệu dinh dưỡng từ API: $e');
      _isLoadingNutritionData = false;
      notifyListeners();
      return null;
    }
  }
  
  // Cập nhật thông tin dinh dưỡng cho một FoodEntry từ API
  Future<FoodEntry?> updateFoodEntryWithAPIData(FoodEntry entry) async {
    if (entry.items.isEmpty) {
      return entry;
    }
    
    try {
      // Đánh dấu đang tải dữ liệu
      _isLoadingNutritionData = true;
      notifyListeners();
      
      // Lấy tên thực phẩm từ item đầu tiên
      final foodName = entry.items.first.name;
      
      // Kiểm tra cache trước
      if (_nutritionDataCache.containsKey(foodName.toLowerCase())) {
        final cachedData = _nutritionDataCache[foodName.toLowerCase()];
        
        // Cập nhật entry với dữ liệu cache
        final updatedEntry = FoodDataAdapter.updateWithNutritionInfo(
          entry: entry,
          nutritionInfo: cachedData!,
          fromAPI: true,
        );
        
        // Cập nhật danh sách
        _updateEntryInList(updatedEntry);
        
        // Xóa cache để đảm bảo dữ liệu được tính toán lại
        _calculationCache.clear();
        
        _isLoadingNutritionData = false;
        notifyListeners();
        
        return updatedEntry;
      }
      
      // Gọi API nếu không có trong cache
      final nutritionData = await FoodDataAdapter.fetchNutritionInfo(foodName);
      
      if (nutritionData != null) {
        // Cập nhật entry với dữ liệu từ API
        final updatedEntry = FoodDataAdapter.updateWithNutritionInfo(
          entry: entry,
          nutritionInfo: nutritionData,
          fromAPI: true,
        );
        
        // Cập nhật danh sách
        _updateEntryInList(updatedEntry);
        
        // Lưu vào cache
        _nutritionDataCache[foodName.toLowerCase()] = nutritionData;
        
        // Xóa cache để đảm bảo dữ liệu được tính toán lại khi hiển thị vòng tròn dinh dưỡng
        _calculationCache.clear();
        
        _isLoadingNutritionData = false;
        notifyListeners();
        
        // Lưu dữ liệu sau khi cập nhật để đảm bảo dữ liệu mới được lưu
        await _saveData();
        
        return updatedEntry;
      }
      
      _isLoadingNutritionData = false;
      notifyListeners();
      return entry;
      
    } catch (e) {
      print('Lỗi khi cập nhật thông tin dinh dưỡng từ API: $e');
      _isLoadingNutritionData = false;
      notifyListeners();
      return entry;
    }
  }
  
  // Cập nhật entry trong danh sách
  void _updateEntryInList(FoodEntry updatedEntry) {
    final index = _foodEntries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index != -1) {
      _foodEntries[index] = updatedEntry;
      // Đảm bảo xóa cache và lưu dữ liệu sau khi cập nhật
      _calculationCache.clear();
      _saveData();
    } else {
      // Nếu không tìm thấy, thêm mới vào danh sách
      _foodEntries.add(updatedEntry);
      _calculationCache.clear();
      _saveData();
    }
  }
  
  // Trạng thái đang tải dữ liệu dinh dưỡng
  bool _isLoadingNutritionData = false;
  bool get isLoadingNutritionData => _isLoadingNutritionData;
  
  // Cache dữ liệu dinh dưỡng
  final Map<String, Map<String, dynamic>> _nutritionDataCache = {};
  
  // Load data from local storage
  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load food entries
      final entriesJson = prefs.getStringList('food_entries') ?? [];
      _foodEntries = entriesJson
          .map((json) => FoodEntry.fromJson(jsonDecode(json)))
          .toList();
      
      // Load favorite items
      final favoritesJson = prefs.getStringList('favorite_foods') ?? [];
      _favoriteItems = favoritesJson
          .map((json) => FoodItem.fromJson(jsonDecode(json)))
          .toList();
      
      // Load recent items
      final recentJson = prefs.getStringList('recent_foods') ?? [];
      _recentItems = recentJson
          .map((json) => FoodItem.fromJson(jsonDecode(json)))
          .toList();
          
      notifyListeners();
    } catch (e) {
      print('Error loading food data: $e');
    }
  }
  
  // Save data to local storage
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save food entries
      final entriesJson = _foodEntries
          .map((entry) => jsonEncode(entry.toJson()))
          .toList();
      await prefs.setStringList('food_entries', entriesJson);
      
      // Save favorite items
      final favoritesJson = _favoriteItems
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      await prefs.setStringList('favorite_foods', favoritesJson);
      
      // Save recent items
      final recentJson = _recentItems
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      await prefs.setStringList('recent_foods', recentJson);
    } catch (e) {
      print('Error saving food data: $e');
    }
  }
  
  // Add food entry with manual description
  Future<FoodEntry> addFoodEntry({
    required String description,
    File? image,
    String? mealType,
    DateTime? dateTime,
    List<FoodItem>? items,
  }) async {
    final now = dateTime ?? DateTime.now();
    final entry = FoodEntry(
      id: _uuid.v4(),
      description: description,
      imagePath: image?.path,
      mealType: mealType ?? 'Meal',
      dateTime: now,
      items: items ?? [],
    );
    
    _foodEntries.add(entry);
    
    // If there are items, add them to recent items
    if (items != null && items.isNotEmpty) {
      for (var item in items) {
        _addToRecentItems(item);
      }
    }
    
    notifyListeners();
    _saveData();
    
    return entry;
  }
  
  // Add food entry with AI recognition
  Future<FoodEntry?> addFoodEntryWithAI({
    required File image,
    required String description,
    required String mealType,
    String? date,
  }) async {
    try {
      // Lấy danh sách các món ăn từ mô hình AI
      final List<String> recognizedItems = await _recognitionService.recognizeFoodFromImage(image);
      
      // Chuyển đổi các tên món ăn được nhận diện thành đối tượng FoodItem
      List<FoodItem> foodItems = [];
      
      // Nếu có các món ăn được nhận diện, tìm kiếm dữ liệu dinh dưỡng tương ứng
      if (recognizedItems.isNotEmpty) {
        for (var itemName in recognizedItems) {
          // Tìm thông tin dinh dưỡng từ cơ sở dữ liệu
          final items = await _databaseService.searchFoodByNameOrBarcode(itemName);
          if (items.isNotEmpty) {
            foodItems.add(items.first);
          }
        }
      }
      
      // Nếu không nhận diện được món ăn nào hoặc không tìm thấy dữ liệu dinh dưỡng,
      // vẫn tạo một mục trống để người dùng có thể thêm sau
      if (foodItems.isEmpty) {
        foodItems.add(FoodItem(
          id: _uuid.v4(),
          name: description,
          calories: 0,
          protein: 0,
          fat: 0,
          carbs: 0,
          servingSize: 1.0,
          servingUnit: 'serving',
        ));
      }
      
      // Sử dụng ngày được chọn hoặc lấy ngày từ _selectedDate
      if (date != null) {
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
        
        // In ra log để debug
        print('addFoodEntryWithAI: Tạo entry với ngày được chọn: $date -> $timestamp');
        
        // Tạo food entry với ngày được chỉ định
        final entry = FoodEntry(
          id: _uuid.v4(),
          description: description,
          imagePath: image.path,
          mealType: mealType,
          dateTime: timestamp,
          items: foodItems,
        );
        
        _foodEntries.add(entry);
        
        // Thêm các món ăn vào danh sách gần đây
        for (var item in foodItems) {
          _addToRecentItems(item);
        }
        
        notifyListeners();
        _saveData();
        
        return entry;
      } else {
        // Sử dụng ngày hiện tại nếu không có ngày được chỉ định
        print('addFoodEntryWithAI: Không có ngày được chỉ định, sử dụng ngày được chọn từ provider: $_selectedDate');
        
        return await addFoodEntryForDate(
          date: _selectedDate,
          description: description,
          mealType: mealType,
          items: foodItems,
          image: image,
        );
      }
    } catch (e) {
      print('Lỗi khi thêm food entry với AI: $e');
      return null;
    }
  }
  
  // Hàm tính toán độ tương đồng giữa hai chuỗi (thuật toán Levenshtein đơn giản)
  double _calculateSimilarity(String s1, String s2) {
    s1 = s1.toLowerCase();
    s2 = s2.toLowerCase();
    
    if (s1 == s2) return 1.0;
    
    // Nếu một chuỗi là một phần của chuỗi còn lại
    if (s1.contains(s2) || s2.contains(s1)) {
      double ratio = min(s1.length, s2.length) / max(s1.length, s2.length);
      return 0.7 + (ratio * 0.3); // Cho kết quả cao hơn nếu chuỗi dài tương đối giống nhau
    }
    
    // Kiểm tra từng từ
    List<String> words1 = s1.split(' ');
    List<String> words2 = s2.split(' ');
    
    int matchingWords = 0;
    for (var word1 in words1) {
      if (word1.length <= 2) continue; // Bỏ qua các từ ngắn
      for (var word2 in words2) {
        if (word2.length <= 2) continue;
        if (word1 == word2 || word1.contains(word2) || word2.contains(word1)) {
          matchingWords++;
          break;
        }
      }
    }
    
    if (words1.isNotEmpty && words2.isNotEmpty) {
      return matchingWords / max(words1.length, words2.length);
    }
    
    return 0.0;
  }
  
  // Xác định loại bữa ăn dựa vào thời gian trong ngày
  String _determineMealTypeFromTime() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour >= 5 && hour < 10) {
      return 'Bữa sáng';
    } else if (hour >= 10 && hour < 14) {
      return 'Bữa trưa';
    } else if (hour >= 14 && hour < 17) {
      return 'Bữa nhẹ';
    } else if (hour >= 17 && hour < 22) {
      return 'Bữa tối';
    } else {
      return 'Bữa khuya';
    }
  }
  
  // Update existing food entry
  Future<void> updateFoodEntry(FoodEntry updatedEntry) async {
    final index = _foodEntries.indexWhere((entry) => entry.id == updatedEntry.id);
    
    if (index != -1) {
      final oldEntry = _foodEntries[index];
      
      // Kiểm tra nếu có thay đổi về khẩu phần
      if (oldEntry.items.isNotEmpty && updatedEntry.items.isNotEmpty) {
        final oldServingSize = oldEntry.items.first.servingSize;
        final newServingSize = updatedEntry.items.first.servingSize;
        
        if (oldServingSize != newServingSize) {
          // Nếu khẩu phần thay đổi, sử dụng synchronizeNutrition để cập nhật chính xác
          await synchronizeNutrition(
            entryId: updatedEntry.id,
            servingSize: newServingSize,
            notifyChange: false, // Không thông báo ngay vì sẽ thông báo ở cuối hàm
          );
        } else {
          // Nếu không thay đổi khẩu phần, cập nhật trực tiếp
          _foodEntries[index] = updatedEntry;
        }
      } else {
        // Nếu không có items hoặc có sự thay đổi về cấu trúc, cập nhật trực tiếp
        _foodEntries[index] = updatedEntry;
      }
    } else {
      // Nếu không tìm thấy, thêm mới
      _foodEntries.add(updatedEntry);
    }
    
    // Xóa cache để đảm bảo dữ liệu được tính toán lại
    _calculationCache.clear();
    
    // Thông báo cho UI cập nhật
    notifyListeners();
    
    // Lưu dữ liệu
    await _saveData();
  }
  
  // Delete food entry
  Future<void> deleteFoodEntry(String id) async {
    _foodEntries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    _saveData();
  }
  
  // Add item to favorites
  Future<void> addToFavorites(FoodItem item) async {
    if (!_favoriteItems.any((favItem) => favItem.id == item.id)) {
      _favoriteItems.add(item);
      notifyListeners();
      _saveData();
    }
  }
  
  // Remove item from favorites
  Future<void> removeFromFavorites(String id) async {
    _favoriteItems.removeWhere((item) => item.id == id);
    notifyListeners();
    _saveData();
  }
  
  // Add item to recent items
  void _addToRecentItems(FoodItem item) {
    // Remove if already exists to avoid duplicates
    _recentItems.removeWhere((recentItem) => recentItem.id == item.id);
    
    // Add to beginning of list
    _recentItems.insert(0, item);
    
    // Keep only the most recent 20 items
    if (_recentItems.length > 20) {
      _recentItems = _recentItems.sublist(0, 20);
    }
    
    _saveData();
  }
  
  // Calculate nutrition totals for a specific date with tính năng cache
  Map<String, dynamic> getNutritionTotals({String? date}) {
    final targetDate = date ?? _selectedDate;
    
    // Xem trong cache nếu đã có kết quả
    final cacheKey = 'nutrition_totals_$targetDate';
    if (_calculationCache.containsKey(cacheKey)) {
      return _calculationCache[cacheKey]!;
    }
    
    // Lấy danh sách các entries cho ngày cụ thể
    final entries = _foodEntries.where(
      (entry) => entry.dateTime.toIso8601String().split('T')[0] == targetDate
    ).toList();
    
    // Tính toán tổng giá trị dinh dưỡng
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalFat = 0.0;
    double totalCarbs = 0.0;
    double totalWeight = 0.0;
    
    for (var entry in entries) {
      // Ưu tiên sử dụng dữ liệu từ API nếu có
      final nutrition = entry.calculateNutritionFromAPI();
      
      totalCalories += nutrition['calories'] ?? 0.0;
      totalProtein += nutrition['protein'] ?? 0.0;
      totalFat += nutrition['fat'] ?? 0.0;
      totalCarbs += nutrition['carbs'] ?? 0.0;
      
      // Đảm bảo totalWeight được tính đúng từ mỗi entry
      if (nutrition.containsKey('totalWeight') && nutrition['totalWeight'] != null) {
        totalWeight += nutrition['totalWeight']!;
      } else if (entry.nutritionInfo != null && entry.nutritionInfo!.containsKey('totalWeight')) {
        totalWeight += entry.nutritionInfo!['totalWeight'] as double;
      } else if (entry.items.isNotEmpty) {
        // Nếu không có totalWeight, tính từ servingSize của items
        totalWeight += entry.totalWeight;
      }
    }
    
    // Tạo kết quả
    final result = {
      'calories': totalCalories,
      'protein': totalProtein,
      'fat': totalFat,
      'carbs': totalCarbs,
      'totalWeight': totalWeight,
    };
    
    // Lưu vào cache
    _calculationCache[cacheKey] = result;
    
    return result;
  }
  
  // Thêm biến cache để lưu kết quả tính toán
  final Map<String, Map<String, dynamic>> _calculationCache = {};
  
  // Phương thức để xóa cache khi cần
  Future<void> clearNutritionCache() async {
    _calculationCache.clear();
    notifyListeners();
  }
  
  // Phương thức để làm mới dữ liệu dinh dưỡng
  Future<void> refreshNutrition() async {
    _calculationCache.clear();
    notifyListeners();
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
  
  // Thêm phương thức đồng bộ dữ liệu dinh dưỡng để đảm bảo thông tin nhất quán từ API đến UI khi thay đổi khẩu phần
  Future<void> synchronizeNutritionData(String foodId, double servingSize) async {
    // Tìm tất cả các FoodEntry có chứa món ăn này
    final entriesToUpdate = _foodEntries.where((entry) {
      return entry.items.any((item) => item.id == foodId);
    }).toList();
    
    if (entriesToUpdate.isEmpty) return;
    
    // Cập nhật khẩu phần và giá trị dinh dưỡng cho từng entry
    for (var entry in entriesToUpdate) {
      final updatedItems = entry.items.map((item) {
        if (item.id == foodId) {
          // Cập nhật servingSize nếu ID trùng khớp
          return item.copyWith(servingSize: servingSize);
        }
        return item;
      }).toList();
      
      // Tạo FoodEntry mới với danh sách items đã cập nhật
      final updatedEntry = entry.copyWith(items: updatedItems);
      
      // Cập nhật entry trong danh sách
      final index = _foodEntries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _foodEntries[index] = updatedEntry;
      }
    }
    
    // Xóa cache để tính toán lại các giá trị dinh dưỡng
    _calculationCache.clear();
    
    // Thông báo cho UI cập nhật
    notifyListeners();
    
    // Lưu dữ liệu
    await _saveData();
  }
  
  // Cập nhật servingSize cho món ăn trong một entry cụ thể
  Future<void> updateFoodItemServingSize({
    required String entryId,
    required String foodItemId,
    required double newServingSize
  }) async {
    final entryIndex = _foodEntries.indexWhere((entry) => entry.id == entryId);
    if (entryIndex == -1) return;
    
    final entry = _foodEntries[entryIndex];
    final updatedItems = entry.items.map((item) {
      if (item.id == foodItemId) {
        return item.copyWith(servingSize: newServingSize);
      }
      return item;
    }).toList();
    
    _foodEntries[entryIndex] = entry.copyWith(items: updatedItems);
    
    // Xóa cache để tính toán lại các giá trị dinh dưỡng
    _calculationCache.clear();
    
    // Thông báo cho UI cập nhật
    notifyListeners();
    
    // Lưu dữ liệu
    await _saveData();
  }
  
  // Đồng bộ dữ liệu dinh dưỡng trong toàn bộ ứng dụng
  Future<void> synchronizeNutrition({
    required String entryId, 
    required double servingSize,
    bool notifyChange = true
  }) async {
    // Tìm và cập nhật FoodEntry theo ID
    final entryIndex = _foodEntries.indexWhere((entry) => entry.id == entryId);
    if (entryIndex == -1) {
      return;
    }
    
    // Lấy entry cần cập nhật
    final entry = _foodEntries[entryIndex];
    
    // Cập nhật các items trong entry
    if (entry.items.isNotEmpty) {
      // Lấy khẩu phần cũ để tính tỷ lệ
      final oldServingSize = entry.items.first.servingSize;
      final ratio = servingSize / oldServingSize;
      
      // Cập nhật từng item với servingSize mới
      final updatedItems = entry.items.map((item) {
        return item.copyWith(servingSize: servingSize);
      }).toList();
      
      // Cập nhật thông tin dinh dưỡng trong nutritionInfo nếu có
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
          'cholesterol', 'omega3', 'vitaminD', 'vitaminB12', 'vitaminC', 
          'calcium', 'iron', 'potassium', 'magnesium'
        ];
        
        for (var nutrient in micronutrients) {
          if (updatedNutritionInfo.containsKey(nutrient) && updatedNutritionInfo[nutrient] is num) {
            updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
          }
        }
      } else {
        // Nếu không có nutritionInfo, tạo mới với totalWeight
        updatedNutritionInfo = {
          'servingSize': servingSize,
          'totalWeight': servingSize * 100,
        };
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
        calories: entry.calories,
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
        notifyListeners();
      }
      
      // Lưu dữ liệu
      await _saveData();
      
      // Làm mới dữ liệu dinh dưỡng để đảm bảo UI được cập nhật
      refreshNutrition();
    }
  }
  
  // Thêm món ăn vào bữa ăn
  Future<void> addFoodItemToEntry({
    required String entryId,
    required FoodItem foodItem
  }) async {
    final entryIndex = _foodEntries.indexWhere((entry) => entry.id == entryId);
    if (entryIndex == -1) return;
    
    final entry = _foodEntries[entryIndex];
    final updatedItems = [...entry.items, foodItem];
    
    _foodEntries[entryIndex] = entry.copyWith(items: updatedItems);
    
    // Xóa cache để tính toán lại các giá trị dinh dưỡng
    _calculationCache.clear();
    
    // Thông báo cho UI cập nhật
    notifyListeners();
    
    // Lưu dữ liệu
    await _saveData();
  }
} 