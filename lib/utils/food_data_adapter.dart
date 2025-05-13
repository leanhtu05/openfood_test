import 'package:uuid/uuid.dart';
import '../models/food_item.dart';
import '../models/food_entry.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lớp FoodDataAdapter đảm nhiệm việc chuyển đổi dữ liệu từ các nguồn khác nhau
/// (phân tích AI, quét mã vạch, tìm kiếm cơ sở dữ liệu) sang định dạng đồng nhất
/// để hiển thị trong màn hình FoodNutritionDetailScreen
class FoodDataAdapter {
  static final _uuid = Uuid();

  /// Tạo FoodEntry từ kết quả nhận dạng AI
  static FoodEntry createFromAIRecognition({
    required List<String> recognizedItems,
    required Map<String, dynamic>? nutritionData,
    String? imagePath,
    DateTime? dateTime,
    String mealType = 'Bữa chính',
  }) {
    // Tạo mô tả từ danh sách các món đã nhận dạng
    final description = recognizedItems.isNotEmpty 
        ? recognizedItems.first 
        : 'Món ăn đã nhận dạng';
    
    // Tạo các FoodItem từ dữ liệu dinh dưỡng
    final items = <FoodItem>[];
    
    if (nutritionData != null) {
      items.add(FoodItem(
        id: _uuid.v4(),
        name: description,
        calories: nutritionData['calories'] ?? 0.0,
        protein: nutritionData['protein'] ?? 0.0,
        fat: nutritionData['fat'] ?? 0.0,
        carbs: nutritionData['carbs'] ?? 0.0,
        fiber: nutritionData['fiber'],
        sugar: nutritionData['sugar'],
        sodium: nutritionData['sodium'],
        servingSize: 1.0, // Đại diện cho 100g/ml
        servingUnit: 'g',
        additionalNutrients: _extractAdditionalNutrients(nutritionData),
      ));
    } else {
      // Nếu không có dữ liệu dinh dưỡng, tạo item mặc định
      items.add(FoodItem(
        id: _uuid.v4(),
        name: description,
        calories: 0.0,
        protein: 0.0,
        fat: 0.0,
        carbs: 0.0,
        servingSize: 1.0,
        servingUnit: 'g',
      ));
    }
    
    return FoodEntry(
      id: _uuid.v4(),
      description: description,
      imagePath: imagePath,
      dateTime: dateTime ?? DateTime.now(),
      mealType: mealType,
      items: items,
    );
  }
  
  /// Tạo FoodEntry từ kết quả quét mã vạch
  static FoodEntry createFromBarcode({
    required FoodItem foodItem,
    String? imagePath,
    DateTime? dateTime,
    String mealType = 'Bữa chính',
  }) {
    return FoodEntry(
      id: _uuid.v4(),
      description: foodItem.name,
      imagePath: imagePath ?? foodItem.imageUrl,
      dateTime: dateTime ?? DateTime.now(),
      mealType: mealType,
      items: [foodItem],
    );
  }
  
