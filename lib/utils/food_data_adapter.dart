import 'package:uuid/uuid.dart';
import '../models/food_item.dart';
import '../models/food_entry.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import './constants.dart';

/// Lớp FoodDataAdapter đảm nhiệm việc chuyển đổi dữ liệu từ các nguồn khác nhau
/// (phân tích AI, quét mã vạch, tìm kiếm cơ sở dữ liệu) sang định dạng đồng nhất
/// để hiển thị trong màn hình FoodNutritionDetailScreen
/// 
/// Lưu ý: Ứng dụng đã được cập nhật để sử dụng USDA FoodData Central API thay vì Edamam API.
/// USDA API cung cấp dữ liệu dinh dưỡng chi tiết hơn, bao gồm nhiều loại thực phẩm và vi chất
/// dinh dưỡng. Để sử dụng API này, bạn cần đăng ký và lấy API key tại:
/// https://fdc.nal.usda.gov/api-key-signup.html
/// Sau đó cập nhật key trong lib/utils/constants.dart
class FoodDataAdapter {
  static final _uuid = Uuid();

  /// Tạo FoodEntry từ kết quả nhận dạng AI
  static FoodEntry createFromAIRecognition({
    required List<String> recognizedItems,
    required Map<String, dynamic>? nutritionData,
    String? imagePath,
    DateTime? dateTime,
    String mealType = 'Bữa chính',
  }) {
    // Tạo mô tả từ danh sách các món đã nhận dạng
    final description = recognizedItems.isNotEmpty 
        ? recognizedItems.first 
        : 'Món ăn đã nhận dạng';
    
    // Tạo các FoodItem từ dữ liệu dinh dưỡng
    final items = <FoodItem>[];
    
    if (nutritionData != null) {
      items.add(FoodItem(
        id: _uuid.v4(),
        name: description,
        calories: nutritionData['calories'] ?? 0.0,
        protein: nutritionData['protein'] ?? 0.0,
        fat: nutritionData['fat'] ?? 0.0,
        carbs: nutritionData['carbs'] ?? 0.0,
        fiber: nutritionData['fiber'],
        sugar: nutritionData['sugar'],
        sodium: nutritionData['sodium'],
        servingSize: 1.0, // Đại diện cho 100g/ml
        servingUnit: 'g',
        additionalNutrients: _extractAdditionalNutrients(nutritionData),
      ));
    } else {
      // Nếu không có dữ liệu dinh dưỡng, tạo item mặc định
      items.add(FoodItem(
        id: _uuid.v4(),
        name: description,
        calories: 0.0,
        protein: 0.0,
        fat: 0.0,
        carbs: 0.0,
        servingSize: 1.0,
        servingUnit: 'g',
      ));
    }
    
    return FoodEntry(
      id: _uuid.v4(),
      description: description,
      imagePath: imagePath,
      dateTime: dateTime ?? DateTime.now(),
      mealType: mealType,
      items: items,
    );
  }
  
  /// Tạo FoodEntry từ kết quả quét mã vạch
  static FoodEntry createFromBarcode({
    required FoodItem foodItem,
    String? imagePath,
    DateTime? dateTime,
    String mealType = 'Bữa chính',
  }) {
    return FoodEntry(
      id: _uuid.v4(),
      description: foodItem.name,
      imagePath: imagePath ?? foodItem.imageUrl,
      dateTime: dateTime ?? DateTime.now(),
      mealType: mealType,
      items: [foodItem],
    );
  }
  
