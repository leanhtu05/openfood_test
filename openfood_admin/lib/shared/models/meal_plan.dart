import 'dart:convert';

class DetailedIngredient {
  final String name;
  final String amount;
  final String? unit;
  final String? category;

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
    Map<String, DayMealPlan> weeklyPlanMap = {};
    
    if (json['days'] != null) {
      List<dynamic> days = json['days'];
      for (var day in days) {
        String dayOfWeek = day['day_of_week'];
        String englishDay = _convertVietnameseDayToEnglish(dayOfWeek);
        weeklyPlanMap[englishDay] = DayMealPlan.fromJson(day);
      }
    } else if (json['weekly_plan'] != null) {
      dynamic weeklyPlanData = json['weekly_plan'];
      if (weeklyPlanData is Map) {
        weeklyPlanData.forEach((key, value) {
          if (key is String && value is Map) {
            final Map<String, dynamic> cleanValue = Map<String, dynamic>.from(value);
            weeklyPlanMap[key] = DayMealPlan.fromJson(cleanValue);
          }
        });
      }
    }
    
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
  
  static String _convertVietnameseDayToEnglish(String vietnameseDay) {
    switch (vietnameseDay) {
      case 'Thứ 2': return 'Monday';
      case 'Thứ 3': return 'Tuesday';
      case 'Thứ 4': return 'Wednesday';
      case 'Thứ 5': return 'Thursday';
      case 'Thứ 6': return 'Friday';
      case 'Thứ 7': return 'Saturday';
      case 'Chủ nhật': return 'Sunday';
      case 'Chủ Nhật': return 'Sunday';
      default: return vietnameseDay;
    }
  }
  
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

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    
    data['weekly_plan'] = {};
    weeklyPlan.forEach((day, plan) {
      data['weekly_plan'][day] = {
        'day_of_week': day,
        'nutrition_summary': plan.nutritionSummary,
        'meals': {}
      };
      
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
    
    if (json['breakfast'] != null) {
      mealsMap['breakfast'] = (json['breakfast'] as List)
          .map((meal) => Meal.fromJson(meal))
          .toList();
    }
    if (json['lunch'] != null) {
      mealsMap['lunch'] = (json['lunch'] as List)
          .map((meal) => Meal.fromJson(meal))
          .toList();
    }
    if (json['dinner'] != null) {
      mealsMap['dinner'] = (json['dinner'] as List)
          .map((meal) => Meal.fromJson(meal))
          .toList();
    }
    
    Map<String, double> nutritionSummary = {};
    if (json['nutrition'] != null) {
      var nutrition = json['nutrition'];
      nutritionSummary = {
        'calories': (nutrition['calories'] ?? 0).toDouble(),
        'protein': (nutrition['protein'] ?? 0).toDouble(),
        'fat': (nutrition['fat'] ?? 0).toDouble(),
        'carbs': (nutrition['carbs'] ?? 0).toDouble(),
      };
    }
    
    return DayMealPlan(
      meals: mealsMap,
      nutritionSummary: nutritionSummary,
    );
  }
}

class Meal {
  final String name;
  final String description;
  final List<String> ingredients;
  final Map<String, double> nutrition;
  final String? imageUrl;
  final List<String> instructions;

  Meal({
    required this.name,
    required this.description,
    required this.ingredients,
    required this.nutrition,
    this.imageUrl,
    required this.instructions,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      nutrition: Map<String, double>.from(
        (json['nutrition'] ?? {}).map((key, value) => MapEntry(key, (value ?? 0).toDouble()))
      ),
      imageUrl: json['image_url'],
      instructions: List<String>.from(json['instructions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'ingredients': ingredients,
      'nutrition': nutrition,
      'image_url': imageUrl,
      'instructions': instructions,
    };
  }
}
