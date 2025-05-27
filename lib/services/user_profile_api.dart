import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../providers/user_data_provider.dart';
import '../models/food_entry.dart';
import '../models/meal_plan.dart';
import '../models/exercise.dart';
import '../models/water_entry.dart';
import 'api_service.dart';

class ApiService {
  // Base URL for FastAPI server
  // When running on Android emulator, use 10.0.2.2 to connect to host's localhost
  static const String baseUrl = 'http://192.168.0.101:8000/api';
  
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
  
  // Get user profile from FastAPI
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$userProfileUrl/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile from API: $e');
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
  
  // Get meal plan from FastAPI
  static Future<Map<String, dynamic>?> getMealPlan(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$mealPlanUrl/$userId'),
        headers: {'Content-Type': 'application/json'},
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
  
  // Get food logs by date from FastAPI
  static Future<List<FoodEntry>?> getFoodEntriesByDate(String userId, String date) async {
    try {
      final response = await http.get(
        Uri.parse('$foodLogUrl/$userId/$date'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => FoodEntry.fromJson(item)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting food entries from API: $e');
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

  // Gửi thông tin người dùng đầy đủ đến endpoint /firestore/users/{user_id}
  static Future<bool> sendUserProfileToFirestore(String userId, Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$firestoreUsersUrl/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
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
      final response = await http.post(
        Uri.parse('$firestoreUsersUrl/sync?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );
      
      debugPrint('API Response (syncUserProfileToFirestore): ${response.statusCode} - ${response.body}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error syncing user profile to Firestore API: $e');
      return false;
    }
  }
}

class UserProfileApi {
  // Giữ lại các phương thức đơn giản để tương thích ngược
  static String getApiUrl() {
    return ApiService.userProfileUrl;
  }
  
  static Future<bool> sendUserProfile(UserDataProvider userData) {
    // Chuyển tiếp đến ApiService
    return ApiService.sendUserProfile(userData);
  }
  
  static Future<Map<String, dynamic>?> getUserProfile(String userId) {
    // Chuyển tiếp đến ApiService
    return ApiService.getUserProfile(userId);
  }
} 