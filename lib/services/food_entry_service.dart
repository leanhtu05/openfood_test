import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../providers/food_provider.dart';
import '../services/food_database_service.dart';

class FoodEntryService {
  final FoodDatabaseService _databaseService = FoodDatabaseService();
  
  FoodEntryService() {
    _databaseService.initialize();
  }

  Future<FoodEntry> createFoodEntryManual({
    required String description,
    required String mealType,
    required DateTime dateTime,
    File? image,
    List<FoodItem>? items,
  }) async {
    final uuid = Uuid();
    final String entryId = uuid.v4();
    
    final entry = FoodEntry(
      id: entryId,
      description: description,
      items: items ?? [],
      dateTime: dateTime,
      mealType: mealType,
      imagePath: image?.path,
    );
    
    return entry;
  }

  Future<void> searchProductByBarcode(
    String barcode,
    String mealType,
    Function(FoodEntry) onFound,
    VoidCallback onNotFound,
  ) async {
    try {
      final items = await _databaseService.searchFoodByBarcode(barcode);
      
      if (items.isNotEmpty) {
        final uuid = Uuid();
        final String entryId = uuid.v4();
        
        final FoodItem foodItem = items.first;
        final entry = FoodEntry(
          id: entryId,
          description: foodItem.name,
          items: [foodItem],
          dateTime: DateTime.now(),
          mealType: mealType,
          barcode: barcode,
          nutritionInfo: _createNutritionInfoFromFoodItem(foodItem, barcode),
        );
        
        onFound(entry);
      } else {
        onNotFound();
      }
    } catch (e) {
      onNotFound();
    }
  }
  
  Map<String, dynamic> _createNutritionInfoFromFoodItem(FoodItem item, String barcode) {
    return {
      'calories': item.calories,
      'protein': item.protein,
      'fat': item.fat,
      'carbs': item.carbs,
      'fiber': item.fiber,
      'sugar': item.sugar,
      'sodium': item.sodium,
      'servingSize': item.servingSize,
      'totalWeight': item.servingSize * 100,
      'dataSource': 'Database',
      'barcode': barcode,
      ...item.additionalNutrients ?? {},
    };
  }
} 