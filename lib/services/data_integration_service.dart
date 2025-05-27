import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import '../providers/user_data_provider.dart';
import 'api_service.dart';

/// Service to integrate data between local storage, Firestore, and API
class DataIntegrationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Get current user ID
  String? get userId => _auth.currentUser?.uid;
  
  // Sync user profile data to API only
  Future<bool> syncUserProfileData(UserDataProvider userData) async {
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
  
  // Get user profile from API only
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (userId == null) {
      debugPrint('❌ Cannot get user profile: No authenticated user found');
      return null;
    }
    
    try {
      // Get data from API
      final apiData = await ApiService.getUserProfile(userId!);
      if (apiData != null && apiData.isNotEmpty) {
        debugPrint('✅ Got user profile from API');
        return apiData;
      }
      
      debugPrint('⚠️ User profile not found in API');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user profile from API: $e');
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
  
  // Get meal plan from API only
  Future<Map<String, dynamic>> getMealPlan() async {
    try {
      // Get user ID
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('⚠️ No authenticated user, returning empty meal plan');
        return {};
      }
      
      // Get from API
      final apiData = await ApiService.getMealPlan(userId);
      if (apiData != null && apiData.isNotEmpty) {
        debugPrint('✅ Got meal plan from API');
        return apiData;
      }
      
      debugPrint('⚠️ No meal plan found in API');
      return {};
    } catch (e) {
      debugPrint('❌ Error getting meal plan from API: $e');
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