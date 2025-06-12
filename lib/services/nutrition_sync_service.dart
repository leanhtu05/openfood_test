import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../providers/food_provider.dart';
import '../adapters/food_data_adapter.dart';

/// Dịch vụ đồng bộ dữ liệu dinh dưỡng
class NutritionSyncService {
  /// Đồng bộ dữ liệu dinh dưỡng với provider
  static Future<FoodEntry> synchronizeNutritionData({
    required BuildContext context,
    required FoodEntry foodEntry,
    required double servingSize,
  }) async {
    try {
      FoodEntry tempEntry = foodEntry;
      
      // Lấy FoodProvider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Đồng bộ dữ liệu với provider
      if (tempEntry.items.isNotEmpty) {
        // Tách phần gọi UI vào microtask để đảm bảo chạy sau khi build hoàn tất
        await foodProvider.synchronizeNutrition(
          entryId: tempEntry.id,
          servingSize: servingSize,
          notifyChange: false, // Không thông báo ngay lập tức
        );
        
        // Làm mới dữ liệu
        await foodProvider.refreshNutrition();
        
        // Lấy lại entry đã cập nhật sau khi đồng bộ
        final refreshedEntry = foodProvider.getFoodEntryById(tempEntry.id);
        
        if (refreshedEntry != null) {
          tempEntry = refreshedEntry;
          
          // Đảm bảo tất cả các khóa dinh dưỡng được đồng bộ
          if (tempEntry.nutritionInfo != null) {
            final nutritionInfo = Map<String, dynamic>.from(tempEntry.nutritionInfo!);
            _syncNutrientKeys(nutritionInfo);
            
            // Cập nhật FoodEntry với nutritionInfo đã đồng bộ khóa
            tempEntry = tempEntry.copyWith(nutritionInfo: nutritionInfo);
          }
        }
      }
      
      return tempEntry;
    } catch (e) {
      return foodEntry;
    }
  }

  /// Fetch dữ liệu dinh dưỡng từ API
  static Future<FoodEntry> fetchNutritionDataFromAPI({
    required BuildContext context,
    required FoodEntry foodEntry,
    required double servingSize,
  }) async {
    try {
      // Sử dụng tên món ăn làm từ khóa tìm kiếm
      String searchTerm = foodEntry.description;
      
      // Sử dụng FoodDataAdapter để gọi API
      final nutritionInfo = await FoodDataAdapter.fetchNutritionInfo(searchTerm);
      
      if (nutritionInfo != null) {
        // Đảm bảo totalWeight và servingSize được thiết lập đúng
        nutritionInfo['servingSize'] = servingSize;
        nutritionInfo['totalWeight'] = servingSize * 100;
        
        // Đồng bộ hóa các khóa dinh dưỡng
        _syncNutrientKeys(nutritionInfo);
        
        // Lấy FoodProvider
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        
        // Cập nhật FoodEntry với dữ liệu từ API
        final updatedEntry = FoodDataAdapter.updateWithNutritionInfo(
          entry: foodEntry,
          nutritionInfo: nutritionInfo,
          fromAPI: true,
        );
        
        // Cập nhật entry trong provider
        foodProvider.updateFoodEntry(updatedEntry);
        
        return updatedEntry;
      }
    } catch (e) {
    }
    
    return foodEntry;
  }

  /// Đồng bộ toàn bộ dữ liệu dinh dưỡng
  static Future<FoodEntry> synchronizeAllData({
    required BuildContext context,
    required FoodEntry foodEntry,
    required double servingSize,
  }) async {
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Chỉ đồng bộ nếu có items
      if (foodEntry.items.isNotEmpty) {
        // Đồng bộ cho từng item
        for (var item in foodEntry.items) {
          // Đồng bộ dữ liệu với khẩu phần hiện tại
          foodProvider.synchronizeNutritionData(item.id, servingSize);
        }
        
        // Đồng bộ entry hiện tại
        foodProvider.synchronizeNutrition(
          entryId: foodEntry.id,
          servingSize: servingSize,
        );
        
        // Xóa cache để đảm bảo dữ liệu được tính toán lại
        foodProvider.refreshNutrition();
      }
      
      // Cập nhật entry trong provider
      foodProvider.updateFoodEntry(foodEntry);
      
      // Lấy entry cập nhật
      final updatedEntry = foodProvider.getFoodEntryById(foodEntry.id);
      if (updatedEntry != null) {
        return updatedEntry;
      }
    } catch (e) {
    }
    