  /// Cập nhật FoodEntry với thông tin dinh dưỡng mới
  static FoodEntry updateWithNutritionInfo({
    required FoodEntry entry,
    required Map<String, dynamic> nutritionInfo,
    bool fromAPI = false, // Thêm tham số để đánh dấu nguồn dữ liệu
  }) {
    // Đảm bảo đồng bộ hóa tất cả các khóa trước khi xử lý
    Map<String, dynamic> syncedNutritionInfo = Map<String, dynamic>.from(nutritionInfo);
    
    // Đồng bộ khóa dinh dưỡng giữa camelCase và snake_case
    _syncNutrientKeys(syncedNutritionInfo);
    
    // Đảm bảo tất cả các khóa dinh dưỡng cơ bản tồn tại
    final basicNutrients = ['calories', 'protein', 'fat', 'carbs', 'fiber', 'sugar', 'sodium'];
    for (final key in basicNutrients) {
      syncedNutritionInfo.putIfAbsent(key, () => 0.0);
    }
    
    // Cập nhật danh sách items nếu đã có
    List<FoodItem> updatedItems = [];
    
    if (entry.items.isNotEmpty) {
      // Cập nhật item đầu tiên
      final item = entry.items.first;
      updatedItems.add(FoodItem(
        id: item.id,
        name: item.name,
        brand: item.brand,
        imageUrl: item.imageUrl,
        calories: syncedNutritionInfo['calories'] ?? item.calories,
        protein: syncedNutritionInfo['protein'] ?? item.protein,
        fat: syncedNutritionInfo['fat'] ?? item.fat,
        carbs: syncedNutritionInfo['carbs'] ?? item.carbs,
        fiber: syncedNutritionInfo['fiber'] ?? item.fiber,
        sugar: syncedNutritionInfo['sugar'] ?? item.sugar,
        sodium: syncedNutritionInfo['sodium'] ?? item.sodium,
        servingSize: item.servingSize,
        servingUnit: item.servingUnit,
        additionalNutrients: _extractAdditionalNutrients(syncedNutritionInfo),
      ));
      
      // Thêm các items còn lại nếu có
      if (entry.items.length > 1) {
        updatedItems.addAll(entry.items.sublist(1));
      }
    } else {
      // Tạo item mới nếu chưa có
      updatedItems.add(FoodItem(
        id: _uuid.v4(),
        name: entry.description,
        calories: syncedNutritionInfo['calories'] ?? 0.0,
        protein: syncedNutritionInfo['protein'] ?? 0.0,
        fat: syncedNutritionInfo['fat'] ?? 0.0,
        carbs: syncedNutritionInfo['carbs'] ?? 0.0,
        fiber: syncedNutritionInfo['fiber'] ?? 0.0,
        sugar: syncedNutritionInfo['sugar'] ?? 0.0,
        sodium: syncedNutritionInfo['sodium'] ?? 0.0,
        servingSize: syncedNutritionInfo['servingSize'] ?? 1.0,
        servingUnit: 'g',
        additionalNutrients: _extractAdditionalNutrients(syncedNutritionInfo),
      ));
    }
    
    // Nếu dữ liệu từ API, cập nhật thêm trường dataSource
    if (fromAPI) {
      syncedNutritionInfo['dataSource'] = 'API';
      syncedNutritionInfo['dataTimestamp'] = DateTime.now().toIso8601String();
    }
    
    // In thông tin để debug
    print("FoodDataAdapter.updateWithNutritionInfo: Nutrient keys: ${syncedNutritionInfo.keys.toList()}");
    
    // Kiểm tra và in ra các giá trị vitamin - chỉ cho mục đích debug
    print("FoodDataAdapter.updateWithNutritionInfo: Vitamin values - vitamin_a: ${syncedNutritionInfo['vitamin_a']}, vitaminA: ${syncedNutritionInfo['vitaminA']}");
    print("FoodDataAdapter.updateWithNutritionInfo: Vitamin values - vitamin_c: ${syncedNutritionInfo['vitamin_c']}, vitaminC: ${syncedNutritionInfo['vitaminC']}");
    
    // Tạo một FoodEntry mới với dữ liệu dinh dưỡng đã được cập nhật
    return FoodEntry(
      id: entry.id,
      description: entry.description,
      imagePath: entry.imagePath,
      audioPath: entry.audioPath,
      dateTime: entry.dateTime,
      isFavorite: entry.isFavorite,
      barcode: entry.barcode,
      calories: syncedNutritionInfo['calories'] ?? entry.calories,
      nutritionInfo: syncedNutritionInfo,
      mealType: entry.mealType,
      items: updatedItems,
    );
  }
  
