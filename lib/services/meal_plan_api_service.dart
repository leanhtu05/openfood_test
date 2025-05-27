import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/meal_plan.dart';
import '../utils/constants.dart';
import 'package:flutter/foundation.dart';
import '../utils/config.dart' as app_config;
import 'package:firebase_auth/firebase_auth.dart';

class MealPlanApiService {
  // URL cơ sở của API
  static String get baseUrl => app_config.apiBaseUrl;
  
  // Thời gian chờ tối đa cho các API request
  static const Duration apiTimeout = Duration(seconds: 15);
  
  // Phương thức kiểm tra kết nối với API
  static Future<bool> checkApiConnection() async {
    try {
      debugPrint('🔄 Đang kiểm tra kết nối API tại: $baseUrl');
      final response = await http.get(Uri.parse('$baseUrl/')).timeout(
        const Duration(seconds: 3), // Giảm timeout xuống 3 giây để nhanh hơn
        onTimeout: () {
          debugPrint('⏱️ Timeout khi kiểm tra kết nối API');
          return http.Response('Timeout', 408);
        },
      );
      
      // Ghi log kết quả
      final isConnected = response.statusCode == 200 || response.statusCode == 404;
      debugPrint('📊 Kết quả kiểm tra kết nối API: ${isConnected ? "✅ Kết nối thành công (${response.statusCode})" : "❌ Không kết nối được (${response.statusCode})"}');
      
      // Chấp nhận 200 OK hoặc 404 Not Found (server hoạt động nhưng không có route /)
      return isConnected;
    } catch (e) {
      // Xác định loại lỗi cụ thể để ghi log chi tiết hơn
      String errorType = "Không xác định";
      if (e.toString().contains('SocketException')) {
        errorType = "Lỗi Socket - Không thể kết nối đến máy chủ";
      } else if (e.toString().contains('HttpException')) {
        errorType = "Lỗi HTTP - Không tìm thấy máy chủ";
      } else if (e.toString().contains('FormatException')) {
        errorType = "Lỗi định dạng - Phản hồi không hợp lệ";
      } else if (e.toString().contains('Timeout')) {
        errorType = "Timeout - Máy chủ không phản hồi kịp thời";
      }
      
      debugPrint('❌ Lỗi kết nối API: $errorType - Chi tiết: $e');
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
  
  // Kiểm tra một endpoint cụ thể
  static Future<bool> checkEndpoint(String endpoint) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$endpoint')).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('Timeout', 408),
      );
      
      // Nếu server trả về 200 OK hoặc 404 Not Found, server vẫn hoạt động
      // Nếu là endpoint POST, có thể server sẽ trả về lỗi nếu gọi bằng GET
      return response.statusCode == 200 || 
             response.statusCode == 404 || 
             response.statusCode == 405; // Method Not Allowed cũng ok
    } catch (e) {
      print('Endpoint check error: $e');
      return false;
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
  
  // Tạo kế hoạch bữa ăn hàng tuần
  static Future<Map<String, dynamic>> generateWeeklyMealPlan({
    double? caloriesTarget = 2000.0,
    double? proteinTarget = 120.0,
    double? fatTarget = 65.0,
    double? carbsTarget = 250.0,
    bool useAI = true,
    String? userId,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
        'use_ai': useAI,
      };
      
      if (userId != null && userId.isNotEmpty) {
        requestData['user_id'] = userId;
      }
      
      debugPrint('Đang gửi yêu cầu tạo kế hoạch ăn...');
      final response = await http.post(
        Uri.parse('${baseUrl}${app_config.ApiEndpoints.generateMealPlan}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        debugPrint('Tạo kế hoạch ăn thành công!');
        return json.decode(response.body);
      } else {
        debugPrint('Lỗi khi tạo kế hoạch ăn: ${response.statusCode} ${response.body}');
        return getMockMealPlan();
      }
    } catch (e) {
      debugPrint('Exception khi tạo kế hoạch ăn: $e');
      return getMockMealPlan();
    }
  }
  
  // Thay thế kế hoạch cho một ngày
  static Future<Map<String, dynamic>> replaceDayMealPlan({
    required String day,
    double? caloriesTarget = 2000.0,
    double? proteinTarget = 120.0,
    double? fatTarget = 65.0,
    double? carbsTarget = 250.0,
    bool useAI = true,
    String? userId,
    List<String>? preferences,
    List<String>? allergies,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'day_of_week': day,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
        'use_ai': useAI,
      };
      
      if (userId != null) {
        requestData['user_id'] = userId;
      }
      
      if (preferences != null && preferences.isNotEmpty) {
        requestData['preferences'] = preferences;
      }
      
      if (allergies != null && allergies.isNotEmpty) {
        requestData['allergies'] = allergies;
      }
      
      final response = await http.post(
        Uri.parse('${baseUrl}${app_config.ApiEndpoints.replaceDay}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Lỗi khi thay thế bữa ăn: ${response.statusCode} ${response.body}');
        return _getMockDayMealPlan(day);
      }
    } catch (e) {
      debugPrint('Exception khi thay thế ngày: $e');
      return _getMockDayMealPlan(day);
    }
  }
  
