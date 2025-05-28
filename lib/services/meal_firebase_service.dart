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
      // Chuẩn bị dữ liệu để lưu vào Firebase
      final data = FirebaseHelpers.prepareDataForFirestore(mealPlan.toJson());
      
      // Đảm bảo có trường user_id trong dữ liệu
      if (!data.containsKey('user_id')) {
        data['user_id'] = mealPlan.userId;
      }
      
      // Lưu vào collection chính
      await _firestore
          .collection(_mealPlansCollection)
          .doc(mealPlan.id)
          .set(data);
          
      debugPrint('✅ Đã lưu kế hoạch bữa ăn vào Firebase: ${mealPlan.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu kế hoạch bữa ăn: $e');
      return false;
    }
  }
  
  /// Lấy kế hoạch bữa ăn hiện tại của người dùng
  Future<MealPlan?> getCurrentMealPlan(String userId) async {
    try {
      // Lấy tất cả kế hoạch bữa ăn của người dùng và sắp xếp ở phía client
      final querySnapshot = await _firestore
          .collection(_mealPlansCollection)
          .where('user_id', isEqualTo: userId)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // Sắp xếp theo thời gian tạo giảm dần ở phía client
        final sortedDocs = querySnapshot.docs.toList()
          ..sort((a, b) {
            final aData = a.data();
            final bData = b.data();
            
            // Lấy trường createdAt hoặc timestamp
            final aTime = aData['createdAt'] ?? aData['timestamp'] ?? 0;
            final bTime = bData['createdAt'] ?? bData['timestamp'] ?? 0;
            
            // Chuyển đổi sang DateTime nếu cần
            final aDateTime = aTime is Timestamp ? aTime.toDate() : 
                             (aTime is String ? DateTime.tryParse(aTime) ?? DateTime(1970) : DateTime(1970));
            final bDateTime = bTime is Timestamp ? bTime.toDate() : 
                             (bTime is String ? DateTime.tryParse(bTime) ?? DateTime(1970) : DateTime(1970));
            
            return bDateTime.compareTo(aDateTime); // Sắp xếp giảm dần
          });
        
        if (sortedDocs.isNotEmpty) {
          final data = FirebaseHelpers.processFirestoreData(sortedDocs.first.data());
          debugPrint('✅ Đã tìm thấy kế hoạch bữa ăn trên Firebase');
          return MealPlan.fromJson(data);
        }
      }
      
      debugPrint('ℹ️ Không tìm thấy kế hoạch bữa ăn trên Firebase');
      return null;
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy kế hoạch bữa ăn: $e');
      return null;
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
        final data = FirebaseHelpers.processFirestoreData(doc.data());
        try {
          history.add(MealPlanHistory.fromJson(data));
        } catch (e) {
          debugPrint('⚠️ Lỗi khi chuyển đổi dữ liệu lịch sử: $e');
        }
      }
      
      // Sắp xếp theo thời gian tạo giảm dần ở phía client
      history.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime); // Sắp xếp giảm dần
      });
      
      debugPrint('✅ Đã lấy ${history.length} kế hoạch bữa ăn từ lịch sử');
      return history;
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy lịch sử kế hoạch bữa ăn: $e');
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
          
      debugPrint('✅ Đã xóa kế hoạch bữa ăn: $planId');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa kế hoạch bữa ăn: $e');
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
          
      debugPrint('✅ Đã lưu bữa ăn đã tiêu thụ: $mealName');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu bữa ăn đã tiêu thụ: $e');
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
        final data = FirebaseHelpers.processFirestoreData(doc.data());
        
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
      
      debugPrint('ℹ️ Tìm thấy ${meals.length} bữa ăn đã tiêu thụ cho ngày $dateString');
      return meals;
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy bữa ăn đã tiêu thụ: $e');
      return [];
    }
  }
  
  /// Đồng bộ dữ liệu từ API lên Firebase
  Future<bool> syncMealPlanFromApi(MealPlan mealPlan) async {
    return await saveMealPlan(mealPlan);
  }
}
