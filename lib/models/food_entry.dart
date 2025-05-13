import 'package:uuid/uuid.dart';
import 'food_item.dart';

class FoodEntry {
  final String id;
  final String description;
  final String? imagePath;
  final String? audioPath;
  final DateTime dateTime;
  final bool isFavorite;
  final String? barcode;
  final double calories; // Ước tính calo
  final Map<String, dynamic>? nutritionInfo; // Thông tin dinh dưỡng bổ sung
  final String mealType;
  final List<FoodItem> items;

  FoodEntry({
    String? id,
    required this.description,
    this.imagePath,
    this.audioPath,
    DateTime? dateTime,
    this.isFavorite = false,
    this.barcode,
    this.calories = 0.0,
    this.nutritionInfo,
    required this.mealType,
    required this.items,
  }) : this.id = id ?? Uuid().v4(),
       this.dateTime = dateTime ?? DateTime.now();

  // Getters for nutrition information based on items
  // servingSize là tỷ lệ theo 100g, ví dụ: servingSize=1.0 tương đương 100g
  double get totalCalories => items.isEmpty ? 0.0 : items.fold(0.0, (sum, item) => sum + (item.calories * item.servingSize));
  double get totalProtein => items.isEmpty ? 0.0 : items.fold(0.0, (sum, item) => sum + (item.protein * item.servingSize));
  double get totalFat => items.isEmpty ? 0.0 : items.fold(0.0, (sum, item) => sum + (item.fat * item.servingSize));
  double get totalCarbs => items.isEmpty ? 0.0 : items.fold(0.0, (sum, item) => sum + (item.carbs * item.servingSize));
  
  // Additional nutritional calculations
  double get totalFiber => items.isEmpty ? 0.0 : items.fold(0.0, (sum, item) => sum + ((item.fiber ?? 0.0) * item.servingSize));
  double get totalSugar => items.isEmpty ? 0.0 : items.fold(0.0, (sum, item) => sum + ((item.sugar ?? 0.0) * item.servingSize));
  double get totalSodium => items.isEmpty ? 0.0 : items.fold(0.0, (sum, item) => sum + ((item.sodium ?? 0.0) * item.servingSize));
  
  // Get total weight in grams
  double get totalWeight => items.isEmpty ? 0.0 : items.fold(0.0, (sum, item) => sum + (item.servingSize * 100));

  // Tính toán giá trị dinh dưỡng dựa trên dữ liệu API
  Map<String, double> calculateNutritionFromAPI() {
    // Nếu không có thông tin dinh dưỡng từ API, trả về giá trị mặc định từ items
    if (nutritionInfo == null || nutritionInfo!.isEmpty) {
      return {
        'calories': totalCalories,
        'protein': totalProtein,
        'fat': totalFat,
        'carbs': totalCarbs,
        'fiber': totalFiber,
        'sugar': totalSugar,
        'sodium': totalSodium,
        'totalWeight': totalWeight,
      };
    }
    
    // Lấy giá trị từ API, dùng giá trị từ items nếu không có
    final caloriesFromAPI = nutritionInfo!['calories'] is num ? (nutritionInfo!['calories'] as num).toDouble() : totalCalories;
    final proteinFromAPI = nutritionInfo!['protein'] is num ? (nutritionInfo!['protein'] as num).toDouble() : totalProtein;
    final fatFromAPI = nutritionInfo!['fat'] is num ? (nutritionInfo!['fat'] as num).toDouble() : totalFat;
    final carbsFromAPI = nutritionInfo!['carbs'] is num ? (nutritionInfo!['carbs'] as num).toDouble() : totalCarbs;
    final fiberFromAPI = nutritionInfo!['fiber'] is num ? (nutritionInfo!['fiber'] as num).toDouble() : totalFiber;
    final sugarFromAPI = nutritionInfo!['sugar'] is num ? (nutritionInfo!['sugar'] as num).toDouble() : totalSugar;
    final sodiumFromAPI = nutritionInfo!['sodium'] is num ? (nutritionInfo!['sodium'] as num).toDouble() : totalSodium;
    
    // Lấy tổng khối lượng từ API hoặc tính từ items
    final totalWeightFromAPI = nutritionInfo!['totalWeight'] is num ? 
        (nutritionInfo!['totalWeight'] as num).toDouble() : totalWeight;
    
    return {
      'calories': caloriesFromAPI,
      'protein': proteinFromAPI,
      'fat': fatFromAPI,
      'carbs': carbsFromAPI,
      'fiber': fiberFromAPI,
      'sugar': sugarFromAPI,
      'sodium': sodiumFromAPI,
      'totalWeight': totalWeightFromAPI,
    };
  }