  /// Hàm đồng bộ khóa dinh dưỡng giữa camelCase và snake_case
  static void _syncNutrientKeys(Map<String, dynamic> nutritionInfo) {
    // Danh sách các khóa cần đồng bộ: snake_case -> camelCase và ngược lại
    final keyMappings = {
      'vitamin_a': 'vitaminA',
      'vitamin_b12': 'vitaminB12',
      'vitamin_c': 'vitaminC',
      'vitamin_d': 'vitaminD',
      'vitamin_e': 'vitaminE',
      'vitamin_k': 'vitaminK',
      'vitamin_b9': 'vitaminB9',
      'vitamin_b': 'vitaminB',
      'saturated_fat': 'saturatedFat',
      'trans_fat': 'transFat',
      // Thêm các khóa còn thiếu
      'cholesterol': 'cholesterol',
      'omega3': 'omega3',
      'fiber': 'fiber',
      'water': 'water',
      'sugar': 'sugar',
      'caffeine': 'caffeine',
      'alcohol': 'alcohol',
      'iron': 'iron',
      'calcium': 'calcium',
      'magnesium': 'magnesium',
      'potassium': 'potassium',
      'zinc': 'zinc',
      'phosphorus': 'phosphorus',
      'selenium': 'selenium',
      'copper': 'copper',
      'manganese': 'manganese',
      'thiamin': 'thiamin',
      'riboflavin': 'riboflavin',
      'niacin': 'niacin',
    };
    
    // Đảm bảo các giá trị cơ bản luôn tồn tại với giá trị mặc định là 0.0
    final defaultNutrients = [
      'vitamin_a', 'vitaminA', 'vitamin_b12', 'vitaminB12', 'vitamin_c', 'vitaminC',
      'vitamin_d', 'vitaminD', 'vitamin_e', 'vitaminE', 'vitamin_k', 'vitaminK',
      'vitamin_b9', 'vitaminB9', 'vitamin_b', 'vitaminB', 'saturated_fat', 'saturatedFat',
      'trans_fat', 'transFat', 'cholesterol', 'omega3', 'fiber', 'water', 'sugar',
      'caffeine', 'alcohol', 'iron', 'calcium', 'magnesium', 'potassium', 'zinc',
      'phosphorus', 'selenium', 'copper', 'manganese', 'thiamin', 'riboflavin', 'niacin'
    ];
    
    // Thêm giá trị mặc định 0.0 cho các khóa chưa tồn tại
    for (final key in defaultNutrients) {
      nutritionInfo.putIfAbsent(key, () => 0.0);
    }
    
    // Đồng bộ từ snake_case sang camelCase và ngược lại
    keyMappings.forEach((snakeKey, camelKey) {
      // Đảm bảo cả hai khóa tồn tại
      nutritionInfo.putIfAbsent(snakeKey, () => 0.0);
      nutritionInfo.putIfAbsent(camelKey, () => 0.0);
      
      // Giá trị không null sẽ được ưu tiên
      if (nutritionInfo[snakeKey] != null && nutritionInfo[snakeKey] is num) {
        nutritionInfo[camelKey] = nutritionInfo[snakeKey];
      } else if (nutritionInfo[camelKey] != null && nutritionInfo[camelKey] is num) {
        nutritionInfo[snakeKey] = nutritionInfo[camelKey];
      } else {
        // Nếu cả hai đều null hoặc không phải số, gán giá trị mặc định 0.0
        nutritionInfo[snakeKey] = 0.0;
        nutritionInfo[camelKey] = 0.0;
      }
    });
    
    // In thông tin để debug
    print("FoodDataAdapter._syncNutrientKeys: Các khóa sau khi đồng bộ: ${nutritionInfo.keys.toList()}");
  }
  
