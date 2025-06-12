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

        return true;
      } else {

        // Thử lại với endpoint khác
        try {
          final fallbackResult = await ApiService.sendUserProfileData(fullUserData);
          if (fallbackResult) {

            return true;
          }
        } catch (e) {

        }
        
        return false;
      }
    } catch (e) {

      return false;
    }
  }
  
  // Lấy thông tin người dùng trực tiếp từ Firebase
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (userId == null) {

      return null;
    }
    
    try {
      // Lấy dữ liệu trực tiếp từ Firestore
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {

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

      return null;
    } catch (e) {

      return null;
    }
  }
  
  // Sync meal plan to FastAPI only
  Future<bool> syncMealPlanToAPI(Map<String, dynamic> mealPlanData) async {
    try {
      // Send to FastAPI only
      final apiResult = await ApiService.sendMealPlan(mealPlanData);
      
      if (apiResult) {

      } else {

      }
      
      return apiResult;
    } catch (e) {

      return false;
    }
  }
  
  // Lấy kế hoạch ăn trực tiếp từ Firestore
  Future<Map<String, dynamic>> getMealPlan() async {
    try {
      // Lấy user ID
      final userId = _auth.currentUser?.uid;
      if (userId == null) {

        return {};
      }
      
      // Lấy dữ liệu trực tiếp từ Firestore
      final docSnapshot = await _firestore.collection('meal_plans').doc(userId).get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {

        return docSnapshot.data()!;
      }

      return {};
    } catch (e) {

      return {};
    }
  }
  
  // Sync food entry to FastAPI only
  Future<bool> syncFoodEntry(dynamic foodEntry) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {

        return false;
      }
      
      // Send to FastAPI only
      final apiResult = await ApiService.sendFoodEntry(foodEntry, userId);
      
      if (apiResult) {

      } else {

      }
      
      return apiResult;
    } catch (e) {

      return false;
    }
  }
} 