class FoodItem {
  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double calories;     // kcal per 100g or per serving
  final double protein;   // g per 100g or per serving
  final double fat;       // g per 100g or per serving
  final double carbs;     // g per 100g or per serving
  final double? fiber;    // g per 100g or per serving
  final double? sugar;    // g per 100g or per serving
  final double? sodium;   // mg per 100g or per serving
  final double servingSize; // g or ml
  final String servingUnit; // "g", "ml", "piece", etc.
  final Map<String, dynamic>? additionalNutrients; // For other nutrients
  final String? portionSize; // Thêm portionSize dưới dạng optional parameter

  FoodItem({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    this.calories = 0.0,
    this.protein = 0.0,
    this.fat = 0.0,
    this.carbs = 0.0,
    this.fiber,
    this.sugar,
    this.sodium,
    this.servingSize = 1.0,
    this.servingUnit = "g",
    this.additionalNutrients,
    this.portionSize,
  });

  // Factory method to create a FoodItem from JSON
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'],
      name: json['name'],
      brand: json['brand'],
      imageUrl: json['imageUrl'],
      calories: json['calories'] != null ? (json['calories'] as num).toDouble() : 0.0,
      protein: json['protein'] != null ? (json['protein'] as num).toDouble() : 0.0,
      fat: json['fat'] != null ? (json['fat'] as num).toDouble() : 0.0,
      carbs: json['carbs'] != null ? (json['carbs'] as num).toDouble() : 0.0,
      fiber: json['fiber'] != null ? (json['fiber'] as num).toDouble() : null,
      sugar: json['sugar'] != null ? (json['sugar'] as num).toDouble() : null,
      sodium: json['sodium'] != null ? (json['sodium'] as num).toDouble() : null,
      servingSize: json['servingSize'] != null ? (json['servingSize'] as num).toDouble() : 1.0,
      servingUnit: json['servingUnit'] ?? 'g',
      additionalNutrients: json['additionalNutrients'],
      portionSize: json['portionSize'],
    );
  }
  
  // Factory method for compatibility with existing code
  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem.fromJson(map);
  }

  // Convert FoodItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'imageUrl': imageUrl,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'additionalNutrients': additionalNutrients,
      'portionSize': portionSize,
    };
  }
  
  // For compatibility with existing code
  Map<String, dynamic> toMap() {
    return toJson();
  }

  // Similar API format conversion for Open Food Facts API
  factory FoodItem.fromOpenFoodFactsApi(Map<String, dynamic> json) {
    final nutrients = json['nutriments'] ?? {};
    
    return FoodItem(
      id: json['code'] ?? json['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['product_name'] ?? 'Unknown Food',
      brand: json['brands'],
      imageUrl: json['image_url'],
      calories: nutrients['energy-kcal'] != null ? 
              ((nutrients['energy-kcal']) as num).toDouble() : 
              (nutrients['energy'] != null ? ((nutrients['energy']) as num).toDouble() : 0.0),
      protein: nutrients['proteins'] != null ? ((nutrients['proteins']) as num).toDouble() : 0.0,
      fat: nutrients['fat'] != null ? ((nutrients['fat']) as num).toDouble() : 0.0,
      carbs: nutrients['carbohydrates'] != null ? ((nutrients['carbohydrates']) as num).toDouble() : 0.0,
      fiber: nutrients['fiber'] != null ? ((nutrients['fiber']) as num).toDouble() : null,
      sugar: nutrients['sugars'] != null ? ((nutrients['sugars']) as num).toDouble() : null,
      sodium: nutrients['sodium'] != null ? ((nutrients['sodium']) as num).toDouble() : null,
      servingSize: json['serving_quantity'] != null ? 
                 double.tryParse('${json['serving_quantity']}') ?? 1.0 : 1.0,
      servingUnit: json['serving_size'] != null ? 
          json['serving_size'].toString().replaceAll(RegExp(r'[0-9,.]+'), '').trim() : 'g',
      portionSize: json['portionSize'],
    );
  }

  // Tạo bản sao mới với một số thuộc tính có thể thay đổi
  FoodItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? imageUrl,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
    double? servingSize,
    String? servingUnit,
    double? fiber,
    double? sugar,
    double? sodium,
    Map<String, dynamic>? additionalNutrients,
    String? portionSize,
  }) {
    // Tạo bản sao hoàn toàn mới của additionalNutrients để tránh chia sẻ tham chiếu
    Map<String, dynamic>? newAdditionalNutrients;
    if (additionalNutrients != null) {
      newAdditionalNutrients = Map<String, dynamic>.from(additionalNutrients);
    } else if (this.additionalNutrients != null) {
      newAdditionalNutrients = Map<String, dynamic>.from(this.additionalNutrients!);
    }
    
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      additionalNutrients: newAdditionalNutrients,
      portionSize: portionSize ?? this.portionSize,
    );
  }
  
  // Calculate macronutrient percentages
  Map<String, double> get macroPercentages {
    final totalGrams = protein + fat + carbs;
    if (totalGrams == 0) return {'protein': 0, 'fat': 0, 'carbs': 0};
    
    return {
      'protein': protein / totalGrams * 100,
      'fat': fat / totalGrams * 100,
      'carbs': carbs / totalGrams * 100,
    };
  }
  
  // Format for display
  Map<String, String> get formattedNutrients {
    return {
      'calories': '$calories kcal',
      'protein': '${protein.toStringAsFixed(1)}g',
      'fat': '${fat.toStringAsFixed(1)}g',
      'carbs': '${carbs.toStringAsFixed(1)}g',
      'fiber': fiber != null ? '${fiber!.toStringAsFixed(1)}g' : 'N/A',
      'sugar': sugar != null ? '${sugar!.toStringAsFixed(1)}g' : 'N/A',
      'sodium': sodium != null ? '${sodium!.toStringAsFixed(1)}mg' : 'N/A',
    };
  }
} 