  /// Cập nhật FoodEntry với thông tin dinh dưỡng mới
  static FoodEntry updateWithNutritionInfo({
    required FoodEntry entry,
    required Map<String, dynamic> nutritionInfo,
    bool fromAPI = false, // Thêm tham số để đánh dấu nguồn dữ liệu
  }) {
    // Cập nhật danh sách items nếu đã có
    List<FoodItem> updatedItems = [];
    
    if (entry.items.isNotEmpty) {
      // Cập nhật item đầu tiên
      final item = entry.items.first;
      updatedItems.add(FoodItem(
        id: item.id,
        name: item.name,
        brand: item.brand,
        imageUrl: item.imageUrl,
        calories: nutritionInfo['calories'] ?? item.calories,
        protein: nutritionInfo['protein'] ?? item.protein,
        fat: nutritionInfo['fat'] ?? item.fat,
        carbs: nutritionInfo['carbs'] ?? item.carbs,
        fiber: nutritionInfo['fiber'] ?? item.fiber,
        sugar: nutritionInfo['sugar'] ?? item.sugar,
        sodium: nutritionInfo['sodium'] ?? item.sodium,
        servingSize: item.servingSize,
        servingUnit: item.servingUnit,
        additionalNutrients: _extractAdditionalNutrients(nutritionInfo),
      ));
      
      // Thêm các items còn lại nếu có
      if (entry.items.length > 1) {
        updatedItems.addAll(entry.items.sublist(1));
      }
    } else {
      // Tạo item mới nếu chưa có
      updatedItems.add(FoodItem(
        id: _uuid.v4(),
        name: entry.description,
        calories: nutritionInfo['calories'] ?? 0.0,
        protein: nutritionInfo['protein'] ?? 0.0,
        fat: nutritionInfo['fat'] ?? 0.0,
        carbs: nutritionInfo['carbs'] ?? 0.0,
        fiber: nutritionInfo['fiber'],
        sugar: nutritionInfo['sugar'],
        sodium: nutritionInfo['sodium'],
        servingSize: 1.0,
        servingUnit: 'g',
        additionalNutrients: _extractAdditionalNutrients(nutritionInfo),
      ));
    }
    
    // Nếu dữ liệu từ API, cập nhật thêm trường dataSource
    Map<String, dynamic> updatedNutritionInfo = Map.from(nutritionInfo);
    if (fromAPI) {
      updatedNutritionInfo['dataSource'] = 'API';
      updatedNutritionInfo['dataTimestamp'] = DateTime.now().toIso8601String();
    }
    
    return FoodEntry(
      id: entry.id,
      description: entry.description,
      imagePath: entry.imagePath,
      audioPath: entry.audioPath,
      dateTime: entry.dateTime,
      isFavorite: entry.isFavorite,
      barcode: entry.barcode,
      calories: nutritionInfo['calories'] ?? entry.calories,
      nutritionInfo: updatedNutritionInfo,
      mealType: entry.mealType,
      items: updatedItems,
    );
  }
  
  /// Trích xuất thông tin dinh dưỡng bổ sung
  static Map<String, dynamic>? _extractAdditionalNutrients(Map<String, dynamic> data) {
    final additionalNutrients = <String, dynamic>{};
    
    // Danh sách các dinh dưỡng cơ bản đã được xử lý riêng
    final basicNutrients = ['calories', 'protein', 'fat', 'carbs', 'fiber', 'sugar', 'sodium'];
    
    // Trích xuất tất cả các dinh dưỡng khác
    data.forEach((key, value) {
      if (!basicNutrients.contains(key) && value != null) {
        additionalNutrients[key] = value;
      }
    });
    
    return additionalNutrients.isNotEmpty ? additionalNutrients : null;
  }
  
  /// Lấy bữa ăn dựa trên thời gian hiện tại
  static String getMealTypeBasedOnTime(DateTime time) {
    final hour = time.hour;
    
    if (hour >= 5 && hour < 10) {
      return 'Bữa sáng';
    } else if (hour >= 10 && hour < 14) {
      return 'Bữa trưa';
    } else if (hour >= 17 && hour < 21) {
      return 'Bữa tối';
    } else {
      return 'Bữa phụ';
    }
  }
  
