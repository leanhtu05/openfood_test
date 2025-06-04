import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/user_data_provider.dart' as udp;
import '../models/food_entry.dart';
import '../models/meal_plan.dart';
import '../models/exercise.dart';
import '../models/water_entry.dart';
import '../providers/user_data_provider.dart';
import 'package:openfood/services/api_service.dart';

/// API dịch vụ để tương tác với Firebase và API bên ngoài
class UserProfileAPI {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Base URL cho API nếu cần
  final String _apiBaseUrl = 'https://api.openfood.com'; // Thay đổi theo API thật của bạn
  
  // Phương thức lấy thông tin profile người dùng từ Firebase
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      debugPrint('🔄 UserProfileAPI: Đang lấy thông tin người dùng từ Firebase...');
      final DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        debugPrint('✅ UserProfileAPI: Đã lấy thông tin người dùng thành công');
        return doc.data() as Map<String, dynamic>;
      } else {
        debugPrint('ℹ️ UserProfileAPI: Không tìm thấy hồ sơ người dùng');
        return null;
      }
    } catch (e) {
      debugPrint('❌ UserProfileAPI: Lỗi khi lấy thông tin người dùng: $e');
      return null;
    }
  }
  
  // Phương thức cập nhật thông tin người dùng lên Firebase
  Future<bool> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 UserProfileAPI: Đang cập nhật thông tin người dùng lên Firebase...');
      
      await _firestore.collection('users').doc(userId).set(
        data,
        SetOptions(merge: true), // Merge để chỉ cập nhật các trường được cung cấp
      );
      
      debugPrint('✅ UserProfileAPI: Đã cập nhật thông tin người dùng thành công');
      return true;
    } catch (e) {
      debugPrint('❌ UserProfileAPI: Lỗi khi cập nhật thông tin người dùng: $e');
      return false;
    }
  }
  
  // Phương thức lấy dữ liệu nước uống
  Future<List<Map<String, dynamic>>?> getUserWaterEntries(String userId) async {
    try {
      debugPrint('🔄 UserProfileAPI: Đang lấy dữ liệu nước uống từ Firebase...');
      
      final QuerySnapshot snapshot = await _firestore
          .collection('water_entries')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100) // Giới hạn số lượng để tránh tải quá nhiều
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('ℹ️ UserProfileAPI: Không tìm thấy dữ liệu nước uống');
        return [];
      }
      
      final entries = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Đảm bảo ID được bao gồm
        return data;
      }).toList();
      
      debugPrint('✅ UserProfileAPI: Đã lấy ${entries.length} bản ghi nước uống');
      return entries;
    } catch (e) {
      debugPrint('❌ UserProfileAPI: Lỗi khi lấy dữ liệu nước uống: $e');
      return null;
    }
  }
  
  // Phương thức lấy dữ liệu bài tập
  Future<List<Map<String, dynamic>>?> getUserExerciseEntries(String userId) async {
    try {
      debugPrint('🔄 UserProfileAPI: Đang lấy dữ liệu bài tập từ Firebase...');
      
      final QuerySnapshot snapshot = await _firestore
          .collection('exercises')
          .where('user_id', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(100) // Giới hạn số lượng
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('ℹ️ UserProfileAPI: Không tìm thấy dữ liệu bài tập');
        return [];
      }
      
      final entries = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Đảm bảo ID được bao gồm
        return data;
      }).toList();
      
      debugPrint('✅ UserProfileAPI: Đã lấy ${entries.length} bản ghi bài tập');
      return entries;
    } catch (e) {
      debugPrint('❌ UserProfileAPI: Lỗi khi lấy dữ liệu bài tập: $e');
      return null;
    }
  }
  
  // Phương thức lấy dữ liệu thực phẩm
  Future<List<Map<String, dynamic>>?> getUserFoodEntries(String userId) async {
    try {
      debugPrint('🔄 UserProfileAPI: Đang lấy dữ liệu thực phẩm từ Firebase...');
      
      final QuerySnapshot snapshot = await _firestore
          .collection('food_records')
          .where('user_id', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(100) // Giới hạn số lượng
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('ℹ️ UserProfileAPI: Không tìm thấy dữ liệu thực phẩm');
        return [];
      }
      
      final entries = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Đảm bảo ID được bao gồm
        return data;
      }).toList();
      
      debugPrint('✅ UserProfileAPI: Đã lấy ${entries.length} bản ghi thực phẩm');
      return entries;
    } catch (e) {
      debugPrint('❌ UserProfileAPI: Lỗi khi lấy dữ liệu thực phẩm: $e');
      return null;
    }
  }
  
  // Gọi API bên ngoài (nếu cần)
  Future<Map<String, dynamic>?> callExternalAPI(String endpoint, Map<String, dynamic> data) async {
    try {
      // Lấy token xác thực từ Firebase
      final idToken = await _auth.currentUser?.getIdToken();
      
      if (idToken == null) {
        debugPrint('⚠️ UserProfileAPI: Không có token xác thực');
        return null;
      }
      
      debugPrint('🔄 UserProfileAPI: Đang gọi API ngoài: $_apiBaseUrl$endpoint');
      
      final response = await http.post(
        Uri.parse('$_apiBaseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ UserProfileAPI: Gọi API thành công');
        return jsonDecode(response.body);
      } else {
        debugPrint('❌ UserProfileAPI: Lỗi khi gọi API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ UserProfileAPI: Lỗi khi gọi API ngoài: $e');
      return null;
    }
  }
}

