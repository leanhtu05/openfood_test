import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeFirestoreCollections() async {
    try {
      await _createUserStructure();
      await _createFoodItemsCollection();
      await _createExerciseTypesCollection();
      await _createLatestMealPlansStructure();
      await _createNutritionCacheCollection();
      debugPrint('🔥 Khởi tạo Firestore collections thành công');
    } catch (e) {
      debugPrint('❌ Lỗi khi khởi tạo Firestore collections: $e');
      rethrow;
    }
  }

  // Tạo cấu trúc User
  Future<void> _createUserStructure() async {
    // Tạo user mẫu để minh họa cấu trúc
    final sampleUserRef = _firestore.collection('users').doc('sample_user_structure');
    final userDoc = await sampleUserRef.get();
    
    if (!userDoc.exists) {
      await sampleUserRef.set({
        'uid': 'sample_user_structure',
        'email': 'sample@email.com',
        'displayName': 'Sample User',
        'photoURL': '',
        'gender': 'Nam',
        'age': 30,
        'heightCm': 170.0,
        'weightKg': 65.0,
        'activityLevel': 'Hoạt động vừa phải',
        'goal': 'Duy trì cân nặng',
        'dietPreference': 'balanced',
        'dietRestrictions': ['Không có'],
        'healthConditions': ['Không có'],
        'tdeeValues': {
          'calories': 2000.0,
          'protein': 120.0,
          'carbs': 200.0,
          'fat': 65.0
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isAnonymous': false,
        'isStructureSample': true, // Để đánh dấu đây là mẫu
      });
      
      // Tạo mẫu daily_logs
      await sampleUserRef.collection('daily_logs').doc('sample_date').set({
        'date': '2023-08-01',
        'meals': [
          {
            'id': 'sample_meal_1',
            'name': 'Cơm gà',
            'mealType': 'lunch',
            'servingSize': 1,
            'servingUnit': 'phần',
            'calories': 450,
            'protein': 25,
            'carbs': 60,
            'fat': 12,
            'imageUrl': '',
            'timeConsumed': Timestamp.now()
          }
        ],
        'waterIntake': 2000,
        'exercises': [
          {
            'id': 'sample_exercise_1',
            'name': 'Chạy bộ',
            'duration': 30,
            'caloriesBurned': 250,
            'type': 'cardio',
            'timePerformed': Timestamp.now()
          }
        ],
        'weight': 65.0,
        'notes': 'Ghi chú mẫu',
        'dailySummary': {
          'totalCaloriesConsumed': 1800,
          'totalCaloriesBurned': 250,
          'netCalories': 1550,
          'totalProtein': 85,
          'totalCarbs': 230,
          'totalFat': 55
        }
      });
      
      debugPrint('✅ Đã tạo cấu trúc users và daily_logs mẫu');
    } else {
      debugPrint('📝 Cấu trúc users đã tồn tại');
    }
  }

  // Tạo collection food_items với dữ liệu mẫu
  Future<void> _createFoodItemsCollection() async {
    final foodItemsRef = _firestore.collection('food_items');
    final foodItemsSnapshot = await foodItemsRef.limit(1).get();
    
    // Chỉ tạo nếu collection trống
    if (foodItemsSnapshot.docs.isEmpty) {
      // Danh sách các thực phẩm cơ bản
      final basicFoods = [
        {
          'name': 'Cơm trắng',
          'nameLower': 'com trang',
          'nameEn': 'White rice',
          'category': 'Tinh bột',
          'nutrition': {
            'calories': 130,
            'protein': 2.7,
            'fat': 0.3,
            'carbs': 28.2,
            'fiber': 0.4,
            'sugar': 0.1,
            'sodium': 1,
            'cholesterol': 0,
          },
          'servingSize': 100,
          'servingUnit': 'g',
          'source': 'USDA',
          'searchTerms': ['cơm', 'gạo', 'rice', 'staple'],
        },
        {
          'name': 'Thịt gà',
          'nameLower': 'thit ga',
          'nameEn': 'Chicken breast',
          'category': 'Protein',
          'nutrition': {
            'calories': 165,
            'protein': 31,
            'fat': 3.6,
            'carbs': 0,
            'fiber': 0,
            'sugar': 0,
            'sodium': 74,
            'cholesterol': 85,
          },
          'servingSize': 100,
          'servingUnit': 'g',
          'source': 'USDA',
          'searchTerms': ['gà', 'thịt gà', 'chicken'],
        },
        {
          'name': 'Rau cải xanh',
          'nameLower': 'rau cai xanh',
          'nameEn': 'Green vegetables',
          'category': 'Rau củ',
          'nutrition': {
            'calories': 25,
            'protein': 2.1,
            'fat': 0.3,
            'carbs': 4.3,
            'fiber': 2.5,
            'sugar': 1.2,
            'sodium': 28,
            'cholesterol': 0,
          },
          'servingSize': 100,
          'servingUnit': 'g',
          'source': 'USDA',
          'searchTerms': ['rau', 'cải', 'rau xanh', 'vegetables'],
        },
      ];
      
      // Thêm các thực phẩm vào collection
      for (var food in basicFoods) {
        await foodItemsRef.add(food);
      }
      
      debugPrint('✅ Đã tạo collection food_items với ${basicFoods.length} thực phẩm cơ bản');
    } else {
      debugPrint('📝 Collection food_items đã tồn tại');
    }
  }

  // Tạo collection exercise_types với dữ liệu mẫu
  Future<void> _createExerciseTypesCollection() async {
    final exerciseRef = _firestore.collection('exercise_types');
    final exerciseSnapshot = await exerciseRef.limit(1).get();
    
    // Chỉ tạo nếu collection trống
    if (exerciseSnapshot.docs.isEmpty) {
      // Danh sách các bài tập cơ bản
      final basicExercises = [
        {
          'name': 'Chạy bộ',
          'category': 'cardio',
          'caloriesBurnedPerMinute': {
            '50kg': 8.3,
            '60kg': 10.0,
            '70kg': 11.7,
            '80kg': 13.3,
            '90kg': 15.0,
            '100kg': 16.7,
          },
          'description': 'Chạy bộ với tốc độ trung bình',
          'imageUrl': '',
        },
        {
          'name': 'Đạp xe',
          'category': 'cardio',
          'caloriesBurnedPerMinute': {
            '50kg': 5.0,
            '60kg': 6.0,
            '70kg': 7.0,
            '80kg': 8.0,
            '90kg': 9.0,
            '100kg': 10.0,
          },
          'description': 'Đạp xe với tốc độ trung bình',
          'imageUrl': '',
        },
        {
          'name': 'Plank',
          'category': 'strength',
          'caloriesBurnedPerMinute': {
            '50kg': 3.0,
            '60kg': 3.5,
            '70kg': 4.0,
            '80kg': 4.5,
            '90kg': 5.0,
            '100kg': 5.5,
          },
          'description': 'Tư thế plank giữ thăng bằng',
          'imageUrl': '',
        },
      ];
      
      // Thêm các bài tập vào collection
      for (var exercise in basicExercises) {
        await exerciseRef.add(exercise);
      }
      
      debugPrint('✅ Đã tạo collection exercise_types với ${basicExercises.length} bài tập cơ bản');
    } else {
      debugPrint('📝 Collection exercise_types đã tồn tại');
    }
  }

  // Tạo cấu trúc latest_meal_plans
  Future<void> _createLatestMealPlansStructure() async {
    final latestMealPlansRef = _firestore.collection('latest_meal_plans').doc('sample_structure');
    final mealPlanDoc = await latestMealPlansRef.get();
    
    if (!mealPlanDoc.exists) {
      // Tạo mẫu meal plan
      await latestMealPlansRef.set({
        'user_id': 'sample_user',
        'name': 'Kế hoạch ăn uống mẫu',
        'startDate': FieldValue.serverTimestamp(),
        'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'weekly_plan': {
          'Thứ 2': {
            'day_of_week': 'Thứ 2',
            'meals': {
              'breakfast': [
                {
                  'name': 'Bánh mì trứng',
                  'calories': 350,
                  'protein': 15,
                  'fat': 12,
                  'carbs': 45,
                  'ingredients': ['bánh mì', 'trứng gà', 'rau xà lách'],
                  'imageUrl': ''
                }
              ],
              'lunch': [
                {
                  'name': 'Cơm gà',
                  'calories': 450,
                  'protein': 25,
                  'fat': 10,
                  'carbs': 65,
                  'ingredients': ['cơm', 'thịt gà', 'rau cải'],
                  'imageUrl': ''
                }
              ],
              'dinner': [
                {
                  'name': 'Bún chả',
                  'calories': 400,
                  'protein': 22,
                  'fat': 15,
                  'carbs': 50,
                  'ingredients': ['bún', 'thịt lợn', 'rau sống'],
                  'imageUrl': ''
                }
              ]
            },
            'nutrition_summary': {
              'calories': 1200,
              'protein': 62,
              'fat': 37,
              'carbs': 160
            }
          }
        },
        'nutritionTargets': {
          'calories_target': 2000,
          'protein_target': 120,
          'carbs_target': 200,
          'fat_target': 65
        },
        'preferences': ['Ít muối', 'Nhiều rau'],
        'allergies': ['Hải sản'],
        'cuisineStyle': 'Việt Nam',
        'timestamp': FieldValue.serverTimestamp(),
        'isStructureSample': true,
      });
      
      // Tạo mẫu meal plan collection
      await _firestore.collection('meal_plans').add({
        'user_id': 'sample_user',
        'name': 'Kế hoạch ăn uống mẫu trong collection meal_plans',
        'startDate': FieldValue.serverTimestamp(),
        'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'weekly_plan': {
          'Thứ 2': {
            'day_of_week': 'Thứ 2',
            'meals': {
              'breakfast': [
                {
                  'name': 'Phở gà',
                  'calories': 380,
                  'protein': 22,
                  'fat': 10,
                  'carbs': 55,
                  'ingredients': ['bánh phở', 'thịt gà', 'hành ngò'],
                  'imageUrl': ''
                }
              ]
            },
          }
        },
        'isStructureSample': true,
      });
      
      debugPrint('✅ Đã tạo cấu trúc meal_plans và latest_meal_plans mẫu');
    } else {
      debugPrint('📝 Cấu trúc meal_plans đã tồn tại');
    }
  }

  // Tạo collection nutrition_cache
  Future<void> _createNutritionCacheCollection() async {
    final cacheRef = _firestore.collection('nutrition_cache');
    final cacheSnapshot = await cacheRef.limit(1).get();
    
    if (cacheSnapshot.docs.isEmpty) {
      // Tạo mẫu cache entry
      await cacheRef.doc('sample_cache_thit_ga').set({
        'data': {
          'name': 'Thịt gà',
          'calories': 165,
          'protein': 31,
          'fat': 3.6,
          'carbs': 0,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'source': 'USDA',
        'query': 'thịt gà',
        'isStructureSample': true,
      });
      
      // Tạo mẫu AI suggestion
      await _firestore.collection('ai_suggestions').add({
        'userId': 'sample_user',
        'type': 'meal',
        'content': 'Bạn nên tăng lượng protein vào bữa sáng để đảm bảo đủ năng lượng cho cả ngày.',
        'context': {
          'query': 'Tôi cần gợi ý bữa sáng',
          'userProfile': {
            'goal': 'Tăng cơ',
            'age': 28
          },
          'nutritionContext': {
            'currentProtein': 80,
            'targetProtein': 120
          }
        },
        'suggestedMeals': [
          {
            'name': 'Bánh mì trứng gà và sữa',
            'calories': 450,
            'protein': 25,
            'carbs': 45,
            'fat': 18
          }
        ],
        'timestamp': FieldValue.serverTimestamp(),
        'isImplemented': false,
        'isStructureSample': true,
      });
      
      debugPrint('✅ Đã tạo collection nutrition_cache và ai_suggestions mẫu');
    } else {
      debugPrint('📝 Collection nutrition_cache đã tồn tại');
    }
  }
} 