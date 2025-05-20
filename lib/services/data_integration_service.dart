import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'user_profile_api.dart';
import '../providers/user_data_provider.dart';

class DataIntegrationService {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Đồng bộ dữ liệu hồ sơ người dùng từ UserDataProvider lên cả Firestore và FastAPI
  Future<bool> syncUserProfileData(UserDataProvider userData) async {
    try {
      // Kiểm tra đăng nhập
      if (_auth.currentUser == null) {
        debugPrint('Chưa đăng nhập, không thể đồng bộ');
        return false;
      }
      
      // Tạo dữ liệu người dùng
      final profileData = _createUserProfileData(userData);
      
      // Lưu vào Firestore
      await _firestoreService.saveUserProfile(profileData);
      debugPrint('Đã lưu hồ sơ người dùng vào Firestore');
      
      // Gửi lên FastAPI
      final apiResult = await UserProfileApi.sendUserProfile(userData);
      if (apiResult) {
        debugPrint('Đã gửi hồ sơ người dùng lên FastAPI');
      } else {
        debugPrint('Không thể gửi hồ sơ người dùng lên FastAPI');
      }
      
      // Nếu lưu vào Firestore thành công, coi như đồng bộ thành công
      // ngay cả khi FastAPI thất bại
      return true;
    } catch (e) {
      debugPrint('Lỗi khi đồng bộ dữ liệu người dùng: $e');
      return false;
    }
  }
  
  // Đồng bộ dữ liệu từ Firestore xuống UserDataProvider
  Future<bool> loadUserProfileFromFirestore(UserDataProvider userData) async {
    try {
      // Kiểm tra đăng nhập
      if (_auth.currentUser == null) {
        debugPrint('Chưa đăng nhập, không thể tải dữ liệu');
        return false;
      }
      
      // Lấy dữ liệu từ Firestore
      final profileData = await _firestoreService.getUserProfile();
      if (profileData.isEmpty) {
        debugPrint('Không có dữ liệu hồ sơ trong Firestore');
        return false;
      }
      
      // Cập nhật vào UserDataProvider
      _updateUserDataFromProfile(userData, profileData);
      debugPrint('Đã tải dữ liệu hồ sơ từ Firestore');
      
      return true;
    } catch (e) {
      debugPrint('Lỗi khi tải dữ liệu hồ sơ từ Firestore: $e');
      return false;
    }
  }
  
  // Đồng bộ kế hoạch ăn lên Firestore
  Future<bool> syncMealPlanToFirestore(Map<String, dynamic> mealPlanData) async {
    try {
      // Kiểm tra đăng nhập
      if (_auth.currentUser == null) {
        debugPrint('Chưa đăng nhập, không thể đồng bộ kế hoạch ăn');
        return false;
      }
      
      // Cập nhật lên Firestore
      await _firestoreService.updateMealPlan(mealPlanData);
      debugPrint('Đã đồng bộ kế hoạch ăn lên Firestore');
      
      return true;
    } catch (e) {
      debugPrint('Lỗi khi đồng bộ kế hoạch ăn: $e');
      return false;
    }
  }
  
  // Tạo đối tượng dữ liệu từ UserDataProvider
  Map<String, dynamic> _createUserProfileData(UserDataProvider userData) {
    return {
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
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
  
  // Cập nhật UserDataProvider từ dữ liệu Firestore
  void _updateUserDataFromProfile(UserDataProvider userData, Map<String, dynamic> profileData) {
    // Chỉ cập nhật các trường có dữ liệu
    if (profileData['gender'] != null) userData.setGender(profileData['gender']);
    if (profileData['age'] != null) userData.setAge(profileData['age']);
    if (profileData['height_cm'] != null) userData.setHeight(profileData['height_cm'].toDouble());
    if (profileData['weight_kg'] != null) userData.setWeight(profileData['weight_kg'].toDouble());
    if (profileData['activity_level'] != null) userData.setActivityLevel(profileData['activity_level']);
    if (profileData['goal'] != null) userData.setGoal(profileData['goal']);
    if (profileData['pace'] != null) userData.setPace(profileData['pace'].toDouble());
    
    if (profileData['nutrition_goals'] != null && profileData['nutrition_goals'] is Map) {
      Map<String, dynamic> nutritionGoals = Map<String, dynamic>.from(profileData['nutrition_goals']);
      userData.updateNutritionGoals(nutritionGoals.map((key, value) => MapEntry(key, (value as num).toDouble())));
    }
    
    if (profileData['target_weight_kg'] != null) userData.targetWeightKg = profileData['target_weight_kg'].toDouble();
    if (profileData['event'] != null) userData.event = profileData['event'];
    
    if (profileData['event_date'] != null && profileData['event_date'] is Map) {
      final eventDate = profileData['event_date'];
      if (eventDate['day'] != null) userData.eventDay = eventDate['day'];
      if (eventDate['month'] != null) userData.eventMonth = eventDate['month'];
      if (eventDate['year'] != null) userData.eventYear = eventDate['year'];
    }
    
    if (profileData['diet_restrictions'] != null && profileData['diet_restrictions'] is List) {
      userData.dietRestrictions = List<String>.from(profileData['diet_restrictions']);
    }
    
    if (profileData['diet_preference'] != null) userData.dietPreference = profileData['diet_preference'];
    
    if (profileData['health_conditions'] != null && profileData['health_conditions'] is List) {
      userData.healthConditions = List<String>.from(profileData['health_conditions']);
    }
    
    // Cập nhật TDEE nếu có
    if (profileData['tdee'] != null && profileData['tdee'] is Map) {
      final tdee = profileData['tdee'];
      userData.updateTDEEValues(
        calories: (tdee['calories'] ?? 0).toDouble(),
        protein: (tdee['protein'] ?? 0).toDouble(),
        carbs: (tdee['carbs'] ?? 0).toDouble(),
        fat: (tdee['fat'] ?? 0).toDouble(),
      );
    }
  }
} 