  // Replace a specific meal in the meal plan
  static Future<Map<String, dynamic>> replaceMeal({
    required String day,
    required String mealType,
    double? caloriesTarget,
    double? proteinTarget,
    double? fatTarget,
    double? carbsTarget,
    bool useAI = true,
    String? userId,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'day_of_week': day,
        'meal_type': mealType,
        'use_ai': useAI,
      };

      if (caloriesTarget != null) requestData['calories_target'] = caloriesTarget;
      if (proteinTarget != null) requestData['protein_target'] = proteinTarget;
      if (fatTarget != null) requestData['fat_target'] = fatTarget;
      if (carbsTarget != null) requestData['carbs_target'] = carbsTarget;
      if (userId != null) requestData['user_id'] = userId;
      
      final response = await http.post(
        Uri.parse('${baseUrl}${app_config.ApiEndpoints.replaceMeal}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Lỗi khi thay thế bữa ăn: ${response.statusCode} ${response.body}');
        return _getMockMeal(mealType);
      }
    } catch (e) {
      debugPrint('Exception khi thay thế bữa ăn: $e');
      return _getMockMeal(mealType);
    }
  }
  
  // Lấy dữ liệu mẫu cho kế hoạch ăn
  static Future<Map<String, dynamic>> getMockMealPlan() async {
    try {
      // Đọc từ API mock data endpoint
      final response = await http.get(Uri.parse('${baseUrl}/generate-weekly-meal-demo'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Fallback to hardcoded data
        return _getHardcodedMockData();
      }
    } catch (e) {
      debugPrint('Lỗi khi lấy dữ liệu mẫu: $e');
      return _getHardcodedMockData();
    }
  }
  
  // Dữ liệu mẫu cho một ngày
  static Map<String, dynamic> _getMockDayMealPlan(String day) {
    // Trả về cấu trúc dữ liệu cho một ngày từ dữ liệu mẫu
    return {
      'day_of_week': day,
      'meals': {
        'Bữa sáng': [
          {
            'name': 'Bánh mì trứng',
            'description': 'Bánh mì kẹp trứng ốp la với rau xà lách và cà chua',
            'ingredients': [
              'Bánh mì', 'Trứng gà', 'Xà lách', 'Cà chua', 'Dầu ô liu'
            ],
            'nutrition': {
              'calories': 350,
              'protein': 15,
              'fat': 12,
              'carbs': 45,
            }
          }
        ],
        'Bữa trưa': [
          {
            'name': 'Cơm gà xối mỡ',
            'description': 'Cơm với gà chiên giòn phủ nước mắm chua ngọt',
            'ingredients': [
              'Cơm trắng', 'Đùi gà', 'Nước mắm', 'Đường', 'Tỏi', 'Ớt'
            ],
            'nutrition': {
              'calories': 650,
              'protein': 35,
              'fat': 20,
              'carbs': 75,
            }
          }
        ],
        'Bữa tối': [
          {
            'name': 'Canh cá nấu chua',
            'description': 'Canh chua ngọt với cá diêu hồng và rau thơm',
            'ingredients': [
              'Cá diêu hồng', 'Me chua', 'Đậu bắp', 'Cà chua', 'Thơm', 'Rau ngổ', 'Giá'
            ],
            'nutrition': {
              'calories': 400,
              'protein': 30,
              'fat': 10,
              'carbs': 35,
            }
          }
        ],
      },
      'nutrition_summary': {
        'calories': 1400,
        'protein': 80,
        'fat': 42,
        'carbs': 155,
      }
    };
  }

  // Dữ liệu mẫu cho một bữa ăn
  static Map<String, dynamic> _getMockMeal(String mealType) {
    String mealName;
    Map<String, dynamic> nutritionInfo;
    List<String> ingredients;
    String description;
    
    switch (mealType) {
      case 'Bữa sáng':
        mealName = 'Cháo trắng với trứng bắc thảo';
        description = 'Cháo trắng nấu mềm với trứng bắc thảo bổ dưỡng';
        ingredients = ['Gạo', 'Trứng bắc thảo', 'Hành lá', 'Tiêu', 'Nước mắm'];
        nutritionInfo = {
          'calories': 300,
          'protein': 12,
          'fat': 8,
          'carbs': 45,
        };
        break;
        
      case 'Bữa trưa':
        mealName = 'Bún bò Huế';
        description = 'Bún bò Huế cay thơm với giò heo và thịt bò';
        ingredients = ['Bún', 'Thịt bò', 'Giò heo', 'Mắm ruốc', 'Sả', 'Ớt', 'Rau thơm'];
        nutritionInfo = {
          'calories': 550,
          'protein': 30,
          'fat': 15,
          'carbs': 65,
        };
        break;
        
      case 'Bữa tối':
        mealName = 'Cá kho tộ';
        description = 'Cá kho tộ đậm đà với nước mắm và thịt ba chỉ';
        ingredients = ['Cá lóc', 'Thịt ba chỉ', 'Nước mắm', 'Đường', 'Tiêu', 'Ớt'];
        nutritionInfo = {
          'calories': 450,
          'protein': 35,
          'fat': 20,
          'carbs': 10,
        };
        break;
        
      default:
        mealName = 'Món ăn mẫu';
        description = 'Món ăn mẫu cho demo';
        ingredients = ['Thành phần 1', 'Thành phần 2', 'Thành phần 3'];
        nutritionInfo = {
          'calories': 400,
          'protein': 20,
          'fat': 15,
          'carbs': 40,
        };
    }
    
    return {
      'meal': {
        'name': mealName,
        'description': description,
        'ingredients': ingredients,
        'nutrition': nutritionInfo,
      }
    };
  }

  // Hardcoded mock data
  static Map<String, dynamic> _getHardcodedMockData() {
    return {
      'id': 'mock-meal-plan-001',
      'user_id': 'default-user',
      'created_at': DateTime.now().toIso8601String(),
      'weekly_plan': {
        'Monday': _getMockDayMealPlan('Thứ 2'),
        'Tuesday': _getMockDayMealPlan('Thứ 3'),
        'Wednesday': _getMockDayMealPlan('Thứ 4'),
        'Thursday': _getMockDayMealPlan('Thứ 5'),
        'Friday': _getMockDayMealPlan('Thứ 6'),
        'Saturday': _getMockDayMealPlan('Thứ 7'),
        'Sunday': _getMockDayMealPlan('Chủ Nhật'),
      },
      'nutrition_targets': {
        'calories_target': 2000,
        'protein_target': 120,
        'fat_target': 65,
        'carbs_target': 250,
      },
    };
  }
} 