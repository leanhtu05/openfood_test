import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan.dart';
import '../services/meal_plan_api_service.dart';
import 'package:openfood/models/food_item.dart';
import 'package:openfood/models/food_entry.dart';
import 'package:openfood/models/exercise.dart';
import 'package:openfood/models/water_entry.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../utils/firebase_helpers.dart';

/// Service to interact with Firestore
/// QUAN TRỌNG: Firebase chỉ được sử dụng để đọc dữ liệu, không ghi trực tiếp
/// Tất cả các thao tác ghi dữ liệu phải thông qua API
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  String? get userId => _auth.currentUser?.uid;
  
  // Get user document reference
  DocumentReference? get userDocRef {
    final uid = userId;
    return uid != null ? _firestore.collection('users').doc(uid) : null;
  }
  
  // Get user profile from Firestore
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final uid = userId;
      if (uid == null) {

        return {};
      }
      
      // Kiểm tra Google Play Services
      final isGooglePlayAvailable = await FirebaseHelpers.isGooglePlayServicesAvailable();
      if (!isGooglePlayAvailable) {

        // Thử lấy dữ liệu trực tiếp từ Firestore
        try {
          final docSnapshot = await _firestore.collection('users').doc(uid).get();
          
          if (docSnapshot.exists && docSnapshot.data() != null) {

            return docSnapshot.data()!;
          }
        } catch (e) {

        }
        return {};
      }
      
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {

          // Xử lý các trường thời gian để đảm bảo tương thích
          final processedData = FirebaseHelpers.processFirestoreData(data);
          return processedData;
        }
      }

      return {};
    } catch (e) {

      return {};
    }
  }
  
  // Phương thức xử lý các trường thời gian
  Map<String, dynamic> _processTimestampFields(Map<String, dynamic> data) {
    // Sử dụng helper class mới
    return FirebaseHelpers.processFirestoreData(data);
  }
  
  // Phương thức chuyển đổi an toàn giữa String và Timestamp
  dynamic safeConvertTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    
    return FirebaseHelpers.toTimestamp(value);
  }
  
  // Get weekly meal plan from Firestore
  Future<Map<String, dynamic>> getWeeklyMealPlan() async {
    try {
      final uid = userId;
      if (uid == null) {

        return {};
      }
      
      // Kiểm tra Google Play Services
      final isGooglePlayAvailable = await FirebaseHelpers.isGooglePlayServicesAvailable();
      if (!isGooglePlayAvailable) {

        // Thử lấy dữ liệu từ API
        try {
          final apiData = await ApiService.getUserMealPlan(uid);
          if (apiData != null) {

            return apiData;
          }
        } catch (e) {

        }
        return {};
      }
      
      // Thử lấy từ latest_meal_plans trước
      final latestDocSnapshot = await _firestore.collection('latest_meal_plans').doc(uid).get();
      
      if (latestDocSnapshot.exists) {
        final data = latestDocSnapshot.data();
        if (data != null) {

          return FirebaseHelpers.processFirestoreData(data);
        }
      }
      
      // Nếu không tìm thấy trong latest_meal_plans, thử tìm trong meal_plans
      final docSnapshot = await _firestore.collection('meal_plans').doc(uid).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {

          return FirebaseHelpers.processFirestoreData(data);
        }
      }

      return {};
    } catch (e) {

      return {};
    }
  }
  
  // Get food entries for a specific date
  Future<List<Map<String, dynamic>>> getFoodEntries(String date) async {
    try {
      final uid = userId;
      if (uid == null) {

        return [];
      }
      
      final querySnapshot = await _firestore
          .collection('food_entries')
          .where('user_id', isEqualTo: uid)
          .where('date', isEqualTo: date)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {

        return querySnapshot.docs.map((doc) => doc.data()).toList();
      }

      return [];
    } catch (e) {

      return [];
    }
  }
  
  // Get exercise entries for a specific date
  Future<List<Map<String, dynamic>>> getExerciseEntries(String date) async {
    try {
      final uid = userId;
      if (uid == null) {

        return [];
      }
      
      final querySnapshot = await _firestore
          .collection('exercise_entries')
          .where('user_id', isEqualTo: uid)
          .where('date', isEqualTo: date)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {

        return querySnapshot.docs.map((doc) => doc.data()).toList();
      }

      return [];
    } catch (e) {

      return [];
    }
  }
  
  // Get water entries for a specific date
  Future<List<Map<String, dynamic>>> getWaterEntries(String date) async {
    try {
      final uid = userId;
      if (uid == null) {

        return [];
      }
      
      final querySnapshot = await _firestore
          .collection('water_entries')
          .where('user_id', isEqualTo: uid)
          .where('date', isEqualTo: date)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {

        return querySnapshot.docs.map((doc) => doc.data()).toList();
      }

      return [];
    } catch (e) {

      return [];
    }
  }
  
  // Get user favorites
  Future<List<Map<String, dynamic>>> getUserFavorites() async {
    try {
      final uid = userId;
      if (uid == null) {

        return [];
      }
      
      final querySnapshot = await _firestore
          .collection('favorites')
          .where('user_id', isEqualTo: uid)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {

        return querySnapshot.docs.map((doc) => doc.data()).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }
  
  // Stream weekly meal plan để tương thích với code cũ
  Stream<Map<String, dynamic>> streamWeeklyMealPlan() {
    final uid = userId;
    if (uid == null) {
      // Return empty stream if no user is authenticated
      return Stream.value({});
    }
    
    // Sử dụng StreamController để kết hợp 2 streams
    final StreamController<Map<String, dynamic>> controller = StreamController<Map<String, dynamic>>();
    
    // Lắng nghe sự thay đổi từ latest_meal_plans
    StreamSubscription? latestSubscription;
    StreamSubscription? regularSubscription;
    
    latestSubscription = _firestore.collection('latest_meal_plans').doc(uid).snapshots().listen(
      (latestSnapshot) {
        if (latestSnapshot.exists && latestSnapshot.data() != null) {
          controller.add(latestSnapshot.data()!);
        } else {
          // Hủy đăng ký từ stream hiện tại
          regularSubscription?.cancel();
          
          // Đăng ký stream từ meal_plans
          regularSubscription = _firestore.collection('meal_plans').doc(uid).snapshots().listen(
            (snapshot) {
              if (snapshot.exists && snapshot.data() != null) {
                controller.add(snapshot.data()!);
              } else {
                controller.add({});
              }
            },
            onError: (error) {
              controller.addError(error);
            }
          );
        }
      },
      onError: (error) {
        controller.addError(error);
      }
    );
    
    // Đảm bảo hủy tất cả subscriptions khi stream bị đóng
    controller.onCancel = () {
      latestSubscription?.cancel();
      regularSubscription?.cancel();
    };
    
    return controller.stream;
  }
  
  // Update meal plan để tương thích với code cũ
  Future<void> updateMealPlan(Map<String, dynamic> mealPlanData) async {
    try {
      final uid = userId;
      if (uid == null) {
        return;
      }
      
      // Sử dụng API để cập nhật meal plan
      final success = await ApiService.sendMealPlan({
        'user_id': uid,
        'meal_plan': mealPlanData
      });
      
      if (success) {
      } else {
      }
    } catch (e) {
    }
  }
  
  // Save user profile để tương thích với code cũ
  Future<void> saveUserProfile(Map<String, dynamic> userData) async {
    try {
      final uid = userId;
      if (uid == null) {
        return;
      }
      
      // Chuẩn bị dữ liệu trước khi gửi lên Firebase - đảm bảo tất cả Timestamp được chuyển thành chuỗi
      final preparedData = FirebaseHelpers.prepareAnyDataForJson(userData);
      
      // Sử dụng API để cập nhật user profile
      final success = await ApiService.sendUserProfileToFirestore(uid, preparedData);
      
      if (success) {
      } else {
      }
    } catch (e) {
    }
  }
  
  // Thêm mới một bản ghi thức ăn
  Future<String> addFoodEntry(FoodEntry entry) async {
    try {
      final uid = userId;
      if (uid == null) {
        throw Exception('Không có người dùng đăng nhập');
      }
      
      // Chuẩn bị dữ liệu để lưu vào Firestore
      final data = entry.toJson();
      data['user_id'] = uid;
      
      // Xử lý các trường thời gian
      final preparedData = FirebaseHelpers.prepareDataForFirestore(data);
      
      // Tạo một ID mới nếu không có
      final docRef = _firestore.collection('food_entries').doc();
      await docRef.set(preparedData);
      return docRef.id;
    } catch (e) {
      throw e;
    }
  }
  
  // Cập nhật một bản ghi thức ăn
  Future<void> updateFoodEntry(FoodEntry entry) async {
    try {
      final uid = userId;
      if (uid == null) {
        throw Exception('Không có người dùng đăng nhập');
      }
      
      // Kiểm tra ID
      if (entry.id.isEmpty) {
        throw Exception('ID bản ghi thức ăn không hợp lệ');
      }
      
      // Chuẩn bị dữ liệu để lưu vào Firestore
      final data = entry.toJson();
      data['user_id'] = uid;
      
      // Xử lý các trường thời gian
      final preparedData = FirebaseHelpers.prepareDataForFirestore(data);
      
      // Cập nhật bản ghi
      await _firestore.collection('food_entries').doc(entry.id).update(preparedData);
    } catch (e) {
      throw e;
    }
  }
  
  // Thêm mới một bản ghi tập luyện
  Future<String> addExerciseEntry(Exercise entry) async {
    try {
      final uid = userId;
      if (uid == null) {
        throw Exception('Không có người dùng đăng nhập');
      }
      
      // Chuẩn bị dữ liệu để lưu vào Firestore
      final data = entry.toJson();
      data['user_id'] = uid;
      
      // Xử lý các trường thời gian
      final preparedData = FirebaseHelpers.prepareDataForFirestore(data);
      
      // Tạo một ID mới nếu không có
      final docRef = _firestore.collection('exercise_entries').doc();
      await docRef.set(preparedData);
      return docRef.id;
    } catch (e) {
      throw e;
    }
  }
  
  // Thêm mới một bản ghi nước
  Future<String> addWaterEntry(WaterEntry entry) async {
    try {
      final uid = userId;
      if (uid == null) {
        throw Exception('Không có người dùng đăng nhập');
      }
      
      // Chuẩn bị dữ liệu để lưu vào Firestore
      final data = entry.toJson();
      data['user_id'] = uid;
      
      // Xử lý các trường thời gian
      final preparedData = FirebaseHelpers.prepareDataForFirestore(data);
      
      // Tạo một ID mới nếu không có
      final docRef = _firestore.collection('water_entries').doc();
      await docRef.set(preparedData);
      return docRef.id;
    } catch (e) {
      throw e;
    }
  }
  
  // Lấy danh sách bản ghi thức ăn theo ngày
  Future<List<FoodEntry>> getFoodEntriesByDate(DateTime date) async {
    try {
      final uid = userId;
      if (uid == null) {
        return [];
      }
      
      // Chuyển đổi ngày thành chuỗi theo định dạng yyyy-MM-dd
      final dateString = "${date.year.toString()}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      // Truy vấn Firestore
      final querySnapshot = await _firestore
          .collection('food_entries')
          .where('user_id', isEqualTo: uid)
          .where('date', isEqualTo: dateString)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // Chuyển đổi từ document sang FoodEntry
        return querySnapshot.docs.map((doc) {
          final data = FirebaseHelpers.processFirestoreData(doc.data());
          data['id'] = doc.id; // Đảm bảo ID được bao gồm
          return FoodEntry.fromJson(data);
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
} 