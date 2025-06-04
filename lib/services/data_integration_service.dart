import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import '../providers/user_data_provider.dart' as udp;
import 'api_service.dart';

/// Service to integrate data between local storage, Firestore, and API
class DataIntegrationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Get current user ID
  String? get userId => _auth.currentUser?.uid;
  
  // Sync user profile data to API only
  Future<bool> syncUserProfileData(udp.UserDataProvider userData) async {
    if (userId == null) {
      debugPrint('❌ Cannot sync user profile: No authenticated user found');
      return false;
    }
    
    try {
      // Chuẩn bị đầy đủ dữ liệu người dùng để đồng bộ
      final Map<String, dynamic> fullUserData = {
        'user_id': userId,
        'name': userData.name,
        'gender': userData.gender,
        'age': userData.age,
        'height_cm': userData.heightCm,
        'weight_kg': userData.weightKg,
        'activity_level': userData.activityLevel,
        'goal': userData.goal,
        'pace': userData.pace,
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
        'nutrition_goals': userData.nutritionGoals,
        'daily_calories': userData.dailyCalories,
        'tdee': {
          'calories': userData.tdeeCalories,
          'protein': userData.tdeeProtein,
          'carbs': userData.tdeeCarbs,
          'fat': userData.tdeeFat,
        },
        'preferences': userData.preferences,
        'allergies': userData.allergies,
        'cuisine_style': userData.cuisineStyle,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Sử dụng phương thức để đồng bộ đầy đủ dữ liệu qua API
      final result = await ApiService.syncFullUserData(userId!, fullUserData);
      
      if (result) {
        debugPrint('✅ Đã đồng bộ đầy đủ dữ liệu người dùng thành công qua API');
        return true;
      } else {
        debugPrint('❌ Đồng bộ đầy đủ dữ liệu người dùng thất bại');
        
        // Thử lại với endpoint khác
        try {
          final fallbackResult = await ApiService.sendUserProfileData(fullUserData);
          if (fallbackResult) {
            debugPrint('✅ Đã đồng bộ dữ liệu người dùng thành công qua API (fallback)');
            return true;
          }
        } catch (e) {
          debugPrint('❌ Lỗi khi đồng bộ dữ liệu người dùng (fallback): $e');
        }
        
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error syncing user profile: $e');
      return false;
    }
  }
  
  // Lấy thông tin người dùng trực tiếp từ Firebase
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (userId == null) {
      debugPrint('❌ Không thể lấy thông tin người dùng: Không tìm thấy người dùng đã xác thực');
      return null;
    }
    
    try {
      // Lấy dữ liệu trực tiếp từ Firestore
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        debugPrint('✅ Đã lấy thông tin người dùng từ Firestore');
        return docSnapshot.data();
      }
      
      // Nếu không có dữ liệu trong Firestore, lấy thông tin cơ bản từ Firebase Auth
      final user = _auth.currentUser;
      if (user != null) {
        return {
          'user_id': user.uid,
          'email': user.email,
          'display_name': user.displayName,
          'photo_url': user.photoURL,
        };
      }
      
      debugPrint('⚠️ Không tìm thấy hồ sơ người dùng');
      return null;
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy thông tin người dùng: $e');
      return null;
    }
  }
  
  // Sync meal plan to FastAPI only
  Future<bool> syncMealPlanToAPI(Map<String, dynamic> mealPlanData) async {
    try {
      // Send to FastAPI only
      final apiResult = await ApiService.sendMealPlan(mealPlanData);
      
      if (apiResult) {
        debugPrint('✅ Successfully sent meal plan to FastAPI');
      } else {
        debugPrint('❌ Failed to send meal plan to FastAPI');
      }
      
      return apiResult;
    } catch (e) {
      debugPrint('❌ Error syncing meal plan: $e');
      return false;
    }
  }
  
  // Lấy kế hoạch ăn trực tiếp từ Firestore
  Future<Map<String, dynamic>> getMealPlan() async {
    try {
      // Lấy user ID
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('⚠️ Không có người dùng đã xác thực, trả về kế hoạch ăn trống');
        return {};
      }
      
      // Lấy dữ liệu trực tiếp từ Firestore
      final docSnapshot = await _firestore.collection('meal_plans').doc(userId).get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        debugPrint('✅ Đã lấy kế hoạch ăn từ Firestore');
        return docSnapshot.data()!;
      }
      
      debugPrint('⚠️ Không tìm thấy kế hoạch ăn trong Firestore');
      return {};
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy kế hoạch ăn: $e');
      return {};
    }
  }
  
  // Sync food entry to FastAPI only
  Future<bool> syncFoodEntry(dynamic foodEntry) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('⚠️ No authenticated user, can\'t sync food entry');
        return false;
      }
      
      // Send to FastAPI only
      final apiResult = await ApiService.sendFoodEntry(foodEntry, userId);
      
      if (apiResult) {
        debugPrint('✅ Added food entry to API');
      } else {
        debugPrint('❌ Failed to add food entry to API');
      }
      
      return apiResult;
    } catch (e) {
      debugPrint('❌ Error syncing food entry: $e');
      return false;
    }
  }
} 