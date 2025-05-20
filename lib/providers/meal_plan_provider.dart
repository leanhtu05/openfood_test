import 'package:flutter/foundation.dart';
import '../models/meal_plan.dart';
import '../services/meal_plan_service.dart';

class MealPlanProvider with ChangeNotifier {
  final MealPlanService _mealPlanService = MealPlanService();
  
  MealPlan? _currentMealPlan;
  List<MealPlanHistory> _mealPlanHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  MealPlan? get currentMealPlan => _currentMealPlan;
  List<MealPlanHistory> get mealPlanHistory => _mealPlanHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Tạo kế hoạch thực đơn cho cả tuần
  Future<void> generateWeeklyMealPlan({
    required String userId,
    required double caloriesGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
  }) async {
    _setLoading(true);
    try {
      _currentMealPlan = await _mealPlanService.generateWeeklyMealPlan(
        userId: userId,
        caloriesGoal: caloriesGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      print('Error generating weekly meal plan: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Thay thế kế hoạch thực đơn cho một ngày
  Future<void> replaceDayMealPlan({
    required String userId,
    required String dayOfWeek,
    required double caloriesGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
  }) async {
    _setLoading(true);
    try {
      final updatedDayPlan = await _mealPlanService.replaceDayMealPlan(
        userId: userId,
        dayOfWeek: dayOfWeek,
        caloriesGoal: caloriesGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
      );
      
      // Cập nhật kế hoạch tuần hiện tại
      if (_currentMealPlan != null) {
        final updatedWeeklyPlan = {..._currentMealPlan!.weeklyPlan};
        updatedWeeklyPlan[dayOfWeek] = updatedDayPlan;
        
        _currentMealPlan = MealPlan(
          id: _currentMealPlan!.id,
          userId: _currentMealPlan!.userId,
          createdAt: _currentMealPlan!.createdAt,
          weeklyPlan: updatedWeeklyPlan,
          nutritionTargets: _currentMealPlan!.nutritionTargets,
        );
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      print('Error replacing day meal plan: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Tạo lại kế hoạch thực đơn cho cả tuần
  Future<void> replaceWeeklyMealPlan({
    required String userId,
    required double caloriesGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
  }) async {
    _setLoading(true);
    try {
      _currentMealPlan = await _mealPlanService.replaceWeeklyMealPlan(
        userId: userId,
        caloriesGoal: caloriesGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      print('Error replacing weekly meal plan: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Lấy lịch sử kế hoạch thực đơn
  Future<void> loadMealPlanHistory(String userId) async {
    _setLoading(true);
    try {
      _mealPlanHistory = await _mealPlanService.getMealPlanHistory(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      print('Error loading meal plan history: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Xóa một kế hoạch thực đơn
  Future<bool> deleteMealPlan(String filename, String userId) async {
    _setLoading(true);
    try {
      final success = await _mealPlanService.deleteMealPlan(filename);
      if (success) {
        // Cập nhật lịch sử
        await loadMealPlanHistory(userId);
      }
      _errorMessage = null;
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      print('Error deleting meal plan: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Helper method để set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Reset error
  void resetError() {
    _errorMessage = null;
    notifyListeners();
  }
} 