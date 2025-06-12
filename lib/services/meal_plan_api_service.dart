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

      final response = await http.get(Uri.parse('$baseUrl/')).timeout(
        const Duration(seconds: 3), // Giảm timeout xuống 3 giây để nhanh hơn
        onTimeout: () {

          return http.Response('Timeout', 408);
        },
      );

      final isConnected = response.statusCode == 200 || response.statusCode == 404;

      // Chấp nhận 200 OK hoặc 404 Not Found (server hoạt động nhưng không có route /)
      return isConnected;
    } catch (e) {

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
      
      // Chuẩn bị URL với endpoint chính xác từ config
      final uri = Uri.parse('${baseUrl}${app_config.ApiEndpoints.generateMealPlan}')
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

        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {

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

        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {

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
    List<String>? preferences,
    List<String>? allergies,
    List<String>? dietRestrictions,
    List<String>? healthConditions,
    String? dietPreference,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'calories_target': caloriesTarget?.round() ?? 2000,
        'protein_target': proteinTarget?.round() ?? 120,
        'fat_target': fatTarget?.round() ?? 65,
        'carbs_target': carbsTarget?.round() ?? 250,
        'use_ai': useAI,
      };
      
      if (userId != null && userId.isNotEmpty) {
        requestData['user_id'] = userId;
      }
      
      if (preferences != null && preferences.isNotEmpty) {
        requestData['preferences'] = preferences;
      }
      
      if (allergies != null && allergies.isNotEmpty) {
        requestData['allergies'] = allergies;
      }
      
      if (dietRestrictions != null && dietRestrictions.isNotEmpty) {
        requestData['diet_restrictions'] = dietRestrictions;
      }
      
      if (healthConditions != null && healthConditions.isNotEmpty) {
        requestData['health_conditions'] = healthConditions;
      }
      
      if (dietPreference != null && dietPreference.isNotEmpty) {
        requestData['diet_preference'] = dietPreference;
      }

      final response = await http.post(
        Uri.parse('${baseUrl}${app_config.ApiEndpoints.generateMealPlan}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {

        return json.decode(response.body);
      } else {

        return getMockMealPlan();
      }
    } catch (e) {

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
    List<String>? dietRestrictions,
    List<String>? healthConditions,
    String? dietPreference,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'day_of_week': day,
        'calories_target': caloriesTarget?.round() ?? 2000,
        'protein_target': proteinTarget?.round() ?? 120,
        'fat_target': fatTarget?.round() ?? 65,
        'carbs_target': carbsTarget?.round() ?? 250,
        'use_ai': useAI,
      };
      
      if (userId != null && userId.isNotEmpty) {
        requestData['user_id'] = userId;
      }
      
      if (preferences != null && preferences.isNotEmpty) {
        requestData['preferences'] = preferences;
      }
      
      if (allergies != null && allergies.isNotEmpty) {
        requestData['allergies'] = allergies;
      }
      
      if (dietRestrictions != null && dietRestrictions.isNotEmpty) {
        requestData['diet_restrictions'] = dietRestrictions;
      }
      
      if (healthConditions != null && healthConditions.isNotEmpty) {
        requestData['health_conditions'] = healthConditions;
      }
      
      if (dietPreference != null && dietPreference.isNotEmpty) {
        requestData['diet_preference'] = dietPreference;
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

        return _getMockDayMealPlan(day);
      }
    } catch (e) {

      return _getMockDayMealPlan(day);
    }
  }
  
  // Replace a specific meal in the meal plan
  static Future<Map<String, dynamic>?> replaceMeal({
    required String day,
    required String mealType,
    double? caloriesTarget = 2000.0,
    double? proteinTarget = 120.0,
    double? fatTarget = 65.0,
    double? carbsTarget = 250.0,
    bool useAI = true,
    String? userId,
    List<String>? preferences,
    List<String>? allergies,
    List<String>? dietRestrictions,
    List<String>? healthConditions,
    String? dietPreference,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'day_of_week': day,
        'meal_type': mealType,
        'use_ai': useAI,
      };

      if (caloriesTarget != null) requestData['calories_target'] = caloriesTarget.round();
      if (proteinTarget != null) requestData['protein_target'] = proteinTarget.round();
      if (fatTarget != null) requestData['fat_target'] = fatTarget.round();
      if (carbsTarget != null) requestData['carbs_target'] = carbsTarget.round();
      if (userId != null && userId.isNotEmpty) requestData['user_id'] = userId;
      if (preferences != null && preferences.isNotEmpty) requestData['preferences'] = preferences;
      if (allergies != null && allergies.isNotEmpty) requestData['allergies'] = allergies;
      if (dietRestrictions != null && dietRestrictions.isNotEmpty) requestData['diet_restrictions'] = dietRestrictions;
      if (healthConditions != null && healthConditions.isNotEmpty) requestData['health_conditions'] = healthConditions;
      if (dietPreference != null && dietPreference.isNotEmpty) requestData['diet_preference'] = dietPreference;
      
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

        return null;
      }
    } catch (e) {

      return null;
    }
  }
  
  // Lấy dữ liệu mẫu cho kế hoạch ăn
  static Future<Map<String, dynamic>> getMockMealPlan() async {
    try {
      // Đọc từ API mock data endpoint
      final response = await http.get(Uri.parse('${baseUrl}/api/meal-plan/demo'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Fallback to hardcoded data
        return _getHardcodedMockData();
      }
    } catch (e) {

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
            },
            'dishes': [
              {
                'name': 'Bánh mì trứng ốp la',
                'description': 'Bánh mì giòn kẹp trứng ốp la thơm ngon với rau xà lách tươi',
                'nutrition': {
                  'calories': 350,
                  'protein': 15,
                  'fat': 12,
                  'carbs': 45,
                },
                'ingredients': [
                  'Bánh mì Việt Nam - 1 ổ',
                  'Trứng gà - 2 quả',
                  'Xà lách - 3 lá',
                  'Cà chua - 1/2 quả',
                  'Dầu ô liu - 1 thìa cà phê'
                ],
                'preparation': [
                  'Làm nóng chảo với một ít dầu ô liu',
                  'Đập trứng vào chảo, rắc một chút muối và tiêu',
                  'Chiên trứng ốp la vàng đều hai mặt',
                  'Cắt bánh mì dọc, nướng nhẹ cho giòn',
                  'Rửa sạch xà lách và cà chua, thái lát mỏng',
                  'Kẹp trứng ốp la, xà lách và cà chua vào bánh mì',
                  'Thưởng thức khi còn nóng'
                ],
                'prep_time_minutes': 10,
                'detailed_ingredients': [
                  {
                    'name': 'Bánh mì Việt Nam',
                    'amount': '1',
                    'unit': 'ổ',
                    'category': 'Thực phẩm khô'
                  },
                  {
                    'name': 'Trứng gà',
                    'amount': '2',
                    'unit': 'quả',
                    'category': 'Sản phẩm từ sữa'
                  },
                  {
                    'name': 'Xà lách',
                    'amount': '3',
                    'unit': 'lá',
                    'category': 'Rau củ'
                  }
                ]
              }
            ]
          }
        ],
        'Bữa trưa': [
          {
            'name': 'Bún riêu cua',
            'description': 'Bún riêu cua đậm đà với cà chua và đậu phụ',
            'ingredients': [
              'Bún tươi', 'Cua đồng', 'Cà chua', 'Đậu phụ', 'Tôm khô', 'Mắm tôm'
            ],
            'nutrition': {
              'calories': 650,
              'protein': 35,
              'fat': 20,
              'carbs': 75,
            },
            'dishes': [
              {
                'name': 'Bún riêu cua đồng',
                'description': 'Món bún riêu cua truyền thống với nước dùng đậm đà từ cua đồng',
                'nutrition': {
                  'calories': 650,
                  'protein': 35,
                  'fat': 20,
                  'carbs': 75,
                },
                'ingredients': [
                  'Bún tươi - 200g',
                  'Cua đồng - 300g',
                  'Cà chua - 2 quả',
                  'Đậu phụ - 100g',
                  'Tôm khô - 50g',
                  'Mắm tôm - 2 thìa canh'
                ],
                'preparation': [
                  'Rửa sạch cua đồng, giã nhuyễn lấy nước cua',
                  'Ngâm tôm khô cho mềm, sau đó giã nhuyễn',
                  'Thái cà chua múi cau, đậu phụ thái miếng vừa ăn',
                  'Đun nước sôi, cho tôm khô giã vào nấu 10 phút',
                  'Thêm cà chua vào nấu cho mềm, nêm mắm tôm vừa ăn',
                  'Cho nước cua vào, đun sôi rồi thêm đậu phụ',
                  'Trụng bún qua nước sôi, múc vào tô',
                  'Chan nước dùng nóng, rắc hành lá và ngò gai'
                ],
                'prep_time_minutes': 45,
                'video_url': 'https://example.com/bun-rieu-cua-recipe.mp4',
                'detailed_ingredients': [
                  {
                    'name': 'Bún tươi',
                    'amount': '200',
                    'unit': 'g',
                    'category': 'Thực phẩm khô'
                  },
                  {
                    'name': 'Cua đồng',
                    'amount': '300',
                    'unit': 'g',
                    'category': 'Thịt tươi sống'
                  },
                  {
                    'name': 'Cà chua',
                    'amount': '2',
                    'unit': 'quả',
                    'category': 'Rau củ'
                  },
                  {
                    'name': 'Đậu phụ',
                    'amount': '100',
                    'unit': 'g',
                    'category': 'Sản phẩm từ sữa'
                  }
                ]
              }
            ]
          }
        ],
        'Bữa tối': [
          {
            'name': 'Canh chua cá lóc',
            'description': 'Canh chua ngọt với cá lóc và rau thơm miền Tây',
            'ingredients': [
              'Cá lóc', 'Me chua', 'Đậu bắp', 'Cà chua', 'Thơm', 'Rau ngổ', 'Giá'
            ],
            'nutrition': {
              'calories': 400,
              'protein': 30,
              'fat': 10,
              'carbs': 35,
            },
            'dishes': [
              {
                'name': 'Canh chua cá lóc miền Tây',
                'description': 'Món canh chua truyền thống miền Tây với cá lóc tươi ngon',
                'nutrition': {
                  'calories': 400,
                  'protein': 30,
                  'fat': 10,
                  'carbs': 35,
                },
                'ingredients': [
                  'Cá lóc - 500g',
                  'Me chua - 2 thìa canh',
                  'Đậu bắp - 100g',
                  'Cà chua - 1 quả',
                  'Thơm - 1/4 quả',
                  'Rau ngổ - 50g',
                  'Giá đỗ - 100g'
                ],
                'preparation': [
                  'Rửa sạch cá lóc, cắt khúc vừa ăn, ướp với muối và tiêu',
                  'Thái cà chua múi cau, thơm thái lát mỏng',
                  'Cắt đậu bắp thành khúc 3cm, rau ngổ cắt khúc',
                  'Đun nước sôi, cho me chua vào nấu 5 phút',
                  'Thêm cà chua và thơm vào nấu cho mềm',
                  'Cho cá lóc vào nấu 10 phút cho chín',
                  'Thêm đậu bắp, nêm nếm vừa ăn',
                  'Cuối cùng cho rau ngổ và giá đỗ, tắt bếp',
                  'Rắc hành lá và ngò gai lên trên'
                ],
                'prep_time_minutes': 30,
                'health_benefits': [
                  'Cá lóc giàu protein, tốt cho cơ bắp',
                  'Me chua chứa vitamin C, tăng cường miễn dịch',
                  'Rau ngổ giúp tiêu hóa tốt'
                ],
                'detailed_ingredients': [
                  {
                    'name': 'Cá lóc',
                    'amount': '500',
                    'unit': 'g',
                    'category': 'Thịt tươi sống'
                  },
                  {
                    'name': 'Me chua',
                    'amount': '2',
                    'unit': 'thìa canh',
                    'category': 'Gia vị'
                  },
                  {
                    'name': 'Đậu bắp',
                    'amount': '100',
                    'unit': 'g',
                    'category': 'Rau củ'
                  },
                  {
                    'name': 'Cà chua',
                    'amount': '1',
                    'unit': 'quả',
                    'category': 'Rau củ'
                  }
                ]
              }
            ]
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
  
  // Ghi nhận một món ăn từ kế hoạch bữa ăn
  static Future<Map<String, dynamic>> logDishFromMealPlan({
    required String userId,
    required String dayOfWeek,
    required String mealType,
    required int dishIndex,
    String? token,
  }) async {
    try {
      // Chuẩn bị URL
      final uri = Uri.parse('${baseUrl}${app_config.ApiEndpoints.foodLog}/log-dish');
      
      // Chuẩn bị headers
      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      
      // Thêm token nếu có
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      } else if (FirebaseAuth.instance.currentUser != null) {
        // Lấy token từ Firebase nếu không được cung cấp
        try {
          final userToken = await FirebaseAuth.instance.currentUser?.getIdToken();
          if (userToken != null) {
            headers['Authorization'] = 'Bearer $userToken';
          }
        } catch (e) {

        }
      }
      
      // Chuẩn bị body
      final requestBody = json.encode({
        'user_id': userId,
        'day_of_week': dayOfWeek,
        'meal_type': mealType,
        'dish_index': dishIndex,
      });
      
      // Gửi request

      final response = await http.post(
        uri,
        headers: headers,
        body: requestBody,
      );
      
      if (response.statusCode == 200) {

        return json.decode(response.body);
      } else {

        return {'status': 'error', 'message': 'Không thể ghi nhận món ăn'};
      }
    } catch (e) {

      return {'status': 'error', 'message': 'Lỗi: $e'};
    }
  }

  static Future<bool> isApiReady() async {
    try {
      final response = await http.get(Uri.parse('${baseUrl}${app_config.ApiEndpoints.apiStatus}')).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          return http.Response('{"status": "timeout"}', 408);
        }
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['status'] == 'ok';
      }
      
      return false;
    } catch (e) {

      return false;
    }
  }
  
  // Kiểm tra trạng thái API với endpoint cụ thể
  static Future<bool> checkApiStatusWithEndpoint(String endpoint) async {
    try {
      final response = await http.get(Uri.parse('${baseUrl}${endpoint}')).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          return http.Response('{"status": "timeout"}', 408);
        }
      );
      
      if (response.statusCode == 200) {
        return true;
      }
      
      return false;
    } catch (e) {

      return false;
    }
  }
} 