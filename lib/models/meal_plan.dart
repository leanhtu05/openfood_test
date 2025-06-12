import 'dart:convert';
import 'package:http/http.dart' as http;

// Class để đại diện cho nguyên liệu chi tiết với số lượng
class DetailedIngredient {
  final String name;
  final String amount;
  final String? unit;
  final String? category; // Phân loại nguyên liệu (rau củ, thịt, gia vị...)

  DetailedIngredient({
    required this.name,
    required this.amount,
    this.unit,
    this.category,
  });

  factory DetailedIngredient.fromJson(Map<String, dynamic> json) {
    return DetailedIngredient(
      name: json['name'] ?? '',
      amount: json['amount'] ?? '',
      unit: json['unit'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'category': category,
    };
  }
}

class MealPlan {
  final String id;
  final String userId;
  final DateTime createdAt;
  final Map<String, DayMealPlan> weeklyPlan;
  final Map<String, double> nutritionTargets;

  MealPlan({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.weeklyPlan,
    required this.nutritionTargets,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    // Debug để xem cấu trúc JSON thực tế
    print('📦 JSON gốc từ Firebase: $json');
    print('🔍 Đang phân tích dữ liệu MealPlan...');
    print('🔑 Các khóa cấp cao nhất: ${json.keys.toList()}');
    
    Map<String, DayMealPlan> weeklyPlanMap = {};
    
    // Kiểm tra cấu trúc từ API thực tế (meal_plan.days hoặc days trực tiếp)
    if (json['days'] != null) {
      print('📅 Số ngày từ Firebase: ${json['days'].length}');
      print('📅 Cấu trúc mảng days: ${json['days']}');
      List<dynamic> days = json['days'];
      
      for (var day in days) {
        String dayOfWeek = day['day_of_week'];
        print('📆 Ngày tiếng Việt: $dayOfWeek');
        print('📆 Cấu trúc ngày: $day');
        // Chuyển đổi tên ngày tiếng Việt sang tiếng Anh
        String englishDay = _convertVietnameseDayToEnglish(dayOfWeek);
        print('📆 Ngày sau khi chuyển đổi: $englishDay');
        weeklyPlanMap[englishDay] = DayMealPlan.fromJson(day);
      }
    }
    // Cấu trúc cũ từ mock data
    else if (json['weekly_plan'] != null) {
      print('📒 Cấu trúc weekly_plan: ${json['weekly_plan']}');
      try {
        dynamic weeklyPlanData = json['weekly_plan'];
        if (weeklyPlanData is Map) {
          weeklyPlanData.forEach((key, value) {
            try {
              print('🔄 Xử lý ngày $key với dữ liệu: $value');
              if (key is String && value is Map) {
                // Chuyển đổi map để đảm bảo đúng kiểu dữ liệu
                final Map<String, dynamic> cleanValue = Map<String, dynamic>.from(value);
                weeklyPlanMap[key] = DayMealPlan.fromJson(cleanValue);
              } else {
                print('⚠️ Bỏ qua day plan không hợp lệ: key=$key, value type=${value.runtimeType}');
              }
            } catch (dayError) {
              print('❌ Lỗi khi xử lý day plan cho $key: $dayError');
            }
          });
        } else {
          print('⚠️ json["weekly_plan"] không phải là Map: ${weeklyPlanData.runtimeType}');
        }
      } catch (e) {
        print('Lỗi khi xử lý weekly_plan: $e');
      }
    }
    
    // Xử lý thông tin nutrition targets
    Map<String, double> nutritionTargets = {};
    if (json['meal_plan'] != null && json['meal_plan']['nutrition_targets'] != null) {
      var targets = json['meal_plan']['nutrition_targets'];
      nutritionTargets = {
        'calories': (targets['calories_target'] ?? 0).toDouble(),
        'protein': (targets['protein_target'] ?? 0).toDouble(),
        'fat': (targets['fat_target'] ?? 0).toDouble(),
        'carbs': (targets['carbs_target'] ?? 0).toDouble(),
      };
    } else {
      nutritionTargets = {
        'calories': (json['nutrition_targets']?['calories_target'] ?? 0).toDouble(),
        'protein': (json['nutrition_targets']?['protein_target'] ?? 0).toDouble(),
        'fat': (json['nutrition_targets']?['fat_target'] ?? 0).toDouble(),
        'carbs': (json['nutrition_targets']?['carbs_target'] ?? 0).toDouble(),
      };
    }
    
    return MealPlan(
      id: json['meal_plan']?['id'] ?? json['id'] ?? '',
      userId: json['meal_plan']?['user_id'] ?? json['user_id'] ?? 'default',
      createdAt: _parseDateTime(json['meal_plan']?['created_at'] ?? json['created_at']),
      weeklyPlan: weeklyPlanMap,
      nutritionTargets: nutritionTargets,
    );
  }
  
  // Hàm chuyển đổi tên ngày từ tiếng Việt sang tiếng Anh
  static String _convertVietnameseDayToEnglish(String vietnameseDay) {
    switch (vietnameseDay) {
      case 'Thứ 2': return 'Monday';
      case 'Thứ 3': return 'Tuesday';
      case 'Thứ 4': return 'Wednesday';
      case 'Thứ 5': return 'Thursday';
      case 'Thứ 6': return 'Friday';
      case 'Thứ 7': return 'Saturday';
      case 'Chủ nhật': return 'Sunday';
      case 'Chủ Nhật': return 'Sunday'; // Thêm trường hợp với 'N' viết hoa
      default: 
        // Debug để xem giá trị thực tế
        print("⚠️ Không thể chuyển đổi ngày tiếng Việt không xác định: '$vietnameseDay'");
        return vietnameseDay;
    }
  }
  
  // Hàm xử lý DateTime an toàn
  static DateTime _parseDateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return DateTime.now();
    
    try {
      if (dateTimeValue is String) {
        return DateTime.parse(dateTimeValue);
      }
    } catch (e) {
      print('Error parsing datetime: $e');
    }
    
    return DateTime.now();
  }

