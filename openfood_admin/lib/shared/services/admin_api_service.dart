import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_user.dart';
import '../models/meal_plan.dart';

class AdminApiService {
  static const String baseUrl = 'https://backend-openfood.onrender.com';
  
  // ===== USER MANAGEMENT =====
  
  /// Lấy danh sách tất cả người dùng
  static Future<List<AppUser>> getAllUsers({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/users?page=$page&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AppUser.fromFirestore(json)).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }
  
  /// Lấy thông tin chi tiết một người dùng
  static Future<AppUser?> getUserById(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AppUser.fromFirestore(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }
  
  /// Cập nhật thông tin người dùng
  static Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/firestore/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }
  
  /// Xóa người dùng
  static Future<bool> deleteUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/firestore/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }
  
  // ===== MEAL PLAN MANAGEMENT =====
  
  /// Lấy tất cả meal plans
  static Future<List<MealPlan>> getAllMealPlans({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/meal-plans?page=$page&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MealPlan.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load meal plans: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching meal plans: $e');
      return [];
    }
  }
  
  /// Lấy meal plans của một user cụ thể
  static Future<List<MealPlan>> getUserMealPlans(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/meal-plans/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MealPlan.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching user meal plans: $e');
      return [];
    }
  }
  
  // ===== ANALYTICS =====
  
  /// Lấy thống kê tổng quan
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/dashboard-stats'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'total_users': 0,
          'active_users_today': 0,
          'meal_plans_generated': 0,
          'ai_requests_today': 0,
        };
      }
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      return {
        'total_users': 0,
        'active_users_today': 0,
        'meal_plans_generated': 0,
        'ai_requests_today': 0,
      };
    }
  }
  
  /// Lấy thống kê người dùng theo thời gian
  static Future<List<Map<String, dynamic>>> getUserGrowthStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/user-growth?start=${startDate.toIso8601String()}&end=${endDate.toIso8601String()}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching user growth stats: $e');
      return [];
    }
  }
  
  /// Lấy thống kê sử dụng tính năng
  static Future<Map<String, dynamic>> getFeatureUsageStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/feature-usage'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {};
      }
    } catch (e) {
      print('Error fetching feature usage stats: $e');
      return {};
    }
  }
  
  // ===== SYSTEM MANAGEMENT =====
  
  /// Kiểm tra trạng thái hệ thống
  static Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api-status'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'message': 'API not responding'};
      }
    } catch (e) {
      print('Error checking system health: $e');
      return {'status': 'error', 'message': 'Connection failed'};
    }
  }
  
  /// Kiểm tra trạng thái AI service
  static Future<Map<String, dynamic>> getAIServiceStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/check-ai-availability'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'available': false, 'message': 'AI service not responding'};
      }
    } catch (e) {
      print('Error checking AI service: $e');
      return {'available': false, 'message': 'Connection failed'};
    }
  }
}
