import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:openfood/utils/config.dart';
import '../providers/user_data_provider.dart' as udp;
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
        return true;
      }
    }

    // Các chức năng phức tạp vẫn sử dụng API
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
      } else {
        // Thử lấy token từ SharedPreferences nếu không có user đăng nhập
        try {
          final prefs = await SharedPreferences.getInstance();
          final apiToken = prefs.getString('api_token');
          if (apiToken != null) {
            headers['Authorization'] = 'Bearer $apiToken';
          }
        } catch (e) {
          // Silent error handling
        }
      }
    } catch (e) {
      // Thử lấy token từ SharedPreferences nếu có lỗi
      try {
        final prefs = await SharedPreferences.getInstance();
        final apiToken = prefs.getString('api_token');
        if (apiToken != null) {
          headers['Authorization'] = 'Bearer $apiToken';
        }
      } catch (e) {
        // Silent error handling
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
      return false;
    }
  }
  
  // Kiểm tra kết nối với API và trả về thông tin chi tiết
  static Future<Map<String, dynamic>> checkApiConnectionDetailed() async {
    try {
      final response = await http.get(
        Uri.parse('${authBaseUrl}${AppConfig.ApiEndpoints.apiStatus}'),
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          return http.Response('{"error": "Timeout"}', 408);
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'status_code': response.statusCode,
          'message': 'Kết nối API thành công'
        };
      } else {
        return {
          'success': false,
          'status_code': response.statusCode,
          'message': 'Kết nối API thất bại'
        };
      }
    } catch (e) {
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
      return {'ai_available': false, 'error': 'Lỗi kết nối: $e'};
    }
  }
  
  // Thông báo đã đọc dữ liệu
  static Future<void> notifyDataRead(String dataType, String userId) async {
    // Không gọi API không tồn tại nữa
    // Endpoint /api/data-read-notification không tồn tại trong backend

  }
  
  // USER PROFILE METHODS
  
  // Send user profile data to FastAPI
  static Future<bool> sendUserProfile(udp.UserDataProvider userData) async {
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

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
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

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
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
      
      final response = await http.post(
        Uri.parse('$firestoreUsersUrl/$userId'),
        headers: headers,
        body: jsonEncode(preparedData),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
  
  // Phương thức này đã bị xóa để tránh đồng bộ dữ liệu từ backend
  // Trả về true để không làm ảnh hưởng đến luồng chạy của ứng dụng
  static Future<bool> syncUserProfileToFirestore(String userId, Map<String, dynamic> userData) async {
    return true;
  }

  // Phương thức này đã bị xóa để tránh đồng bộ dữ liệu từ backend
  // Trả về true để không làm ảnh hưởng đến luồng chạy của ứng dụng
  static Future<bool> syncFullUserData(String userId, Map<String, dynamic> userData) async {
    return true;
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

      return false;
    }
  }
  
  // Phương thức này đã bị xóa để tránh nhận dữ liệu từ backend
  
  // Thay thế bữa ăn
  static Future<Map<String, dynamic>?> replaceMeal(Map<String, dynamic> mealData) async {
    try {
      final headers = await getAuthHeaders();
      
      // Sử dụng phương thức POST với body JSON
      final replaceUrl = Uri.parse('$baseUrl${ApiEndpoints.replaceMeal}');

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

          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {

        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // Trả về lỗi 404 để caller có thể xử lý

        return {'error': 'not_found', 'status': 404, 'message': 'Không tìm thấy kế hoạch ăn'};
      } else if (response.statusCode == 500) {
        // Trả về lỗi 500 để caller có thể xử lý

        // Phân tích lỗi nếu có thể
        String errorMessage = 'Lỗi server';
        try {
          final errorData = json.decode(response.body);
          if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];
          }
        } catch (e) {

        }
        
        return {
          'error': 'server_error', 
          'status': 500, 
          'message': errorMessage
        };
      } else {

        return null;
      }
    } catch (e) {

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

      return null;
    }
  }

  // Send food entry to FastAPI
  static Future<bool> sendFoodEntry(FoodEntry entry, String userId) async {
    try {
      // In ra thông tin chi tiết về mục nhập thực phẩm

      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('food_entry')) {

        try {
          // Chuẩn bị dữ liệu để lưu vào Firestore
          final foodData = entry.toJson();
          foodData['user_id'] = userId;
          foodData['date'] = entry.dateTime.toIso8601String().split('T')[0];
          foodData['created_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          foodData['updated_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          
          // Lưu vào Firestore sử dụng collection mới 'food_records'
          await FirebaseFirestore.instance
              .collection('food_records')
              .doc(entry.id)
              .set(foodData);

          // Kiểm tra số lượng bản ghi trong collection mới
          final countQuery = await FirebaseFirestore.instance
              .collection('food_records')
              .where('user_id', isEqualTo: userId)
              .get();

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

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

      return false;
    }
  }
  
  // Phương thức này đã bị xóa để tránh nhận dữ liệu từ backend
  
  // Delete food entry
  static Future<bool> deleteFoodEntry(String entryId, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('food_entry')) {

        try {
          // Xóa mục nhập thực phẩm từ collection mới food_records
          await FirebaseFirestore.instance
              .collection('food_records')
              .doc(entryId)
              .delete();

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

        final headers = await getAuthHeaders();
        final response = await http.delete(
          Uri.parse('$foodLogUrl/$userId/$entryId'),
          headers: headers,
        );
        
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } catch (e) {

      return false;
    }
  }
  
  // Update food entry
  static Future<bool> updateFoodEntry(FoodEntry entry, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('food_entry')) {

        try {
          // Chuẩn bị dữ liệu để cập nhật vào Firestore
          final entryData = entry.toJson();
          entryData['user_id'] = userId;
          entryData['date'] = entry.dateTime.toIso8601String().split('T')[0];
          entryData['updated_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          
          // Sử dụng collection mới food_records
          await FirebaseFirestore.instance
              .collection('food_records')
              .doc(entry.id)
              .set(entryData, SetOptions(merge: true));

          // Kiểm tra số lượng bản ghi trong collection mới
          final countQuery = await FirebaseFirestore.instance
              .collection('food_records')
              .where('user_id', isEqualTo: userId)
              .get();

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

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

      return false;
    }
  }
  // Phương thức này đã bị xóa để tránh nhận dữ liệu từ backend
  
  // Send exercise data to API
  static Future<bool> sendExercise(Exercise exercise, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('exercise')) {

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

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

        final headers = await getAuthHeaders();
        final response = await http.post(
          Uri.parse(exerciseUrl),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'exercise_data': exercise.toJson(),
          }),
        );

        return response.statusCode == 200 || response.statusCode == 201;
      }
    } catch (e) {

      return false;
    }
  }
  
  // Update exercise data
  static Future<bool> updateExercise(Exercise exercise, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('exercise')) {

        try {
          // Chuẩn bị dữ liệu để cập nhật vào Firestore
          final exerciseData = exercise.toJson();
          exerciseData['user_id'] = userId;
          exerciseData['updated_at'] = DateTime.now().toIso8601String(); // Timestamp hiện tại
          
          // Sử dụng set với merge: true thay vì update để tránh lỗi NOT_FOUND
          await FirebaseFirestore.instance
              .collection('exercises')
              .doc(exercise.id)
              .set(exerciseData, SetOptions(merge: true));

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

        final headers = await getAuthHeaders();
        final response = await http.put(
          Uri.parse('$exerciseUrl/${exercise.id}'),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'exercise_data': exercise.toJson(),
          }),
        );

        return response.statusCode == 200;
      }
    } catch (e) {

      return false;
    }
  }
  
  // Delete exercise
  static Future<bool> deleteExercise(String exerciseId, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('exercise')) {

        try {
          // Xóa bài tập từ Firestore
          await FirebaseFirestore.instance
              .collection('exercises')
              .doc(exerciseId)
              .delete();

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

        final headers = await getAuthHeaders();
        final response = await http.delete(
          Uri.parse('$exerciseUrl/$exerciseId'),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
          }),
        );

        return response.statusCode == 200;
      }
    } catch (e) {

      return false;
    }
  }
  
  // Phương thức này đã bị xóa để tránh nhận dữ liệu từ backend
  
  // Phương thức này đã bị xóa để tránh nhận dữ liệu từ backend
  
  // Send water entry to API
  static Future<bool> sendWaterEntry(WaterEntry entry, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('water_entry')) {

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

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

        final headers = await getAuthHeaders();
        final response = await http.post(
          Uri.parse(waterLogUrl),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'water_data': entry.toMap(),
          }),
        );

        return response.statusCode == 200 || response.statusCode == 201;
      }
    } catch (e) {

      return false;
    }
  }
  
  // Delete water entry
  static Future<bool> deleteWaterEntry(String entryId, String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('water_entry')) {

        try {
          // Xóa mục nhập nước uống từ Firestore
          await FirebaseFirestore.instance
              .collection('water_entries')
              .doc(entryId)
              .delete();

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

        final headers = await getAuthHeaders();
        final response = await http.delete(
          Uri.parse('$waterLogUrl/$entryId'),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
          }),
        );

        return response.statusCode == 200;
      }
    } catch (e) {

      return false;
    }
  }
  
  // Clear all water entries
  static Future<bool> clearAllWaterEntries(String userId) async {
    try {
      // Kiểm tra xem có nên sử dụng Firestore trực tiếp không
      if (shouldUseDirectFirestore('water_entry')) {

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

          return true;
        } catch (firestoreError) {

          return false;
        }
      } else {
        // Sử dụng API

        final headers = await getAuthHeaders();
        final response = await http.delete(
          Uri.parse('$waterLogUrl/$userId/all'),
          headers: headers,
        );

        return response.statusCode == 200;
      }
    } catch (e) {

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

      return false;
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

          return http.Response('{"error": "Timeout"}', 408);
        },
      );

      if (response.statusCode == 200) {

        try {
          final responseData = json.decode(response.body);
          // Xử lý phản hồi bằng helper
          return FirebaseHelpers.safeHandleApiResponse(responseData);
        } catch (e) {

          // Trả về một đối tượng đơn giản
          return {'success': true, 'parse_error': e.toString()};
        }
      }

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

      return {'error': 'Lỗi kết nối: ${e.toString()}'};
    }
  }
  
  // Phương thức này đã bị xóa để tránh nhận dữ liệu từ backend
  // Trả về thông tin người dùng trực tiếp từ Firebase
  static Future<Map<String, dynamic>?> getCurrentUser() async {

    try {
      // Lấy thông tin người dùng hiện tại từ Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        return {
          'user_id': currentUser.uid,
          'email': currentUser.email,
          'display_name': currentUser.displayName,
          'photo_url': currentUser.photoURL,
          'is_authenticated': true,
          'from_firebase_direct': true
        };
      } else {
        return {'error': 'Không có người dùng đăng nhập'};
      }
    } catch (e) {

      return {'error': 'Lỗi kết nối Firebase: ${e.toString()}'};
    }
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

          return http.Response('{"valid": false, "error": "Timeout"}', 408);
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return data['valid'] ?? false;
      }

      return false;
    } catch (e) {

      return false;
    }
  }
  
  // Kiểm tra endpoint cụ thể có tồn tại hay không
  static Future<bool> checkEndpointExists(String endpoint) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$authBaseUrl$endpoint'),
        headers: headers
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {

          return http.Response('Timeout', 408);
        },
      );

      // 200 OK hoặc 404 Not Found
      return response.statusCode == 200;
    } catch (e) {

      return false;
    }
  }
  
  // Lấy dữ liệu food entries từ Firebase
  static Future<List<FoodEntry>?> getFoodEntriesFromFirebase(String userId, String date) async {
    try {

      // Ưu tiên truy vấn collection mới food_records trước

      final newCollectionQuery = await FirebaseFirestore.instance
          .collection('food_records')
          .where('user_id', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .get();
      
      // Nếu tìm thấy dữ liệu trong collection mới food_records
      if (newCollectionQuery.docs.isNotEmpty) {

        // Chuyển đổi kết quả truy vấn thành danh sách FoodEntry
        final entries = newCollectionQuery.docs.map((doc) {
          final data = doc.data();
          // Đảm bảo id của document được sử dụng
          if (data['id'] == null) {
            data['id'] = doc.id;
          }
          return FoodEntry.fromJson(data);
        }).toList();

        return entries;
      }
      
      // Nếu không tìm thấy trong collection mới, thử truy vấn collection cũ (chiến lược fallback)

      final oldCollectionQuery = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('user_id', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .get();
      
      // Nếu không tìm thấy dữ liệu trong collection cũ, thử phương pháp khác
      if (oldCollectionQuery.docs.isEmpty) {

        // Lấy tất cả food entries của người dùng và lọc theo ngày
        final allEntriesSnapshot = await FirebaseFirestore.instance
            .collection('food_entries')
            .where('user_id', isEqualTo: userId)
            .get();
        
        final filteredEntries = <FoodEntry>[];

        for (var doc in allEntriesSnapshot.docs) {
          final data = doc.data();
          String entryDate = '';
          
          // Kiểm tra trường date
          if (data['date'] != null) {
            entryDate = data['date'];
          } 
          // Kiểm tra trường dateTime nếu không có trường date
          else if (data['dateTime'] != null) {
            String dateTimeStr = data['dateTime'];
            if (dateTimeStr.contains('T')) {
              entryDate = dateTimeStr.split('T')[0];
            } else {
              entryDate = dateTimeStr;
            }
          }
          
          // Nếu ngày khớp, thêm vào danh sách kết quả
          if (entryDate == date) {
            // Đảm bảo id của document được sử dụng
            if (data['id'] == null) {
              data['id'] = doc.id;
            }
            filteredEntries.add(FoodEntry.fromJson(data));
          }
        }
        
        if (filteredEntries.isEmpty) {

        } else {

        }
        return filteredEntries;
      }
      
      // Chuyển đổi kết quả truy vấn collection cũ thành danh sách FoodEntry
      final entries = oldCollectionQuery.docs.map((doc) {
        final data = doc.data();
        // Đảm bảo id của document được sử dụng
        if (data['id'] == null) {
          data['id'] = doc.id;
        }
        return FoodEntry.fromJson(data);
      }).toList();

      return entries;
    } catch (e) {

      return null;
    }
  }
  
  // Lấy dữ liệu exercise từ Firebase
  static Future<List<Exercise>?> getExercisesFromFirebase(String userId, String date) async {
    try {

      // Thử truy vấn với date
      final querySnapshot = await FirebaseFirestore.instance
          .collection('exercises')
          .where('user_id', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .get();
      
      // Nếu không tìm thấy, thử lấy tất cả và lọc theo ngày
      if (querySnapshot.docs.isEmpty) {
        // Lấy tất cả exercises của người dùng
        final allExercisesSnapshot = await FirebaseFirestore.instance
            .collection('exercises')
            .where('user_id', isEqualTo: userId)
            .get();

        final filteredExercises = <Exercise>[];
        
        for (var doc in allExercisesSnapshot.docs) {
          final data = doc.data();
          String exerciseDate = '';
          
          // Kiểm tra trường date
          if (data['date'] != null) {
            exerciseDate = data['date'];
          } 
          // Kiểm tra trường dateTime nếu không có trường date
          else if (data['dateTime'] != null) {
            String dateTimeStr = data['dateTime'];
            if (dateTimeStr.contains('T')) {
              exerciseDate = dateTimeStr.split('T')[0];
            } else {
              exerciseDate = dateTimeStr;
            }
          }
          
          // Nếu ngày khớp, thêm vào danh sách
          if (exerciseDate == date) {
            // Đảm bảo id của document được sử dụng
            if (data['id'] == null) {
              data['id'] = doc.id;
            }

            filteredExercises.add(Exercise.fromJson(data));
          }
        }

        return filteredExercises;
      }
      
      // Chuyển đổi kết quả truy vấn thành danh sách Exercise
      final exercises = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Đảm bảo id của document được sử dụng
        if (data['id'] == null) {
          data['id'] = doc.id;
        }
        return Exercise.fromJson(data);
      }).toList();

      return exercises;
    } catch (e) {

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

      return null;
    }
  }
  
  // Lấy dữ liệu water entries từ Firebase
  static Future<List<WaterEntry>?> getWaterEntriesFromFirebase(String userId, String date) async {
    try {

      // Thử truy vấn dựa trên trường date
      final querySnapshot = await FirebaseFirestore.instance
          .collection('water_entries')
          .where('user_id', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .get();
      
      // Nếu không tìm thấy dữ liệu, thử phương pháp khác
      if (querySnapshot.docs.isEmpty) {
        // Lấy tất cả water entries của người dùng và lọc theo ngày
        final allEntriesSnapshot = await FirebaseFirestore.instance
            .collection('water_entries')
            .where('user_id', isEqualTo: userId)
            .get();
        
        final filteredEntries = <WaterEntry>[];
        
        for (var doc in allEntriesSnapshot.docs) {
          final data = doc.data();
          String entryDate = '';
          
          // Kiểm tra trường date
          if (data['date'] != null) {
            entryDate = data['date'];
          } 
          // Kiểm tra trường dateTime nếu không có trường date
          else if (data['dateTime'] != null) {
            String dateTimeStr = data['dateTime'];
            if (dateTimeStr.contains('T')) {
              entryDate = dateTimeStr.split('T')[0];
            } else {
              entryDate = dateTimeStr;
            }
          }
          
          // Nếu ngày khớp, thêm vào danh sách kết quả
          if (entryDate == date) {
            // Đảm bảo id của document được sử dụng
            if (data['id'] == null) {
              data['id'] = doc.id;
            }
            filteredEntries.add(WaterEntry.fromMap(data));
          }
        }

        return filteredEntries;
      }
      
      // Chuyển đổi kết quả truy vấn thành danh sách WaterEntry
      final entries = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Đảm bảo id của document được sử dụng
        if (data['id'] == null) {
          data['id'] = doc.id;
        }
        return WaterEntry.fromMap(data);
      }).toList();

      return entries;
    } catch (e) {

      return null;
    }
  }
  
  // Lấy tất cả water entries từ Firebase
  static Future<List<WaterEntry>?> getAllWaterEntriesFromFirebase(String userId) async {
    try {

      // Truy vấn trực tiếp từ Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('water_entries')
          .where('user_id', isEqualTo: userId)
          .get();
      
      if (querySnapshot.docs.isEmpty) {

        return [];
      }
      
      // Chuyển đổi kết quả truy vấn thành danh sách WaterEntry
      final entries = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Đảm bảo id của document được sử dụng
        if (data['id'] == null) {
          data['id'] = doc.id;
        }
        return WaterEntry.fromMap(data);
      }).toList();

      return entries;
    } catch (e) {

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {

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

          return http.Response('{"error": "Timeout"}', 408);
        },
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

          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {

        return json.decode(response.body);
      } else if (response.statusCode == 500) {
        // Trả về lỗi 500 để caller có thể xử lý

        // Phân tích lỗi nếu có thể
        String errorMessage = 'Lỗi server';
        try {
          final errorData = json.decode(response.body);
          if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];
          }
        } catch (e) {

        }
        
        return {
          'error': 'server_error', 
          'status': 500, 
          'message': errorMessage
        };
      } else {

        return null;
      }
    } catch (e) {

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

          return http.Response('{"error": "Timeout"}', 408);
        },
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

          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {

        final responseData = json.decode(response.body);
        return FirebaseHelpers.safeHandleApiResponse(responseData);
      } else if (response.statusCode == 404) {

        return null;
      } else {

        return null;
      }
    } catch (e) {

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

          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {

        final responseData = json.decode(response.body);
        return FirebaseHelpers.safeHandleApiResponse(responseData);
      } else {

        return null;
      }
    } catch (e) {

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

          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {

        final responseData = json.decode(response.body);
        return FirebaseHelpers.safeHandleApiResponse(responseData);
      } else {

        return null;
      }
    } catch (e) {

      return null;
    }
  }
  
  // DELETE /firestore/users/{user_id}: Xóa người dùng khỏi Firestore
  static Future<bool> deleteFirestoreUser(String userId) async {
    try {
      // Thêm header cho authorization
      final headers = await getAuthHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl${ApiEndpoints.deleteUser}/$userId'),
        headers: headers,
      ).timeout(
        defaultTimeout,
        onTimeout: () {

          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {

        return true;
      } else {

        return false;
      }
    } catch (e) {

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

          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {

        final responseData = json.decode(response.body);
        return FirebaseHelpers.safeHandleApiResponse(responseData);
      } else {

        return null;
      }
    } catch (e) {

      return null;
    }
  }
  
  // USER PROFILE API METHODS
  
  // POST /api/user-profile: Tạo hoặc cập nhật hồ sơ người dùng
  static Future<Map<String, dynamic>?> createOrUpdateUserProfile(Map<String, dynamic> profileData) async {
    try {
      // Thêm header cho authorization
      final headers = await getAuthHeaders();

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

          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {

        return json.decode(response.body);
      } else {

        return null;
      }
    } catch (e) {

      return null;
    }
  }
  
  // Phương thức này đã bị xóa để tránh nhận dữ liệu từ backend
} 
