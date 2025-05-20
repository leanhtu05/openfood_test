import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/meal_plan.dart';
import '../utils/constants.dart';
import 'package:flutter/foundation.dart';

class MealPlanApiService {
  // URL cơ sở của API
  static const String baseUrl = ApiEndpoints.baseUrl;
  
  // Phương thức kiểm tra kết nối với API
  static Future<bool> checkApiConnection() async {
    // Nếu forceMockData được bật, luôn trả về false để sử dụng mock data
    if (ApiEndpoints.forceMockData) {
      print('API connection check skipped, using mock data as configured in constants');
      return false;
    }
    
    try {
      print('Đang kiểm tra kết nối API tại: $baseUrl');
      final response = await http.get(Uri.parse('$baseUrl/'));
      print('Kết quả kiểm tra kết nối: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Lỗi kết nối API: $e');
      return false;
    }
  }
  
  // Tạo kế hoạch thực đơn cho cả tuần
  static Future<Map<String, dynamic>> generateWeeklyMealPlan({
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    String userId = 'default',
    bool useAI = true,
  }) async {
    try {
      final url = '$baseUrl/generate-weekly-meal?user_id=$userId&use_ai=${useAI}';
      final body = {
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      print('Gọi API tạo kế hoạch tuần: $url');
      print('Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      print('Kết quả API tạo kế hoạch tuần: ${response.statusCode}');
      if (kDebugMode) {
        print('Response body (truncated): ${response.body.substring(0, min(200, response.body.length))}...');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Lỗi khi tạo kế hoạch thực đơn: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Lỗi khi gọi API tạo kế hoạch thực đơn: $e');
      rethrow;
    }
  }
  
  // Thay thế kế hoạch thực đơn cho một ngày cụ thể
  static Future<Map<String, dynamic>> replaceDayMealPlan({
    required String day,
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    String userId = 'default',
  }) async {
    try {
      final url = '$baseUrl/replace-day?user_id=$userId';
      final body = {
        'day': day,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      print('Gọi API thay thế kế hoạch ngày: $url');
      print('Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      print('Kết quả API thay thế kế hoạch ngày: ${response.statusCode}');
      if (kDebugMode) {
        print('Response body (truncated): ${response.body.substring(0, min(200, response.body.length))}...');
      }
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        throw Exception('Lỗi khi thay thế kế hoạch thực đơn ngày: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Lỗi khi gọi API thay thế kế hoạch thực đơn ngày: $e');
      rethrow;
    }
  }
  
  // Tạo lại toàn bộ kế hoạch thực đơn trong tuần
  static Future<Map<String, dynamic>> replaceWeekMealPlan({
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    String userId = 'default',
  }) async {
    try {
      final url = '$baseUrl/replace-week?user_id=$userId';
      final body = {
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      print('Gọi API thay thế kế hoạch tuần: $url');
      print('Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      print('Kết quả API thay thế kế hoạch tuần: ${response.statusCode}');
      if (kDebugMode) {
        print('Response body (truncated): ${response.body.substring(0, min(200, response.body.length))}...');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Lỗi khi tạo lại kế hoạch thực đơn tuần: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Lỗi khi gọi API tạo lại kế hoạch thực đơn tuần: $e');
      rethrow;
    }
  }
  
  // Lấy lịch sử kế hoạch thực đơn
  static Future<List<dynamic>> getMealPlanHistory({
    String userId = 'default',
    int limit = 10,
  }) async {
    // Kiểm tra xem có sử dụng dữ liệu mẫu hay không
    if (ApiEndpoints.forceMockData) {
      return await getMockMealPlanHistory();
    }
    
    try {
      final url = '$baseUrl/meal-plan-history?user_id=$userId&limit=$limit';
      print('Gọi API lấy lịch sử kế hoạch: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('Kết quả API lấy lịch sử kế hoạch: ${response.statusCode}');
      if (kDebugMode && response.body.isNotEmpty) {
        print('Response body (truncated): ${response.body.substring(0, min(200, response.body.length))}...');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Nếu API thật thất bại, thử dùng dữ liệu mẫu
        print('API thất bại, chuyển sang dữ liệu mẫu cho lịch sử kế hoạch');
        return await getMockMealPlanHistory();
      }
    } catch (e) {
      print('Lỗi khi gọi API lấy lịch sử kế hoạch thực đơn: $e');
      // Trong trường hợp lỗi, trả về dữ liệu mẫu
      return await getMockMealPlanHistory();
    }
  }
  
  // Tạo lịch sử kế hoạch thực đơn mẫu
  static Future<List<dynamic>> getMockMealPlanHistory() async {
    // Tạo danh sách mẫu với 3 kế hoạch
    final mockHistory = [
      {
        "filename": "meal_plan_1.json",
        "user_id": "default",
        "plan_id": "mock-plan-1",
        "created_at": DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
        "goals": {
          "calories_target": 2000,
          "protein_target": 120,
          "fat_target": 65,
          "carbs_target": 250
        }
      },
      {
        "filename": "meal_plan_2.json",
        "user_id": "default",
        "plan_id": "mock-plan-2",
        "created_at": DateTime.now().subtract(Duration(days: 3)).toIso8601String(),
        "goals": {
          "calories_target": 1800,
          "protein_target": 130,
          "fat_target": 60,
          "carbs_target": 220
        }
      },
      {
        "filename": "meal_plan_3.json",
        "user_id": "default",
        "plan_id": "mock-plan-3",
        "created_at": DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
        "goals": {
          "calories_target": 2200,
          "protein_target": 140,
          "fat_target": 70,
          "carbs_target": 270
        }
      }
    ];
    
    // Simulate API delay
    await Future.delayed(Duration(milliseconds: 500));
    
    return mockHistory;
  }
  
  // Xóa một kế hoạch thực đơn cụ thể
  static Future<Map<String, dynamic>> deleteMealPlan(String filename) async {
    // Nếu đang sử dụng dữ liệu mẫu, trả về response thành công giả
    if (ApiEndpoints.forceMockData) {
      await Future.delayed(Duration(milliseconds: 500)); // Giả lập độ trễ
      return {
        "success": true,
        "message": "Đã xóa kế hoạch thực đơn (mẫu)"
      };
    }
    
    try {
      final url = '$baseUrl/meal-plan/$filename';
      print('Gọi API xóa kế hoạch: $url');
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('Kết quả API xóa kế hoạch: ${response.statusCode}');
      if (kDebugMode && response.body.isNotEmpty) {
        print('Response body: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Nếu API thất bại, trả về kết quả mẫu nhưng vẫn ghi nhận lỗi
        print('API thất bại, trả về kết quả mẫu cho xóa kế hoạch: ${response.statusCode}');
        return {
          "success": true,
          "message": "Đã xóa kế hoạch thực đơn (mẫu)"
        };
      }
    } catch (e) {
      print('Lỗi khi gọi API xóa kế hoạch thực đơn: $e');
      // Trả về kết quả mẫu trong trường hợp lỗi
      return {
        "success": true,
        "message": "Đã xóa kế hoạch thực đơn (mẫu sau lỗi)"
      };
    }
  }
  
  // Add this method below the deleteMealPlan method
  static Future<Map<String, dynamic>> getMockMealPlan() async {
    // This is a mock meal plan to use when the API is not available
    final mockMealPlan = {
      "id": "mock-plan-123",
      "user_id": "default",
      "created_at": DateTime.now().toIso8601String(),
      "nutrition_targets": {
        "calories_target": 2000,
        "protein_target": 120,
        "fat_target": 65,
        "carbs_target": 250
      },
      "weekly_plan": {
        "Monday": _createMockDayPlan("Thứ 2"),
        "Tuesday": _createMockDayPlan("Thứ 3"),
        "Wednesday": _createMockDayPlan("Thứ 4"),
        "Thursday": _createMockDayPlan("Thứ 5"),
        "Friday": _createMockDayPlan("Thứ 6"),
        "Saturday": _createMockDayPlan("Thứ 7"),
        "Sunday": _createMockDayPlan("Chủ nhật")
      }
    };
    
    // Simulate API delay
    await Future.delayed(Duration(seconds: 1));
    
    return mockMealPlan;
  }
  
  // Helper method to create a mock day plan
  static Map<String, dynamic> _createMockDayPlan(String dayName) {
    return {
      "meals": {
        "Bữa sáng": [
          {
            "name": "Phở gà",
            "description": "Phở với thịt gà, ăn kèm rau thơm và giá đỗ",
            "nutrition": {
              "calories": 450,
              "protein": 25,
              "fat": 10,
              "carbs": 65,
              "fiber": 3,
              "sugar": 2
            },
            "ingredients": ["Bánh phở", "Thịt gà", "Nước dùng", "Hành", "Rau thơm", "Giá đỗ"],
            "image_url": "https://example.com/pho.jpg"
          }
        ],
        "Bữa trưa": [
          {
            "name": "Cơm gà",
            "description": "Cơm trắng với thịt gà xé và rau cải luộc",
            "nutrition": {
              "calories": 550,
              "protein": 30,
              "fat": 15,
              "carbs": 75,
              "fiber": 4,
              "sugar": 1
            },
            "ingredients": ["Cơm", "Thịt gà", "Rau cải", "Nước mắm", "Dầu ăn"],
            "image_url": "https://example.com/com-ga.jpg"
          }
        ],
        "Bữa tối": [
          {
            "name": "Bún chả",
            "description": "Bún với thịt lợn nướng và nước chấm",
            "nutrition": {
              "calories": 500,
              "protein": 25,
              "fat": 18,
              "carbs": 60,
              "fiber": 3,
              "sugar": 5
            },
            "ingredients": ["Bún", "Thịt lợn", "Giá đỗ", "Rau thơm", "Nước mắm", "Đường"],
            "image_url": "https://example.com/bun-cha.jpg"
          }
        ]
      },
      "nutrition_summary": {
        "calories": 1500,
        "protein": 80,
        "fat": 43,
        "carbs": 200
      }
    };
  }
  
  // Helper function to get minimum of two numbers
  static int min(int a, int b) {
    return a < b ? a : b;
  }
  
  // Tạo một bữa ăn đơn lẻ
  static Future<Map<String, dynamic>> generateSingleMeal({
    required String mealType,
    required double caloriesTarget,
    double? proteinTarget,
    double? fatTarget,
    double? carbsTarget,
    String userId = 'default',
    bool useAI = true,
  }) async {
    // Nếu đã quy định để sử dụng dữ liệu mẫu, hoặc giá trị mục tiêu còn thiếu
    if (ApiEndpoints.forceMockData || proteinTarget == null || fatTarget == null || carbsTarget == null) {
      return await _getMockSingleMeal(mealType, caloriesTarget);
    }
    
    try {
      final url = '$baseUrl/generate-meal?user_id=$userId&use_ai=${useAI}';
      final body = {
        'meal_type': mealType,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      print('Gọi API tạo bữa ăn đơn lẻ: $url');
      print('Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      print('Kết quả API tạo bữa ăn đơn lẻ: ${response.statusCode}');
      if (kDebugMode && response.body.isNotEmpty) {
        print('Response body (truncated): ${response.body.substring(0, min(200, response.body.length))}...');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Lỗi khi tạo bữa ăn đơn lẻ: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Lỗi khi gọi API tạo bữa ăn đơn lẻ: $e');
      return await _getMockSingleMeal(mealType, caloriesTarget);
    }
  }
  
  // Tạo bữa ăn mẫu cho trường hợp không kết nối được API
  static Future<Map<String, dynamic>> _getMockSingleMeal(String mealType, double caloriesTarget) async {
    // Mô phỏng độ trễ của API
    await Future.delayed(Duration(milliseconds: 500));
    
    // Các giá trị dinh dưỡng mục tiêu dựa trên tổng calo
    final proteinRatio = 0.3; // 30% calo từ protein
    final fatRatio = 0.35;    // 35% calo từ chất béo
    final carbsRatio = 0.35;  // 35% calo từ carbs
    
    // 1g protein = 4 calo, 1g fat = 9 calo, 1g carbs = 4 calo
    final proteinGrams = (caloriesTarget * proteinRatio / 4).round();
    final fatGrams = (caloriesTarget * fatRatio / 9).round();
    final carbsGrams = (caloriesTarget * carbsRatio / 4).round();
    
    // Tên các bữa ăn theo loại
    Map<String, List<String>> mealNames = {
      'Bữa sáng': [
        'Bánh mì trứng ốp la',
        'Phở gà',
        'Bún riêu cua',
        'Bánh cuốn nóng',
        'Cháo trắng thịt bằm',
      ],
      'Bữa trưa': [
        'Cơm gà xối mỡ',
        'Bún chả Hà Nội',
        'Cơm tấm sườn bì chả',
        'Mì xào hải sản',
        'Bún thịt nướng',
      ],
      'Bữa tối': [
        'Canh chua cá lóc',
        'Lẩu gà lá giang',
        'Cá kho tộ',
        'Thịt kho tàu',
        'Gỏi cuốn tôm thịt',
      ],
    };
    
    // Lấy ngẫu nhiên tên bữa ăn từ danh sách theo loại
    final random = Random();
    final names = mealNames[mealType] ?? ['Bữa ăn tự chọn'];
    final name = names[random.nextInt(names.length)];
    
    // Mô tả bữa ăn
    final description = 'Món $name dinh dưỡng với $proteinGrams grams protein và $caloriesTarget calories.';
    
    // Danh sách nguyên liệu
    final ingredients = [
      'Nguyên liệu 1: 100g',
      'Nguyên liệu 2: 50g',
      'Nguyên liệu 3: 30g',
      'Gia vị các loại vừa đủ',
    ];
    
    // Tạo thông tin dinh dưỡng với độ lệch ngẫu nhiên nhỏ
    final nutritionVariance = 0.1; // 10% variance
    
    final caloriesActual = caloriesTarget * (1 + (random.nextDouble() * 2 - 1) * nutritionVariance);
    final proteinActual = proteinGrams * (1 + (random.nextDouble() * 2 - 1) * nutritionVariance);
    final fatActual = fatGrams * (1 + (random.nextDouble() * 2 - 1) * nutritionVariance);
    final carbsActual = carbsGrams * (1 + (random.nextDouble() * 2 - 1) * nutritionVariance);
    
    // Tạo dữ liệu bữa ăn mẫu
    return {
      'name': name,
      'description': description,
      'ingredients': ingredients,
      'nutrition': {
        'calories': caloriesActual,
        'protein': proteinActual,
        'fat': fatActual,
        'carbs': carbsActual,
        'fiber': 5.0,
        'sugar': 10.0,
        'sodium': 500.0,
      },
      'meal_type': mealType,
    };
  }
} 