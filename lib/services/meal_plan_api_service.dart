import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/meal_plan.dart';
import '../utils/constants.dart';
import 'package:flutter/foundation.dart';
import '../utils/config.dart';

class MealPlanApiService {
  // URL cơ sở của API
  static const String baseUrl = apiBaseUrl;
  
  // Thời gian chờ tối đa cho các API request
  static const Duration apiTimeout = Duration(seconds: 15);
  
  // Phương thức kiểm tra kết nối với API
  static Future<bool> checkApiConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/')).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('Timeout', 408),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('API connection error: $e');
      return false;
    }
  }
  
  // Kiểm tra tình trạng AI
  static Future<Map<String, dynamic>> checkAIAvailability() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api-status')).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('{"ai_available":false,"error":"Timeout"}', 408),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'ai_available': false, 'error': 'Status code: ${response.statusCode}'};
      }
    } catch (e) {
      print('AI status check error: $e');
      return {'ai_available': false, 'error': e.toString()};
    }
  }
  
  // Tạo kế hoạch tuần cá nhân hóa
  static Future<Map<String, dynamic>> generatePersonalizedWeeklyMealPlan({
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    List<String> preferences = const [],
    List<String> allergies = const [],
    String? cuisineStyle,
    bool useAI = false,
  }) async {
    try {
      // Chuẩn bị thông tin dinh dưỡng
      final nutritionTarget = {
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      // Chuẩn bị URL với query parameters
      final uri = Uri.parse('$baseUrl/generate-weekly-meal-personalized')
        .replace(queryParameters: {
          'user_id': 'flutter_app',
          'use_ai': useAI.toString(),
        });
      
      // Chuẩn bị request body
      final requestBody = json.encode({
        ...nutritionTarget,
        'preferences': preferences,
        'allergies': allergies,
        'cuisine_style': cuisineStyle,
      });
      
      // Gửi request
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => http.Response('{"error":"Request timeout"}', 408),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['meal_plan'];
      } else {
        final errorMsg = response.body;
        print('API error: [${response.statusCode}] $errorMsg');
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to generate meal plan: $e');
      throw Exception('Failed to generate meal plan: $e');
    }
  }
  
  // Thay thế một ngày trong kế hoạch
  static Future<Map<String, dynamic>> replaceDay({
    required Map<String, dynamic> replaceRequest,
    List<String> preferences = const [],
    List<String> allergies = const [],
    String? cuisineStyle,
    bool useAI = false,
  }) async {
    try {
      // Chuẩn bị URL với query parameters
      final uri = Uri.parse('$baseUrl/replace-day-personalized')
        .replace(queryParameters: {
          'user_id': 'flutter_app',
          'use_ai': useAI.toString(),
        });
      
      // Chuẩn bị request body
      final requestBody = json.encode({
        ...replaceRequest,
        'preferences': preferences,
        'allergies': allergies,
        'cuisine_style': cuisineStyle,
      });
      
      // Gửi request
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => http.Response('{"error":"Request timeout"}', 408),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorMsg = response.body;
        print('API error: [${response.statusCode}] $errorMsg');
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to replace day: $e');
      throw Exception('Failed to replace day: $e');
    }
  }
  
  // Legacy method - Sử dụng demo API endpoint
  static Future<Map<String, dynamic>> generateWeeklyMealPlan({
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    bool useAI = false,
  }) async {
    try {
      // Chuẩn bị thông tin dinh dưỡng
      final nutritionTarget = {
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      // Sử dụng endpoint demo để tránh tác động đến API chính
      final uri = Uri.parse('$baseUrl/generate-weekly-meal-demo')
        .replace(queryParameters: {
          'user_id': 'flutter_app',
          'use_ai': useAI.toString(),
        });
      
      // Gửi request
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(nutritionTarget),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => http.Response('{"error":"Request timeout"}', 408),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['meal_plan'];
      } else {
        final errorMsg = response.body;
        print('API error: [${response.statusCode}] $errorMsg');
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to generate meal plan: $e');
      throw Exception('Failed to generate meal plan: $e');
    }
  }
  
  // Lấy dữ liệu mẫu khi không thể kết nối API
  static Future<Map<String, dynamic>> getMockMealPlan() async {
    // Mô phỏng độ trễ mạng
    await Future.delayed(Duration(seconds: 1));
    
    // Tạo dữ liệu giả
    return {
      'weekly_plan': {
        'Monday': _createMockDayPlan('Thứ 2'),
        'Tuesday': _createMockDayPlan('Thứ 3'),
        'Wednesday': _createMockDayPlan('Thứ 4'),
        'Thursday': _createMockDayPlan('Thứ 5'),
        'Friday': _createMockDayPlan('Thứ 6'),
        'Saturday': _createMockDayPlan('Thứ 7'),
        'Sunday': _createMockDayPlan('Chủ Nhật'),
      }
    };
  }
  
  // Hàm tạo dữ liệu giả cho một ngày
  static Map<String, dynamic> _createMockDayPlan(String dayName) {
    return {
      'day_of_week': dayName,
      'nutrition_summary': {
        'calories': 2000,
        'protein': 120,
        'fat': 65,
        'carbs': 250,
        'fiber': 30,
      },
      'meals': {
        'Bữa sáng': [
          {
            'name': 'Bữa sáng mẫu',
            'description': 'Đây là dữ liệu mẫu khi không kết nối được với API.',
            'ingredients': [
              '2 quả trứng',
              '1 lát bánh mì nguyên cám',
              '1 quả chuối',
            ],
            'nutrition': {
              'calories': 400,
              'protein': 20,
              'fat': 15,
              'carbs': 50,
            }
          }
        ],
        'Bữa trưa': [
          {
            'name': 'Bữa trưa mẫu',
            'description': 'Đây là dữ liệu mẫu khi không kết nối được với API.',
            'ingredients': [
              '100g cơm trắng',
              '100g thịt gà',
              'Rau xanh các loại',
            ],
            'nutrition': {
              'calories': 600,
              'protein': 40,
              'fat': 20,
              'carbs': 80,
            }
          }
        ],
        'Bữa tối': [
          {
            'name': 'Bữa tối mẫu',
            'description': 'Đây là dữ liệu mẫu khi không kết nối được với API.',
            'ingredients': [
              '80g mì ăn liền',
              '50g thịt bò',
              'Rau củ các loại',
            ],
            'nutrition': {
              'calories': 500,
              'protein': 30,
              'fat': 15,
              'carbs': 70,
            }
          }
        ],
      }
    };
  }
  
  // Tạo kế hoạch thực đơn cho cả tuần
  static Future<Map<String, dynamic>> legacyGenerateWeeklyMealPlan({
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    String userId = 'default',
    bool useAI = true,
  }) async {
    try {
      // Kiểm tra kết nối trước khi gọi API
      final isConnected = await checkApiConnection();
      if (!isConnected) {
        debugPrint('Không có kết nối API, sử dụng dữ liệu mẫu');
        return getMockMealPlan();
      }
      
      final url = '$baseUrl/generate-weekly-meal?user_id=$userId&use_ai=${useAI}';
      final body = {
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      debugPrint('Gọi API tạo kế hoạch tuần: $url');
      debugPrint('Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(apiTimeout);
      
      debugPrint('Kết quả API tạo kế hoạch tuần: ${response.statusCode}');
      if (kDebugMode) {
        debugPrint('Response body (truncated): ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('API trả về lỗi, sử dụng dữ liệu mẫu thay thế');
        return getMockMealPlan();
      }
    } catch (e) {
      debugPrint('Lỗi khi gọi API tạo kế hoạch thực đơn: $e');
      return getMockMealPlan();
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
      // Kiểm tra kết nối trước khi gọi API
      final isConnected = await checkApiConnection();
      if (!isConnected) {
        debugPrint('Không có kết nối API, sử dụng dữ liệu mẫu cho ngày');
        return getMockDayPlan(day);
      }
      
      final url = '$baseUrl/replace-day?user_id=$userId';
      final body = {
        'day': day,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      debugPrint('Gọi API thay thế kế hoạch ngày: $url');
      debugPrint('Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(apiTimeout);
      
      debugPrint('Kết quả API thay thế kế hoạch ngày: ${response.statusCode}');
      if (kDebugMode) {
        debugPrint('Response body (truncated): ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');
      }
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        debugPrint('API trả về lỗi, sử dụng dữ liệu mẫu thay thế cho ngày');
        return getMockDayPlan(day);
      }
    } catch (e) {
      debugPrint('Lỗi khi gọi API thay thế kế hoạch thực đơn ngày: $e');
      return getMockDayPlan(day);
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
  
  // Helper function to get a mock day plan for a specific day
  static Map<String, dynamic> getMockDayPlan(String day) {
    // Simulate API delay
    return _createMockDayPlan(day);
  }
  
  // Helper function to get minimum of two numbers
  static int min(int a, int b) {
    return a < b ? a : b;
  }
  
  // Tạo một bữa ăn đơn lẻ
  static Future<Map<String, dynamic>> generateSingleMeal({
    required String mealType,
    required double caloriesTarget,
    String userId = 'default',
  }) async {
    try {
      // Kiểm tra kết nối trước khi gọi API
      final isConnected = await checkApiConnection();
      if (!isConnected) {
        debugPrint('Không có kết nối API, sử dụng dữ liệu mẫu cho bữa ăn');
        return getMockMeal(mealType);
    }
    
      final url = '$baseUrl/generate-meal?user_id=$userId';
      final body = {
        'meal_type': mealType,
        'calories_target': caloriesTarget,
      };
      
      debugPrint('Gọi API tạo bữa ăn đơn: $url');
      debugPrint('Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(apiTimeout);
      
      debugPrint('Kết quả API tạo bữa ăn: ${response.statusCode}');
      if (kDebugMode) {
        debugPrint('Response body (truncated): ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('API trả về lỗi, sử dụng dữ liệu mẫu thay thế cho bữa ăn');
        return getMockMeal(mealType);
      }
    } catch (e) {
      debugPrint('Lỗi khi gọi API tạo bữa ăn: $e');
      return getMockMeal(mealType);
    }
  }
  
  // Helper để lấy mẫu cho một bữa ăn
  static Map<String, dynamic> getMockMeal(String mealType) {
    // Tạo bữa ăn mẫu dựa trên loại bữa
    final random = Random();
    final mealOptions = [
      {
        "name": "Cơm gà nướng",
        "description": "Cơm với gà nướng và rau xào",
        "ingredients": ["Gạo", "Thịt gà", "Rau củ", "Gia vị"],
        "nutrition": {
          "calories": random.nextInt(300) + 300.0,
          "protein": random.nextInt(20) + 20.0,
          "fat": random.nextInt(10) + 10.0,
          "carbs": random.nextInt(30) + 40.0
        }
      },
      {
        "name": "Salad cá hồi",
        "description": "Salad rau với cá hồi nướng",
        "ingredients": ["Rau xà lách", "Cá hồi", "Dầu ô liu", "Chanh"],
        "nutrition": {
          "calories": random.nextInt(200) + 250.0,
          "protein": random.nextInt(15) + 25.0,
          "fat": random.nextInt(15) + 15.0,
          "carbs": random.nextInt(15) + 10.0
        }
      },
      {
        "name": "Phở bò",
        "description": "Phở với thịt bò và rau thơm",
        "ingredients": ["Bánh phở", "Thịt bò", "Hành ngò", "Nước dùng"],
        "nutrition": {
          "calories": random.nextInt(300) + 400.0,
          "protein": random.nextInt(20) + 30.0,
          "fat": random.nextInt(10) + 10.0,
          "carbs": random.nextInt(20) + 60.0
        }
      }
    ];
    
    return mealOptions[random.nextInt(mealOptions.length)];
  }
} 