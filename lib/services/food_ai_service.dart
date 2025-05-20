import 'dart:io';
import 'package:flutter/material.dart';
import '../models/food_entry.dart';

class FoodAIService {
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
} 