  /// Trích xuất thông tin dinh dưỡng bổ sung
  static Map<String, dynamic>? _extractAdditionalNutrients(Map<String, dynamic> data) {
    final additionalNutrients = <String, dynamic>{};
    
    // Danh sách các dinh dưỡng cơ bản đã được xử lý riêng trong FoodItem
    final basicNutrients = ['calories', 'protein', 'fat', 'carbs', 'fiber', 'sugar', 'sodium'];
    
    // QUAN TRỌNG: Sao chép tất cả các khóa dinh dưỡng vào additionalNutrients 
    // kể cả các khóa đã được xử lý để đảm bảo đầy đủ dữ liệu
    data.forEach((key, value) {
      // Bỏ qua các dinh dưỡng cơ bản đã được xử lý riêng
      if (!basicNutrients.contains(key)) {
        // Với dữ liệu số, đảm bảo đúng định dạng double
        if (value == null) {
          additionalNutrients[key] = 0.0; // Đảm bảo không có giá trị null
        } else if (value is num) {
          additionalNutrients[key] = value.toDouble();
        } else if (value is String) {
          // Thử parse giá trị nếu là chuỗi số
          try {
            additionalNutrients[key] = double.tryParse(value) ?? 0.0;
          } catch (e) {
            additionalNutrients[key] = value; // Giữ nguyên nếu không phải số
          }
        } else {
          additionalNutrients[key] = value;
        }
      }
    });
    
    // Đồng bộ hóa các khóa dinh dưỡng
    _syncNutrientKeys(additionalNutrients);
    
    // Đảm bảo các vitamin quan trọng luôn có giá trị
    final importantNutrients = [
      'vitamin_a', 'vitaminA', 
      'vitamin_b12', 'vitaminB12', 
      'vitamin_c', 'vitaminC',
      'vitamin_d', 'vitaminD',
      'vitamin_e', 'vitaminE',
      'vitamin_k', 'vitaminK',
      'cholesterol',
      'omega3',
    ];
    
    for (final key in importantNutrients) {
      additionalNutrients.putIfAbsent(key, () => 0.0);
    }
    
    // Debug: in ra các additionalNutrients
    print("_extractAdditionalNutrients: ${additionalNutrients.keys.toList()}");
    print("Số lượng additionalNutrients: ${additionalNutrients.length}");
    
    return additionalNutrients.isNotEmpty ? additionalNutrients : null;
  }
  
  /// Lấy bữa ăn dựa trên thời gian hiện tại
  static String getMealTypeBasedOnTime(DateTime time) {
    final hour = time.hour;
    
    if (hour >= 5 && hour < 10) {
      return 'Bữa sáng';
    } else if (hour >= 10 && hour < 14) {
      return 'Bữa trưa';
    } else if (hour >= 17 && hour < 21) {
      return 'Bữa tối';
    } else {
      return 'Bữa phụ';
    }
  }
  
