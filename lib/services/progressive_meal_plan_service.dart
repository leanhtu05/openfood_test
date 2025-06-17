import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan.dart';
import '../utils/config.dart' as app_config;
import '../services/api_service.dart';

class ProgressiveMealPlanService {
  static const int DAYS_PER_BATCH = 2; // Tạo 2 ngày một lần
  static const int MAX_DAYS_AHEAD = 7; // Tối đa 7 ngày
  
  /// Kiểm tra và tạo kế hoạch ăn theo từng batch sử dụng replace_day endpoint
  static Future<MealPlan?> checkAndGenerateProgressivePlan({
    required String userId,
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    Map<String, dynamic>? userPreferences,
  }) async {
    try {
      print('🔄 Bắt đầu kiểm tra kế hoạch ăn progressive với replace_day...');
      
      // 1. Kiểm tra kế hoạch hiện tại
      final existingPlan = await _getExistingMealPlan(userId);
      final today = DateTime.now();
      
      if (existingPlan == null) {
        // Người dùng mới - tạo 2 ngày đầu tiên
        print('👤 Người dùng mới - tạo kế hoạch 2 ngày đầu bằng replace_day');
        return await _generateDaysRangeWithReplaceDay(
          userId: userId,
          startDate: today,
          daysCount: DAYS_PER_BATCH,
          caloriesTarget: caloriesTarget,
          proteinTarget: proteinTarget,
          fatTarget: fatTarget,
          carbsTarget: carbsTarget,
          userPreferences: userPreferences,
          isFirstTime: true,
        );
      }
      
      // 2. Kiểm tra ngày nào cần tạo thêm
      final missingDays = _getMissingDays(existingPlan, today);
      
      if (missingDays.isNotEmpty) {
        print('📅 Cần tạo thêm ${missingDays.length} ngày: ${missingDays.map((d) => d.toString().split(' ')[0]).join(', ')}');
        
        // Tạo từng batch 2 ngày bằng replace_day
        return await _generateMissingDaysWithReplaceDay(
          userId: userId,
          existingPlan: existingPlan,
          missingDays: missingDays,
          caloriesTarget: caloriesTarget,
          proteinTarget: proteinTarget,
          fatTarget: fatTarget,
          carbsTarget: carbsTarget,
          userPreferences: userPreferences,
        );
      }
      
      print('✅ Kế hoạch ăn đã đầy đủ');
      return existingPlan;
      
    } catch (e) {
      print('❌ Lỗi trong progressive meal planning: $e');
      return null;
    }
  }
  
  /// Lấy kế hoạch ăn hiện tại từ Firestore
  static Future<MealPlan?> _getExistingMealPlan(String userId) async {
    try {
      // Kiểm tra latest_meal_plans trước
      final latestDoc = await FirebaseFirestore.instance
          .collection('latest_meal_plans')
          .doc(userId)
          .get();
          
      if (latestDoc.exists && latestDoc.data() != null) {
        return MealPlan.fromJson(latestDoc.data()!);
      }
      
      // Nếu không có, kiểm tra meal_plans
      final doc = await FirebaseFirestore.instance
          .collection('meal_plans')
          .doc(userId)
          .get();
          
      if (doc.exists && doc.data() != null) {
        return MealPlan.fromJson(doc.data()!);
      }
      
      return null;
    } catch (e) {
      print('❌ Lỗi khi lấy kế hoạch ăn hiện tại: $e');
      return null;
    }
  }
  
  /// Tìm những ngày còn thiếu trong kế hoạch
  static List<DateTime> _getMissingDays(MealPlan existingPlan, DateTime today) {
    final missingDays = <DateTime>[];
    
    // Kiểm tra 7 ngày tới
    for (int i = 0; i < MAX_DAYS_AHEAD; i++) {
      final checkDate = today.add(Duration(days: i));
      final dayName = _getDayName(checkDate);
      
      // Kiểm tra xem ngày này có trong kế hoạch không
      if (!existingPlan.weeklyPlan.containsKey(dayName) || 
          existingPlan.weeklyPlan[dayName] == null ||
          existingPlan.weeklyPlan[dayName]!.meals.isEmpty) {
        missingDays.add(checkDate);
      }
    }
    
    return missingDays;
  }
  
  /// Tạo kế hoạch cho một khoảng ngày sử dụng replace_day endpoint
  static Future<MealPlan?> _generateDaysRangeWithReplaceDay({
    required String userId,
    required DateTime startDate,
    required int daysCount,
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    Map<String, dynamic>? userPreferences,
    bool isFirstTime = false,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      
      // Tạo danh sách ngày cần generate
      final targetDays = <String>[];
      for (int i = 0; i < daysCount; i++) {
        final date = startDate.add(Duration(days: i));
        targetDays.add(_getDayName(date));
      }
      
      print('🔄 Tạo kế hoạch ${daysCount} ngày: ${targetDays.join(', ')} bằng replace_day endpoint');
      
      // Sử dụng replace_day endpoint cho từng ngày
      for (final dayName in targetDays) {
        final replaceUrl = Uri.parse('${app_config.apiBaseUrl}${app_config.ApiEndpoints.replaceDay}');
        
        final requestData = {
          'user_id': userId,
          'day_of_week': dayName,
          'calories_target': caloriesTarget.round(),
          'protein_target': proteinTarget.round(),
          'fat_target': fatTarget.round(),
          'carbs_target': carbsTarget.round(),
          'use_ai': true,
        };
        
        // Thêm preferences nếu có
        if (userPreferences != null) {
          userPreferences.forEach((key, value) {
            requestData[key] = value;
          });
        }
        
        print('🔄 Tạo ngày $dayName: ${jsonEncode(requestData)}');
        
        final response = await http.post(
          replaceUrl,
          headers: {
            ...headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestData),
        ).timeout(
          Duration(seconds: 30),
          onTimeout: () {
            print('⏱️ Timeout khi tạo ngày $dayName');
            return http.Response('{"error": "Timeout"}', 408);
          },
        );
        
        if (response.statusCode == 200) {
          print('✅ Tạo thành công ngày $dayName');
          // Đợi một chút giữa các request để tránh overload
          await Future.delayed(Duration(seconds: 1));
        } else {
          print('❌ Lỗi khi tạo ngày $dayName: ${response.statusCode} - ${response.body}');
        }
      }
      
      // Đợi một chút để API lưu vào Firestore
      await Future.delayed(Duration(seconds: 3));
      
      // Lấy kế hoạch mới từ Firestore
      return await _getExistingMealPlan(userId);
      
    } catch (e) {
      print('❌ Lỗi khi tạo kế hoạch ${daysCount} ngày: $e');
      return null;
    }
  }
  