class ApiService {
  // Base URL for FastAPI server
  // When running on Android emulator, use 10.0.2.2 to connect to host's localhost
  static const String baseUrl = 'https://backend-openfood.onrender.com/api';
  
  // API endpoints
  static String get userProfileUrl => '$baseUrl/user-profile';
  static String get mealPlanUrl => '$baseUrl/meal-plan';
  static String get foodLogUrl => '$baseUrl/food-log';
  static String get exerciseUrl => '$baseUrl/exercise';
  static String get waterLogUrl => '$baseUrl/water-log';
  static String get favoritesUrl => '$baseUrl/favorites';
  static String get firestoreUsersUrl => '$baseUrl/firestore/users';
  
  // Check API connection
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('Timeout', 408),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API connection error: $e');
      return false;
    }
  }
  
  // USER PROFILE METHODS
  
  // Send user profile data to FastAPI
  static Future<bool> sendUserProfile(UserDataProvider userData) async {
    try {
      final response = await http.post(
        Uri.parse(userProfileUrl),
        headers: {'Content-Type': 'application/json'},
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
  
  // Lấy thông tin người dùng trực tiếp từ Firestore
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Lấy dữ liệu trực tiếp từ Firestore
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        debugPrint('✅ Đã lấy thông tin người dùng từ Firestore');
        return docSnapshot.data();
      }
      
      debugPrint('⚠️ Không tìm thấy hồ sơ người dùng trong Firestore');
      return null;
    } catch (e) {
      debugPrint('Lỗi khi lấy thông tin người dùng từ Firestore: $e');
      return null;
    }
  }
  
  // MEAL PLAN METHODS
  
  // Send meal plan to FastAPI
  static Future<bool> sendMealPlan(Map<String, dynamic> mealPlanData) async {
    try {
      final response = await http.post(
        Uri.parse(mealPlanUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(mealPlanData),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending meal plan to API: $e');
      return false;
    }
  }
  
  // Lấy kế hoạch ăn trực tiếp từ Firestore
  static Future<Map<String, dynamic>?> getMealPlan(String userId) async {
    try {
      // Lấy dữ liệu trực tiếp từ Firestore
      final docSnapshot = await FirebaseFirestore.instance.collection('meal_plans').doc(userId).get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        debugPrint('✅ Đã lấy kế hoạch ăn từ Firestore');
        return docSnapshot.data();
      }
      
      debugPrint('⚠️ Không tìm thấy kế hoạch ăn trong Firestore');
      return null;
    } catch (e) {
      debugPrint('Lỗi khi lấy kế hoạch ăn từ Firestore: $e');
      return null;
    }
  }
  
  // FOOD LOG METHODS
  
  // Send food entry to FastAPI
  static Future<bool> sendFoodEntry(FoodEntry entry, String userId) async {
    try {
      final response = await http.post(
        Uri.parse(foodLogUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'entry': entry.toJson(),
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending food entry to API: $e');
      return false;
    }
  }
  
  // Lấy danh sách thực phẩm theo ngày trực tiếp từ Firestore
  static Future<List<FoodEntry>?> getFoodEntriesByDate(String userId, String date) async {
    try {
      // Truy vấn Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('user_id', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final List<FoodEntry> entries = querySnapshot.docs
            .map((doc) => FoodEntry.fromJson(doc.data()))
            .toList();
        
        debugPrint('✅ Đã lấy ${entries.length} món ăn từ Firestore cho ngày $date');
        return entries;
      }
      
      debugPrint('⚠️ Không tìm thấy món ăn nào cho ngày $date');
      return [];
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy danh sách thực phẩm từ Firestore: $e');
      return null;
    }
  }
  
  // Delete food entry
  static Future<bool> deleteFoodEntry(String entryId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$foodLogUrl/$userId/$entryId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting food entry from API: $e');
      return false;
    }
  }
  
  // EXERCISE METHODS
  
  // Send exercise entry to FastAPI
  static Future<bool> sendExerciseEntry(Exercise exercise, String userId) async {
    try {
      final response = await http.post(
        Uri.parse(exerciseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'exercise': exercise.toJson(),
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending exercise to API: $e');
      return false;
    }
  }
  
  // WATER LOG METHODS
  
  // Send water entry to FastAPI
  static Future<bool> sendWaterEntry(WaterEntry entry, String userId) async {
    try {
      final response = await http.post(
        Uri.parse(waterLogUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'amount': entry.amount,
          'timestamp': entry.timestamp.toIso8601String(),
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending water entry to API: $e');
      return false;
    }
  }

  // Lưu thông tin người dùng trực tiếp vào Firestore
  static Future<bool> sendUserProfileToFirestore(String userId, Map<String, dynamic> userData) async {
    try {
      // Thêm trường timestamp
      userData['created_at'] = DateTime.now().toIso8601String();
      
      // Lưu trực tiếp vào Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: false), // Ghi đè hoàn toàn
      );
      
      debugPrint('✅ Đã lưu thông tin người dùng vào Firestore thành công');
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu thông tin người dùng vào Firestore: $e');
      return false;
    }
  }
  
  // Đồng bộ thông tin người dùng trực tiếp vào Firestore
  static Future<bool> syncUserProfileToFirestore(String userId, Map<String, dynamic> userData) async {
    try {
      // Thêm trường timestamp
      userData['last_updated'] = DateTime.now().toIso8601String();
      
      // Lưu trực tiếp vào Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: true),
      );
      
      debugPrint('✅ Đã đồng bộ thông tin người dùng vào Firestore thành công');
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ thông tin người dùng vào Firestore: $e');
      return false;
    }
  }
}

class UserProfileApi {
  static const String baseUrl = 'https://backend-openfood.onrender.com/api';
  
  static String getApiUrl() {
    return '$baseUrl/user-profile';
  }
  
  static Future<bool> sendUserProfile(UserDataProvider userData) async {
    try {
      // Gửi dữ liệu người dùng lên API
      final url = Uri.parse(getApiUrl());
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userData.userId ?? 'anonymous',
          'gender': userData.gender,
          'age': userData.age,
          'height_cm': userData.heightCm,
          'weight_kg': userData.weightKg,
          'activity_level': userData.activityLevel,
          'goal': userData.goal,
          'pace': userData.pace,
          'target_weight_kg': userData.targetWeightKg,
          'tdee': {
            'calories': userData.tdeeCalories,
            'protein': userData.tdeeProtein,
            'carbs': userData.tdeeCarbs,
            'fat': userData.tdeeFat,
          }
        }),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        debugPrint('⏱️ API timeout khi gửi dữ liệu người dùng');
        return http.Response('Timeout', 408);
      });
      
      debugPrint('API Response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi dữ liệu người dùng lên API: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // ƯU TIÊN: Lấy dữ liệu trực tiếp từ Firestore trước
      debugPrint('🔍 Đang tìm kiếm dữ liệu người dùng từ Firestore...');
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        debugPrint('✅ Đã lấy thông tin người dùng từ Firestore');
        return docSnapshot.data();
      }
      
      // Nếu không có dữ liệu trong Firestore, thử lấy từ API
      debugPrint('⚠️ Không tìm thấy dữ liệu trong Firestore, thử lấy từ API...');
      final url = Uri.parse('${getApiUrl()}/$userId');
      final response = await http.get(url).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ API timeout khi lấy dữ liệu người dùng');
          return http.Response('Timeout', 408);
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Đã lấy thông tin người dùng từ API');
        
        // Lưu dữ liệu vào Firestore để sử dụng offline
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set(
            data,
            SetOptions(merge: true),
          );
          debugPrint('✅ Đã lưu dữ liệu người dùng từ API vào Firestore');
        } catch (e) {
          debugPrint('⚠️ Không thể lưu dữ liệu API vào Firestore: $e');
        }
        
        return data;
      } else {
        debugPrint('⚠️ Không thể lấy dữ liệu từ API: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy thông tin người dùng: $e');
      return null;
    }
  }
}