  /// Tìm thông tin dinh dưỡng từ API cho món ăn
  static Future<Map<String, dynamic>?> fetchNutritionInfo(String foodName, {String? language = 'vi'}) async {
    try {
      // Import thông tin API từ constants
      final apiKey = ApiKeys.usdaApiKey;
      final baseUrl = ApiKeys.usdaBaseUrl;
      
      if (apiKey == 'YOUR_USDA_API_KEY') {
        print('Cần cấu hình USDA API Key trong constants.dart');
        // Sử dụng dữ liệu giả lập nếu không có API key
        final mockData = _generateMockNutritionData(foodName);
        print("Đang sử dụng dữ liệu giả lập cho '$foodName': ${mockData.keys.toList()}");
        return mockData;
      }

      // BƯỚC 1: Tìm kiếm thực phẩm theo tên
      final searchUrl = '$baseUrl/foods/search';
      final searchParams = {
        'api_key': apiKey,
        'query': foodName,
        'dataType': 'Foundation,SR Legacy,Survey (FNDDS)',
        'pageSize': '1', // Chỉ lấy kết quả đầu tiên
      };
      
      final searchUri = Uri.parse(searchUrl).replace(queryParameters: searchParams);
      final searchResponse = await http.get(
        searchUri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 15));
      
      if (searchResponse.statusCode != 200) {
        print('Lỗi khi tìm kiếm thực phẩm: ${searchResponse.statusCode}');
        final mockData = _generateMockNutritionData(foodName);
        print("Đang sử dụng dữ liệu giả lập cho '$foodName' (lỗi tìm kiếm): ${mockData.keys.toList()}");
        return mockData;
      }

      final searchData = jsonDecode(searchResponse.body);
      if (searchData['foods'] == null || searchData['foods'].isEmpty) {
        print('Không tìm thấy thực phẩm: $foodName');
        final mockData = _generateMockNutritionData(foodName);
        print("Đang sử dụng dữ liệu giả lập cho '$foodName' (không tìm thấy kết quả): ${mockData.keys.toList()}");
        return mockData;
      }

      // BƯỚC 2: Lấy thông tin chi tiết của thực phẩm đầu tiên
      final foodId = searchData['foods'][0]['fdcId'];
      final detailUrl = '$baseUrl/food/$foodId';
      final detailParams = {
        'api_key': apiKey,
        'format': 'full'
      };

      final detailUri = Uri.parse(detailUrl).replace(queryParameters: detailParams);
      final detailResponse = await http.get(
        detailUri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (detailResponse.statusCode != 200) {
        print('Lỗi khi lấy chi tiết thực phẩm: ${detailResponse.statusCode}');
        final mockData = _generateMockNutritionData(foodName);
        print("Đang sử dụng dữ liệu giả lập cho '$foodName' (lỗi chi tiết): ${mockData.keys.toList()}");
        return mockData;
      }

      // BƯỚC 3: Chuyển đổi dữ liệu từ USDA sang định dạng ứng dụng
      final detailData = jsonDecode(detailResponse.body);
      final nutrients = detailData['foodNutrients'] ?? [];
      
      // Map để lưu thông tin dinh dưỡng
      final nutritionInfo = <String, dynamic>{
        'dataSource': 'USDA:${detailData['dataType'] ?? 'unknown'}',
        'timestamp': DateTime.now().toIso8601String(),
        'servingSize': 100.0, // Mặc định 100g/ml
        'totalWeight': 100.0,
      };
      
      // Mapping ID dinh dưỡng của USDA sang tên dinh dưỡng của ứng dụng
      // Tham khảo: https://fdc.nal.usda.gov/docs/Foundation_Food_JSON_Format.pdf
      final nutrientMapping = {
        1008: 'calories',        // Energy (kcal)
        1003: 'protein',         // Protein
        1004: 'fat',             // Total lipid (fat)
        1005: 'carbs',           // Carbohydrate, by difference
        1079: 'fiber',           // Fiber, total dietary
        2000: 'sugar',           // Sugars, total including NLEA
        1093: 'sodium',          // Sodium, Na
        1253: 'cholesterol',     // Cholesterol
        1258: 'omega3',          // Fatty acids, total omega 3
        1051: 'water',           // Water
        1257: 'saturated_fat',   // Fatty acids, total saturated
        1057: 'caffeine',        // Caffeine
        1018: 'alcohol',         // Alcohol, ethyl
        1114: 'vitamin_d',       // Vitamin D
        1178: 'vitamin_b12',     // Vitamin B-12
        1162: 'vitamin_c',       // Vitamin C, total ascorbic acid
        1190: 'vitamin_b9',      // Folate, total
        1089: 'iron',            // Iron, Fe
        1087: 'calcium',         // Calcium, Ca
        1090: 'magnesium',       // Magnesium, Mg
        1095: 'zinc',            // Zinc, Zn
        1092: 'potassium',       // Potassium, K
        1106: 'vitamin_a',       // Vitamin A, RAE
        1109: 'vitamin_e',       // Vitamin E (alpha-tocopherol)
        1185: 'vitamin_k',       // Vitamin K (phylloquinone)
        1165: 'thiamin',         // Thiamin
        1166: 'riboflavin',      // Riboflavin
        1167: 'niacin',          // Niacin
        1091: 'phosphorus',      // Phosphorus, P
        1103: 'selenium',        // Selenium, Se
        1098: 'copper',          // Copper, Cu
        1101: 'manganese',       // Manganese, Mn
      };

      // Xử lý từng dinh dưỡng
      for (var nutrient in nutrients) {
        final nutrientId = nutrient['nutrientId'] ?? nutrient['nutrient']?['id'];
        final amount = nutrient['amount'] ?? nutrient['value'] ?? 0.0;
        
        if (nutrientId != null && nutrientMapping.containsKey(nutrientId)) {
          nutritionInfo[nutrientMapping[nutrientId]!] = amount;
        }
      }

      // Đảm bảo các thông tin dinh dưỡng cơ bản luôn có giá trị
      nutritionInfo['calories'] ??= 0.0;
      nutritionInfo['protein'] ??= 0.0;
      nutritionInfo['fat'] ??= 0.0;
      nutritionInfo['carbs'] ??= 0.0;
      
      print("Dữ liệu dinh dưỡng từ API USDA cho '$foodName': ${nutritionInfo.keys.toList()}");
      print("Giá trị Vitamin và khoáng chất: vitamin_a: ${nutritionInfo['vitamin_a']}, vitamin_c: ${nutritionInfo['vitamin_c']}, iron: ${nutritionInfo['iron']}");
      
      return nutritionInfo;
      
    } catch (e) {
      print('Lỗi khi gọi USDA API lấy thông tin dinh dưỡng: $e');
      
      // Sử dụng dữ liệu giả lập trong trường hợp lỗi
      final mockData = _generateMockNutritionData(foodName);
      print("Đang sử dụng dữ liệu giả lập cho '$foodName' (lỗi): ${mockData.keys.toList()}");
      return mockData;
    }
  }
  
