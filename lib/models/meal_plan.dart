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
    Map<String, DayMealPlan> weeklyPlanMap = {};
    
    // Kiểm tra cấu trúc từ API thực tế (meal_plan.days)
    if (json['meal_plan'] != null && json['meal_plan']['days'] != null) {
      List<dynamic> days = json['meal_plan']['days'];
      for (var day in days) {
        String dayOfWeek = day['day_of_week'];
        // Chuyển đổi tên ngày tiếng Việt sang tiếng Anh
        String englishDay = _convertVietnameseDayToEnglish(dayOfWeek);
        weeklyPlanMap[englishDay] = DayMealPlan.fromJson(day);
      }
    }
    // Cấu trúc cũ từ mock data
    else if (json['weekly_plan'] != null) {
      (json['weekly_plan'] as Map<String, dynamic>).forEach((key, value) {
        weeklyPlanMap[key] = DayMealPlan.fromJson(value);
      });
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
      default: return vietnameseDay;
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
      (json['meals'] as Map<String, dynamic>).forEach((mealType, mealsList) {
        mealsMap[mealType] = (mealsList as List)
            .map((mealJson) => Meal.fromJson(mealJson))
            .toList();
      });
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

  Meal({
    required this.name,
    required this.description,
    required this.nutrition,
    required this.ingredients,
    this.imageUrl,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    // Chuyển đổi nutrition từ Map<String, dynamic> sang Map<String, double>
    Map<String, double> nutritionMap = {};
    if (json['nutrition'] != null) {
      (json['nutrition'] as Map<String, dynamic>).forEach((key, value) {
        if (value is num) {
          nutritionMap[key] = value.toDouble();
        }
      });
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
    } else if (json['instructions'] != null) {
      description = json['instructions'].toString();
    }
    
    return Meal(
      name: json['name'] ?? '',
      description: description,
      nutrition: nutritionMap,
      ingredients: ingredientsList,
      imageUrl: json['image_url'],
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