  /// Tạo những ngày còn thiếu sử dụng replace_day
  static Future<MealPlan?> _generateMissingDaysWithReplaceDay({
    required String userId,
    required MealPlan existingPlan,
    required List<DateTime> missingDays,
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    Map<String, dynamic>? userPreferences,
  }) async {
    // Tạo từng batch 2 ngày
    final batches = <List<DateTime>>[];
    for (int i = 0; i < missingDays.length; i += DAYS_PER_BATCH) {
      final end = (i + DAYS_PER_BATCH < missingDays.length) 
          ? i + DAYS_PER_BATCH 
          : missingDays.length;
      batches.add(missingDays.sublist(i, end));
    }
    
    // Tạo batch đầu tiên (ưu tiên cao nhất)
    if (batches.isNotEmpty) {
      final firstBatch = batches.first;
      print('🔄 Tạo batch đầu tiên: ${firstBatch.length} ngày bằng replace_day');
      
      return await _generateDaysRangeWithReplaceDay(
        userId: userId,
        startDate: firstBatch.first,
        daysCount: firstBatch.length,
        caloriesTarget: caloriesTarget,
        proteinTarget: proteinTarget,
        fatTarget: fatTarget,
        carbsTarget: carbsTarget,
        userPreferences: userPreferences,
      );
    }
    
    return existingPlan;
  }
  
  /// Thay thế một ngày cụ thể trong kế hoạch ăn sử dụng replace_day endpoint
  static Future<MealPlan?> replaceDayInPlan({
    required String userId,
    required String dayOfWeek,
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    Map<String, dynamic>? userPreferences,
  }) async {
    try {
      print('🔄 Thay thế ngày $dayOfWeek trong kế hoạch bằng replace_day...');
      
      final headers = await ApiService.getAuthHeaders();
      final replaceUrl = Uri.parse('${app_config.apiBaseUrl}${app_config.ApiEndpoints.replaceDay}');
      
      final requestData = {
        'user_id': userId,
        'day_of_week': dayOfWeek,
        'calories_target': caloriesTarget.round(),
        'protein_target': proteinTarget.round(),
        'fat_target': fatTarget.round(),
        'carbs_target': carbsTarget.round(),
        'use_ai': true,
      };
      
      // Thêm preferences nếu có
      if (userPreferences != null) {
        userPreferences.forEach((key, value) {
          requestData[key] = value;
        });
      }
      
      print('🔄 Gửi yêu cầu thay thế ngày: ${jsonEncode(requestData)}');
      
      final response = await http.post(
        replaceUrl,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ Timeout khi thay thế ngày $dayOfWeek');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        print('✅ Thay thế ngày $dayOfWeek thành công');
        
        // Đợi một chút để API lưu vào Firestore
        await Future.delayed(Duration(seconds: 2));
        
        // Lấy kế hoạch mới từ Firestore
        return await _getExistingMealPlan(userId);
      } else {
        print('❌ Lỗi API khi thay thế ngày: ${response.statusCode} - ${response.body}');
        return null;
      }
      
    } catch (e) {
      print('❌ Lỗi khi thay thế ngày $dayOfWeek: $e');
      return null;
    }
  }
  
  /// Lấy tên ngày theo định dạng tiếng Anh
  static String _getDayName(DateTime date) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 
      'Friday', 'Saturday', 'Sunday'
    ];
    return days[date.weekday - 1];
  }
  
  /// Kiểm tra xem có cần tạo thêm kế hoạch không
  static bool shouldGenerateMore(MealPlan? currentPlan) {
    if (currentPlan == null) return true;
    
    final today = DateTime.now();
    final missingDays = _getMissingDays(currentPlan, today);
    
    return missingDays.isNotEmpty;
  }
  
  /// Lấy thông báo trạng thái cho UI
  static String getStatusMessage(MealPlan? currentPlan) {
    if (currentPlan == null) {
      return 'Đang tạo kế hoạch ăn cho bạn...';
    }
    
    final today = DateTime.now();
    final missingDays = _getMissingDays(currentPlan, today);
    
    if (missingDays.isEmpty) {
      return 'Kế hoạch ăn đã sẵn sàng cho 7 ngày tới!';
    } else {
      return 'Đang chuẩn bị thêm ${missingDays.length} ngày...';
    }
  }
}
