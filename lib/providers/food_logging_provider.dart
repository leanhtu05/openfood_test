import 'package:flutter/material.dart';
import 'dart:io';
import '../models/food_item.dart';

class FoodLoggingProvider with ChangeNotifier {
  // Dữ liệu tạm thời cho quá trình ghi nhận thức ăn
  String _description = '';
  File? _foodImage;
  List<FoodItem> _selectedFoods = [];
  bool _isProcessing = false;

  // Getters
  String get description => _description;
  File? get foodImage => _foodImage;
  List<FoodItem> get selectedFoods => _selectedFoods;
  bool get isProcessing => _isProcessing;

  // Setters
  void setDescription(String desc) {
    _description = desc;
    notifyListeners();
  }

  void setFoodImage(File? image) {
    _foodImage = image;
    notifyListeners();
  }

  void addFoodItem(FoodItem item) {
    _selectedFoods.add(item);
    notifyListeners();
  }

  void removeFoodItem(FoodItem item) {
    _selectedFoods.remove(item);
    notifyListeners();
  }

  void clearFoodItems() {
    _selectedFoods.clear();
    notifyListeners();
  }

  void setSelectedFoods(List<FoodItem> foods) {
    _selectedFoods = foods;
    notifyListeners();
  }

  void setProcessingState(bool isProcessing) {
    _isProcessing = isProcessing;
    notifyListeners();
  }

  // Reset tất cả dữ liệu ghi nhận thức ăn
  void reset() {
    _description = '';
    _foodImage = null;
    _selectedFoods = [];
    _isProcessing = false;
    notifyListeners();
  }
} 