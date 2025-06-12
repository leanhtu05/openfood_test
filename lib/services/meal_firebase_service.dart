import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/meal_plan.dart';
import '../utils/firebase_helpers.dart';

/// Service để xử lý các thao tác CRUD với Firebase cho dữ liệu bữa ăn
class MealFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection paths
  final String _mealPlansCollection = 'meal_plans_data';
  final String _consumedMealsCollection = 'consumed_meals_data';
  
  /// Lưu kế hoạch bữa ăn vào Firebase
  Future<bool> saveMealPlan(MealPlan mealPlan) async {
    try {

      // Hiển thị cấu trúc JSON trước khi chuyển đổi
      final originalJson = mealPlan.toJson();

      // Chuẩn bị dữ liệu để lưu vào Firebase
      final data = FirebaseHelpers.prepareDataForFirestore(originalJson);
      
      // Kiểm tra dữ liệu sau khi chuyển đổi

      // Đảm bảo có trường user_id trong dữ liệu
      if (!data.containsKey('user_id')) {
        data['user_id'] = mealPlan.userId;

      }
      
      // Đảm bảo có cấu trúc days hoặc weekly_plan
      if (!data.containsKey('days') && !data.containsKey('weekly_plan')) {

      }
      
      // Lưu vào collection chính
      final docRef = _firestore
          .collection(_mealPlansCollection)
          .doc(mealPlan.id);

      await docRef.set(data);

      return true;
    } catch (e) {

      return false;
    }
  }
  
  /// Lấy kế hoạch bữa ăn hiện tại của người dùng (mới nhất)
  Future<MealPlan?> getCurrentMealPlan(String userId) async {
    try {

      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Lấy kế hoạch bữa ăn mới nhất từ collection meal_plans
      QuerySnapshot querySnapshot = await _firestore
          .collection('meal_plans')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      // Nếu không tìm thấy với user_id, thử với userId
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _firestore
            .collection('meal_plans')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

      }
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final rawData = doc.data() as Map<String, dynamic>;

        // Kiểm tra timestamp
        final timestamp = rawData['timestamp'];
        if (timestamp != null) {
          final timestampDate = timestamp is String ? DateTime.tryParse(timestamp) : null;

          if (timestampDate != null) {

          }
        }

        // Kiểm tra cấu trúc dữ liệu
        if (rawData.containsKey('days')) {

        }
        if (rawData.containsKey('weekly_plan')) {

        }

        final data = FirebaseHelpers.processFirestoreData(rawData);

        // Thử tạo MealPlan từ dữ liệu đã xử lý
        try {
          final mealPlan = MealPlan.fromJson(data);

          return mealPlan;
        } catch (parseError) {

          return null;
        }
      }

      return null;
    } catch (e) {

      return null;
    }
  }

  /// Lấy kế hoạch bữa ăn cho ngày cụ thể
  Future<Map<String, dynamic>?> getMealPlanForDate(String userId, DateTime date) async {
    try {
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Lấy kế hoạch mới nhất
      final mealPlan = await getCurrentMealPlan(userId);
      if (mealPlan == null) {

        return null;
      }

      // Tìm ngày trong weekly plan
      final dayOfWeek = _getDayOfWeekString(date.weekday);

      if (mealPlan.weeklyPlan.containsKey(dayOfWeek)) {
        final dayPlan = mealPlan.weeklyPlan[dayOfWeek];

        return dayPlan?.toJson();
      }

      return null;
    } catch (e) {

      return null;
    }
  }

  /// Chuyển đổi số ngày trong tuần thành chuỗi
  String _getDayOfWeekString(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }
  
  /// Lấy lịch sử kế hoạch bữa ăn
  Future<List<MealPlanHistory>> getMealPlanHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_mealPlansCollection)
          .where('user_id', isEqualTo: userId)
          .get();
      
      List<MealPlanHistory> history = [];
      
      // Chuyển đổi dữ liệu
      for (var doc in querySnapshot.docs) {
        final rawData = doc.data() as Map<String, dynamic>;
        final data = FirebaseHelpers.processFirestoreData(rawData);
        try {
          history.add(MealPlanHistory.fromJson(data));
        } catch (e) {

        }
      }
      
      // Sắp xếp theo thời gian tạo giảm dần ở phía client
      history.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime); // Sắp xếp giảm dần
      });

      return history;
    } catch (e) {

      return [];
    }
  }
  
  /// Xóa kế hoạch bữa ăn
  Future<bool> deleteMealPlan(String planId, String userId) async {
    try {
      // Xóa từ collection chính
      await _firestore
          .collection(_mealPlansCollection)
          .doc(planId)
          .delete();

      return true;
    } catch (e) {

      return false;
    }
  }
  
  /// Lưu bữa ăn đã tiêu thụ vào Firebase
  Future<bool> saveConsumedMeal({
    required String userId,
    required String mealId,
    required String mealName,
    required String mealType,
    required DateTime consumedAt,
    required Map<String, dynamic> nutritionInfo,
    String? notes,
  }) async {
    try {
      final String docId = '$userId-$mealId-${consumedAt.millisecondsSinceEpoch}';
      
      final Map<String, dynamic> mealData = {
        'user_id': userId, // Đảm bảo sử dụng user_id nhất quán
        'mealId': mealId,
        'mealName': mealName,
        'mealType': mealType,
        'consumedAt': Timestamp.fromDate(consumedAt),
        'nutritionInfo': nutritionInfo,
        'notes': notes,
        'createdAt': Timestamp.now(),
      };
      
      // Lưu vào collection consumed_meals
      await _firestore
          .collection(_consumedMealsCollection)
          .doc(docId)
          .set(mealData);

      return true;
    } catch (e) {

      return false;
    }
  }
  
  /// Lấy danh sách bữa ăn đã tiêu thụ trong một ngày
  Future<List<Map<String, dynamic>>> getConsumedMealsForDay(
    String userId, 
    DateTime date
  ) async {
    try {
      // Tính toán ngày dưới dạng chuỗi ISO để lọc
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // Truy vấn Firestore - chỉ lọc theo user_id
      final querySnapshot = await _firestore
          .collection(_consumedMealsCollection)
          .where('user_id', isEqualTo: userId)
          .get();
      
      List<Map<String, dynamic>> meals = [];
      
      // Lọc kết quả theo ngày ở phía client
      for (var doc in querySnapshot.docs) {
        final rawData = doc.data() as Map<String, dynamic>;
        final data = FirebaseHelpers.processFirestoreData(rawData);
        
        // Lấy trường consumedAt
        final consumedAt = data['consumedAt'];
        DateTime consumedDateTime;
        
        if (consumedAt is Timestamp) {
          consumedDateTime = consumedAt.toDate();
        } else if (consumedAt is String) {
          consumedDateTime = DateTime.tryParse(consumedAt) ?? DateTime(1970);
        } else {
          continue; // Bỏ qua nếu không có thời gian hợp lệ
        }
        
        // Kiểm tra xem có phải cùng ngày không
        final entryDateString = '${consumedDateTime.year}-${consumedDateTime.month.toString().padLeft(2, '0')}-${consumedDateTime.day.toString().padLeft(2, '0')}';
        
        if (entryDateString == dateString) {
          meals.add(data);
        }
      }

      return meals;
    } catch (e) {

      return [];
    }
  }
  
  /// Đồng bộ dữ liệu từ API lên Firebase
  Future<bool> syncMealPlanFromApi(MealPlan mealPlan) async {
    return await saveMealPlan(mealPlan);
  }
}
