import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan.dart';
import '../services/meal_plan_api_service.dart';
import 'package:openfood/models/food_item.dart';
import 'package:openfood/models/food_entry.dart';
import 'package:openfood/models/exercise.dart';
import 'package:openfood/models/water_entry.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy tham chiếu tới collection meal_plans
  CollectionReference<Map<String, dynamic>> get _mealPlansCollection =>
      _firestore.collection('meal_plans');
  
  // Lấy tham chiếu tới collection users
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');
      
  // Lấy ID của người dùng hiện tại
  String? get _currentUserId => _auth.currentUser?.uid;
  
  // Lấy kế hoạch ăn uống theo tuần cho người dùng hiện tại
  Future<Map<String, dynamic>> getWeeklyMealPlan() async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      // Kiểm tra nếu người dùng đã có kế hoạch ăn
      final userDoc = await _usersCollection.doc(_currentUserId).get();
      String? mealPlanId = userDoc.data()?['current_meal_plan_id'];
      
      // Nếu không có, tạo một kế hoạch mới
      if (mealPlanId == null) {
        return await _generateNewMealPlan();
      }
      
      // Lấy kế hoạch ăn từ Firestore
      final mealPlanDoc = await _mealPlansCollection.doc(mealPlanId).get();
      
      if (!mealPlanDoc.exists) {
        // Nếu không tồn tại, tạo mới
        return await _generateNewMealPlan();
      }
      
      return mealPlanDoc.data() ?? {};
    } catch (e) {
      print('Lỗi khi lấy kế hoạch ăn: $e');
      throw e;
    }
  }
  
  // Tạo kế hoạch ăn mới
  Future<Map<String, dynamic>> _generateNewMealPlan() async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      // Lấy mẫu kế hoạch từ service khác
      // Ở đây, bạn có thể thay thế bằng API call thực tế hoặc tạo dữ liệu mẫu
      final newPlanData = await MealPlanApiService.getMockMealPlan();
      
      // Lưu vào Firestore
      final docRef = await _mealPlansCollection.add({
        'user_id': _currentUserId,
        'created_at': FieldValue.serverTimestamp(),
        'weekly_plan': newPlanData['weekly_plan'],
      });
      
      // Cập nhật ID kế hoạch hiện tại cho người dùng
      await _usersCollection.doc(_currentUserId).set({
        'current_meal_plan_id': docRef.id,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Lấy dữ liệu vừa tạo
      final newDoc = await docRef.get();
      return newDoc.data() ?? {};
    } catch (e) {
      print('Lỗi khi tạo kế hoạch ăn mới: $e');
      throw e;
    }
  }
  
  // Cập nhật kế hoạch ăn
  Future<void> updateMealPlan(Map<String, dynamic> mealPlanData) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      final userDoc = await _usersCollection.doc(_currentUserId).get();
      String? mealPlanId = userDoc.data()?['current_meal_plan_id'];
      
      if (mealPlanId == null) {
        throw Exception('Không tìm thấy kế hoạch ăn');
      }
      
      await _mealPlansCollection.doc(mealPlanId).update({
        'weekly_plan': mealPlanData['weekly_plan'],
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Lỗi khi cập nhật kế hoạch ăn: $e');
      throw e;
    }
  }
  
  // Thay thế một bữa ăn cụ thể trong kế hoạch
  Future<Map<String, dynamic>> replaceMeal({
    required String day,
    required String mealType,
    required Map<String, dynamic> newMeal,
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      final userDoc = await _usersCollection.doc(_currentUserId).get();
      String? mealPlanId = userDoc.data()?['current_meal_plan_id'];
      
      if (mealPlanId == null) {
        throw Exception('Không tìm thấy kế hoạch ăn');
      }
      
      // Lấy kế hoạch ăn hiện tại
      final mealPlanDoc = await _mealPlansCollection.doc(mealPlanId).get();
      final mealPlanData = mealPlanDoc.data() ?? {};
      
      // Cập nhật bữa ăn cụ thể
      if (mealPlanData.containsKey('weekly_plan') && 
          mealPlanData['weekly_plan'] is Map &&
          mealPlanData['weekly_plan'].containsKey(day)) {
        
        // Thay thế bữa ăn trong weekly_plan[day].meals[mealType][0]
        var weeklyPlan = Map<String, dynamic>.from(mealPlanData['weekly_plan']);
        var dayPlan = Map<String, dynamic>.from(weeklyPlan[day]);
        var meals = Map<String, dynamic>.from(dayPlan['meals']);
        
        if (meals.containsKey(mealType) && meals[mealType] is List) {
          var mealsList = List.from(meals[mealType]);
          
          if (mealsList.isNotEmpty) {
            mealsList[0] = newMeal;
            meals[mealType] = mealsList;
            dayPlan['meals'] = meals;
            weeklyPlan[day] = dayPlan;
            
            // Cập nhật lại nutrition summary cho ngày đó
            double totalCalories = 0, totalProtein = 0, totalFat = 0, totalCarbs = 0;
            
            meals.forEach((mealTypeKey, mealList) {
              if (mealList is List && mealList.isNotEmpty) {
                for (var meal in mealList) {
                  if (meal is Map && meal.containsKey('nutrition')) {
                    var nutrition = meal['nutrition'];
                    totalCalories += (nutrition['calories'] ?? 0).toDouble();
                    totalProtein += (nutrition['protein'] ?? 0).toDouble();
                    totalFat += (nutrition['fat'] ?? 0).toDouble();
                    totalCarbs += (nutrition['carbs'] ?? 0).toDouble();
                  }
                }
              }
            });
            
            dayPlan['nutrition_summary'] = {
              'calories': totalCalories,
              'protein': totalProtein,
              'fat': totalFat,
              'carbs': totalCarbs,
            };
            
            weeklyPlan[day] = dayPlan;
            
            // Lưu cập nhật vào Firestore
            await _mealPlansCollection.doc(mealPlanId).update({
              'weekly_plan': weeklyPlan,
              'updated_at': FieldValue.serverTimestamp(),
            });
            
            // Trả về kế hoạch đã cập nhật
            return {'weekly_plan': weeklyPlan};
          }
        }
      }
      
      throw Exception('Không tìm thấy bữa ăn cần thay thế');
    } catch (e) {
      print('Lỗi khi thay thế bữa ăn: $e');
      throw e;
    }
  }
  
  // Lưu hồ sơ người dùng
  Future<void> saveUserProfile(Map<String, dynamic> userData) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      await _usersCollection.doc(_currentUserId).set({
        'profile': userData,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      print('Lỗi khi lưu hồ sơ người dùng: $e');
      throw e;
    }
  }
  
  // Lấy hồ sơ người dùng
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      final userDoc = await _usersCollection.doc(_currentUserId).get();
      return userDoc.data()?['profile'] ?? {};
      
    } catch (e) {
      print('Lỗi khi lấy hồ sơ người dùng: $e');
      throw e;
    }
  }

  // ==================== USER METHODS ====================

  // Lưu thông tin người dùng
  Future<void> saveUserData({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Lỗi khi lưu thông tin người dùng: $e');
      throw e;
    }
  }

  // Lấy thông tin người dùng
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      debugPrint('Lỗi khi lấy thông tin người dùng: $e');
      throw e;
    }
  }

  // ==================== FOOD METHODS ====================

  // Lấy danh sách thực phẩm
  Future<List<FoodItem>> getAllFoodItems() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('food_items').get();
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return FoodItem.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Lỗi khi lấy danh sách thực phẩm: $e');
      return [];
    }
  }

  // Tìm kiếm thực phẩm
  Future<List<FoodItem>> searchFoodItems(String query) async {
    try {
      // Chuyển đổi query thành chữ thường để tìm kiếm không phân biệt hoa thường
      String lowercaseQuery = query.toLowerCase();
      
      QuerySnapshot snapshot = await _firestore.collection('food_items').get();
      
      // Lọc kết quả dựa trên query
      return snapshot.docs
          .map((doc) => FoodItem.fromJson(doc.data() as Map<String, dynamic>))
          .where((food) => 
              food.name.toLowerCase().contains(lowercaseQuery) || 
              (food.brand != null && food.brand!.toLowerCase().contains(lowercaseQuery)))
          .toList();
    } catch (e) {
      debugPrint('Lỗi khi tìm kiếm thực phẩm: $e');
      return [];
    }
  }

  // Thêm bản ghi thực phẩm
  Future<String> addFoodEntry(FoodEntry entry) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('food_entries')
          .add(entry.toJson());
      
      return docRef.id;
    } catch (e) {
      debugPrint('Lỗi khi thêm bản ghi thực phẩm: $e');
      throw e;
    }
  }

  // Lấy bản ghi thực phẩm theo ngày
  Future<List<FoodEntry>> getFoodEntriesByDate(DateTime date) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      // Tạo ngày bắt đầu và kết thúc
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('food_entries')
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('dateTime', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();
      
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return FoodEntry.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Lỗi khi lấy bản ghi thực phẩm: $e');
      return [];
    }
  }

  // Cập nhật bản ghi thực phẩm
  Future<void> updateFoodEntry(FoodEntry entry) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('food_entries')
          .doc(entry.id)
          .update(entry.toJson());
    } catch (e) {
      debugPrint('Lỗi khi cập nhật bản ghi thực phẩm: $e');
      throw e;
    }
  }

  // Xóa bản ghi thực phẩm
  Future<void> deleteFoodEntry(String entryId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('food_entries')
          .doc(entryId)
          .delete();
    } catch (e) {
      debugPrint('Lỗi khi xóa bản ghi thực phẩm: $e');
      throw e;
    }
  }

  // ==================== EXERCISE METHODS ====================

  // Thêm bản ghi tập luyện
  Future<String> addExerciseEntry(Exercise exercise) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('exercise_entries')
          .add(exercise.toJson());
      
      return docRef.id;
    } catch (e) {
      debugPrint('Lỗi khi thêm bản ghi tập luyện: $e');
      throw e;
    }
  }

  // Lấy bản ghi tập luyện theo ngày
  Future<List<Exercise>> getExerciseEntriesByDate(String date) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('exercise_entries')
          .where('date', isEqualTo: date)
          .get();
      
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Exercise.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Lỗi khi lấy bản ghi tập luyện: $e');
      return [];
    }
  }

  // ==================== WATER METHODS ====================

  // Thêm bản ghi uống nước
  Future<String> addWaterEntry(WaterEntry entry) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      Map<String, dynamic> entryData = {
        'id': entry.id,
        'amount': entry.amount,
        'timestamp': entry.timestamp.millisecondsSinceEpoch,
      };
      
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('water_entries')
          .add(entryData);
      
      return docRef.id;
    } catch (e) {
      debugPrint('Lỗi khi thêm bản ghi uống nước: $e');
      throw e;
    }
  }

  // Lấy bản ghi uống nước theo ngày
  Future<List<WaterEntry>> getWaterEntriesByDate(DateTime date) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      // Tạo thời điểm bắt đầu và kết thúc của ngày
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      // Chuyển đổi thành millisecondsSinceEpoch để truy vấn
      int startTimestamp = startOfDay.millisecondsSinceEpoch;
      int endTimestamp = endOfDay.millisecondsSinceEpoch;
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('water_entries')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .get();
      
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return WaterEntry(
          id: data['id'],
          amount: data['amount'],
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp']),
        );
      }).toList();
    } catch (e) {
      debugPrint('Lỗi khi lấy bản ghi uống nước: $e');
      return [];
    }
  }

  // ==================== FAVORITES METHODS ====================

  // Thêm món ăn vào danh sách yêu thích
  Future<void> addToFavorites(String itemId, String name, String type) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('favorites')
          .add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'itemId': itemId,
            'name': name,
            'type': type,
            'addedAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Lỗi khi thêm vào yêu thích: $e');
      throw e;
    }
  }

  // Lấy danh sách món ăn yêu thích
  Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Lỗi khi lấy danh sách yêu thích: $e');
      return [];
    }
  }

  // Xóa khỏi danh sách yêu thích
  Future<void> removeFromFavorites(String favoriteId) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }
      
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('favorites')
          .doc(favoriteId)
          .delete();
    } catch (e) {
      debugPrint('Lỗi khi xóa khỏi yêu thích: $e');
      throw e;
    }
  }
} 