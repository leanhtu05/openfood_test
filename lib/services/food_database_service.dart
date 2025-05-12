import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/nutrition_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food_item.dart';
import 'dart:math'; // For demo data
import '../data/vietnamese_food_data.dart';

class FoodDatabaseService {
  static final FoodDatabaseService _instance = FoodDatabaseService._internal();
  
  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';
  static const String _cacheBoxName = 'food_database_cache';
  static const String _openFoodFactsApiBaseUrl = 'https://world.openfoodfacts.org/api/v0';
  static const String _cachedFoodsKey = 'cached_foods';
  
  late Box<Map<dynamic, dynamic>> _cacheBox;
  bool _isInitialized = false;
  String _apiKey = 'DEMO_KEY';  // Default to demo key
  bool _isDemoMode = true; // Default to demo mode
  
  Database? _database;
  
  // Singleton pattern
  factory FoodDatabaseService() => _instance;
  
  FoodDatabaseService._internal();
  
  // Set API key (call this from your app initialization)
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }
  
  // Initialize the service with cache
  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        // Initialize Hive cache
        if (!Hive.isBoxOpen(_cacheBoxName)) {
          _cacheBox = await Hive.openBox<Map<dynamic, dynamic>>(_cacheBoxName);
        } else {
          _cacheBox = Hive.box<Map<dynamic, dynamic>>(_cacheBoxName);
        }
        
        _isInitialized = true;
      } catch (e) {
        debugPrint('Error initializing FoodDatabaseService: $e');
        rethrow;
      }
    }
  }
  
  // Initialize the database
  Future<void> initializeDatabase() async {
    if (_database != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'food_database.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create tables
        await db.execute('''
          CREATE TABLE food_items(
            id TEXT PRIMARY KEY,
            name TEXT,
            brand TEXT,
            imageUrl TEXT,
            calories INTEGER,
            protein REAL,
            fat REAL,
            carbs REAL,
            fiber REAL,
            sugar REAL,
            sodium REAL,
            servingSize REAL,
            servingUnit TEXT,
            additionalNutrients TEXT,
            lastAccessed INTEGER
          )
        ''');
        
        await db.execute('''
          CREATE TABLE food_history(
            id TEXT PRIMARY KEY,
            foodData TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
  }
  
  // Search for food items
  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (!_isInitialized) await initialize();
    
    // Check cache first
    final cacheKey = 'search:$query';
    if (_cacheBox.containsKey(cacheKey)) {
      final cachedResult = _cacheBox.get(cacheKey);
      if (cachedResult != null) {
        return List<Map<String, dynamic>>.from(cachedResult['items'] ?? []);
      }
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/foods/search?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&pageSize=10'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> results = [];
        
        if (data['foods'] != null) {
          for (var food in data['foods']) {
            results.add({
              'fdcId': food['fdcId'],
              'description': food['description'],
              'brandOwner': food['brandOwner'],
              'brandName': food['brandName'],
              'servingSize': food['servingSize'],
              'servingSizeUnit': food['servingSizeUnit'],
              'category': food['foodCategory'],
            });
          }
        }
        
        // Cache the results
        _cacheBox.put(cacheKey, {'items': results, 'timestamp': DateTime.now().toIso8601String()});
        
        return results;
      } else {
        throw Exception('Failed to search foods. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching foods: $e');
      
      // Return demo data in case of error
      return _getDemoSearchResults(query);
    }
  }
  
  // Get detailed nutrition information for a specific food
  Future<NutritionInfo?> getFoodDetails(String fdcId) async {
    if (!_isInitialized) await initialize();
    
    // Check cache first
    final cacheKey = 'food:$fdcId';
    if (_cacheBox.containsKey(cacheKey)) {
      final cachedResult = _cacheBox.get(cacheKey);
      if (cachedResult != null) {
        final Map<String, dynamic> convertedMap = {};
        (cachedResult as Map).forEach((key, value) {
          convertedMap[key.toString()] = value;
        });
        return NutritionInfo.fromUSDA(convertedMap);
      }
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/food/$fdcId?api_key=$_apiKey'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Cache the results
        _cacheBox.put(cacheKey, data);
        
        return NutritionInfo.fromUSDA(data);
      } else {
        throw Exception('Failed to get food details. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting food details: $e');
      
      // Return demo data in case of error
      return _getDemoFoodDetails(fdcId);
    }
  }
  
  // Helper method to return demo search results
  List<Map<String, dynamic>> _getDemoSearchResults(String query) {
    final demoFoods = [
      {
        'fdcId': '1',
        'description': 'Apple, raw',
        'brandOwner': '',
        'brandName': '',
        'category': 'Fruits',
      },
      {
        'fdcId': '2',
        'description': 'Banana, raw',
        'brandOwner': '',
        'brandName': '',
        'category': 'Fruits',
      },
      {
        'fdcId': '3',
        'description': 'Chicken breast, grilled',
        'brandOwner': '',
        'brandName': '',
        'category': 'Poultry',
      },
      {
        'fdcId': '4',
        'description': 'White rice, cooked',
        'brandOwner': '',
        'brandName': '',
        'category': 'Grains and Pasta',
      },
      {
        'fdcId': '5',
        'description': 'Spinach, raw',
        'brandOwner': '',
        'brandName': '',
        'category': 'Vegetables',
      },
    ];
    
    // Filter demo foods based on query
    return demoFoods
        .where((food) {
          final description = food['description'] as String?;
          return description != null && 
                 description.toLowerCase().contains(query.toLowerCase());
        })
        .toList();
  }
  
  // Helper method to return demo food details
  NutritionInfo _getDemoFoodDetails(String fdcId) {
    final demoDetails = {
      '1': NutritionInfo(  // Apple
        calories: 95,
        protein: 0.5,
        fat: 0.3,
        carbs: 25.1,
        sugar: 19.0,
        fiber: 4.4,
        sodium: 2,
        servingSize: '1 medium (182g)',
        servingWeight: 182,
      ),
      '2': NutritionInfo(  // Banana
        calories: 105,
        protein: 1.3,
        fat: 0.4,
        carbs: 27.0,
        sugar: 14.4,
        fiber: 3.1,
        sodium: 1,
        servingSize: '1 medium (118g)',
        servingWeight: 118,
      ),
      '3': NutritionInfo(  // Chicken breast
        calories: 165,
        protein: 31.0,
        fat: 3.6,
        carbs: 0.0,
        sugar: 0.0,
        fiber: 0.0,
        sodium: 74,
        servingSize: '100g',
        servingWeight: 100,
      ),
      '4': NutritionInfo(  // White rice
        calories: 130,
        protein: 2.7,
        fat: 0.3,
        carbs: 28.2,
        sugar: 0.1,
        fiber: 0.4,
        sodium: 1,
        servingSize: '100g',
        servingWeight: 100,
      ),
      '5': NutritionInfo(  // Spinach
        calories: 23,
        protein: 2.9,
        fat: 0.4,
        carbs: 3.6,
        sugar: 0.4,
        fiber: 2.2,
        sodium: 79,
        servingSize: '100g',
        servingWeight: 100,
      ),
    };
    
    return demoDetails[fdcId] ?? NutritionInfo(
      calories: 100,
      protein: 2.0,
      fat: 1.5,
      carbs: 20.0,
      sugar: 5.0,
      fiber: 2.0,
      sodium: 50,
      servingSize: 'Standard serving',
      servingWeight: 100,
    );
  }
  
  // Search food by name or barcode
  Future<List<FoodItem>> searchFoodByNameOrBarcode(String query) async {
    await initialize(); // Đảm bảo cơ sở dữ liệu đã được khởi tạo
    
    // Chuẩn hóa từ khóa tìm kiếm
    final normalizedQuery = query.trim().toLowerCase();
    
    // Tìm kiếm trong dữ liệu món ăn Việt Nam trước
    final vietnameseFoodItem = VietnameseFoodData.getFoodByName(normalizedQuery);
    if (vietnameseFoodItem != null) {
      return [vietnameseFoodItem];
    }
    
    // Nếu không tìm thấy trong dữ liệu món Việt Nam, tìm trong API hoặc cơ sở dữ liệu khác
    // ... existing search code ...
    
    try {
      // Tìm kiếm trong dữ liệu offline nếu có
      List<FoodItem> results = [];
      
      // Thêm mã tìm kiếm từ API
      if (_isDemoMode) {
        results = await _searchDemoData(normalizedQuery);
      } else {
        // Thêm code tìm kiếm từ API thực tế
        results = await _searchApiData(normalizedQuery);
      }
      
      return results;
    } catch (e) {
      print('Lỗi khi tìm kiếm thực phẩm: $e');
      return [];
    }
  }
  
  // Search food in local database
  Future<List<FoodItem>> _searchLocalDatabase(String query, {String? barcode}) async {
    if (_database == null) await initializeDatabase();
    
    try {
      List<Map<String, dynamic>> results;
      
      if (barcode != null && barcode.isNotEmpty) {
        // Search by barcode
        results = await _database!.query(
          'food_items',
          where: 'id = ?',
          whereArgs: [barcode],
        );
      } else {
        // Search by name
        results = await _database!.query(
          'food_items',
          where: 'name LIKE ?',
          whereArgs: ['%$query%'],
          orderBy: 'lastAccessed DESC',
          limit: 20,
        );
      }
      
      // Update last accessed time for results
      for (var result in results) {
        await _database!.update(
          'food_items',
          {'lastAccessed': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [result['id']],
        );
      }
      
      // Convert to FoodItem objects
      return results.map((item) => _foodItemFromMap(item)).toList();
    } catch (e) {
      print('Error searching in local database: $e');
      return [];
    }
  }
  
  // Cache a food item
  Future<void> _cacheFood(FoodItem item) async {
    if (_database == null) await initializeDatabase();
    
    try {
      await _database!.insert(
        'food_items',
        _foodItemToMap(item),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error caching food: $e');
    }
  }
  
  // Helper to convert database Map to FoodItem
  FoodItem _foodItemFromMap(Map<String, dynamic> map) {
    // Parse additionalNutrients if available
    Map<String, dynamic>? additionalNutrients;
    if (map['additionalNutrients'] != null) {
      try {
        additionalNutrients = json.decode(map['additionalNutrients']);
      } catch (e) {
        print('Error parsing additionalNutrients: $e');
      }
    }
    
    return FoodItem(
      id: map['id'],
      name: map['name'],
      brand: map['brand'],
      imageUrl: map['imageUrl'],
      calories: map['calories'],
      protein: map['protein'],
      fat: map['fat'],
      carbs: map['carbs'],
      fiber: map['fiber'],
      sugar: map['sugar'],
      sodium: map['sodium'],
      servingSize: map['servingSize'],
      servingUnit: map['servingUnit'],
      additionalNutrients: additionalNutrients,
    );
  }
  
  // Helper to convert FoodItem to database Map
  Map<String, dynamic> _foodItemToMap(FoodItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'brand': item.brand,
      'imageUrl': item.imageUrl,
      'calories': item.calories,
      'protein': item.protein,
      'fat': item.fat,
      'carbs': item.carbs,
      'fiber': item.fiber,
      'sugar': item.sugar,
      'sodium': item.sodium,
      'servingSize': item.servingSize,
      'servingUnit': item.servingUnit,
      'additionalNutrients': item.additionalNutrients != null 
          ? json.encode(item.additionalNutrients) 
          : null,
      'lastAccessed': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  // Search food by barcode using Open Food Facts API
  Future<FoodItem?> searchByBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_openFoodFactsApiBaseUrl/product/$barcode.json'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 1) {
          return FoodItem.fromOpenFoodFactsApi(data['product']);
        }
      }
      
      return null;
    } catch (e) {
      print('Error searching by barcode: $e');
      return null;
    }
  }
  
  // Search food by name using Open Food Facts API
  Future<List<FoodItem>> searchByName(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_openFoodFactsApiBaseUrl/search?search_terms=$query&page_size=10&json=true'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['products'] != null && data['products'].isNotEmpty) {
          return (data['products'] as List)
              .map((product) => FoodItem.fromOpenFoodFactsApi(product))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error searching by name: $e');
      return [];
    }
  }
  
  // Get recent food items
  Future<List<FoodItem>> getRecentFoodItems({int limit = 10}) async {
    if (_database == null) await initializeDatabase();
    
    try {
      final results = await _database!.query(
        'food_items',
        orderBy: 'lastAccessed DESC',
        limit: limit,
      );
      
      return results.map((item) => _foodItemFromMap(item)).toList();
    } catch (e) {
      print('Error getting recent food items: $e');
      return [];
    }
  }
  
  // Generate demo data for testing when API is unavailable
  List<FoodItem> _getDemoFoodData(String query) {
    // List of common Vietnamese and international foods
    final demoFoods = [
      {
        'name': 'Phở bò',
        'brand': 'Vietnamese Cuisine',
        'calories': 420,
        'protein': 25.0,
        'fat': 10.0,
        'carbs': 60.0,
        'aliases': ['Pho', 'Phở', 'Pho bo', 'Beef noodle soup']
      },
      {
        'name': 'Bánh mì thịt',
        'brand': 'Street Food',
        'calories': 350,
        'protein': 15.0,
        'fat': 12.0,
        'carbs': 50.0,
        'aliases': ['Banh mi', 'Bánh mì', 'Vietnamese sandwich']
      },
      {
        'name': 'Cơm tấm sườn',
        'brand': 'Vietnamese Cuisine',
        'calories': 650,
        'protein': 30.0,
        'fat': 20.0,
        'carbs': 80.0,
        'aliases': ['Com tam', 'Com tam suon', 'Broken rice', 'Rice dish']
      },
      {
        'name': 'Gỏi cuốn',
        'brand': 'Vietnamese Appetizers',
        'calories': 150,
        'protein': 8.0,
        'fat': 2.0,
        'carbs': 25.0,
        'aliases': ['Goi cuon', 'Spring rolls', 'Fresh spring rolls']
      },
      {
        'name': 'Bún chả',
        'brand': 'Hanoi Cuisine',
        'calories': 500,
        'protein': 22.0,
        'fat': 18.0,
        'carbs': 60.0,
        'aliases': ['Bun cha', 'Grilled pork with noodles', 'Noodles']
      },
      {
        'name': 'Bánh xèo',
        'brand': 'Vietnamese Cuisine',
        'calories': 380,
        'protein': 10.0,
        'fat': 18.0,
        'carbs': 45.0,
        'aliases': ['Banh xeo', 'Vietnamese pancake', 'Crepe']
      },
      {
        'name': 'Cháo',
        'brand': 'Vietnamese Breakfast',
        'calories': 220,
        'protein': 8.0,
        'fat': 3.0,
        'carbs': 42.0,
        'aliases': ['Chao', 'Rice porridge', 'Congee', 'Soup']
      },
      {
        'name': 'Bún bò Huế',
        'brand': 'Hue Cuisine',
        'calories': 550,
        'protein': 28.0,
        'fat': 15.0,
        'carbs': 70.0,
        'aliases': ['Bun bo Hue', 'Spicy beef noodle soup', 'Noodles']
      },
      {
        'name': 'Cà phê sữa đá',
        'brand': 'Vietnamese Drinks',
        'calories': 120,
        'protein': 2.0,
        'fat': 4.0,
        'carbs': 18.0,
        'aliases': ['Ca phe sua da', 'Vietnamese coffee', 'Iced coffee']
      },
      {
        'name': 'Burger',
        'brand': 'Fast Food',
        'calories': 550,
        'protein': 25.0,
        'fat': 30.0,
        'carbs': 40.0,
        'aliases': ['Hamburger', 'Cheeseburger', 'Beef burger']
      },
      {
        'name': 'Pizza',
        'brand': 'Italian Food',
        'calories': 285,
        'protein': 12.0,
        'fat': 10.0,
        'carbs': 36.0,
        'aliases': ['Cheese pizza', 'Pepperoni pizza', 'Italian food']
      },
      {
        'name': 'Rice dish',
        'brand': 'Asian Food',
        'calories': 200,
        'protein': 4.0,
        'fat': 0.5,
        'carbs': 45.0,
        'aliases': ['Rice', 'White rice', 'Steamed rice', 'Cơm']
      },
      {
        'name': 'Noodles',
        'brand': 'Asian Food',
        'calories': 190,
        'protein': 7.0,
        'fat': 2.0,
        'carbs': 40.0,
        'aliases': ['Pasta', 'Ramen', 'Mì', 'Bún']
      },
      {
        'name': 'Soup',
        'brand': 'General Food',
        'calories': 120,
        'protein': 6.0,
        'fat': 3.0,
        'carbs': 15.0,
        'aliases': ['Vegetable soup', 'Chicken soup', 'Beef soup', 'Súp']
      },
      {
        'name': 'Salad',
        'brand': 'Healthy Food',
        'calories': 100,
        'protein': 3.0,
        'fat': 2.0,
        'carbs': 12.0,
        'aliases': ['Green salad', 'Vegetable salad', 'Lettuce', 'Rau trộn']
      }
    ];
    
    // Check for exact match or aliases first
    final exactMatchFoods = demoFoods.where((food) {
      final name = food['name'].toString().toLowerCase();
      final aliases = food['aliases'] as List<String>;
      final queryLower = query.toLowerCase();
      
      return name == queryLower || 
             aliases.any((alias) => alias.toLowerCase() == queryLower);
    }).toList();
    
    if (exactMatchFoods.isNotEmpty) {
      return _convertToFoodItems(exactMatchFoods);
    }
    
    // If no exact match, try partial match
    final filteredFoods = demoFoods.where((food) {
      final name = food['name'].toString().toLowerCase();
      final aliases = food['aliases'] as List<String>;
      final queryLower = query.toLowerCase();
      
      return name.contains(queryLower) || 
             aliases.any((alias) => alias.toLowerCase().contains(queryLower));
    }).toList();
    
    return _convertToFoodItems(filteredFoods);
  }
  
  // Helper method to convert Map to FoodItem
  List<FoodItem> _convertToFoodItems(List<dynamic> foods) {
    return foods.map((food) {
      return FoodItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + 
            (food['name'] as String).hashCode.toString(),
        name: food['name'] as String,
        brand: food['brand'] as String,
        calories: (food['calories'] as int).toDouble(),
        protein: food['protein'] as double,
        fat: food['fat'] as double,
        carbs: food['carbs'] as double,
        fiber: (food['fiber'] as double?) ?? 0.0,
        sugar: (food['sugar'] as double?) ?? 0.0,
        sodium: (food['sodium'] as double?) ?? 0.0,
      );
    }).toList();
  }

  // Phương thức tìm kiếm mới sử dụng dữ liệu Việt Nam
  Future<List<FoodItem>> searchVietnameseFood(String query) async {
    final results = <FoodItem>[];
    
    // Lấy danh sách món ăn Việt Nam
    final vietnameseFoods = VietnameseFoodData.getVietnameseFoodItems();
    
    // Tìm kiếm món ăn phù hợp
    for (var food in vietnameseFoods) {
      if (food.name.toLowerCase().contains(query.toLowerCase())) {
        results.add(food);
      }
    }
    
    return results;
  }
  
  // Gợi ý món ăn Việt Nam phổ biến
  Future<List<FoodItem>> getPopularVietnameseFoods(int limit) async {
    final vietnameseFoods = VietnameseFoodData.getVietnameseFoodItems();
    
    // Lấy các món ăn phổ biến (có thể sắp xếp theo thứ tự mong muốn trước khi trả về)
    if (vietnameseFoods.length <= limit) {
      return vietnameseFoods;
    } else {
      return vietnameseFoods.sublist(0, limit);
    }
  }
  
  // Search demo data by term
  Future<List<FoodItem>> _searchDemoData(String query) async {
    return _getDemoFoodData(query);
  }
  
  // Search in API data
  Future<List<FoodItem>> _searchApiData(String query) async {
    try {
      // First search in Vietnamese food data
      final vietnameseFoods = await searchVietnameseFood(query);
      if (vietnameseFoods.isNotEmpty) {
        return vietnameseFoods;
      }
      
      // Then try local database
      final localResults = await _searchLocalDatabase(query);
      if (localResults.isNotEmpty) {
        return localResults;
      }
      
      // Finally try external API
      final barcode = query.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (barcode.length >= 8) {
        // If query looks like a barcode
        final barcodeItem = await searchByBarcode(barcode);
        if (barcodeItem != null) {
          return [barcodeItem];
        }
      }
      
      // Search by name on API
      final apiResults = await searchByName(query);
      return apiResults;
    } catch (e) {
      print('Error searching API data: $e');
      // Return demo data as fallback
      return _getDemoFoodData(query);
    }
  }

  // Tìm kiếm thực phẩm theo mã vạch
  Future<List<FoodItem>> searchFoodByBarcode(String barcode) async {
    try {
      // Đầu tiên, tìm trong cơ sở dữ liệu cục bộ
      List<FoodItem> localResults = await _database!.query(
        'food_items',
        where: 'barcode = ?',
        whereArgs: [barcode],
      ).then((maps) => maps.map((map) => FoodItem.fromMap(map)).toList());
      
      if (localResults.isNotEmpty) {
        return localResults;
      }
      
      // Nếu không tìm thấy, thử tìm từ API Open Food Facts
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json')
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          // Sản phẩm được tìm thấy
          final product = data['product'];
          final foodItem = FoodItem.fromOpenFoodFactsApi(product);
          
          // Lưu vào cơ sở dữ liệu cục bộ để sử dụng sau này
          await _cacheFood(foodItem);
          
          return [foodItem];
        }
      }
      
      // Nếu không tìm thấy, trả về danh sách trống
      return [];
    } catch (e) {
      print('Lỗi khi tìm kiếm thực phẩm theo mã vạch: $e');
      return [];
    }
  }
} 