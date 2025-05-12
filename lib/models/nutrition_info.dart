class NutritionInfo {
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;
  final String? servingSize;
  final double? servingWeight; // Trọng lượng (g)
  final Map<String, dynamic>? additionalNutrients;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.sugar = 0,
    this.fiber = 0,
    this.sodium = 0,
    this.servingSize,
    this.servingWeight,
    this.additionalNutrients,
  });

  // Từ USDA API
  factory NutritionInfo.fromUSDA(Map<String, dynamic> json) {
    // Các giá trị mặc định
    double calories = 0;
    double protein = 0;
    double fat = 0;
    double carbs = 0;
    double sugar = 0;
    double fiber = 0;
    double sodium = 0;
    String? servingSize;
    double? servingWeight;
    Map<String, dynamic> additionalNutrients = {};

    // Xử lý dữ liệu từ API
    try {
      // Parse serving size
      final servingSizeInfo = json['servingSize'];
      if (servingSizeInfo != null) {
        servingSize = '${servingSizeInfo['amount']} ${servingSizeInfo['unit']}';
        servingWeight = servingSizeInfo['weightInGrams']?.toDouble();
      }

      // Parse các thành phần dinh dưỡng
      final nutrients = json['foodNutrients'] as List?;
      if (nutrients != null) {
        for (var nutrient in nutrients) {
          final name = nutrient['nutrient']['name'];
          final value = nutrient['amount']?.toDouble() ?? 0;
          final unit = nutrient['nutrient']['unitName'] ?? '';

          switch (name) {
            case 'Energy':
              calories = value;
              break;
            case 'Protein':
              protein = value;
              break;
            case 'Total lipid (fat)':
              fat = value;
              break;
            case 'Carbohydrate, by difference':
              carbs = value;
              break;
            case 'Sugars, total including NLEA':
              sugar = value;
              break;
            case 'Fiber, total dietary':
              fiber = value;
              break;
            case 'Sodium, Na':
              sodium = value;
              break;
            default:
              // Lưu các giá trị khác vào additionalNutrients
              additionalNutrients['${name} (${unit})'] = value;
          }
        }
      }
    } catch (e) {
      print('Lỗi khi phân tích dữ liệu dinh dưỡng: $e');
    }

    return NutritionInfo(
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      sugar: sugar,
      fiber: fiber,
      sodium: sodium,
      servingSize: servingSize,
      servingWeight: servingWeight,
      additionalNutrients: additionalNutrients,
    );
  }

  // Từ API nhận diện ảnh
  factory NutritionInfo.fromImageRecognition(Map<String, dynamic> data) {
    return NutritionInfo(
      calories: data['calories']?.toDouble() ?? 0,
      protein: data['protein']?.toDouble() ?? 0,
      fat: data['fat']?.toDouble() ?? 0,
      carbs: data['carbs']?.toDouble() ?? 0,
      sugar: data['sugar']?.toDouble() ?? 0,
      fiber: data['fiber']?.toDouble() ?? 0,
      sodium: data['sodium']?.toDouble() ?? 0,
    );
  }

  // Từ API barcode
  factory NutritionInfo.fromBarcode(Map<String, dynamic> data) {
    return NutritionInfo(
      calories: data['calories']?.toDouble() ?? 0,
      protein: data['protein']?.toDouble() ?? 0,
      fat: data['fat']?.toDouble() ?? 0,
      carbs: data['carbohydrates']?.toDouble() ?? 0,
      sugar: data['sugar']?.toDouble() ?? 0,
      fiber: data['fiber']?.toDouble() ?? 0,
      sodium: data['sodium']?.toDouble() ?? 0,
      servingSize: data['servingSize'],
      servingWeight: data['servingWeight']?.toDouble(),
    );
  }

  // Chuyển đổi sang Map để lưu vào database
  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'sugar': sugar,
      'fiber': fiber,
      'sodium': sodium,
      'servingSize': servingSize,
      'servingWeight': servingWeight,
      'additionalNutrients': additionalNutrients,
    };
  }

  // Từ Map trong database
  factory NutritionInfo.fromMap(Map<String, dynamic> map) {
    return NutritionInfo(
      calories: map['calories'] ?? 0,
      protein: map['protein'] ?? 0,
      fat: map['fat'] ?? 0,
      carbs: map['carbs'] ?? 0,
      sugar: map['sugar'] ?? 0,
      fiber: map['fiber'] ?? 0,
      sodium: map['sodium'] ?? 0,
      servingSize: map['servingSize'],
      servingWeight: map['servingWeight'],
      additionalNutrients: map['additionalNutrients'],
    );
  }
} 