    return foodEntry;
  }

  /// Cập nhật kích thước khẩu phần
  static FoodEntry updateServingSize({
    required BuildContext context,
    required FoodEntry foodEntry,
    required double newServingSize,
    required double oldServingSize,
  }) {
    try {
      // Tính tỷ lệ thay đổi
      var ratio = newServingSize / oldServingSize;
      
      // Cập nhật từng item với servingSize mới
      final updatedItems = foodEntry.items.map((item) {
        return item.copyWith(
          servingSize: newServingSize,
        );
      }).toList();
      
      // Cập nhật FoodEntry với items mới và thông tin dinh dưỡng mới
      Map<String, dynamic> updatedNutritionInfo = {};
      if (foodEntry.nutritionInfo != null) {
        updatedNutritionInfo = Map<String, dynamic>.from(foodEntry.nutritionInfo!);
        
        // Cập nhật khẩu phần
        updatedNutritionInfo['servingSize'] = newServingSize;
        
        // Cập nhật tổng khối lượng - đồng bộ với khẩu phần (100g = 1 khẩu phần)
        updatedNutritionInfo['totalWeight'] = newServingSize * 100;
        
        // Cập nhật các giá trị dinh dưỡng theo tỷ lệ
        if (updatedNutritionInfo.containsKey('calories')) {
          updatedNutritionInfo['calories'] = (updatedNutritionInfo['calories'] * ratio).toDouble();
        }
        if (updatedNutritionInfo.containsKey('protein')) {
          updatedNutritionInfo['protein'] = (updatedNutritionInfo['protein'] * ratio).toDouble();
        }
        if (updatedNutritionInfo.containsKey('fat')) {
          updatedNutritionInfo['fat'] = (updatedNutritionInfo['fat'] * ratio).toDouble();
        }
        if (updatedNutritionInfo.containsKey('carbs')) {
          updatedNutritionInfo['carbs'] = (updatedNutritionInfo['carbs'] * ratio).toDouble();
        }
        
        // Cập nhật các vi chất
        final micronutrients = [
          // Dinh dưỡng cơ bản khác
          'fiber', 'sugar', 'sodium', 'cholesterol', 'omega3', 'water',
          
          // Vitamin 
          'vitamin_d', 'vitaminD',
          'vitamin_c', 'vitaminC',
          'vitamin_b12', 'vitaminB12', 
          'vitamin_b9', 'vitaminB9',
          'vitamin_b', 'vitaminB',
          'vitamin_a', 'vitaminA',
          'vitamin_e', 'vitaminE',
          'vitamin_k', 'vitaminK',
          
          // Khoáng chất
          'calcium', 'iron', 'potassium', 'magnesium', 'zinc',
          'phosphorus', 'selenium', 'copper', 'manganese',
          
          // Các chất khác
          'saturated_fat', 'saturatedFat',
          'trans_fat', 'transFat',
          'thiamin', 'riboflavin', 'niacin',
          'caffeine', 'alcohol'
        ];
        
        for (var nutrient in micronutrients) {
          if (updatedNutritionInfo.containsKey(nutrient)) {
            updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
          }
        }
        
        // Đảm bảo đồng bộ giữa các khóa snake_case và camelCase
        _syncNutrientKeys(updatedNutritionInfo);
      } else {
        updatedNutritionInfo = {
          'servingSize': newServingSize,
          'totalWeight': newServingSize * 100,
          'calories': foodEntry.totalCalories * ratio,
          'protein': foodEntry.totalProtein * ratio,
          'fat': foodEntry.totalFat * ratio,
          'carbs': foodEntry.totalCarbs * ratio,
        };
      }
      
      // Tạo FoodEntry mới
      final updatedEntry = foodEntry.copyWith(
        items: updatedItems,
        nutritionInfo: updatedNutritionInfo,
      );
      
      // Cập nhật FoodProvider để đồng bộ dữ liệu trên toàn ứng dụng
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Đầu tiên cập nhật entry trong provider
      foodProvider.updateFoodEntry(updatedEntry);
      
      // Sau đó đồng bộ lại thông tin dinh dưỡng
      foodProvider.synchronizeNutrition(
        entryId: updatedEntry.id,
        servingSize: newServingSize,
      );
      
      // Xóa cache để đảm bảo dữ liệu được tính toán lại
      foodProvider.refreshNutrition();
      
      return updatedEntry;
    } catch (e) {
      return foodEntry;
    }
  }

  /// Xử lý lưu và thoát
  static Future<FoodEntry> handleSaveAndExit({
    required BuildContext context,
    required FoodEntry foodEntry,
    required double servingSize,
  }) async {
    try {
      // Lấy FoodProvider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Đảm bảo dữ liệu dinh dưỡng được cập nhật đúng cách
      final nutritionValues = foodEntry.calculateNutritionFromAPI();
      
      // Cập nhật lại nutritionInfo nếu cần thiết
      FoodEntry updatedEntry = foodEntry;
      if (foodEntry.nutritionInfo == null || foodEntry.nutritionInfo!.isEmpty) {
        updatedEntry = foodEntry.copyWith(
          nutritionInfo: {
            'calories': nutritionValues['calories'],
            'protein': nutritionValues['protein'],
            'fat': nutritionValues['fat'],
            'carbs': nutritionValues['carbs'],
            'fiber': nutritionValues['fiber'],
            'sugar': nutritionValues['sugar'],
            'sodium': nutritionValues['sodium'],
            'servingSize': servingSize,
            'totalWeight': nutritionValues['totalWeight'] ?? (servingSize * 100),
          }
        );
      } else {
        // Đảm bảo totalWeight luôn được cập nhật trong nutritionInfo
        final updatedNutritionInfo = Map<String, dynamic>.from(foodEntry.nutritionInfo!);
        updatedNutritionInfo['totalWeight'] = nutritionValues['totalWeight'] ?? (servingSize * 100);
        updatedNutritionInfo['servingSize'] = servingSize;
        updatedEntry = foodEntry.copyWith(nutritionInfo: updatedNutritionInfo);
      }
      
      // QUAN TRỌNG: Đặt selectedDate trước để đảm bảo màn hình home hiển thị đúng ngày
      String dateStr = "${updatedEntry.dateTime.year}-${updatedEntry.dateTime.month.toString().padLeft(2, '0')}-${updatedEntry.dateTime.day.toString().padLeft(2, '0')}";
      foodProvider.setSelectedDate(dateStr);
      
      // Cập nhật entry trong provider
      foodProvider.updateFoodEntry(updatedEntry);
      
      // Đồng bộ dữ liệu dinh dưỡng nếu có items
      if (updatedEntry.items.isNotEmpty) {
        // Đồng bộ từng item
        for (var item in updatedEntry.items) {
          foodProvider.synchronizeNutritionData(item.id, servingSize);
        }
        
        // Đồng bộ entry sau khi items đã được đồng bộ
        foodProvider.synchronizeNutrition(
          entryId: updatedEntry.id,
          servingSize: servingSize,
        );
      }
      
      // Xóa cache để đảm bảo dữ liệu được tính toán lại và lưu thay đổi
      foodProvider.refreshNutrition();
      return updatedEntry;
    } catch (e) {
      return foodEntry;
    }
  }

  /// Xử lý khi thay đổi khối lượng
  static FoodEntry onWeightChanged({
    required BuildContext context,
    required FoodEntry foodEntry,
    required double newWeight,
  }) {
    try {
      // Đảm bảo weight > 0
      if (newWeight <= 0) newWeight = 1.0;
      
      // Tính servingSize mới dựa trên weight (1 servingSize = 100g)
      final newServingSize = newWeight / 100;
      
      // Lấy provider để cập nhật dữ liệu
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Tạo bản sao mới của danh sách items
      final updatedItems = foodEntry.items.map((item) {
        return FoodItem(
          id: item.id,
          name: item.name,
          brand: item.brand,
          calories: item.calories,
          protein: item.protein,
          fat: item.fat,
          carbs: item.carbs,
          servingSize: newServingSize, // Cập nhật servingSize mới
          servingUnit: item.servingUnit,
          fiber: item.fiber,
          sugar: item.sugar,
          sodium: item.sodium,
          imageUrl: item.imageUrl,
          additionalNutrients: item.additionalNutrients != null 
              ? Map<String, dynamic>.from(item.additionalNutrients!) 
              : null,
        );
      }).toList();
      
      // Tạo bản sao mới của nutritionInfo nếu có
      Map<String, dynamic>? updatedNutritionInfo;
      if (foodEntry.nutritionInfo != null) {
        updatedNutritionInfo = Map<String, dynamic>.from(foodEntry.nutritionInfo!);
        
        // Cập nhật totalWeight và servingSize trong nutritionInfo
        updatedNutritionInfo['totalWeight'] = newWeight;
        updatedNutritionInfo['servingSize'] = newServingSize;
        
        // Cập nhật các giá trị dinh dưỡng theo tỷ lệ nếu cần
        if (foodEntry.items.isNotEmpty) {
          final oldServingSize = foodEntry.items.first.servingSize;
          if (oldServingSize > 0 && newServingSize != oldServingSize) {
            final ratio = newServingSize / oldServingSize;
            
            // Cập nhật các giá trị dinh dưỡng theo tỷ lệ
            for (var nutrient in ['calories', 'protein', 'fat', 'carbs', 'fiber', 'sugar', 'sodium']) {
              if (updatedNutritionInfo.containsKey(nutrient) && updatedNutritionInfo[nutrient] is num) {
                updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
              }
            }
          }
        }
      }
      
      // Tạo FoodEntry mới với các bản sao mới
      final updatedEntry = FoodEntry(
        id: foodEntry.id,
        description: foodEntry.description,
        imagePath: foodEntry.imagePath,
        audioPath: foodEntry.audioPath,
        dateTime: foodEntry.dateTime,
        isFavorite: foodEntry.isFavorite,
        barcode: foodEntry.barcode,
        calories: foodEntry.calories,
        nutritionInfo: updatedNutritionInfo,
        mealType: foodEntry.mealType,
        items: updatedItems,
      );
      
      // Cập nhật entry trong provider
      foodProvider.updateFoodEntry(updatedEntry);
      
      return updatedEntry;
    } catch (e) {
      return foodEntry;
    }
  }

  /// Hàm đồng bộ khóa dinh dưỡng giữa camelCase và snake_case
  static void _syncNutrientKeys(Map<String, dynamic> nutritionInfo) {
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
      // Nếu cả hai đều null, đặt giá trị mặc định là 0.0
      else if (!nutritionInfo.containsKey(snakeKey) && !nutritionInfo.containsKey(camelKey)) {
        nutritionInfo[snakeKey] = 0.0;
        nutritionInfo[camelKey] = 0.0;
      }
      // Nếu một trong hai là null, sử dụng giá trị không null
      else if (nutritionInfo.containsKey(snakeKey) && nutritionInfo[snakeKey] == null) {
        nutritionInfo[snakeKey] = nutritionInfo.containsKey(camelKey) && nutritionInfo[camelKey] != null ? 
          nutritionInfo[camelKey] : 0.0;
      }
      else if (nutritionInfo.containsKey(camelKey) && nutritionInfo[camelKey] == null) {
        nutritionInfo[camelKey] = nutritionInfo.containsKey(snakeKey) && nutritionInfo[snakeKey] != null ? 
          nutritionInfo[snakeKey] : 0.0;
      }
    });
  }
}

// Extension để lấy servingSize từ FoodEntry
extension FoodEntryExtension on FoodEntry {
  double getServingSize() {
    if (nutritionInfo != null && nutritionInfo!.containsKey('servingSize')) {
      return (nutritionInfo!['servingSize'] as num).toDouble();
    }
    
    if (items.isNotEmpty) {
      return items.first.servingSize;
    }
    
    return 1.0;
  }
} 