import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:openfood/utils/config.dart';
import '../providers/user_data_provider.dart';
import '../models/food_entry.dart';
import '../models/meal_plan.dart';
import '../models/exercise.dart';
import '../models/water_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/config.dart' as AppConfig;
import '../utils/firebase_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class ApiService {
  // Cờ điều khiển việc sử dụng Firestore trực tiếp
  static bool get useDirectFirestore => AppConfig.useDirectFirestore;
  
  // Base URL for FastAPI server
  // When running on Android emulator, use 10.0.2.2 to connect to host's localhost
  // QUAN TRỌNG: Thay địa chỉ IP này bằng địa chỉ IPv4 của máy tính bạn
  // Kiểm tra địa chỉ IP bằng lệnh 'ipconfig' (Windows) hoặc 'ifconfig' (Mac/Linux)
  // KHÔNG sử dụng 'localhost' hoặc '127.0.0.1' vì thiết bị Android sẽ không kết nối được
  static String get baseUrl => AppConfig.apiBaseUrl;
  
  // URL cho các endpoint auth (không có /api)
  static String get authBaseUrl => AppConfig.apiBaseUrl;
  
  // API endpoints
  static String get userProfileUrl => '$baseUrl/api/user-profile';
  static String get mealPlanUrl => '$baseUrl/api/meal-plan';
  static String get foodLogUrl => '$baseUrl/api/food-log';
  static String get exerciseUrl => '$baseUrl/api/exercise';
  static String get waterLogUrl => '$baseUrl/api/water-log';
  static String get favoritesUrl => '$baseUrl/api/favorites';
  static String get generateMealEndpoint => '/api/meal-plan/generate';
  static String get firestoreUsersUrl => '$baseUrl/firestore/users';
  static String get syncUrl => '$baseUrl/api/sync';
  static String get firestoreMealPlansUrl => '$baseUrl/firestore/meal-plans';
  
  // Phương thức kiểm tra xem có nên sử dụng Firestore trực tiếp không
  static bool shouldUseDirectFirestore(String featureType) {
    // Sử dụng Firestore trực tiếp cho các chức năng CRUD đơn giản
    if (useDirectFirestore) {
      // Các chức năng CRUD đơn giản
      if (featureType == 'user_profile' || 
          featureType == 'food_entry' || 
          featureType == 'water_entry' || 
          featureType == 'exercise') {
        debugPrint('ℹ️ Sử dụng Firestore trực tiếp cho chức năng: $featureType');
        return true;
      }
    }
    
    // Các chức năng phức tạp vẫn sử dụng API
    debugPrint('ℹ️ Sử dụng API cho chức năng phức tạp: $featureType');
    return false;
  }
  
  // QUAN TRỌNG: Tất cả dữ liệu chỉ được gửi qua API, không gửi trực tiếp đến Firebase
  // Firebase chỉ được sử dụng để xác thực và lấy dữ liệu khi cần
  // Các phương thức dưới đây đảm bảo dữ liệu luôn được gửi qua API endpoints
  
  // Thời gian timeout mặc định
  static const Duration defaultTimeout = Duration(seconds: 10);
  
  // Phương thức để lấy auth headers với Firebase ID Token
  static Future<Map<String, String>> getAuthHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Thêm delay nhỏ để đảm bảo thời gian trên token được cập nhật đúng
        await Future.delayed(Duration(milliseconds: 100));
        final token = await user.getIdToken(true); // force refresh
        headers['Authorization'] = 'Bearer $token';
        debugPrint('✅ Đính kèm Firebase ID Token vào request');
      } else {
        // Thử lấy token từ SharedPreferences nếu không có user đăng nhập
        try {
          final prefs = await SharedPreferences.getInstance();
          final apiToken = prefs.getString('api_token');
          if (apiToken != null) {
            headers['Authorization'] = 'Bearer $apiToken';
            debugPrint('✅ Đính kèm API Token từ SharedPreferences vào request');
          } else {
            debugPrint('⚠️ Không có người dùng đăng nhập, không thể lấy token');
          }
        } catch (e) {
          debugPrint('❌ Lỗi khi lấy token từ SharedPreferences: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy Firebase ID Token: $e');
      // Thử lấy token từ SharedPreferences nếu có lỗi
      try {
        final prefs = await SharedPreferences.getInstance();
        final apiToken = prefs.getString('api_token');
        if (apiToken != null) {
          headers['Authorization'] = 'Bearer $apiToken';
          debugPrint('✅ Đính kèm API Token từ SharedPreferences vào request (fallback)');
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi lấy token từ SharedPreferences (fallback): $e');
      }
    }
    
    return headers;
  }
  
  // Kiểm tra kết nối với API
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${authBaseUrl}${ApiEndpoints.apiStatus}'),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Lỗi kết nối API: $e');
      return false;
    }
  }
  
  // Kiểm tra kết nối với API và trả về thông tin chi tiết
  static Future<Map<String, dynamic>> checkApiConnectionDetailed() async {
    try {
      debugPrint('🔍 Đang kiểm tra kết nối API tại: ${authBaseUrl}${ApiEndpoints.apiStatus}');
      
      final response = await http.get(
        Uri.parse('${authBaseUrl}${AppConfig.ApiEndpoints.apiStatus}'),
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ Timeout: API không phản hồi sau 5 giây');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      debugPrint('📊 Trạng thái API: ${response.statusCode}');
      // Không in nội dung phản hồi để tránh hiển thị dữ liệu
      
      if (response.statusCode == 200) {
        debugPrint('✅ Kết nối API thành công');
        return {
          'success': true,
          'status_code': response.statusCode,
          'message': 'Kết nối API thành công'
        };
      } else {
        debugPrint('❌ Kết nối API thất bại: ${response.statusCode}');
        return {
          'success': false,
          'status_code': response.statusCode,
          'message': 'Kết nối API thất bại'
        };
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra kết nối API: $e');
      return {
        'success': false,
        'status_code': null,
        'message': 'Lỗi kết nối: $e'
      };
    }
  }
  
  // Kiểm tra tình trạng AI
  static Future<Map<String, dynamic>> checkAIStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${authBaseUrl}${ApiEndpoints.checkAI}'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'ai_available': false, 'error': 'Không thể kết nối với AI'};
    } catch (e) {
      print('Lỗi khi kiểm tra AI: $e');
      return {'ai_available': false, 'error': 'Lỗi kết nối: $e'};
    }
  }
  
  // Thông báo đã đọc dữ liệu
  static Future<void> notifyDataRead(String dataType, String userId) async {
    // Không gọi API không tồn tại nữa
    debugPrint('📖 Đã đọc dữ liệu: $dataType cho người dùng: $userId');
    // Endpoint /api/data-read-notification không tồn tại trong backend
    // nên chỉ ghi log mà không gọi API
  }
  
  // USER PROFILE METHODS
  
  // Send user profile data to FastAPI
  static Future<bool> sendUserProfile(UserDataProvider userData) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse(userProfileUrl),
        headers: headers,
        body: jsonEncode({
          'user_id': userData.userId ?? 'anonymous',
          'gender': userData.gender,
          'age': userData.age,
          'height_cm': userData.heightCm,
          'weight_kg': userData.weightKg,
          'activity_level': userData.activityLevel,
          'goal': userData.goal,
          'pace': userData.pace,
          'nutrition_goals': userData.nutritionGoals,
          'target_weight_kg': userData.targetWeightKg,
          'event': userData.event,
          'event_date': {
            'day': userData.eventDay,
            'month': userData.eventMonth,
            'year': userData.eventYear,
          },
          'diet_restrictions': userData.dietRestrictions,
          'diet_preference': userData.dietPreference,
          'health_conditions': userData.healthConditions,
          'tdee': {
            'calories': userData.tdeeCalories,
            'protein': userData.tdeeProtein,
            'carbs': userData.tdeeCarbs,
            'fat': userData.tdeeFat,
          },
        }),
      );
      
      debugPrint('API Response: ${response.statusCode} - ${response.body}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending data to API: $e');
      return false;
    }
  }
  
  // Send user profile data (direct JSON)
  static Future<bool> sendUserProfileData(Map<String, dynamic> userData) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse(userProfileUrl),
        headers: headers,
        body: jsonEncode(userData),
      );
      
      debugPrint('API Response: ${response.statusCode} - ${response.body}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending user profile data to API: $e');
      return false;
    }
  }
  

  // Gửi thông tin người dùng đầy đủ đến endpoint /firestore/users/{user_id}
  static Future<bool> sendUserProfileToFirestore(String userId, Map<String, dynamic> userData) async {
    try {
      // Đảm bảo có đầy đủ các trường dữ liệu quan trọng
      if (!userData.containsKey('updated_at')) {
        userData['updated_at'] = DateTime.now().toIso8601String();
      }

      // Xử lý dữ liệu thời gian trước khi gửi - đảm bảo tất cả Timestamp được chuyển thành chuỗi
      final preparedData = FirebaseHelpers.prepareAnyDataForJson(userData);

      // Thêm header cho authorization nếu có
      final headers = await getAuthHeaders();
      
      debugPrint('🔄 Đang gửi dữ liệu người dùng lên API...');
      
      final response = await http.post(
        Uri.parse('$firestoreUsersUrl/$userId'),
        headers: headers,
        body: jsonEncode(preparedData),
      );
      
      debugPrint('API Response (sendUserProfileToFirestore): ${response.statusCode} - ${response.body}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending user profile to Firestore API: $e');
      return false;
    }
  }
  
  // Gửi thông tin người dùng đầy đủ đến endpoint /firestore/users/sync
  static Future<bool> syncUserProfileToFirestore(String userId, Map<String, dynamic> userData) async {
    try {
      // Đảm bảo có đầy đủ các trường dữ liệu quan trọng
      if (!userData.containsKey('updated_at')) {
        userData['updated_at'] = DateTime.now().toIso8601String();
      }
      
      // Xử lý dữ liệu thời gian trước khi gửi - đảm bảo tất cả Timestamp được chuyển thành chuỗi
      final preparedData = FirebaseHelpers.prepareAnyDataForJson(userData);
      
      // Thêm header cho authorization nếu có
      final headers = await getAuthHeaders();
      
      debugPrint('🔄 Đang đồng bộ dữ liệu người dùng lên API...');
      
      final response = await http.post(
        Uri.parse('$syncUrl?user_id=$userId'),
        headers: headers,
        body: jsonEncode(preparedData),
      );
      
      debugPrint('API Response (syncUserProfileToFirestore): ${response.statusCode} - ${response.body}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error syncing user profile to Firestore API: $e');
      return false;
    }
  }
  
  // Phương thức mới để đồng bộ toàn bộ dữ liệu người dùng lên backend
  static Future<bool> syncFullUserData(String userId, Map<String, dynamic> userData) async {
    int retryCount = 0;
    final maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // Tăng thời gian chờ giữa các lần retry
        if (retryCount > 0) {
          debugPrint('🔄 Thử lại đồng bộ dữ liệu lần ${retryCount + 1} sau ${retryCount}s');
          await Future.delayed(Duration(seconds: retryCount));
        }
        
        // Đảm bảo có đầy đủ các trường dữ liệu quan trọng
        Map<String, dynamic> fullData = {
          ...userData,
          'user_id': userId,
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        // Thêm trường name nếu chưa có
        if (!fullData.containsKey('name')) {
          fullData['name'] = fullData['display_name'] ?? fullData['email'] ?? 'Người dùng';
        }
        
        // Xử lý dữ liệu thời gian trước khi gửi - đảm bảo tất cả Timestamp được chuyển thành chuỗi
        final preparedData = FirebaseHelpers.prepareAnyDataForJson(fullData);
        
        // Thêm header cho authorization nếu có
        final headers = await getAuthHeaders();
        
        debugPrint('🔄 Đang đồng bộ dữ liệu người dùng lên API...');
        
        // Sử dụng endpoint /firestore/users/{userId} với phương thức PATCH
        final response = await http.patch(
          Uri.parse('$baseUrl/firestore/users/$userId'),
          headers: headers,
          body: jsonEncode(preparedData),
        ).timeout(
          Duration(seconds: 15), // Tăng timeout lên 15 giây
          onTimeout: () {
            debugPrint('⏱️ Timeout khi đồng bộ dữ liệu');
            return http.Response('{"error": "Timeout"}', 408);
          },
        );
        
        debugPrint('API Response (syncFullUserData): ${response.statusCode} - ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Kiểm tra dữ liệu trả về
          try {
            final responseData = json.decode(response.body);
            
            // Xử lý phản hồi bằng helper
            final safeResponse = FirebaseHelpers.safeHandleApiResponse(responseData);
            
            // Kiểm tra xem có lỗi không
            if (safeResponse.containsKey('error')) {
              debugPrint('❌ Lỗi khi đồng bộ dữ liệu: ${safeResponse['error']}');
              
              // Nếu là lỗi timeout, thử lại
              if (safeResponse['error'].toString().contains('Timeout')) {
                retryCount++;
                continue;
              }
              
              return false;
            }
            
            debugPrint('✅ Đồng bộ đầy đủ dữ liệu người dùng thành công');
            return true;
          } catch (e) {
            debugPrint('⚠️ Không thể phân tích phản hồi API: $e');
            // Vẫn coi là thành công nếu status code phù hợp
            debugPrint('✅ Đồng bộ đầy đủ dữ liệu người dùng thành công (không phân tích được phản hồi)');
            return true;
          }
        } else if (response.statusCode == 408) {
          // Timeout, thử lại
          debugPrint('⏱️ Timeout từ server, thử lại lần ${retryCount + 1}');
          retryCount++;
          continue;
        } else if (response.statusCode == 401) {
          // Lỗi xác thực
          debugPrint('❌ Lỗi xác thực: Không có quyền đồng bộ dữ liệu');
          return false;
        } else if (response.statusCode == 404) {
          // Không tìm thấy tài nguyên
          debugPrint('❌ Không tìm thấy tài nguyên: ${response.body}');
          return false;
        } else {
          // Các lỗi khác
          try {
            final errorData = json.decode(response.body);
            debugPrint('❌ Đồng bộ dữ liệu thất bại: ${errorData['detail'] ?? response.body}');
          } catch (e) {
            debugPrint('❌ Đồng bộ dữ liệu thất bại: ${response.body}');
          }
          
          // Thử lại nếu không phải lỗi nghiêm trọng
          if (response.statusCode >= 500) {
            retryCount++;
            continue;
          }
          
          return false;
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi đồng bộ đầy đủ dữ liệu người dùng: $e');
        retryCount++;
        
        // Nếu đã thử hết số lần cho phép
        if (retryCount >= maxRetries) {
          return false;
        }
      }
    }
    
    // Nếu đã thử hết số lần và vẫn không thành công
    debugPrint('⚠️ Đã thử đồng bộ dữ liệu ${maxRetries} lần nhưng không thành công');
    return false;
  }
  
  // MEAL PLAN METHODS
  
  // Gửi kế hoạch ăn lên API
  static Future<bool> sendMealPlan(Map<String, dynamic> mealPlanData) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}${ApiEndpoints.mealPlan}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(mealPlanData),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Lỗi khi gửi kế hoạch ăn: $e');
      return false;
    }
  }
  
  // Get meal plan from FastAPI
  @Deprecated("Nên sử dụng FirestoreService.getWeeklyMealPlan() để đọc trực tiếp từ Firebase")
  static Future<Map<String, dynamic>?> getMealPlan(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$mealPlanUrl/$userId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting meal plan from API: $e');
      return null;
    }
  }
  
  // Thay thế bữa ăn
  static Future<Map<String, dynamic>?> replaceMeal(Map<String, dynamic> mealData) async {
    try {
      final headers = await getAuthHeaders();
      
      // Sử dụng phương thức POST với body JSON
      final replaceUrl = Uri.parse('$baseUrl${ApiEndpoints.replaceMeal}');
      
      debugPrint('🔄 Đang thay thế bữa ăn từ API: $replaceUrl');
      final response = await http.post(
        replaceUrl,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(mealData),
      ).timeout(
        Duration(seconds: 60),  // Tăng timeout lên 60 giây
        onTimeout: () {
          debugPrint('⏱️ Timeout khi thay thế bữa ăn');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đã thay thế bữa ăn thành công');
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // Trả về lỗi 404 để caller có thể xử lý
        debugPrint('⚠️ Không tìm thấy kế hoạch ăn: ${response.statusCode} - ${response.body}');
        return {'error': 'not_found', 'status': 404, 'message': 'Không tìm thấy kế hoạch ăn'};
      } else if (response.statusCode == 500) {
        // Trả về lỗi 500 để caller có thể xử lý
        debugPrint('❌ Lỗi server: ${response.statusCode} - ${response.body}');
        
        // Phân tích lỗi nếu có thể
        String errorMessage = 'Lỗi server';
        try {
          final errorData = json.decode(response.body);
          if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];
          }
        } catch (e) {
          debugPrint('Không thể phân tích lỗi server: $e');
        }
        
        return {
          'error': 'server_error', 
          'status': 500, 
          'message': errorMessage
        };
      } else {
        debugPrint('❌ Lỗi khi thay thế bữa ăn: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API thay thế bữa ăn: $e');
      return null;
    }
  }
  
  // Thay thế một ngày trong kế hoạch
  static Future<Map<String, dynamic>?> replaceDay(Map<String, dynamic> dayData) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}${ApiEndpoints.replaceDay}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(dayData),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Lỗi khi thay thế ngày: $e');
      return null;
    }
  }
  
  // FOOD LOG METHODS
  
  // Send food entry to FastAPI
  static Future<bool> sendFoodEntry(FoodEntry entry, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('food_entry')) {
        debugPrint('🔄 Đang lưu mục nhập thực phẩm trực tiếp vào Firestore...');
        
        try {
          // Chuẩn bị dữ liệu để lưu vào Firestore
          final entryData = entry.toJson();
          entryData['user_id'] = userId;
          entryData['created_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          entryData['updated_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          
          // Lưu vào Firestore
          await FirebaseFirestore.instance
              .collection('food_entries')
              .doc(entry.id)
              .set(entryData);
          
          debugPrint('✅ Đã lưu mục nhập thực phẩm trực tiếp vào Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi lưu mục nhập thực phẩm vào Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang gửi mục nhập thực phẩm đến API...');
        final headers = await getAuthHeaders();
        final response = await http.post(
          Uri.parse(foodLogUrl),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'entry': entry.toJson(),
          }),
        );
        
        return response.statusCode == 200 || response.statusCode == 201;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi mục nhập thực phẩm: $e');
      return false;
    }
  }
  
  // Get food logs by date from FastAPI
  static Future<List<FoodEntry>?> getFoodEntriesByDate(String userId, String date) async {
    try {
      // Sử dụng Firestore trực tiếp
      if (shouldUseDirectFirestore('food_entry')) {
        debugPrint('🔄 Đang lấy mục nhập thực phẩm trực tiếp từ Firestore...');
        
        try {
          // Truy vấn Firestore chỉ với điều kiện user_id để tránh yêu cầu index phức tạp
          final querySnapshot = await FirebaseFirestore.instance
              .collection('food_entries')
              .where('user_id', isEqualTo: userId)
              .get();
          
          // Lọc kết quả theo ngày ở phía client
          final List<FoodEntry> entries = querySnapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  return FoodEntry.fromJson(data);
                } catch (e) {
                  debugPrint('⚠️ Lỗi khi chuyển đổi dữ liệu: $e');
                  return null;
                }
              })
              .where((entry) => entry != null && entry.dateTime.toIso8601String().split('T')[0] == date)
              .cast<FoodEntry>()
              .toList();
          
          debugPrint('✅ Đã lấy ${entries.length} mục nhập thực phẩm từ Firestore thành công cho ngày $date');
          return entries;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi lấy mục nhập thực phẩm từ Firestore: $firestoreError');
          return [];
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang lấy mục nhập thực phẩm từ API...');
        final headers = await getAuthHeaders();
        final response = await http.get(
          Uri.parse('$foodLogUrl/$userId/$date'),
          headers: headers,
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((item) => FoodEntry.fromJson(item)).toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy mục nhập thực phẩm: $e');
      return [];
    }
  }
  
  // Delete food entry
  static Future<bool> deleteFoodEntry(String entryId, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('food_entry')) {
        debugPrint('🔄 Đang xóa mục nhập thực phẩm trực tiếp từ Firestore...');
        
        try {
          // Xóa mục nhập thực phẩm từ Firestore
          await FirebaseFirestore.instance
              .collection('food_entries')
              .doc(entryId)
              .delete();
          
          debugPrint('✅ Đã xóa mục nhập thực phẩm từ Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi xóa mục nhập thực phẩm từ Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang xóa mục nhập thực phẩm qua API...');
        final headers = await getAuthHeaders();
        final response = await http.delete(
          Uri.parse('$foodLogUrl/$userId/$entryId'),
          headers: headers,
        );
        
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa mục nhập thực phẩm: $e');
      return false;
    }
  }
  
  // Update food entry
  static Future<bool> updateFoodEntry(FoodEntry entry, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('food_entry')) {
        debugPrint('🔄 Đang cập nhật mục nhập thực phẩm trực tiếp vào Firestore...');
        
        try {
          // Chuẩn bị dữ liệu để cập nhật vào Firestore
          final entryData = entry.toJson();
          entryData['user_id'] = userId;
          entryData['updated_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          
          // Cập nhật vào Firestore
          await FirebaseFirestore.instance
              .collection('food_entries')
              .doc(entry.id)
              .update(entryData);
          
          debugPrint('✅ Đã cập nhật mục nhập thực phẩm trực tiếp vào Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi cập nhật mục nhập thực phẩm vào Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang cập nhật mục nhập thực phẩm qua API...');
        final headers = await getAuthHeaders();
        final response = await http.put(
          Uri.parse('$foodLogUrl/$userId/${entry.id}'),
          headers: headers,
          body: jsonEncode({
            'entry': entry.toJson(),
          }),
        );
        
        return response.statusCode == 200;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật mục nhập thực phẩm: $e');
      return false;
    }
  }
  // Get all exercises
  static Future<Map<String, List<Exercise>>?> getAllExercises(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$exerciseUrl/$userId/all'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, List<Exercise>> result = {};
        
        data.forEach((date, exercises) {
          result[date] = (exercises as List)
              .map((e) => Exercise.fromJson(e))
              .toList();
        });
        
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting all exercises from API: $e');
      return null;
    }
  }
  
  // Send exercise data to API
  static Future<bool> sendExercise(Exercise exercise, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('exercise')) {
        debugPrint('🔄 Đang lưu bài tập trực tiếp vào Firestore...');
        
        try {
          // Chuẩn bị dữ liệu để lưu vào Firestore
          final exerciseData = exercise.toJson();
          exerciseData['user_id'] = userId;
          exerciseData['created_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          exerciseData['updated_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          
          // Lưu vào Firestore
          await FirebaseFirestore.instance
              .collection('exercises')
              .doc(exercise.id)
              .set(exerciseData);
          
          debugPrint('✅ Đã lưu bài tập trực tiếp vào Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi lưu bài tập vào Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang gửi bài tập đến API...');
        final headers = await getAuthHeaders();
        final response = await http.post(
          Uri.parse(exerciseUrl),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'exercise_data': exercise.toJson(),
          }),
        );
        
        debugPrint('API Response (sendExercise): ${response.statusCode} - ${response.body}');
        
        return response.statusCode == 200 || response.statusCode == 201;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi bài tập: $e');
      return false;
    }
  }
  
  // Update exercise data
  static Future<bool> updateExercise(Exercise exercise, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('exercise')) {
        debugPrint('🔄 Đang cập nhật bài tập trực tiếp vào Firestore...');
        
        try {
          // Chuẩn bị dữ liệu để cập nhật vào Firestore
          final exerciseData = exercise.toJson();
          exerciseData['user_id'] = userId;
          exerciseData['updated_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          
          // Cập nhật vào Firestore
          await FirebaseFirestore.instance
              .collection('exercises')
              .doc(exercise.id)
              .update(exerciseData);
          
          debugPrint('✅ Đã cập nhật bài tập trực tiếp vào Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi cập nhật bài tập vào Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang cập nhật bài tập qua API...');
        final headers = await getAuthHeaders();
        final response = await http.put(
          Uri.parse('$exerciseUrl/${exercise.id}'),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'exercise_data': exercise.toJson(),
          }),
        );
        
        debugPrint('API Response (updateExercise): ${response.statusCode} - ${response.body}');
        
        return response.statusCode == 200;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật bài tập: $e');
      return false;
    }
  }
  
  // Delete exercise
  static Future<bool> deleteExercise(String exerciseId, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('exercise')) {
        debugPrint('🔄 Đang xóa bài tập trực tiếp từ Firestore...');
        
        try {
          // Xóa bài tập từ Firestore
          await FirebaseFirestore.instance
              .collection('exercises')
              .doc(exerciseId)
              .delete();
          
          debugPrint('✅ Đã xóa bài tập từ Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi xóa bài tập từ Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang xóa bài tập qua API...');
        final headers = await getAuthHeaders();
        final response = await http.delete(
          Uri.parse('$exerciseUrl/$exerciseId'),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
          }),
        );
        
        debugPrint('API Response (deleteExercise): ${response.statusCode} - ${response.body}');
        
        return response.statusCode == 200;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa bài tập: $e');
      return false;
    }
  }
  
  // Get exercises for a specific date
  static Future<List<Exercise>?> getExercisesByDate(String userId, String date) async {
    try {
      // Sử dụng Firestore trực tiếp
      if (shouldUseDirectFirestore('exercise')) {
        debugPrint('🔄 Đang lấy bài tập trực tiếp từ Firestore...');
        
        try {
          // Truy vấn Firestore chỉ với điều kiện user_id để tránh yêu cầu index phức tạp
          final querySnapshot = await FirebaseFirestore.instance
              .collection('exercises')
              .where('user_id', isEqualTo: userId)
              .get();
          
          // Lọc kết quả theo ngày ở phía client
          final List<Exercise> exercises = [];
          
          for (var doc in querySnapshot.docs) {
            try {
              final data = doc.data();
              
              // Xử lý các trường hợp khác nhau của dữ liệu
              Exercise? exercise;
              
              if (data.containsKey('exercise_data')) {
                // Trường hợp dữ liệu từ API
                exercise = Exercise.fromJson(data['exercise_data']);
              } else {
                // Trường hợp dữ liệu lưu trực tiếp
                exercise = Exercise.fromJson(data);
              }
              
              // Kiểm tra ngày
              if (exercise.date == date) {
                exercises.add(exercise);
              }
            } catch (e) {
              debugPrint('⚠️ Lỗi khi chuyển đổi dữ liệu bài tập: $e');
            }
          }
          
          debugPrint('✅ Đã lấy ${exercises.length} bài tập từ Firestore thành công cho ngày $date');
          return exercises;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi lấy bài tập từ Firestore: $firestoreError');
          return [];
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang lấy bài tập từ API...');
        final headers = await getAuthHeaders();
        final response = await http.get(
          Uri.parse('$exerciseUrl/$userId/date/$date'),
          headers: headers,
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => Exercise.fromJson(json)).toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy bài tập: $e');
      return [];
    }
  }
  
  // Get all water entries
  static Future<List<WaterEntry>?> getAllWaterEntries(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$waterLogUrl/$userId/all'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WaterEntry.fromMap(json)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting all water entries from API: $e');
      return null;
    }
  }
  
  // Send water entry to API
  static Future<bool> sendWaterEntry(WaterEntry entry, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('water_entry')) {
        debugPrint('🔄 Đang lưu mục nhập nước uống trực tiếp vào Firestore...');
        
        try {
          // Chuẩn bị dữ liệu để lưu vào Firestore
          final waterData = entry.toMap();
          waterData['user_id'] = userId;
          waterData['created_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          waterData['updated_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          
          // Lưu vào Firestore
          await FirebaseFirestore.instance
              .collection('water_entries')
              .doc(entry.id)
              .set(waterData);
          
          debugPrint('✅ Đã lưu mục nhập nước uống trực tiếp vào Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi lưu mục nhập nước uống vào Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang gửi mục nhập nước uống đến API...');
        final headers = await getAuthHeaders();
        final response = await http.post(
          Uri.parse(waterLogUrl),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'water_data': entry.toMap(),
          }),
        );
        
        debugPrint('API Response (sendWaterEntry): ${response.statusCode} - ${response.body}');
        
        return response.statusCode == 200 || response.statusCode == 201;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi mục nhập nước uống: $e');
      return false;
    }
  }
  
  // Delete water entry
  static Future<bool> deleteWaterEntry(String entryId, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('water_entry')) {
        debugPrint('🔄 Đang xóa mục nhập nước uống trực tiếp từ Firestore...');
        
        try {
          // Xóa mục nhập nước uống từ Firestore
          await FirebaseFirestore.instance
              .collection('water_entries')
              .doc(entryId)
              .delete();
          
          debugPrint('✅ Đã xóa mục nhập nước uống từ Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi xóa mục nhập nước uống từ Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang xóa mục nhập nước uống qua API...');
        final headers = await getAuthHeaders();
        final response = await http.delete(
          Uri.parse('$waterLogUrl/$entryId'),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
          }),
        );
        
        debugPrint('API Response (deleteWaterEntry): ${response.statusCode} - ${response.body}');
        
        return response.statusCode == 200;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa mục nhập nước uống: $e');
      return false;
    }
  }
  
  // Clear all water entries
  static Future<bool> clearAllWaterEntries(String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('water_entry')) {
        debugPrint('🔄 Đang xóa tất cả mục nhập nước uống trực tiếp từ Firestore...');
        
        try {
          // Lấy tất cả mục nhập nước uống của người dùng
          final querySnapshot = await FirebaseFirestore.instance
              .collection('water_entries')
              .where('user_id', isEqualTo: userId)
              .get();
          
          // Xóa từng mục nhập
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in querySnapshot.docs) {
            batch.delete(doc.reference);
          }
          
          // Thực hiện xóa hàng loạt
          await batch.commit();
          
          debugPrint('✅ Đã xóa ${querySnapshot.docs.length} mục nhập nước uống từ Firestore thành công');
          return true;
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi xóa tất cả mục nhập nước uống từ Firestore: $firestoreError');
          return false;
        }
      } else {
        // Sử dụng API
        debugPrint('🔄 Đang xóa tất cả mục nhập nước uống qua API...');
        final headers = await getAuthHeaders();
        final response = await http.delete(
          Uri.parse('$waterLogUrl/$userId/all'),
          headers: headers,
        );
        
        debugPrint('API Response (clearAllWaterEntries): ${response.statusCode} - ${response.body}');
        
        return response.statusCode == 200;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa tất cả mục nhập nước uống: $e');
      return false;
    }
  }
  
  // FAVORITES METHODS
  
  // Add to favorites
  static Future<bool> addToFavorites(Map<String, dynamic> favoriteData) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse(favoritesUrl),
        headers: headers,
        body: jsonEncode(favoriteData),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding to favorites via API: $e');
      return false;
    }
  }
  
  // Get favorites
  static Future<List<Map<String, dynamic>>?> getFavorites(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$favoritesUrl/$userId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting favorites from API: $e');
      return null;
    }
  }
  
  // Remove from favorites
  static Future<bool> removeFromFavorites(String favoriteId, String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$favoritesUrl/$userId/$favoriteId'),
        headers: headers,
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error removing from favorites via API: $e');
      return false;
    }
  }
  
  // AUTH METHODS
  
  // Đăng nhập và trả về user data
  static Future<Map<String, dynamic>?> login(String idToken) async {
    try {
      // Thêm delay nhỏ để đảm bảo thời gian đồng bộ
      await Future.delayed(Duration(milliseconds: 200));
      
      // Remove /api from the URL since auth endpoints are at the root level
      final response = await http.post(
        Uri.parse('$authBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      ).timeout(
        Duration(seconds: 3), // Giảm thời gian timeout xuống 3 giây
        onTimeout: () {
          debugPrint('⚠️ Login API timeout - có thể server đang bận');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      debugPrint('Login API Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đăng nhập API thành công');
        try {
          final responseData = json.decode(response.body);
          // Xử lý phản hồi bằng helper
          return FirebaseHelpers.safeHandleApiResponse(responseData);
        } catch (e) {
          debugPrint('⚠️ Không thể phân tích phản hồi API login: $e');
          // Trả về một đối tượng đơn giản
          return {'success': true, 'parse_error': e.toString()};
        }
      }
      
      debugPrint('⚠️ Đăng nhập API thất bại với mã ${response.statusCode}');
      
      // Xử lý lỗi cụ thể
      if (response.statusCode == 401) {
        return {'error': 'Không có quyền truy cập. Token không hợp lệ hoặc hết hạn'};
      } else if (response.statusCode == 404) {
        return {'error': 'Endpoint không tồn tại. Kiểm tra cấu hình API'};
      } else {
        try {
          final errorData = json.decode(response.body);
          return {'error': errorData['detail'] ?? 'Lỗi không xác định'};
        } catch (e) {
          return {'error': 'Lỗi không xác định (${response.statusCode})'};
        }
      }
    } catch (e) {
      debugPrint('❌ Error logging in via API: $e');
      return {'error': 'Lỗi kết nối: ${e.toString()}'};
    }
  }
  
  // Lấy thông tin người dùng hiện tại từ API
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    int retryCount = 0;
    final maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // Tăng thời gian chờ giữa các lần retry
        if (retryCount > 0) {
          debugPrint('🔄 Thử lại lấy thông tin người dùng lần ${retryCount + 1} sau ${retryCount}s');
          await Future.delayed(Duration(seconds: retryCount));
        }
        
        final headers = await getAuthHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/me'),
          headers: headers,
        ).timeout(
          Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⏱️ Get user API timeout - có thể server đang bận');
            return http.Response('{"error": "Timeout"}', 408);
          },
        );
        
        debugPrint('Get Current User API Response: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          debugPrint('✅ Lấy thông tin người dùng thành công');
          
          try {
            final responseData = json.decode(response.body);
            
            // Sử dụng helper để xử lý mọi định dạng phản hồi
            return FirebaseHelpers.safeHandleApiResponse(responseData);
          } catch (e) {
            debugPrint('❌ Lỗi khi phân tích dữ liệu: $e');
            
            // Nếu lỗi liên quan đến PigeonUserDetails, tạo một userData cơ bản
            if (e.toString().contains('PigeonUserDetails')) {
              debugPrint('⚠️ Phát hiện lỗi PigeonUserDetails, tạo dữ liệu cơ bản');
              
              // Lấy thông tin người dùng hiện tại từ Firebase
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                return {
                  'user_id': currentUser.uid,
                  'email': currentUser.email,
                  'display_name': currentUser.displayName,
                  'photo_url': currentUser.photoURL,
                  'is_authenticated': true,
                  'converted_from_list': true
                };
              }
            }
            
            throw e;
          }
        } else if (response.statusCode == 408) {
          // Timeout, thử lại
          debugPrint('⏱️ Timeout từ server, thử lại lần ${retryCount + 1}');
          retryCount++;
          continue;
        } else {
          debugPrint('⚠️ Lấy thông tin người dùng thất bại: ${response.statusCode}');
          
          // Trả về thông tin lỗi
          if (response.statusCode == 401) {
            if (retryCount < maxRetries - 1) {
              debugPrint('🔄 Lỗi xác thực, thử lại lần ${retryCount + 1}');
              retryCount++;
              continue;
            }
            return {'error': 'Không có quyền truy cập, hãy đăng nhập lại'};
          } else if (response.statusCode == 404) {
            return {'error': 'Không tìm thấy người dùng'};
          } else if (response.statusCode >= 500) {
            // Lỗi server, thử lại
            debugPrint('🔄 Lỗi server, thử lại lần ${retryCount + 1}');
            retryCount++;
            continue;
          } else {
            try {
              // Thử phân tích phản hồi lỗi
              final errorData = json.decode(response.body);
              return {'error': errorData['detail'] ?? 'Lỗi không xác định'};
            } catch (e) {
              return {'error': 'Lỗi không xác định (${response.statusCode})'};
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi lấy thông tin người dùng: $e');
        
        // Nếu lỗi liên quan đến PigeonUserDetails, tạo một userData cơ bản
        if (e.toString().contains('PigeonUserDetails')) {
          debugPrint('⚠️ Phát hiện lỗi PigeonUserDetails, tạo dữ liệu cơ bản');
          
          // Lấy thông tin người dùng hiện tại từ Firebase
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            return {
              'user_id': currentUser.uid,
              'email': currentUser.email,
              'display_name': currentUser.displayName,
              'photo_url': currentUser.photoURL,
              'is_authenticated': true,
              'converted_from_list': true
            };
          }
        }
        
        // Thử lại nếu chưa đạt số lần tối đa
        if (retryCount < maxRetries - 1) {
          retryCount++;
          continue;
        }
        
        return {'error': 'Lỗi kết nối: ${e.toString()}'};
      }
    }
    
    // Nếu đã thử hết số lần và vẫn không thành công
    debugPrint('⚠️ Đã thử lấy thông tin người dùng ${maxRetries} lần nhưng không thành công');
    return {'error': 'Không thể kết nối với server sau nhiều lần thử'};
  }
  
  // Kiểm tra tính hợp lệ của token
  static Future<bool> validateToken() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$authBaseUrl/validate-token'),
        headers: headers,
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⚠️ Validate token API timeout - có thể server đang bận');
          return http.Response('{"valid": false, "error": "Timeout"}', 408);
        },
      );
      
      debugPrint('Validate Token API Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Token hợp lệ');
        return data['valid'] ?? false;
      }
      debugPrint('⚠️ Token không hợp lệ');
      return false;
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra token: $e');
      return false;
    }
  }
  
  // Kiểm tra endpoint cụ thể có tồn tại hay không
  static Future<bool> checkEndpointExists(String endpoint) async {
    try {
      debugPrint('📡 Đang kiểm tra endpoint: $authBaseUrl$endpoint');
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$authBaseUrl$endpoint'),
        headers: headers
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ Timeout: Endpoint không phản hồi sau 5 giây');
          return http.Response('Timeout', 408);
        },
      );
      
      debugPrint('📊 Trạng thái endpoint: ${response.statusCode}');
      // 200 OK hoặc 404 Not Found
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Lỗi kiểm tra endpoint: $e');
      return false;
    }
  }
  
  // FIREBASE DATA METHODS
  
  // Lấy dữ liệu food entries từ Firebase
  static Future<List<FoodEntry>?> getFoodEntriesFromFirebase(String userId, String date) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/users/$userId/food-intake/$date'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => FoodEntry.fromJson(item)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting food entries from Firebase: $e');
      return null;
    }
  }
  
  // Lấy dữ liệu exercise từ Firebase
  static Future<List<Exercise>?> getExercisesFromFirebase(String userId, String date) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/users/$userId/exercise-history/$date'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Exercise.fromJson(json)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting exercises from Firebase: $e');
      return null;
    }
  }
  
  // Lấy tất cả exercise từ Firebase
  static Future<Map<String, List<Exercise>>?> getAllExercisesFromFirebase(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/users/$userId/exercise-history'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, List<Exercise>> result = {};
        
        data.forEach((date, exercises) {
          result[date] = (exercises as List)
              .map((e) => Exercise.fromJson(e))
              .toList();
        });
        
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting all exercises from Firebase: $e');
      return null;
    }
  }
  
  // Lấy dữ liệu water entries từ Firebase
  static Future<List<WaterEntry>?> getWaterEntriesFromFirebase(String userId, String date) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/users/$userId/water-intake/$date'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WaterEntry.fromMap(json)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting water entries from Firebase: $e');
      return null;
    }
  }
  
  // Lấy tất cả water entries từ Firebase
  static Future<List<WaterEntry>?> getAllWaterEntriesFromFirebase(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/users/$userId/water-intake/history'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WaterEntry.fromMap(json)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting all water entries from Firebase: $e');
      return null;
    }
  }
  
  // MEAL PLAN METHODS - UPDATED
  
  // Tạo kế hoạch ăn uống mới (Firestore)
  static Future<Map<String, dynamic>?> createMealPlan(Map<String, dynamic> mealPlanData) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse(firestoreMealPlansUrl),
        headers: headers,
        body: jsonEncode(mealPlanData),
      );
      
      debugPrint('API Response (createMealPlan): ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating meal plan: $e');
      return null;
    }
  }
  
  // Lấy kế hoạch ăn uống theo ID
  static Future<Map<String, dynamic>?> getMealPlanById(String planId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$firestoreMealPlansUrl/$planId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting meal plan by ID: $e');
      return null;
    }
  }
  
  // Lấy kế hoạch ăn uống theo ngày
  static Future<Map<String, dynamic>?> getMealPlanByDate(String userId, String date) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiEndpoints.firestoreUserMealPlans}/$userId/meal-plans/date/$date'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting meal plan by date: $e');
      return null;
    }
  }
  
  // Xóa kế hoạch ăn uống
  static Future<bool> deleteMealPlan(String planId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$firestoreMealPlansUrl/$planId'),
        headers: headers,
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting meal plan: $e');
      return false;
    }
  }
  
  // Lấy tất cả kế hoạch ăn uống của người dùng
  static Future<List<Map<String, dynamic>>?> getMealPlansByUser(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiEndpoints.firestoreMealPlansByUser}/$userId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting meal plans by user: $e');
      return null;
    }
  }
  
  // Lấy kế hoạch ăn uống mới nhất của người dùng
  static Future<Map<String, dynamic>?> getLatestMealPlan(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiEndpoints.firestoreLatestMealPlan}/$userId'),
        headers: headers,
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout khi lấy kế hoạch ăn mới nhất');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đã lấy kế hoạch ăn mới nhất từ API');
        return json.decode(response.body);
      } else {
        debugPrint('❌ Lỗi khi lấy kế hoạch ăn mới nhất: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API lấy kế hoạch ăn mới nhất: $e');
      return null;
    }
  }
  
  // Tạo kế hoạch ăn uống hàng tuần (API)
  static Future<Map<String, dynamic>?> generateWeeklyMealPlan({
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    String? userId,
    bool useAI = true,
  }) async {
    try {
      final headers = await getAuthHeaders();
      
      // Tạo dữ liệu JSON cho body
      final requestData = {
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
        'use_ai': useAI,
      };
      
      // Thêm userId nếu có
      if (userId != null) {
        requestData['user_id'] = userId;
      }
      
      // Sử dụng phương thức POST với body JSON
      final generateUrl = Uri.parse('$baseUrl${ApiEndpoints.generateMealPlan}');
      
      debugPrint('🔄 Đang tạo kế hoạch ăn mới từ API: $generateUrl');
      final response = await http.post(
        generateUrl,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      ).timeout(
        Duration(seconds: 60), // Tăng timeout lên 60 giây vì tạo kế hoạch ăn có thể mất nhiều thời gian
        onTimeout: () {
          debugPrint('⏱️ Timeout khi tạo kế hoạch ăn mới');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Đã tạo kế hoạch ăn mới từ API thành công');
        return json.decode(response.body);
      } else if (response.statusCode == 500) {
        // Trả về lỗi 500 để caller có thể xử lý
        debugPrint('❌ Lỗi server khi tạo kế hoạch ăn: ${response.statusCode} - ${response.body}');
        
        // Phân tích lỗi nếu có thể
        String errorMessage = 'Lỗi server';
        try {
          final errorData = json.decode(response.body);
          if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];
          }
        } catch (e) {
          debugPrint('Không thể phân tích lỗi server: $e');
        }
        
        return {
          'error': 'server_error', 
          'status': 500, 
          'message': errorMessage
        };
      } else {
        debugPrint('❌ Lỗi khi tạo kế hoạch ăn mới: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API tạo kế hoạch ăn: $e');
      return null;
    }
  }
  
  // Lấy kế hoạch ăn uống cho người dùng (API)
  static Future<Map<String, dynamic>?> getUserMealPlan(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiEndpoints.getMealPlan}/$userId'),
        headers: headers,
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout khi lấy kế hoạch ăn từ API');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đã lấy kế hoạch ăn từ API thành công');
        return json.decode(response.body);
      } else {
        debugPrint('❌ Lỗi khi lấy kế hoạch ăn từ API: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API lấy kế hoạch ăn: $e');
      return null;
    }
  }
  
  
  
  // FIRESTORE USERS METHODS
  
  // GET /firestore/users/{user_id}: Lấy thông tin người dùng từ Firestore
  static Future<Map<String, dynamic>?> getFirestoreUser(String userId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiEndpoints.getUser}/$userId'),
        headers: headers,
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout khi lấy thông tin người dùng từ Firestore');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đã lấy thông tin người dùng từ Firestore thành công');
        final responseData = json.decode(response.body);
        return FirebaseHelpers.safeHandleApiResponse(responseData);
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Không tìm thấy người dùng trong Firestore');
        return null;
      } else {
        debugPrint('❌ Lỗi khi lấy thông tin người dùng từ Firestore: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API lấy thông tin người dùng: $e');
      return null;
    }
  }
  
  // POST /firestore/users/{user_id}: Tạo người dùng mới trong Firestore
  static Future<Map<String, dynamic>?> createFirestoreUser(String userId, Map<String, dynamic> userData) async {
    try {
      // Đảm bảo có đầy đủ các trường dữ liệu quan trọng
      final fullData = {
        ...userData,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Xử lý dữ liệu thời gian trước khi gửi
      final preparedData = FirebaseHelpers.prepareAnyDataForJson(fullData);
      
      // Thêm header cho authorization
      final headers = await getAuthHeaders();
      
      debugPrint('🔄 Đang tạo người dùng mới trong Firestore...');
      
      final response = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.createUser}/$userId'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(preparedData),
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout khi tạo người dùng mới');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Đã tạo người dùng mới trong Firestore thành công');
        final responseData = json.decode(response.body);
        return FirebaseHelpers.safeHandleApiResponse(responseData);
      } else {
        debugPrint('❌ Lỗi khi tạo người dùng mới trong Firestore: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API tạo người dùng mới: $e');
      return null;
    }
  }
  
  // PATCH /firestore/users/{user_id}: Cập nhật thông tin người dùng trong Firestore
  static Future<Map<String, dynamic>?> updateFirestoreUser(String userId, Map<String, dynamic> userData) async {
    try {
      // Đảm bảo có đầy đủ các trường dữ liệu quan trọng
      final updatedData = {
        ...userData,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Xử lý dữ liệu thời gian trước khi gửi
      final preparedData = FirebaseHelpers.prepareAnyDataForJson(updatedData);
      
      // Thêm header cho authorization
      final headers = await getAuthHeaders();
      
      debugPrint('🔄 Đang cập nhật thông tin người dùng trong Firestore...');
      
      final response = await http.patch(
        Uri.parse('$baseUrl${ApiEndpoints.updateUser}/$userId'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(preparedData),
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout khi cập nhật thông tin người dùng');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đã cập nhật thông tin người dùng trong Firestore thành công');
        final responseData = json.decode(response.body);
        return FirebaseHelpers.safeHandleApiResponse(responseData);
      } else {
        debugPrint('❌ Lỗi khi cập nhật thông tin người dùng trong Firestore: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API cập nhật thông tin người dùng: $e');
      return null;
    }
  }
  
  // DELETE /firestore/users/{user_id}: Xóa người dùng khỏi Firestore
  static Future<bool> deleteFirestoreUser(String userId) async {
    try {
      // Thêm header cho authorization
      final headers = await getAuthHeaders();
      
      debugPrint('🔄 Đang xóa người dùng khỏi Firestore...');
      
      final response = await http.delete(
        Uri.parse('$baseUrl${ApiEndpoints.deleteUser}/$userId'),
        headers: headers,
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout khi xóa người dùng');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đã xóa người dùng khỏi Firestore thành công');
        return true;
      } else {
        debugPrint('❌ Lỗi khi xóa người dùng khỏi Firestore: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API xóa người dùng: $e');
      return false;
    }
  }
  
  // POST /firestore/users/{user_id}/convert-anonymous: Chuyển đổi tài khoản ẩn danh thành tài khoản thường
  static Future<Map<String, dynamic>?> convertAnonymousAccount(
    String userId, 
    String email, 
    String password, 
    String? displayName
  ) async {
    try {
      // Thêm header cho authorization
      final headers = await getAuthHeaders();
      
      // Chuẩn bị dữ liệu cho việc chuyển đổi
      final conversionData = {
        'email': email,
        'password': password,
        'display_name': displayName ?? email.split('@')[0],
      };
      
      debugPrint('🔄 Đang chuyển đổi tài khoản ẩn danh thành tài khoản thường...');
      
      final response = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.convertAnonymous}/$userId/convert-anonymous'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(conversionData),
      ).timeout(
        Duration(seconds: 15), // Tăng timeout vì quá trình này có thể mất nhiều thời gian
        onTimeout: () {
          debugPrint('⏱️ Timeout khi chuyển đổi tài khoản ẩn danh');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đã chuyển đổi tài khoản ẩn danh thành công');
        final responseData = json.decode(response.body);
        return FirebaseHelpers.safeHandleApiResponse(responseData);
      } else {
        debugPrint('❌ Lỗi khi chuyển đổi tài khoản ẩn danh: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API chuyển đổi tài khoản ẩn danh: $e');
      return null;
    }
  }
  
  // USER PROFILE API METHODS
  
  // POST /api/user-profile: Tạo hoặc cập nhật hồ sơ người dùng
  static Future<Map<String, dynamic>?> createOrUpdateUserProfile(Map<String, dynamic> profileData) async {
    try {
      // Thêm header cho authorization
      final headers = await getAuthHeaders();
      
      debugPrint('🔄 Đang tạo hoặc cập nhật hồ sơ người dùng...');
      
      final response = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.createUpdateUserProfile}'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(profileData),
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout khi tạo hoặc cập nhật hồ sơ người dùng');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Đã tạo hoặc cập nhật hồ sơ người dùng thành công');
        return json.decode(response.body);
      } else {
        debugPrint('❌ Lỗi khi tạo hoặc cập nhật hồ sơ người dùng: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API tạo hoặc cập nhật hồ sơ người dùng: $e');
      return null;
    }
  }
  
  // GET /api/user-profile/{user_id}: Lấy thông tin hồ sơ người dùng
  static Future<Map<String, dynamic>?> getUserProfileData(String userId) async {
    try {
      // Thêm header cho authorization
      final headers = await getAuthHeaders();
      
      debugPrint('🔄 Đang lấy thông tin hồ sơ người dùng...');
      
      final response = await http.get(
        Uri.parse('$baseUrl${ApiEndpoints.getUserProfile}/$userId'),
        headers: headers,
      ).timeout(
        defaultTimeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout khi lấy thông tin hồ sơ người dùng');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Đã lấy thông tin hồ sơ người dùng thành công');
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Không tìm thấy hồ sơ người dùng');
        return null;
      } else {
        debugPrint('❌ Lỗi khi lấy thông tin hồ sơ người dùng: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gọi API lấy thông tin hồ sơ người dùng: $e');
      return null;
    }
  }
} 