  // Method to convert MealPlan object to JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    
    // Add weekly plan with day names as keys
    data['weekly_plan'] = {};
    weeklyPlan.forEach((day, plan) {
      data['weekly_plan'][day] = {
        'day_of_week': day,
        'nutrition_summary': plan.nutritionSummary,
        'meals': {}
      };
      
      // Add meals for each day
      plan.meals.forEach((mealType, meals) {
        data['weekly_plan'][day]['meals'][mealType] = meals.map((meal) => {
          'name': meal.name,
          'description': meal.description,
          'ingredients': meal.ingredients,
          'nutrition': meal.nutrition,
          'image_url': meal.imageUrl,
          'preparation': meal.instructions.isNotEmpty ? meal.instructions.join('\n') : '',
        }).toList();
      });
    });
    
    return data;
  }
  
  // API integration methods
  
  // Lấy kế hoạch bữa ăn mới nhất của người dùng từ API
  static Future<MealPlan?> getLatestMealPlan(String userId, {String baseUrl = 'https://backend-openfood.onrender.com'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/firestore/latest-meal-plan/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MealPlan.fromJson(data);
      } else {
        print('Lỗi khi lấy kế hoạch bữa ăn: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Lỗi khi gọi API lấy kế hoạch bữa ăn: $e');
      return null;
    }
  }
  
  // Tạo kế hoạch bữa ăn mới từ API
  static Future<MealPlan?> generateWeeklyMealPlan({
    required int caloriesTarget,
    required int proteinTarget,
    required int fatTarget,
    required int carbsTarget,
    String userId = 'default',
    bool useAi = false,
    List<String> preferences = const [],
    List<String> allergies = const [],
    String? cuisineStyle,
    String baseUrl = 'https://backend-openfood.onrender.com',
  }) async {
    try {
      final queryParams = {
        'calories_target': caloriesTarget.toString(),
        'protein_target': proteinTarget.toString(),
        'fat_target': fatTarget.toString(),
        'carbs_target': carbsTarget.toString(),
        'user_id': userId,
        'use_ai': useAi.toString(),
      };
      
      // Thêm preferences nếu có
      if (preferences.isNotEmpty) {
        for (int i = 0; i < preferences.length; i++) {
          queryParams['preferences[$i]'] = preferences[i];
        }
      }
      
      // Thêm allergies nếu có
      if (allergies.isNotEmpty) {
        for (int i = 0; i < allergies.length; i++) {
          queryParams['allergies[$i]'] = allergies[i];
        }
      }
      
      // Thêm cuisine style nếu có
      if (cuisineStyle != null && cuisineStyle.isNotEmpty) {
        queryParams['cuisine_style'] = cuisineStyle;
      }
      
      final uri = Uri.parse('$baseUrl/generate-weekly-meal').replace(queryParameters: queryParams);
      
      print('Calling API: $uri');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MealPlan.fromJson(data);
      } else {
        print('Lỗi khi tạo kế hoạch bữa ăn: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Lỗi khi gọi API tạo kế hoạch bữa ăn: $e');
      return null;
    }
  }
  
