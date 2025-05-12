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

  FoodItem({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.fiber,
    this.sugar,
    this.sodium,
    this.servingSize = 1.0,
    this.servingUnit = "g",
    this.additionalNutrients,
  });

  // Factory method to create a FoodItem from JSON
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'],
      name: json['name'],
      brand: json['brand'],
      imageUrl: json['imageUrl'],
      calories: (json['calories'] as num).toDouble(), // Calories per 100g
      protein: (json['protein'] as num).toDouble(), // Protein per 100g
      fat: (json['fat'] as num).toDouble(), // Fat per 100g
      carbs: (json['carbs'] as num).toDouble(), // Carbs per 100g
      fiber: json['fiber'] != null ? (json['fiber'] as num).toDouble() : null,
      sugar: json['sugar'] != null ? (json['sugar'] as num).toDouble() : null,
      sodium: json['sodium'] != null ? (json['sodium'] as num).toDouble() : null,
      servingSize: json['servingSize'] != null ? (json['servingSize'] as num).toDouble() : 1.0,
      servingUnit: json['servingUnit'] ?? 'g',
      additionalNutrients: json['additionalNutrients'],
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
      calories: ((nutrients['energy-kcal'] ?? nutrients['energy'] ?? 0) as num).toDouble(),
      protein: (nutrients['proteins'] ?? 0).toDouble(),
      fat: (nutrients['fat'] ?? 0).toDouble(),
      carbs: (nutrients['carbohydrates'] ?? 0).toDouble(),
      fiber: (nutrients['fiber'] ?? 0).toDouble(),
      sugar: (nutrients['sugars'] ?? 0).toDouble(),
      sodium: (nutrients['sodium'] ?? 0).toDouble(),
      servingSize: double.tryParse('${json['serving_quantity'] ?? 1}') ?? 1.0,
      servingUnit: json['serving_size'] != null ? 
          json['serving_size'].toString().replaceAll(RegExp(r'[0-9,.]+'), '').trim() : 'g',
    );
  }

  // Create a copy with modified values
  FoodItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? imageUrl,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
    double? fiber,
    double? sugar,
    double? sodium,
    double? servingSize,
    String? servingUnit,
    Map<String, dynamic>? additionalNutrients,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      additionalNutrients: additionalNutrients ?? this.additionalNutrients,
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