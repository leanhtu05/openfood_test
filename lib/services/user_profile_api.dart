import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../providers/user_data_provider.dart';

class UserProfileApi {
  // Điều chỉnh URL của FastAPI server
  // Khi chạy trên máy ảo Android, sử dụng 10.0.2.2 để kết nối với localhost của máy host
  static const String apiUrl = 'http://192.168.0.101:8000/api/user-profile';
  
  // Getter cho API URL
  static String getApiUrl() {
    return apiUrl;
  }
  
  // Gửi dữ liệu người dùng đến FastAPI
  static Future<bool> sendUserProfile(UserDataProvider userData) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
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
      debugPrint('Lỗi khi gửi dữ liệu đến API: $e');
      return false;
    }
  }
} 