  // Thay thế một ngày trong kế hoạch bữa ăn
  static Future<bool> replaceDay({
    required String dayOfWeek,
    required int caloriesTarget,
    required int proteinTarget,
    required int fatTarget,
    required int carbsTarget,
    String userId = 'default',
    bool useAi = false,
    List<String> preferences = const [],
    List<String> allergies = const [],
    String? cuisineStyle,
    String baseUrl = 'https://backend-openfood.onrender.com',
  }) async {
    try {
      // Tạo dữ liệu chính cho body API
      final body = {
        'user_id': userId,
        'day_of_week': dayOfWeek,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
        'diet_restrictions': preferences,
        'health_conditions': allergies,
        'diet_preference': cuisineStyle ?? '',
        // Không đưa use_ai vào body
      };
      
      // Tạo query parameters cho URL
      final queryParams = {
        'user_id': userId,
        'use_ai': useAi.toString(), // Đưa use_ai vào query parameter
      };
      
      // Thêm preferences nếu có
      if (preferences.isNotEmpty) {
        for (int i = 0; i < preferences.length; i++) {
          queryParams['preferences[$i]'] = preferences[i];
        }
      }
      
      // Thêm allergies nếu có
      if (allergies.isNotEmpty) {
        for (int i = 0; i < allergies.length; i++) {
          queryParams['allergies[$i]'] = allergies[i];
        }
      }
      
      // Thêm cuisine style nếu có
      if (cuisineStyle != null && cuisineStyle.isNotEmpty) {
        queryParams['cuisine_style'] = cuisineStyle;
      }
      
      // Tạo URI với query parameters
      final uri = Uri.parse('$baseUrl/api/replace-day').replace(queryParameters: queryParams);
      
      print('🔄 Đang thay thế kế hoạch ngày với AI=${useAi}');
      print('🔄 Đang thay thế kế hoạch ngày từ API: $uri');
      print('📦 Dữ liệu gửi đi: $body');
      
      // Sử dụng jsonEncode để chuyển đổi đúng các giá trị boolean
      final jsonBody = jsonEncode(body);
      print('📦 JSON được gửi đi: $jsonBody');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      );
      
      print('📨 Phản hồi HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('✅ Thay thế kế hoạch ngày thành công. Dữ liệu mới sẽ được cập nhật tự động qua Firebase.');
        return true;
      } else {
        print('❌ Lỗi khi thay thế ngày trong kế hoạch: ${response.statusCode}');
        print('📃 Nội dung phản hồi: ${response.body}');
        throw Exception('Lỗi khi thay thế kế hoạch ngày: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi gọi API thay thế ngày: $e');
      throw Exception('Lỗi khi thay thế kế hoạch ngày: $e');
    }
  }
  
  // Thay thế một bữa ăn cụ thể
  static Future<Map<String, dynamic>?> replaceMeal({
    required String dayOfWeek,
    required String mealType,
    required double caloriesTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbsTarget,
    String userId = 'default',
    bool useAi = false,
    List<String> preferences = const [],
    List<String> allergies = const [],
    String? cuisineStyle,
    String baseUrl = 'https://backend-openfood.onrender.com',
  }) async {
    try {
      final body = {
        'day_of_week': dayOfWeek,
        'meal_type': mealType,
        'calories_target': caloriesTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'carbs_target': carbsTarget,
      };
      
      final queryParams = {
        'user_id': userId,
        'use_ai': useAi.toString(),
      };
      
      // Thêm preferences nếu có
      if (preferences.isNotEmpty) {
        for (int i = 0; i < preferences.length; i++) {
          queryParams['preferences[$i]'] = preferences[i];
        }
      }
      
      // Thêm allergies nếu có
      if (allergies.isNotEmpty) {
        for (int i = 0; i < allergies.length; i++) {
          queryParams['allergies[$i]'] = allergies[i];
        }
      }
      
      // Thêm cuisine style nếu có
      if (cuisineStyle != null && cuisineStyle.isNotEmpty) {
        queryParams['cuisine_style'] = cuisineStyle;
      }
      
      final uri = Uri.parse('$baseUrl/api/meal-plan/replace-meal').replace(queryParameters: queryParams);
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Lỗi khi thay thế bữa ăn: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Lỗi khi gọi API thay thế bữa ăn: $e');
      return null;
    }
  }
  
  // Lấy lịch sử kế hoạch bữa ăn
  static Future<List<MealPlanHistory>?> getMealPlanHistory({
    String userId = 'default',
    int limit = 10,
    String baseUrl = 'https://backend-openfood.onrender.com',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/meal-plan-history').replace(
        queryParameters: {
          'user_id': userId,
          'limit': limit.toString(),
        },
      );
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => MealPlanHistory.fromJson(item)).toList();
      } else {
        print('Lỗi khi lấy lịch sử kế hoạch bữa ăn: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Lỗi khi gọi API lấy lịch sử kế hoạch bữa ăn: $e');
      return null;
    }
  }
  
  // Xóa kế hoạch bữa ăn
  static Future<bool> deleteMealPlan(String filename, {String baseUrl = 'https://backend-openfood.onrender.com'}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/meal-plan/$filename'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Lỗi khi gọi API xóa kế hoạch bữa ăn: $e');
      return false;
    }
  }
}