  /// Mã hóa các tham số URL
  static String _encodeParams(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
  
  /// Tạo dữ liệu dinh dưỡng giả lập dựa trên tên món ăn
  static Map<String, dynamic> _generateMockNutritionData(String foodName) {
    final lowerName = foodName.toLowerCase();
    
    // Tạo map đầy đủ cho tất cả các loại thực phẩm
    final baseData = {
      // Dinh dưỡng cơ bản
      'calories': 100.0,
      'protein': 5.0,
      'fat': 3.0,
      'carbs': 10.0,
      'fiber': 2.0,
      'sugar': 2.0,
      'sodium': 50.0,
      
      // Thông tin phục vụ
      'servingSize': 1.0,
      'totalWeight': 100.0,
      'dataSource': 'MockAPI',
      'timestamp': DateTime.now().toIso8601String(),
      
      // Sức khỏe Tim mạch
      'cholesterol': 10.0,
      'omega3': 0.1,
      'water': 70.0,
      
      // Tiêu thụ Kiểm soát
      'saturated_fat': 1.0,
      'saturatedFat': 1.0,
      'trans_fat': 0.1,
      'transFat': 0.1,
      'caffeine': 0.0,
      'alcohol': 0.0,
      
      // Vitamin
      'vitamin_d': 2.0,
      'vitaminD': 2.0,
      'vitamin_b12': 0.5,
      'vitaminB12': 0.5,
      'vitamin_c': 10.0,
      'vitaminC': 10.0,
      'vitamin_b': 0.3,
      'vitaminB': 0.3,
      'vitamin_b9': 20.0,
      'vitaminB9': 20.0,
      'vitamin_a': 100.0,
      'vitaminA': 100.0,
      'vitamin_e': 2.0,
      'vitaminE': 2.0,
      'vitamin_k': 20.0,
      'vitaminK': 20.0,
      
      // Khoáng chất
      'iron': 1.0,
      'calcium': 20.0,
      'magnesium': 10.0,
      'potassium': 200.0,
      'zinc': 0.5,
      'phosphorus': 50.0,
      'selenium': 5.0,
      'copper': 0.1,
      'manganese': 0.2,
      
      // Khác
      'thiamin': 0.1,
      'riboflavin': 0.1,
      'niacin': 1.0,
    };
    
    // Giá trị cho một số món ăn phổ biến
    if (lowerName.contains('gà') || lowerName.contains('chicken')) {
      return {
        ...baseData,
        'calories': 165.0,
        'protein': 31.0,
        'fat': 3.6,
        'carbs': 0.0,
        'cholesterol': 85.0,
        'iron': 1.3,
        'vitamin_b12': 0.4,
        'vitaminB12': 0.4,
      };
    }
    else if (lowerName.contains('cá') || lowerName.contains('fish')) {
      return {
        ...baseData,
        'calories': 206.0,
        'protein': 22.0,
        'fat': 12.0,
        'carbs': 0.0,
        'cholesterol': 63.0,
        'omega3': 1.8,
        'vitamin_d': 10.0,
        'vitaminD': 10.0,
      };
    }
    else if (lowerName.contains('rau') || lowerName.contains('vegetable')) {
      return {
        ...baseData,
        'calories': 65.0,
        'protein': 2.9,
        'fat': 0.4,
        'carbs': 13.0,
        'fiber': 4.0,
        'vitamin_c': 80.0,
        'vitaminC': 80.0,
        'vitamin_a': 400.0,
        'vitaminA': 400.0,
        'iron': 1.8,
      };
    }
    else if (lowerName.contains('trái cây') || lowerName.contains('fruit')) {
      return {
        ...baseData,
        'calories': 95.0,
        'protein': 0.5,
        'fat': 0.3,
        'carbs': 25.0,
        'fiber': 4.0,
        'sugar': 19.0,
        'vitamin_c': 70.0,
        'vitaminC': 70.0,
        'potassium': 450.0,
      };
    }
    
    // Đồng bộ hóa keys trước khi trả về
    _syncNutrientKeys(baseData);
    
    return baseData;
  }
} 