  // Calculate macronutrient percentages
  Map<String, double> get macroPercentages {
    final totalGrams = totalProtein + totalFat + totalCarbs;
    if (totalGrams == 0) return {'protein': 0, 'fat': 0, 'carbs': 0};
    
    return {
      'protein': totalProtein / totalGrams * 100,
      'fat': totalFat / totalGrams * 100,
      'carbs': totalCarbs / totalGrams * 100,
    };
  }

  // Tạo một bản sao của đối tượng với các giá trị mới
  FoodEntry copyWith({
    String? description,
    String? imagePath,
    String? audioPath,
    DateTime? dateTime,
    bool? isFavorite,
    String? barcode,
    double? calories,
    Map<String, dynamic>? nutritionInfo,
    String? mealType,
    List<FoodItem>? items,
  }) {
    return FoodEntry(
      id: this.id,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      audioPath: audioPath ?? this.audioPath,
      dateTime: dateTime ?? this.dateTime,
      isFavorite: isFavorite ?? this.isFavorite,
      barcode: barcode ?? this.barcode,
      calories: calories ?? this.calories,
      nutritionInfo: nutritionInfo ?? this.nutritionInfo,
      mealType: mealType ?? this.mealType,
      items: items ?? this.items,
    );
  }

  // Chuyển đổi từ Map (database) sang đối tượng
  factory FoodEntry.fromMap(Map<String, dynamic> map) {
    return FoodEntry(
      id: map['id'],
      description: map['description'],
      imagePath: map['imagePath'],
      audioPath: map['audioPath'],
      dateTime: DateTime.parse(map['dateTime']),
      isFavorite: map['isFavorite'] == 1,
      barcode: map['barcode'],
      calories: map['calories'] ?? 0.0,
      nutritionInfo: map['nutritionInfo'] != null 
          ? Map<String, dynamic>.from(map['nutritionInfo']) 
          : null,
      mealType: map['mealType'],
      items: map.containsKey('items') && map['items'] != null
          ? (map['items'] as List).map((item) => FoodItem.fromMap(item)).toList()
          : [],
    );
  }

  // Chuyển đổi từ đối tượng sang Map (database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'imagePath': imagePath,
      'audioPath': audioPath,
      'dateTime': dateTime.toIso8601String(),
      'isFavorite': isFavorite ? 1 : 0,
      'barcode': barcode,
      'calories': calories,
      'nutritionInfo': nutritionInfo,
      'mealType': mealType,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  // Factory method to create a FoodEntry from JSON
  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'],
      description: json['description'],
      imagePath: json['imagePath'],
      audioPath: json['audioPath'],
      dateTime: DateTime.parse(json['dateTime']),
      isFavorite: json['isFavorite'] == 1,
      barcode: json['barcode'],
      calories: json['calories'] ?? 0.0,
      nutritionInfo: json['nutritionInfo'] != null 
          ? Map<String, dynamic>.from(json['nutritionInfo']) 
          : null,
      mealType: json['mealType'],
      items: json.containsKey('items') && json['items'] != null
          ? (json['items'] as List).map((item) => FoodItem.fromJson(item)).toList()
          : [],
    );
  }

  // Convert FoodEntry to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'imagePath': imagePath,
      'audioPath': audioPath,
      'dateTime': dateTime.toIso8601String(),
      'isFavorite': isFavorite ? 1 : 0,
      'barcode': barcode,
      'calories': calories,
      'nutritionInfo': nutritionInfo,
      'mealType': mealType,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
} 