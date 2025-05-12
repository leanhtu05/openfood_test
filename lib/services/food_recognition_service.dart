import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class FoodRecognitionService {
  // Clarifai API configurations
  static const String _clarifaiEndpoint = 'https://api.clarifai.com/v2/models/bd367be194cf45149e75f01d59f77ba7/outputs';
  static const String _clarifaiKey = 'YOUR_CLARIFAI_API_KEY'; // Replace with your actual API key
  
  // Google Vision API configurations
  static const String _googleVisionEndpoint = 'https://vision.googleapis.com/v1/images:annotate';
  static const String _googleVisionKey = 'YOUR_GOOGLE_VISION_API_KEY'; // Replace with your actual API key
  
  // API selector
  static const String _activeAPI = 'clarifai'; // Options: 'clarifai', 'google', 'demo'
  
  bool _isDemoMode = true; // Set to false when using a real API
  bool _isInitialized = false;
  final Random _random = Random();
  
  // Initialize the service - this method is called from main.dart
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check which API to use
      if (_activeAPI == 'clarifai' && _clarifaiKey != 'YOUR_CLARIFAI_API_KEY') {
        _isDemoMode = false;
        print('Food Recognition Service: Using Clarifai API');
      } else if (_activeAPI == 'google' && _googleVisionKey != 'YOUR_GOOGLE_VISION_API_KEY') {
        _isDemoMode = false;
        print('Food Recognition Service: Using Google Vision API');
      } else {
        _isDemoMode = true;
        print('Food Recognition Service: Using demo mode');
      }
      
      // Load any cached data or prepare resources if needed
      _isInitialized = true;
    } catch (e) {
      print('Error initializing Food Recognition Service: $e');
      _isDemoMode = true; // Fall back to demo mode in case of error
    }
  }

  // Recognize food from image
  Future<List<String>> recognizeFoodFromImage(File image) async {
    if (_isDemoMode) {
      return _recognizeWithDemoMode(image);
    } else {
      try {
        if (_activeAPI == 'clarifai') {
          return await _recognizeWithClarifai(image);
        } else if (_activeAPI == 'google') {
          return await _recognizeWithGoogleVision(image);
        } else {
          return _recognizeWithDemoMode(image);
        }
      } catch (e) {
        print('Error with cloud API: $e');
        return _recognizeWithDemoMode(image);
      }
    }
  }
  
  // Recognize food using Clarifai Food Model
  Future<List<String>> _recognizeWithClarifai(File imageFile) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Prepare request body
      final requestBody = {
        "inputs": [
          {
            "data": {
              "image": {
                "base64": base64Image
              }
            }
          }
        ]
      };
      
      // Send request
      final response = await http.post(
        Uri.parse(_clarifaiEndpoint),
        headers: {
          'Authorization': 'Key $_clarifaiKey',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extract food predictions
        final outputs = data['outputs'];
        if (outputs != null && outputs.isNotEmpty) {
          final concepts = outputs[0]['data']['concepts'] as List;
          
          // Filter predictions with confidence > 0.7
          final predictions = concepts
              .where((concept) => concept['value'] > 0.7)
              .map((concept) => concept['name'].toString())
              .toList();
          
          if (predictions.isNotEmpty) {
            print('Clarifai identified: $predictions');
            
            // Cache the results
            await _cacheRecognitionResult(imageFile.path, predictions.cast<String>());
            
            return predictions.cast<String>();
          }
        }
      }
      
      print('No food identified by Clarifai or error: ${response.statusCode}, ${response.body}');
      return _recognizeWithDemoMode(imageFile);
    } catch (e) {
      print('Error with Clarifai API: $e');
      return _recognizeWithDemoMode(imageFile);
    }
  }
  
  // Recognize food using Google Vision API
  Future<List<String>> _recognizeWithGoogleVision(File imageFile) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Prepare request body
      final requestBody = {
        "requests": [
          {
            "image": {
              "content": base64Image
            },
            "features": [
              {
                "type": "LABEL_DETECTION",
                "maxResults": 10
              },
              {
                "type": "WEB_DETECTION",
                "maxResults": 10
              }
            ]
          }
        ]
      };
      
      // Send request
      final response = await http.post(
        Uri.parse('$_googleVisionEndpoint?key=$_googleVisionKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <String>[];
        
        // Extract label annotations
        final labelAnnotations = data['responses'][0]['labelAnnotations'] as List?;
        if (labelAnnotations != null) {
          for (var label in labelAnnotations) {
            if (label['score'] > 0.7 && 
                (label['description'].toString().contains('food') || 
                 label['description'].toString().contains('dish') ||
                 label['description'].toString().contains('meal'))) {
              results.add(label['description']);
            }
          }
        }
        
        // Extract web detection results which often have more specific food names
        final webDetection = data['responses'][0]['webDetection'];
        if (webDetection != null) {
          final webEntities = webDetection['webEntities'] as List?;
          if (webEntities != null) {
            for (var entity in webEntities) {
              if (entity['score'] > 0.7) {
                results.add(entity['description']);
              }
            }
          }
        }
        
        if (results.isNotEmpty) {
          print('Google Vision identified: $results');
          
          // Filter food-related terms only
          final foodResults = _filterFoodItems(results);
          
          // Cache the results
          await _cacheRecognitionResult(imageFile.path, foodResults);
          
          return foodResults;
        }
      }
      
      print('No food identified by Google Vision or error: ${response.statusCode}');
      return _recognizeWithDemoMode(imageFile);
    } catch (e) {
      print('Error with Google Vision API: $e');
      return _recognizeWithDemoMode(imageFile);
    }
  }
  
  // Filter out non-food items from recognition results
  List<String> _filterFoodItems(List<String> items) {
    // Food-related keywords
    final foodKeywords = [
      'food', 'dish', 'meal', 'cuisine', 'breakfast', 'lunch', 'dinner',
      'dessert', 'appetizer', 'snack', 'rice', 'noodle', 'meat', 'vegetable',
      'fruit', 'soup', 'salad', 'seafood', 'fish', 'chicken', 'beef', 'pork',
      'pasta', 'bread', 'sandwich', 'burger', 'pizza', 'stew', 'bun', 'bánh',
      'phở', 'cơm', 'bún', 'gỏi', 'canh', 'chả', 'thịt', 'rau'
    ];
    
    return items.where((item) {
      final lowerItem = item.toLowerCase();
      for (var keyword in foodKeywords) {
        if (lowerItem.contains(keyword)) {
          return true;
        }
      }
      return false;
    }).toList();
  }
  
  // Demo mode improved for testing without real API
  Future<List<String>> _recognizeWithDemoMode(File imageFile) async {
    try {
      // Check if we have cached results for this image
      final cachedResults = await _getCachedRecognition(imageFile.path);
      if (cachedResults != null && cachedResults.isNotEmpty) {
        return cachedResults;
      }
      
      // Phân tích tên file
      final fileName = path.basename(imageFile.path).toLowerCase();
      
      // Danh sách các món Việt Nam với độ chính xác cao hơn
      final List<Map<String, dynamic>> vietnameseFoods = [
        {'name': 'Phở bò', 'type': 'soup', 'keywords': ['pho', 'beef', 'noodle', 'soup']},
        {'name': 'Phở gà', 'type': 'soup', 'keywords': ['pho', 'chicken', 'soup']},
        {'name': 'Bánh mì thịt', 'type': 'sandwich', 'keywords': ['banh', 'mi', 'bread', 'sandwich']},
        {'name': 'Cơm tấm sườn', 'type': 'rice', 'keywords': ['com', 'tam', 'rice', 'pork']},
        {'name': 'Bún chả', 'type': 'noodle', 'keywords': ['bun', 'cha', 'noodle', 'pork']},
        {'name': 'Bún bò Huế', 'type': 'soup', 'keywords': ['bun', 'bo', 'hue', 'beef', 'spicy']},
        {'name': 'Bánh xèo', 'type': 'pancake', 'keywords': ['banh', 'xeo', 'pancake', 'crepe']},
        {'name': 'Gỏi cuốn', 'type': 'roll', 'keywords': ['goi', 'cuon', 'roll', 'spring']},
        {'name': 'Chả giò', 'type': 'fried', 'keywords': ['cha', 'gio', 'roll', 'fried']},
        {'name': 'Cơm rang', 'type': 'rice', 'keywords': ['com', 'fried', 'rice']},
        {'name': 'Bún riêu', 'type': 'soup', 'keywords': ['bun', 'rieu', 'crab', 'soup']},
        {'name': 'Canh chua', 'type': 'soup', 'keywords': ['canh', 'chua', 'sour', 'soup']},
        {'name': 'Bò kho', 'type': 'stew', 'keywords': ['bo', 'kho', 'beef', 'stew']},
        {'name': 'Cơm chiên', 'type': 'rice', 'keywords': ['com', 'chien', 'fried', 'rice']},
        {'name': 'Bún thịt nướng', 'type': 'noodle', 'keywords': ['bun', 'thit', 'nuong', 'grilled', 'pork']},
        {'name': 'Bánh cuốn', 'type': 'roll', 'keywords': ['banh', 'cuon', 'roll', 'steamed']},
        {'name': 'Hủ tiếu', 'type': 'soup', 'keywords': ['hu', 'tieu', 'noodle', 'soup']},
        {'name': 'Miến gà', 'type': 'noodle', 'keywords': ['mien', 'ga', 'glass', 'noodle', 'chicken']},
        {'name': 'Cá kho', 'type': 'fish', 'keywords': ['ca', 'kho', 'fish', 'braised']},
        {'name': 'Cháo', 'type': 'porridge', 'keywords': ['chao', 'porridge', 'rice']},
      ];
      
      // Danh sách các món quốc tế
      final List<Map<String, dynamic>> internationalFoods = [
        {'name': 'Burger', 'type': 'sandwich', 'keywords': ['burger', 'beef', 'fast']},
        {'name': 'Pizza', 'type': 'baked', 'keywords': ['pizza', 'cheese', 'tomato']},
        {'name': 'Pasta', 'type': 'noodle', 'keywords': ['pasta', 'noodle', 'italian']},
        {'name': 'Salad', 'type': 'vegetable', 'keywords': ['salad', 'vegetable', 'green']},
        {'name': 'Sushi', 'type': 'rice', 'keywords': ['sushi', 'japanese', 'raw', 'fish']},
        {'name': 'Steak', 'type': 'meat', 'keywords': ['steak', 'beef', 'grilled']},
        {'name': 'Sandwich', 'type': 'bread', 'keywords': ['sandwich', 'bread', 'ham']},
        {'name': 'Taco', 'type': 'mexican', 'keywords': ['taco', 'mexican', 'corn']},
        {'name': 'Curry', 'type': 'stew', 'keywords': ['curry', 'indian', 'spicy']},
        {'name': 'Fried Rice', 'type': 'rice', 'keywords': ['fried', 'rice', 'asian']},
      ];
      
      // Công cụ phân tích màu sắc và nhiều yếu tố khác
      final colorAnalysis = await _analyzeImageColors(imageFile);
      
      // Tạo list kết quả
      final results = <String>[];
      
      // Tìm kiếm từ khóa trong tên file để xác định món ăn
      bool foundMatch = false;
      
      // Kiểm tra từ khóa trong tên file
      for (var food in [...vietnameseFoods, ...internationalFoods]) {
        for (var keyword in food['keywords']) {
          if (fileName.contains(keyword)) {
            results.add(food['name']);
            foundMatch = true;
            break;
          }
        }
        if (foundMatch && results.length >= 2) break;
      }
      
      // Nếu không tìm thấy từ khóa, dùng phân tích màu sắc
      if (!foundMatch) {
        // Chọn món dựa trên phân tích màu sắc
        if (colorAnalysis['isRedDominant'] == true) {
          // Gợi ý các món có màu đỏ (cà chua, ớt)
          results.add(_random.nextBool() ? 'Bún bò Huế' : 'Bò kho');
        } else if (colorAnalysis['isGreenDominant'] == true) {
          // Gợi ý các món có màu xanh lá (rau)
          results.add(_random.nextBool() ? 'Salad' : 'Gỏi cuốn');
        } else if (colorAnalysis['isBrownDominant'] == true) {
          // Gợi ý các món có màu nâu (thịt, đồ chiên)
          results.add(_random.nextBool() ? 'Cơm tấm sườn' : 'Burger');
        } else {
          // Mặc định - thêm món ngẫu nhiên
          results.add(vietnameseFoods[_random.nextInt(vietnameseFoods.length)]['name']);
          
          // Thêm món thứ hai nếu chưa có
          if (results.length < 2 && _random.nextBool()) {
            String secondFood;
            do {
              secondFood = internationalFoods[_random.nextInt(internationalFoods.length)]['name'];
            } while (results.contains(secondFood));
            results.add(secondFood);
          }
        }
      }
      
      // Đảm bảo có ít nhất 1 kết quả
      if (results.isEmpty) {
        results.add(vietnameseFoods[_random.nextInt(vietnameseFoods.length)]['name']);
      }
      
      // Thêm món thứ hai nếu có nhiều món trong ảnh (based on complexity)
      if (results.length < 2 && colorAnalysis['complexity'] > 0.6) {
        String additionalFood;
        do {
          additionalFood = _random.nextBool() 
              ? vietnameseFoods[_random.nextInt(vietnameseFoods.length)]['name']
              : internationalFoods[_random.nextInt(internationalFoods.length)]['name'];
        } while (results.contains(additionalFood));
        results.add(additionalFood);
      }
      
      // Lưu cache kết quả
      _cacheRecognitionResult(imageFile.path, results);
      
      // Giả lập độ trễ mạng
      await Future.delayed(Duration(milliseconds: 800));
      
      print('DEBUG: Recognized food items: $results');
      return results;
    } catch (e) {
      print('Error in demo recognition: $e');
      return ['Cơm tấm']; // Mặc định trả về món ăn phổ biến
    }
  }
  
  // Phân tích ảnh dựa trên màu sắc và méo dạng
  Future<Map<String, dynamic>> _analyzeImageColors(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileSize = await imageFile.length();
      
      // Phương pháp phân tích đơn giản, giả mạo
      // Trong thực tế, chúng ta sẽ sử dụng các thư viện xử lý ảnh như TensorFlow
      
      // Tạo số giả mạo dựa trên hash của file
      final fileHash = imageFile.path.hashCode;
      final hashBasedRandom = Random(fileHash);
      
      // Kết quả phân tích giả định
      return {
        'isRedDominant': hashBasedRandom.nextBool(),
        'isGreenDominant': hashBasedRandom.nextBool(),
        'isYellowDominant': hashBasedRandom.nextBool(),
        'isBrownDominant': hashBasedRandom.nextBool(),
        'hasMultipleColors': hashBasedRandom.nextBool(),
        'complexity': hashBasedRandom.nextDouble(),
        'brightness': hashBasedRandom.nextDouble(),
        'contrast': hashBasedRandom.nextDouble(),
      };
    } catch (e) {
      print('Error analyzing image colors: $e');
      return {'isRedDominant': false, 'isGreenDominant': true};
    }
  }
  
  // Cache recognition results for the same images
  Future<void> _cacheRecognitionResult(String imagePath, List<String> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'food_recognition_${imagePath.hashCode}';
      await prefs.setStringList(cacheKey, results);
    } catch (e) {
      print('Error caching recognition result: $e');
    }
  }
  
  // Check if an image has been recognized before
  Future<List<String>?> _getCachedRecognition(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'food_recognition_${imagePath.hashCode}';
      return prefs.getStringList(cacheKey);
    } catch (e) {
      print('Error getting cached recognition: $e');
      return null;
    }
  }
}
