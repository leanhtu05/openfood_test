import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/meal_plan.dart';
import '../utils/constants.dart';

class MealPlanService {
  final String baseUrl = ApiEndpoints.baseUrl;

  // Tạo kế hoạch thực đơn cho cả tuần
  Future<MealPlan> generateWeeklyMealPlan({
    required String userId,
    required double caloriesGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-weekly-meal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'calories_target': caloriesGoal,
          'protein_target': proteinGoal,
          'fat_target': fatGoal,
          'carbs_target': carbsGoal,
        }),
      );

      if (response.statusCode == 200) {
        return MealPlan.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to generate meal plan: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to meal plan service: $e');
    }
  }

  // Thay thế kế hoạch thực đơn cho một ngày
  Future<DayMealPlan> replaceDayMealPlan({
    required String userId,
    required String dayOfWeek,
    required double caloriesGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/replace-day'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'day': dayOfWeek,
          'calories_target': caloriesGoal,
          'protein_target': proteinGoal,
          'fat_target': fatGoal,
          'carbs_target': carbsGoal,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return DayMealPlan.fromJson(responseData['day_plan']);
      } else {
        throw Exception('Failed to replace day meal plan: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to meal plan service: $e');
    }
  }

  // Tạo lại kế hoạch thực đơn cho cả tuần
  Future<MealPlan> replaceWeeklyMealPlan({
    required String userId,
    required double caloriesGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/replace-week'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'calories_target': caloriesGoal,
          'protein_target': proteinGoal,
          'fat_target': fatGoal,
          'carbs_target': carbsGoal,
        }),
      );

      if (response.statusCode == 200) {
        return MealPlan.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to replace weekly meal plan: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to meal plan service: $e');
    }
  }

  // Lấy lịch sử kế hoạch thực đơn
  Future<List<MealPlanHistory>> getMealPlanHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/meal-plan-history?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => MealPlanHistory.fromJson(item)).toList();
      } else {
        throw Exception('Failed to get meal plan history: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to meal plan service: $e');
    }
  }

  // Xóa một kế hoạch thực đơn
  Future<bool> deleteMealPlan(String filename) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/meal-plan/$filename'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error connecting to meal plan service: $e');
    }
  }
} 