class DayMealPlan {
  final Map<String, List<Meal>> meals;
  final Map<String, double> nutritionSummary;

  DayMealPlan({
    required this.meals,
    required this.nutritionSummary,
  });

  factory DayMealPlan.fromJson(Map<String, dynamic> json) {
    Map<String, List<Meal>> mealsMap = {};
    
    // Xử lý cấu trúc từ API thực (breakfast, lunch, dinner)
    if (json['breakfast'] != null || json['lunch'] != null || json['dinner'] != null) {
      // Duyệt qua các bữa ăn chính
      ['breakfast', 'lunch', 'dinner'].forEach((mealType) {
        if (json[mealType] != null) {
          String mealTypeVietnamese = _convertMealTypeToVietnamese(mealType);
          List<Meal> mealsList = [];
          
          // Xử lý dishes array
          if (json[mealType]['dishes'] != null && json[mealType]['dishes'] is List) {
            // Tạo một Meal từ thông tin tổng hợp và chứa danh sách dishes
            Map<String, dynamic> mealData = {
              'name': '${mealTypeVietnamese}',
              'description': 'Tổng hợp các món ăn cho ${mealTypeVietnamese.toLowerCase()}',
              'nutrition': json[mealType]['nutrition'] ?? {},
              'ingredients': [],
              'instructions': [],
              'dishes': json[mealType]['dishes'],
            };
            
            // Tạo một Meal chứa nhiều món ăn
            Meal combinedMeal = Meal.fromJson(mealData);
            mealsList.add(combinedMeal);
          }
          
          // Nếu không tìm thấy dishes, thử xử lý dạng cũ (bữa ăn = một món)
          if (mealsList.isEmpty) {
            print('⚠️ Không tìm thấy dishes, đang thử xử lý đối tượng bữa ăn dạng cũ...');
            
            // Tạo một món giả (dish) từ bữa ăn
            Map<String, dynamic> dishData = {
              'name': json[mealType]['name'] ?? mealTypeVietnamese,
              'description': json[mealType]['description'] ?? '',
              'nutrition': json[mealType]['nutrition'] ?? {},
              'ingredients': [],
              'preparation': json[mealType]['preparation'] ?? '',
            };
            
            // Lấy ingredients nếu có
            if (json[mealType]['ingredients'] != null) {
              dishData['ingredients'] = json[mealType]['ingredients'];
            }
            
            // Tạo danh sách dishes chỉ với một món
            List<Map<String, dynamic>> dishes = [dishData];
            
            // Tạo một Meal từ thông tin tổng hợp và chứa dish
            Map<String, dynamic> mealData = {
              'name': mealTypeVietnamese,
              'description': 'Tổng hợp các món ăn cho ${mealTypeVietnamese.toLowerCase()}',
              'nutrition': json[mealType]['nutrition'] ?? {},
              'ingredients': [],
              'instructions': [],
              'dishes': dishes,
            };
            
            // Tạo một Meal chứa một món ăn
            Meal singleDishMeal = Meal.fromJson(mealData);
            mealsList.add(singleDishMeal);
          }
          
          mealsMap[mealTypeVietnamese] = mealsList;
        }
      });
    }
    // Cấu trúc cũ từ mock data
    else if (json['meals'] != null) {
      try {
        final dynamic mealsData = json['meals'];
        if (mealsData is Map) {
          mealsData.forEach((mealType, mealsList) {
            // Đảm bảo mealsList là List và mealType là String
            if (mealsList is List && mealType is String) {
              try {
                List<Meal> meals = [];
                
                // Chuyển đổi danh sách món ăn thành danh sách Meal, mỗi Meal sẽ chứa một Dish
                for (var mealJson in mealsList) {
                  if (mealJson is Map) {
                    Map<String, dynamic> cleanMealJson = Map<String, dynamic>.from(mealJson);
                    
                    // Tạo một món ăn từ thông tin hiện tại
                    Map<String, dynamic> dishData = {
                      'name': cleanMealJson['name'] ?? 'Món ăn',
                      'description': cleanMealJson['description'] ?? '',
                      'nutrition': cleanMealJson['nutrition'] ?? {},
                      'ingredients': cleanMealJson['ingredients'] ?? [],
                      'preparation': cleanMealJson['preparation'] ?? cleanMealJson['instructions'] ?? '',
                    };
                    
                    // Tạo một Meal với một dish
                    Map<String, dynamic> mealWithDishData = {
                      'name': mealType,
                      'description': 'Tổng hợp các món ăn cho ${mealType.toLowerCase()}',
                      'nutrition': cleanMealJson['nutrition'] ?? {},
                      'ingredients': [],
                      'dishes': [dishData],
                    };
                    
                    meals.add(Meal.fromJson(mealWithDishData));
                  }
                }
                
                mealsMap[mealType] = meals;
                
              } catch (e) {
                print('Lỗi xử lý bữa ăn $mealType: $e');
                mealsMap[mealType] = []; // Gán list rỗng nếu lỗi
              }
            } else {
              print('Cấu trúc bữa ăn không hợp lệ cho $mealType');
            }
          });
        } else {
          print('json["meals"] không phải là Map: ${mealsData.runtimeType}');
        }
      } catch (e) {
        print('Lỗi khi xử lý cấu trúc bữa ăn: $e');
      }
    }
    
    // Xử lý thông tin nutrition summary
    Map<String, double> nutritionSummary = {};
    
    // Nếu có nutrition_summary từ cấu trúc cũ
    if (json['nutrition_summary'] != null) {
      nutritionSummary = {
        'calories': (json['nutrition_summary']?['calories'] ?? 0).toDouble(),
        'protein': (json['nutrition_summary']?['protein'] ?? 0).toDouble(),
        'fat': (json['nutrition_summary']?['fat'] ?? 0).toDouble(),
        'carbs': (json['nutrition_summary']?['carbs'] ?? 0).toDouble(),
      };
    } 
    // Cấu trúc mới từ API thực, tính tổng từ các bữa
    else {
      double totalCalories = 0, totalProtein = 0, totalFat = 0, totalCarbs = 0;
      
      ['breakfast', 'lunch', 'dinner'].forEach((mealType) {
        if (json[mealType] != null && json[mealType]['nutrition'] != null) {
          var nutrition = json[mealType]['nutrition'];
          totalCalories += (nutrition['calories'] ?? 0).toDouble();
          totalProtein += (nutrition['protein'] ?? 0).toDouble();
          totalFat += (nutrition['fat'] ?? 0).toDouble();
          totalCarbs += (nutrition['carbs'] ?? 0).toDouble();
        }
      });
      
      nutritionSummary = {
        'calories': totalCalories,
        'protein': totalProtein,
        'fat': totalFat,
        'carbs': totalCarbs,
      };
    }
    
    return DayMealPlan(
      meals: mealsMap,
      nutritionSummary: nutritionSummary,
    );
  }

