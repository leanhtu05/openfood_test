import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/nutrition_info.dart';
import '../utils/constants.dart';

class EdamamFoodService {
  // API details
  static const String _baseUrl = 'https://api.edamam.com/api/food-database/v2';
  
  // Lấy API credentials từ file constants.dart
  // Hoặc thay trực tiếp sau khi đăng ký tại https://developer.edamam.com/
  static final String _appId = ApiKeys.edamamAppId; 
  static final String _appKey = ApiKeys.edamamAppKey;
  
  // Cache mechanism
  final Map<String, dynamic> _cache = {};
  
  // Search for foods
  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    try {
      // Check cache
      final cacheKey = 'search:$query';
      if (_cache.containsKey(cacheKey)) {
        return List<Map<String, dynamic>>.from(_cache[cacheKey]);
      }
      
      // Create search URL with Vietnamese cuisine filter
      final searchUrl = Uri.parse(
        '$_baseUrl/parser?app_id=$_appId&app_key=$_appKey&ingr=${Uri.encodeComponent(query)}'
      );
      
      final response = await http.get(searchUrl);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> results = [];
        
        if (data['hints'] != null) {
          // Process the food items
          for (var hint in data['hints']) {
            var food = hint['food'];
            
            // Map Edamam format to our app format
            results.add({
              'fdcId': food['foodId'],
              'description': food['label'],
              'brandOwner': food['brand'] ?? 'Unknown',
              'category': food['category'] ?? 'Food',
              'ingredients': food['foodContentsLabel'] ?? '',
              'calories': (food['nutrients']['ENERC_KCAL'] ?? 0).round(),
              'protein': food['nutrients']['PROCNT'] ?? 0,
              'fat': food['nutrients']['FAT'] ?? 0,
              'carbs': food['nutrients']['CHOCDF'] ?? 0,
              'servingSize': '100g',
              // Get image if available
              'image': food['image'] ?? '',
            });
          }
        }
        
        // Cache the results
        _cache[cacheKey] = results;
        
        return results;
      } else {
        throw Exception('Failed to search foods. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching Edamam foods: $e');
      return [];
    }
  }
  
  // Get detailed nutrition info for a food item
  Future<NutritionInfo?> getFoodDetails(String foodId) async {
    try {
      // Check if we have it in cache already from search results
      for (var entry in _cache.values) {
        if (entry is List) {
          for (var item in entry) {
            if (item['fdcId'] == foodId) {
              return NutritionInfo(
                calories: (item['calories'] ?? 0).toDouble(),
                protein: (item['protein'] ?? 0).toDouble(),
                fat: (item['fat'] ?? 0).toDouble(),
                carbs: (item['carbs'] ?? 0).toDouble(),
                fiber: 0.0, // May not be available in basic data
                sodium: 0.0, // May not be available in basic data
              );
            }
          }
        }
      }
      
      // Get more detailed nutrients through nutrient API
      final url = Uri.parse(
        '$_baseUrl/nutrients?app_id=$_appId&app_key=$_appKey'
      );
      
      // Prepare request body
      final requestBody = json.encode({
        "ingredients": [
          {
            "foodId": foodId,
            "quantity": 100,
            "measureURI": "http://www.edamam.com/ontologies/edamam.owl#Measure_gram"
          }
        ]
      });
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: requestBody
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final nutrients = data['totalNutrients'];
        
        return NutritionInfo(
          calories: nutrients['ENERC_KCAL']?['quantity']?.toDouble() ?? 0.0,
          protein: nutrients['PROCNT']?['quantity']?.toDouble() ?? 0.0,
          fat: nutrients['FAT']?['quantity']?.toDouble() ?? 0.0,
          carbs: nutrients['CHOCDF']?['quantity']?.toDouble() ?? 0.0,
          fiber: nutrients['FIBTG']?['quantity']?.toDouble() ?? 0.0,
          sodium: nutrients['NA']?['quantity']?.toDouble() ?? 0.0,
        );
      } else {
        throw Exception('Failed to get food details. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting Edamam food details: $e');
      return null;
    }
  }
} 