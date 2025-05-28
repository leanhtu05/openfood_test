import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/meal_firebase_service.dart';

class MealPlanProvider with ChangeNotifier {
  final MealPlanService _mealPlanService = MealPlanService();
  final MealFirebaseService _firebaseService = MealFirebaseService();
  
  MealPlan? _currentMealPlan;
  List<MealPlanHistory> _mealPlanHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _syncEnabled = true; // Mặc định bật đồng bộ với Firebase

  // Getters
  MealPlan? get currentMealPlan => _currentMealPlan;
  List<MealPlanHistory> get mealPlanHistory => _mealPlanHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get syncEnabled => _syncEnabled;
  
  // Setter cho syncEnabled
  set syncEnabled(bool value) {
    _syncEnabled = value;
    notifyListeners();
  }

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
      // Tạo kế hoạch từ API
      _currentMealPlan = await _mealPlanService.generateWeeklyMealPlan(
        userId: userId,
        caloriesGoal: caloriesGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
      );
      
      // Đồng bộ lên Firebase nếu được bật
      if (_syncEnabled && _currentMealPlan != null) {
        await _firebaseService.saveMealPlan(_currentMealPlan!);
        debugPrint('Đã đồng bộ kế hoạch bữa ăn lên Firebase');
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Lỗi khi tạo kế hoạch bữa ăn: $e');
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
        
        // Đồng bộ lên Firebase nếu được bật
        if (_syncEnabled) {
          await _firebaseService.saveMealPlan(_currentMealPlan!);
          debugPrint('Đã đồng bộ kế hoạch bữa ăn đã cập nhật lên Firebase');
        }
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Lỗi khi thay thế kế hoạch bữa ăn cho một ngày: $e');
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
      
      // Đồng bộ lên Firebase nếu được bật
      if (_syncEnabled && _currentMealPlan != null) {
        await _firebaseService.saveMealPlan(_currentMealPlan!);
        debugPrint('Đã đồng bộ kế hoạch bữa ăn mới lên Firebase');
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Lỗi khi thay thế kế hoạch bữa ăn cho cả tuần: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Lấy lịch sử kế hoạch thực đơn
  Future<void> loadMealPlanHistory(String userId) async {
    _setLoading(true);
    try {
      if (_syncEnabled) {
        // Ưu tiên lấy từ Firebase nếu đồng bộ được bật
        _mealPlanHistory = await _firebaseService.getMealPlanHistory(userId);
        debugPrint('Đã lấy lịch sử kế hoạch bữa ăn từ Firebase');
      } else {
        // Nếu không, lấy từ API
        _mealPlanHistory = await _mealPlanService.getMealPlanHistory(userId);
        debugPrint('Đã lấy lịch sử kế hoạch bữa ăn từ API');
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Lỗi khi lấy lịch sử kế hoạch bữa ăn: $e');
      
      // Thử lấy từ nguồn khác nếu nguồn đầu tiên thất bại
      try {
        if (_syncEnabled) {
          _mealPlanHistory = await _mealPlanService.getMealPlanHistory(userId);
          debugPrint('Đã lấy lịch sử kế hoạch bữa ăn từ API (backup)');
        } else {
          _mealPlanHistory = await _firebaseService.getMealPlanHistory(userId);
          debugPrint('Đã lấy lịch sử kế hoạch bữa ăn từ Firebase (backup)');
        }
        _errorMessage = null;
      } catch (backupError) {
        debugPrint('Lỗi khi lấy lịch sử kế hoạch bữa ăn từ nguồn backup: $backupError');
      }
    } finally {
      _setLoading(false);
    }
  }

  // Xóa một kế hoạch thực đơn
  Future<bool> deleteMealPlan(String planId, String userId) async {
    _setLoading(true);
    try {
      bool success = false;
      
      // Xóa từ API
      try {
        success = await _mealPlanService.deleteMealPlan(planId);
        debugPrint('Đã xóa kế hoạch bữa ăn từ API');
      } catch (apiError) {
        debugPrint('Lỗi khi xóa kế hoạch bữa ăn từ API: $apiError');
      }
      
      // Xóa từ Firebase nếu đồng bộ được bật
      if (_syncEnabled) {
        try {
          final firebaseSuccess = await _firebaseService.deleteMealPlan(planId, userId);
          success = success || firebaseSuccess; // Thành công nếu ít nhất một trong hai thành công
          debugPrint('Đã xóa kế hoạch bữa ăn từ Firebase');
        } catch (firebaseError) {
          debugPrint('Lỗi khi xóa kế hoạch bữa ăn từ Firebase: $firebaseError');
        }
      }
      
      if (success) {
        // Cập nhật lịch sử
        await loadMealPlanHistory(userId);
      }
      
      _errorMessage = null;
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Lỗi khi xóa kế hoạch bữa ăn: $e');
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
  
  // Tải kế hoạch bữa ăn hiện tại từ Firebase
  Future<void> loadCurrentMealPlanFromFirebase(String userId) async {
    if (!_syncEnabled) return;
    
    _setLoading(true);
    try {
      final mealPlan = await _firebaseService.getCurrentMealPlan(userId);
      if (mealPlan != null) {
        _currentMealPlan = mealPlan;
        debugPrint('✅ Đã tải kế hoạch bữa ăn hiện tại từ Firebase');
        notifyListeners();
      } else {
        debugPrint('ℹ️ Không tìm thấy kế hoạch bữa ăn trên Firebase');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải kế hoạch bữa ăn từ Firebase: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Đồng bộ kế hoạch bữa ăn hiện tại lên Firebase
  Future<bool> syncCurrentMealPlanToFirebase() async {
    if (!_syncEnabled || _currentMealPlan == null) return false;
    
    try {
      final success = await _firebaseService.saveMealPlan(_currentMealPlan!);
      if (success) {
        debugPrint('✅ Đã đồng bộ kế hoạch bữa ăn hiện tại lên Firebase');
      }
      return success;
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ kế hoạch bữa ăn lên Firebase: $e');
      return false;
    }
  }
  
  // Lấy dữ liệu từ Firebase khi đăng nhập
  Future<void> initializeAfterLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_syncEnabled) return;
    
    try {
      // Tải kế hoạch bữa ăn hiện tại
      await loadCurrentMealPlanFromFirebase(user.uid);
      
      // Tải lịch sử kế hoạch bữa ăn
      await loadMealPlanHistory(user.uid);
      
      debugPrint('✅ Đã khởi tạo dữ liệu bữa ăn sau khi đăng nhập');
    } catch (e) {
      debugPrint('❌ Lỗi khi khởi tạo dữ liệu bữa ăn: $e');
    }
  }
}