  // Chuyển đối tượng DayMealPlan thành Map<String, dynamic> để serialize
  Map<String, dynamic> toJson() {
    Map<String, dynamic> mealsJson = {};

    // Chuyển đổi meals map
    meals.forEach((mealType, mealsList) {
      mealsJson[mealType] = mealsList.map((meal) => meal.toJson()).toList();
    });

    return {
      'meals': mealsJson,
      'nutrition_summary': nutritionSummary,
    };
  }

  // Hàm chuyển đổi tên bữa ăn sang tiếng Việt
  static String _convertMealTypeToVietnamese(String englishMealType) {
    switch (englishMealType) {
      case 'breakfast': return 'Bữa sáng';
      case 'lunch': return 'Bữa trưa';
      case 'dinner': return 'Bữa tối';
      case 'snack': return 'Bữa phụ';
      default: return englishMealType;
    }
  }
}

class Meal {
  final String name;
  final String description;
  final Map<String, double> nutrition;
  final List<String> ingredients;
  final String? imageUrl;
  final List<String> instructions;
  final List<Dish> dishes;

  Meal({
    required this.name,
    required this.description,
    required this.nutrition,
    required this.ingredients,
    this.imageUrl,
    this.instructions = const [],
    this.dishes = const [],
  });

  // Chuyển đối tượng Meal thành Map<String, dynamic> để serialize
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'description': description,
      'nutrition': nutrition,
      'ingredients': ingredients,
      'image_url': imageUrl,
      // Luôn gửi preparation dưới dạng List, không chuyển thành chuỗi
      'preparation': instructions,
    };

    // Chuyển đổi danh sách dishes nếu có
    if (dishes.isNotEmpty) {
      data['dishes'] = dishes.map((dish) => dish.toJson()).toList();
    }

    return data;
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    // Chuyển đổi nutrition từ Map<String, dynamic> sang Map<String, double>
    Map<String, double> nutritionMap = {};
    if (json['nutrition'] != null) {
      try {
        final dynamic nutritionData = json['nutrition'];
        if (nutritionData is Map) {
          nutritionData.forEach((key, value) {
            if (value is num) {
              nutritionMap[key.toString()] = value.toDouble();
            } else if (value is String) {
              // Thử chuyển đổi String sang double
              try {
                nutritionMap[key.toString()] = double.parse(value);
              } catch (parseError) {
                print('Không thể chuyển đổi "$value" sang double: $parseError');
              }
            }
          });
        } else {
          print('json["nutrition"] không phải là Map: ${nutritionData.runtimeType}');
        }
      } catch (e) {
        print('Lỗi khi xử lý nutrition: $e');
      }
    }
    
    // Chuyển đổi ingredients từ nhiều định dạng có thể có
    List<String> ingredientsList = [];
    
    // Trường hợp 1: ingredients là List<String> đơn giản
    if (json['ingredients'] != null && json['ingredients'] is List) {
      ingredientsList = (json['ingredients'] as List)
          .map((item) => item.toString())
          .toList();
    }
    // Trường hợp 2: ingredients là List<Map> với cấu trúc phức tạp hơn
    else if (json['ingredients'] != null && json['ingredients'] is List) {
      ingredientsList = (json['ingredients'] as List).map((item) {
        if (item is Map) {
          String text = '';
          if (item['name'] != null) {
            text = item['name'].toString();
            if (item['amount'] != null) {
              text += ' - ${item['amount']}';
            }
          } else {
            text = item.toString();
          }
          return text;
        }
        return item.toString();
      }).toList();
    }
    
    // Xử lý trường description có thể không tồn tại
    String description = '';
    if (json['description'] != null) {
      description = json['description'].toString();
    } else if (json['instructions'] != null && json['instructions'] is String) {
      description = json['instructions'].toString();
    }
    
    // Xử lý hướng dẫn nấu ăn
    List<String> instructionsList = [];
    
    // Kiểm tra các trường hợp định dạng khác nhau của instructions
    if (json['preparation'] != null) {
      print('📝 Found preparation field: ${json['preparation']}');
      print('📝 Preparation type: ${json['preparation'].runtimeType}');
      
      // Trường hợp 1: preparation là List<String>
      if (json['preparation'] is List) {
        instructionsList = (json['preparation'] as List)
            .map((item) => item.toString())
            .toList();
        print('📝 Converted preparation list: $instructionsList');
      } 
      // Trường hợp 2: preparation là String (giữ nguyên chuỗi đó)
      else if (json['preparation'] is String) {
        String instructions = json['preparation'].toString();
        
        // Thử tách thành nhiều bước nếu có dấu hiệu định dạng
        if (instructions.contains("Bước") || instructions.contains("Step") || 
            RegExp(r'\d+[:.]\s+').hasMatch(instructions) || instructions.contains("\n")) {
          print('📝 Preparation có vẻ chứa nhiều bước, thử tách...');
          
          // 1. Thử tách theo regex các bước
          RegExp stepRegex = RegExp(r'(Bước \d+[:.]|Step \d+[:.]|\d+[:.]\s+|Bước [a-zA-Zà-úÀ-Ú]+[:.]|Bước đầu tiên|Bước cuối cùng)');
          Iterable<Match> matches = stepRegex.allMatches(instructions);
          List<int> startPositions = matches.map((m) => m.start).toList();
          
          // 2. Nếu tìm thấy ít nhất hai bước, tách theo vị trí
          if (startPositions.length > 1) {
            List<String> steps = [];
            for (int i = 0; i < startPositions.length; i++) {
              int startPos = startPositions[i];
              int endPos = (i < startPositions.length - 1) ? startPositions[i + 1] : instructions.length;
              String step = instructions.substring(startPos, endPos).trim();
              steps.add(step);
            }
            instructionsList = steps;
            print('📝 Tách được ${steps.length} bước theo định dạng bước');
          }
          // 3. Nếu không, thử tách theo dấu xuống dòng
          else if (instructions.contains("\n")) {
            List<String> steps = instructions.split(RegExp(r'\n+'))
                .where((step) => step.trim().isNotEmpty)
                .map((step) => step.trim())
                .toList();
            
            if (steps.length > 1) {
              instructionsList = steps;
              print('📝 Tách được ${steps.length} bước theo dấu xuống dòng');
            } else {
              instructionsList = [instructions]; // Nếu tách không thành công
            }
          }
          // 4. Nếu không, thử tách theo dấu chấm
          else {
            List<String> steps = instructions.split(RegExp(r'\.\s+'))
                .where((step) => step.trim().isNotEmpty)
                .map((step) => step.trim().endsWith(".") ? step.trim() : step.trim() + ".")
                .toList();
                
            if (steps.length > 1) {
              instructionsList = steps;
              print('📝 Tách được ${steps.length} bước theo dấu chấm');
            } else {
              instructionsList = [instructions]; // Nếu tách không thành công
            }
          }
        } else {
          // Nếu không có dấu hiệu có thể tách, giữ nguyên chuỗi
          instructionsList = [instructions];
        }
        
        print('📝 Final instructions list: ${instructionsList.length} steps');
      }
    } 
    // Trường hợp 3: cooking_instructions là List<String>
    else if (json['cooking_instructions'] != null) {
      // cooking_instructions là List<String>
      if (json['cooking_instructions'] is List) {
        instructionsList = (json['cooking_instructions'] as List)
            .map((item) => item.toString())
            .toList();
      } 
      // cooking_instructions là String
      else if (json['cooking_instructions'] is String) {
        String instructions = json['cooking_instructions'].toString();
        instructionsList = [instructions];
      }
    }
    // Trường hợp 4: instructions là List<String>
    else if (json['instructions'] != null && json['instructions'] is List) {
      instructionsList = (json['instructions'] as List)
          .map((item) => item.toString())
          .toList();
    }
    // Trường hợp 5: instructions là String
    else if (json['instructions'] != null && json['instructions'] is String) {
      String instructions = json['instructions'].toString();
      instructionsList = [instructions];
    }
    // Trường hợp 6: steps là List<String>
    else if (json['steps'] != null && json['steps'] is List) {
      instructionsList = (json['steps'] as List)
          .map((item) => item.toString())
          .toList();
    }
    
    // Đọc trường dishes nếu có (cho nhiều món trong một bữa ăn)
    List<Dish> dishesList = [];
    if (json['dishes'] != null && json['dishes'] is List) {
      try {
        dishesList = (json['dishes'] as List)
            .map((dishJson) => Dish.fromJson(dishJson))
            .toList();
        
        // Nếu tìm thấy dishes, đây là một bữa ăn có nhiều món
        print('📝 Đã tìm thấy ${dishesList.length} món ăn trong bữa ăn');
      } catch (e) {
        print('❌ Lỗi khi xử lý danh sách dishes: $e');
      }
    }
    
    return Meal(
      name: json['name'] ?? '',
      description: description,
      nutrition: nutritionMap,
      ingredients: ingredientsList,
      imageUrl: json['image_url'],
      instructions: instructionsList,
      dishes: dishesList,
    );
  }
}

