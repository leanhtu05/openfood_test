import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class FoodAIService {
  final String baseUrl = ApiConstants.baseUrl; // URL API của bạn
  final AuthService _authService = AuthService();

  // Để giả lập quá trình xử lý AI (sử dụng cho UI loading)
  Future<void> simulateAIProcessing(Function(int) updateStep) async {
    await Future.delayed(Duration(milliseconds: 800));
    updateStep(1); // Tiền xử lý ảnh
    
    await Future.delayed(Duration(milliseconds: 1500));
    updateStep(2); // Nhận diện món ăn
    
    await Future.delayed(Duration(milliseconds: 800));
    updateStep(3); // Ước tính khẩu phần
    
    await Future.delayed(Duration(milliseconds: 800));
    updateStep(4); // Tính toán dinh dưỡng
  }
  
  // Tạo thông báo thành công dựa trên kết quả nhận diện
  String generateSuccessMessage(FoodEntry entry) {
    final itemsCount = entry.items.length;
    
    if (itemsCount == 0) {
      return 'Đã lưu bữa ăn nhưng không tìm thấy thông tin dinh dưỡng chính xác.';
    } else if (itemsCount == 1) {
      return 'Đã nhận diện: ${entry.items.first.name} (${entry.totalCalories} kcal)';
    } else {
      return 'Đã nhận diện ${itemsCount} món ăn (${entry.totalCalories} kcal)';
    }
  }

  // Gửi ảnh lên API để nhận diện thực phẩm
  Future<Map<String, dynamic>> recognizeFoodFromImage(
    File imageFile, 
    String mealType,
    {bool saveToFirebase = true}
  ) async {
    try {
      // Bước 1-2: Chuẩn bị dữ liệu ảnh
      final token = await _authService.getCurrentToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Bạn cần đăng nhập để sử dụng tính năng này',
        };
      }

      // Bước 3: Tạo request gửi lên API
      final uri = Uri.parse('$baseUrl/api/food/recognize');
      
      // Tạo multipart request
      final request = http.MultipartRequest('POST', uri);
      
      // Thêm headers với token xác thực
      request.headers['Authorization'] = 'Bearer $token';
      
      // Thêm các trường form data
      request.fields['meal_type'] = mealType;
      request.fields['save_to_firebase'] = saveToFirebase.toString();
      
      // Đọc file ảnh dưới dạng bytes
      final bytes = await imageFile.readAsBytes();
      
      // Thêm file ảnh với content-type chính xác
      final multipartFile = http.MultipartFile.fromBytes(
        'image', 
        bytes,
        filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: MediaType('image', 'jpeg'), // Thiết lập content-type là image/jpeg
      );
      
      request.files.add(multipartFile);
      
      // Gửi request và đợi response
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Bước 10-11: Xử lý response
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
          'message': data['message'] ?? 'Nhận diện thành công',
        };
      } else {
        debugPrint('Lỗi API: ${response.statusCode}, ${response.body}');
        return {
          'success': false,
          'message': 'Lỗi khi nhận diện: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      debugPrint('Exception khi nhận diện thực phẩm: $e');
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
      };
    }
  }

  // Chuyển đổi dữ liệu nhận diện từ API thành FoodEntry
  FoodEntry? convertRecognitionResponseToFoodEntry(
    Map<String, dynamic> responseData,
    String mealType,
  ) {
    try {
      final List<dynamic> recognizedFoods = responseData['recognized_foods'] ?? [];
      if (recognizedFoods.isEmpty) {
        return null;
      }
      
      // Tạo danh sách các FoodItem từ dữ liệu nhận diện
      final List<FoodItem> foodItems = recognizedFoods.map<FoodItem>((food) {
        final nutritionData = food['nutrition'] ?? {};
        final String foodId = DateTime.now().millisecondsSinceEpoch.toString() + "_" + (food['food_name'] ?? 'unknown');
        
        return FoodItem(
          id: foodId,
          name: food['food_name'] ?? 'Thực phẩm không xác định',
          calories: nutritionData['calories']?.toDouble() ?? 0,
          protein: nutritionData['protein']?.toDouble() ?? 0,
          fat: nutritionData['fat']?.toDouble() ?? 0,
          carbs: nutritionData['carbs']?.toDouble() ?? 0,
          imageUrl: food['image_url'],
          portionSize: food['portion_size'] ?? '1 phần',
        );
      }).toList();
      
      // Tạo mô tả từ danh sách tên thực phẩm
      final description = foodItems.length == 1
          ? foodItems.first.name
          : foodItems.map((item) => item.name).join(", ");
      
      // Lấy URL hình ảnh từ response nếu có
      final String? imageUrl = recognizedFoods.isNotEmpty && recognizedFoods.first['image_url'] != null 
          ? recognizedFoods.first['image_url'] 
          : null;
      
      // Tạo FoodEntry mới với thông tin nhận diện
      return FoodEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: description,
        mealType: mealType,
        items: foodItems,
        imageUrl: imageUrl,
        dateTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Lỗi khi chuyển đổi dữ liệu: $e');
      return null;
    }
  }
} 