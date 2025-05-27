import 'dart:convert';
import 'package:http/http.dart' as http;

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
    print('🔍 Đang phân tích dữ liệu MealPlan...');
    print('🔑 Các khóa cấp cao nhất: ${json.keys.toList()}');
    
    Map<String, DayMealPlan> weeklyPlanMap = {};
    
    // Kiểm tra cấu trúc từ API thực tế (meal_plan.days hoặc days trực tiếp)
    if (json['days'] != null) {
      print('📅 Số ngày từ Firebase: ${json['days'].length}');
      List<dynamic> days = json['days'];
      
      for (var day in days) {
        String dayOfWeek = day['day_of_week'];
        print('📆 Ngày tiếng Việt: $dayOfWeek');
        // Chuyển đổi tên ngày tiếng Việt sang tiếng Anh
        String englishDay = _convertVietnameseDayToEnglish(dayOfWeek);
        print('📆 Ngày sau khi chuyển đổi: $englishDay');
        weeklyPlanMap[englishDay] = DayMealPlan.fromJson(day);
      }
    }
    // Cấu trúc cũ từ mock data
    else if (json['weekly_plan'] != null) {
      try {
        dynamic weeklyPlanData = json['weekly_plan'];
        if (weeklyPlanData is Map) {
          weeklyPlanData.forEach((key, value) {
            try {
              if (key is String && value is Map) {
                // Chuyển đổi map để đảm bảo đúng kiểu dữ liệu
                final Map<String, dynamic> cleanValue = Map<String, dynamic>.from(value);
                weeklyPlanMap[key] = DayMealPlan.fromJson(cleanValue);
              } else {
                print('Bỏ qua day plan không hợp lệ: key=$key, value type=${value.runtimeType}');
              }
            } catch (dayError) {
              print('Lỗi khi xử lý day plan cho $key: $dayError');
            }
          });
        } else {
          print('json["weekly_plan"] không phải là Map: ${weeklyPlanData.runtimeType}');
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
          'preparation': meal.instructions,
        }).toList();
      });
    });
    
    return data;
  }
  
  // API integration methods
  
  // Lấy kế hoạch bữa ăn mới nhất của người dùng từ API
  static Future<MealPlan?> getLatestMealPlan(String userId, {String baseUrl = 'http://192.168.0.101:8000'}) async {
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
    String baseUrl = 'http://192.168.0.101:8000',
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
  static Future<DayMealPlan?> replaceDay({
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
    String baseUrl = 'http://192.168.0.101:8000',
  }) async {
    try {
      final body = {
        'day_of_week': dayOfWeek,
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
      
      final uri = Uri.parse('$baseUrl/api/replace-day').replace(queryParameters: queryParams);
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['day_meal_plan'] != null) {
          return DayMealPlan.fromJson(data['day_meal_plan']);
        }
        return null;
      } else {
        print('Lỗi khi thay thế ngày trong kế hoạch: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Lỗi khi gọi API thay thế ngày: $e');
      return null;
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
    String baseUrl = 'http://192.168.0.101:8000',
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
    String baseUrl = 'http://192.168.0.101:8000',
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
  static Future<bool> deleteMealPlan(String filename, {String baseUrl = 'http://192.168.0.101:8000'}) async {
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
            mealsList = (json[mealType]['dishes'] as List)
                .map((dish) => Meal.fromJson(dish))
                .toList();
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
                mealsMap[mealType] = mealsList
                    .map((mealJson) => Meal.fromJson(Map<String, dynamic>.from(mealJson)))
                    .toList();
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

  Meal({
    required this.name,
    required this.description,
    required this.nutrition,
    required this.ingredients,
    this.imageUrl,
    this.instructions = const [],
  });

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
      // Trường hợp 2: preparation là String (có thể được phân tách bằng dấu xuống dòng)
      else if (json['preparation'] is String) {
        String instructions = json['preparation'].toString();
        // Tách chuỗi thành các bước dựa trên dấu xuống dòng hoặc số
        instructionsList = instructions
            .split(RegExp(r'(?:\r?\n|\r|(?<=\.)(?=\s*\d+\.)|\. (?=\d+\.))'))
            .where((step) => step.trim().isNotEmpty)
            .map((step) => step.trim())
            .toList();
        print('📝 Converted preparation string: $instructionsList');
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
        instructionsList = instructions
            .split(RegExp(r'(?:\r?\n|\r|(?<=\.)(?=\s*\d+\.)|\. (?=\d+\.))'))
            .where((step) => step.trim().isNotEmpty)
            .map((step) => step.trim())
            .toList();
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
      instructionsList = instructions
          .split(RegExp(r'(?:\r?\n|\r|(?<=\.)(?=\s*\d+\.)|\. (?=\d+\.))'))
          .where((step) => step.trim().isNotEmpty)
          .map((step) => step.trim())
          .toList();
    }
    // Trường hợp 6: steps là List<String>
    else if (json['steps'] != null && json['steps'] is List) {
      instructionsList = (json['steps'] as List)
          .map((item) => item.toString())
          .toList();
    }
    
    return Meal(
      name: json['name'] ?? '',
      description: description,
      nutrition: nutritionMap,
      ingredients: ingredientsList,
      imageUrl: json['image_url'],
      instructions: instructionsList,
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