// Thêm class Dish để đại diện cho một món ăn trong bữa ăn
class Dish {
  final String name;
  final String description;
  final Map<String, double> nutrition;
  final List<String> ingredients;
  final String? imageUrl;
  final List<String> instructions;
  final String? dishType; // Thêm thuộc tính loại món
  final String? region; // Thêm thuộc tính vùng miền
  final String? preparationTime; // Thêm thuộc tính thời gian nấu
  final List<String>? healthBenefits; // Thêm thuộc tính lợi ích sức khỏe

  final int? prepTimeInMinutes; // Thời gian chuẩn bị tính bằng phút
  final List<DetailedIngredient> detailedIngredients; // Nguyên liệu chi tiết với số lượng

  Dish({
    required this.name,
    required this.description,
    required this.nutrition,
    required this.ingredients,
    this.imageUrl,
    this.instructions = const [],
    this.dishType = 'main', // Mặc định là món chính
    this.region = 'north', // Mặc định là miền Bắc
    this.preparationTime, // Thời gian nấu ăn
    this.healthBenefits, // Lợi ích sức khỏe

    this.prepTimeInMinutes, // Thời gian chuẩn bị tính bằng phút
    this.detailedIngredients = const [], // Nguyên liệu chi tiết
  });

  // Chuyển đối tượng Dish thành Map<String, dynamic> để serialize
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'nutrition': nutrition,
      'ingredients': ingredients,
      'image_url': imageUrl,
      // Luôn đảm bảo preparation là List<String> khi chuyển đổi
      'preparation': instructions.isEmpty ? [] : instructions,
      'dish_type': dishType,
      'region': region,
      'preparation_time': preparationTime,
      'health_benefits': healthBenefits,
      'prep_time_minutes': prepTimeInMinutes,
      'detailed_ingredients': detailedIngredients.map((ing) => ing.toJson()).toList(),
    };
  }

  factory Dish.fromJson(Map<String, dynamic> json) {
    // Chuyển đổi nutrition từ Map<String, dynamic> sang Map<String, double>
    Map<String, double> nutritionMap = {};
    if (json['nutrition'] != null) {
      try {
        final dynamic nutritionData = json['nutrition'];
        if (nutritionData is Map) {
          nutritionData.forEach((key, value) {
            if (value is num) {
              nutritionMap[key.toString()] = value.toDouble();
            } else if (value is String) {
              try {
                nutritionMap[key.toString()] = double.parse(value);
              } catch (parseError) {
                print('Không thể chuyển đổi "$value" sang double: $parseError');
              }
            }
          });
        }
      } catch (e) {
        print('Lỗi khi xử lý nutrition của món ăn: $e');
      }
    }
    
    // Xử lý ingredients tương tự như trong Meal
    List<String> ingredientsList = [];
    if (json['ingredients'] != null && json['ingredients'] is List) {
      ingredientsList = (json['ingredients'] as List).map((item) {
        if (item is Map) {
          String text = '';
          if (item['name'] != null) {
            text = item['name'].toString();
            if (item['amount'] != null) {
              text += ' - ${item['amount']}';
            }
          } else {
            text = item.toString();
          }
          return text;
        }
        return item.toString();
      }).toList();
    }
    
    // Xử lý description
    String description = '';
    if (json['description'] != null) {
      description = json['description'].toString();
    }
    
    // Xử lý instructions/preparation một cách linh hoạt hơn
    List<String> instructionsList = [];
    
    // Ưu tiên trường preparation
    if (json['preparation'] != null) {
      if (json['preparation'] is List) {
        // Nếu preparation là danh sách, chuyển đổi mỗi phần tử thành chuỗi
        instructionsList = (json['preparation'] as List)
            .map((item) => item.toString())
            .toList();
      } else if (json['preparation'] is String) {
        // Nếu preparation là chuỗi, tách nó theo dấu xuống dòng
        String prepStr = json['preparation'].toString();
        if (prepStr.contains('\n')) {
          instructionsList = prepStr.split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
        } else {
          instructionsList = [prepStr];
        }
      }
    } 
    // Nếu không có preparation, thử dùng instructions
    else if (json['instructions'] != null) {
      if (json['instructions'] is List) {
        instructionsList = (json['instructions'] as List)
            .map((item) => item.toString())
            .toList();
      } else if (json['instructions'] is String) {
        String instrStr = json['instructions'].toString();
        if (instrStr.contains('\n')) {
          instructionsList = instrStr.split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
        } else {
          instructionsList = [instrStr];
        }
      }
    }
    
    // Xử lý loại món và vùng miền
    String? dishType = json['dish_type'] as String?;
    String? region = json['region'] as String?;
    
    // Xử lý thời gian nấu
    String? preparationTime = json['preparation_time'] as String?;
    
    // Xử lý lợi ích sức khỏe
    List<String>? healthBenefits;
    if (json['health_benefits'] != null) {
      if (json['health_benefits'] is List) {
        healthBenefits = (json['health_benefits'] as List)
            .map((item) => item.toString())
            .toList();
      } else if (json['health_benefits'] is String) {
        // Nếu health_benefits là chuỗi, tách nó thành danh sách
        healthBenefits = json['health_benefits'].toString().split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }

    // Xử lý video URL


    // Xử lý thời gian chuẩn bị
    int? prepTimeInMinutes;
    if (json['prep_time_minutes'] != null) {
      if (json['prep_time_minutes'] is int) {
        prepTimeInMinutes = json['prep_time_minutes'];
      } else if (json['prep_time_minutes'] is String) {
        prepTimeInMinutes = int.tryParse(json['prep_time_minutes']);
      }
    }

    // Xử lý nguyên liệu chi tiết
    List<DetailedIngredient> detailedIngredients = [];
    if (json['detailed_ingredients'] != null && json['detailed_ingredients'] is List) {
      detailedIngredients = (json['detailed_ingredients'] as List)
          .map((item) => DetailedIngredient.fromJson(item))
          .toList();
    }
    
    return Dish(
      name: json['name'] ?? '',
      description: description,
      nutrition: nutritionMap,
      ingredients: ingredientsList,
      imageUrl: json['image_url'],
      instructions: instructionsList,
      dishType: dishType ?? 'main', // Mặc định là món chính
      region: region ?? 'north', // Mặc định là miền Bắc
      preparationTime: preparationTime,
      healthBenefits: healthBenefits,
      prepTimeInMinutes: prepTimeInMinutes,
      detailedIngredients: detailedIngredients,
    );
  }
}

// Lớp này chứa thông tin về lịch sử kế hoạch thực đơn
class MealPlanHistory {
  final String filename;
  final String userId;
  final String planId;
  final DateTime createdAt;
  final Map<String, dynamic> goals;

  MealPlanHistory({
    required this.filename,
    required this.userId,
    required this.planId,
    required this.createdAt,
    required this.goals,
  });

  factory MealPlanHistory.fromJson(Map<String, dynamic> json) {
    return MealPlanHistory(
      filename: json['filename'],
      userId: json['user_id'],
      planId: json['plan_id'],
      createdAt: DateTime.parse(json['created_at']),
      goals: json['goals'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'user_id': userId,
      'plan_id': planId,
      'created_at': createdAt.toIso8601String(),
      'goals': goals,
    };
  }
} 