  /// Tìm thông tin dinh dưỡng từ API cho món ăn
  static Future<Map<String, dynamic>?> fetchNutritionInfo(String foodName, {String? language = 'vi'}) async {
    try {
      // URL API (giả định)
      final apiUrl = 'https://api.nutritiondata.example/v1/foods';
      
      // Chuẩn bị tham số
      final params = {
        'query': foodName,
        'lang': language ?? 'vi',
        'units': 'metric',
      };
      
      // Gọi API
      final response = await http.get(
        Uri.parse('$apiUrl?${_encodeParams(params)}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': 'demo_api_key', // Sử dụng API key thực tế trong môi trường thực
        },
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // Xử lý phản hồi
        final data = jsonDecode(response.body);
        
        if (data['results'] != null && data['results'].isNotEmpty) {
          final item = data['results'][0]; // Lấy kết quả đầu tiên
          
          // Chuyển đổi dữ liệu API thành định dạng của ứng dụng
          return {
            'calories': item['nutrients']['energy_kcal'] ?? 0.0,
            'protein': item['nutrients']['protein_g'] ?? 0.0,
            'fat': item['nutrients']['fat_total_g'] ?? 0.0,
            'carbs': item['nutrients']['carbohydrates_total_g'] ?? 0.0,
            'fiber': item['nutrients']['fiber_g'],
            'sugar': item['nutrients']['sugars_g'],
            'sodium': item['nutrients']['sodium_mg'],
            'dataSource': 'API:${data['source'] ?? 'unknown'}',
            'timestamp': DateTime.now().toIso8601String(),
            // Thêm các vi chất nếu có
            'vitaminC': item['nutrients']['vitamin_c_mg'],
            'calcium': item['nutrients']['calcium_mg'],
            'iron': item['nutrients']['iron_mg'],
            'potassium': item['nutrients']['potassium_mg'],
          };
        }
      }
      
      // Mô phỏng dữ liệu API khi không có kết quả thực
      // Trong môi trường thực tế, chúng ta sẽ trả về null ở đây
      print('Mô phỏng dữ liệu API cho: $foodName');
      return _generateMockNutritionData(foodName);
      
    } catch (e) {
      print('Lỗi khi gọi API lấy thông tin dinh dưỡng: $e');
      
      // Mô phỏng dữ liệu trong môi trường phát triển
      return _generateMockNutritionData(foodName);
    }
  }
  
  /// Mã hóa các tham số URL
  static String _encodeParams(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
  
  /// Tạo dữ liệu dinh dưỡng giả lập dựa trên tên món ăn
  static Map<String, dynamic> _generateMockNutritionData(String foodName) {
    final lowerName = foodName.toLowerCase();
    
    // Giá trị cho một số món ăn phổ biến
    if (lowerName.contains('gà') || lowerName.contains('chicken')) {
      return {
        'calories': 165.0,
        'protein': 31.0,
        'fat': 3.6,
        'carbs': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
        'sodium': 74.0,
        'dataSource': 'MockAPI',
        'timestamp': DateTime.now().toIso8601String(),
        'vitaminC': 0.0,
        'calcium': 15.0,
        'iron': 1.3,
        'potassium': 223.0,
      };
    } else if (lowerName.contains('cơm') || lowerName.contains('rice')) {
      return {
        'calories': 130.0,
        'protein': 2.7,
        'fat': 0.3,
        'carbs': 28.2,
        'fiber': 0.4,
        'sugar': 0.1,
        'sodium': 1.0,
        'dataSource': 'MockAPI',
        'timestamp': DateTime.now().toIso8601String(),
        'vitaminC': 0.0,
        'calcium': 10.0,
        'iron': 0.2,
        'potassium': 35.0,
      };
    } else if (lowerName.contains('táo') || lowerName.contains('apple')) {
      return {
        'calories': 52.0,
        'protein': 0.3,
        'fat': 0.2,
        'carbs': 14.0,
        'fiber': 2.4,
        'sugar': 10.3,
        'sodium': 1.0,
        'dataSource': 'MockAPI',
        'timestamp': DateTime.now().toIso8601String(),
        'vitaminC': 4.6,
        'calcium': 6.0,
        'iron': 0.1,
        'potassium': 107.0,
      };
    }
    
    // Giá trị mặc định cho các món khác
    return {
      'calories': 100.0 + (foodName.length % 10) * 20,
      'protein': 5.0 + (foodName.length % 5) * 2,
      'fat': 3.0 + (foodName.length % 7),
      'carbs': 10.0 + (foodName.length % 15),
      'fiber': 1.5 + (foodName.length % 3) * 0.5,
      'sugar': 2.0 + (foodName.length % 4),
      'sodium': 50.0 + (foodName.length % 30) * 3,
      'dataSource': 'MockAPI',
      'timestamp': DateTime.now().toIso8601String(),
      'vitaminC': (foodName.length % 10) * 0.5,
      'calcium': 20.0 + (foodName.length % 8) * 5,
      'iron': 1.0 + (foodName.length % 3) * 0.3,
      'potassium': 100.0 + (foodName.length % 20) * 10,
    };
  }
} 