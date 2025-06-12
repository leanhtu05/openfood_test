import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/food_entry.dart';
import '../models/exercise.dart';
import '../models/water_entry.dart';

class LocalStorageService {
  static const String USER_DATA_KEY = 'user_data';
  static const String FOOD_ENTRIES_KEY = 'food_entries';
  static const String EXERCISE_ENTRIES_KEY = 'exercise_entries'; 
  static const String WATER_ENTRIES_KEY = 'water_entries';
  static const String SYNC_STATUS_KEY = 'last_sync_status';
  
  // Save user data locally
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(USER_DATA_KEY, jsonEncode(userData));
    } catch (e) {
      throw e;
    }
  }
  
  // Get user data from local storage
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(USER_DATA_KEY);
      if (data != null) {
        return jsonDecode(data) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Save food entries locally
  Future<void> saveFoodEntries(List<FoodEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = entries.map((e) => e.toJson()).toList();
      await prefs.setString(FOOD_ENTRIES_KEY, jsonEncode(entriesJson));
    } catch (e) {
      throw e;
    }
  }
  
  // Get food entries from local storage
  Future<List<FoodEntry>> getFoodEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(FOOD_ENTRIES_KEY);
      if (data != null) {
        final List<dynamic> jsonData = jsonDecode(data);
        return jsonData.map((e) => FoodEntry.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  // Save exercise entries locally
  Future<void> saveExerciseEntries(List<Exercise> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = entries.map((e) => e.toJson()).toList();
      await prefs.setString(EXERCISE_ENTRIES_KEY, jsonEncode(entriesJson));
    } catch (e) {
      throw e;
    }
  }
  
  // Get exercise entries from local storage
  Future<List<Exercise>> getExerciseEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(EXERCISE_ENTRIES_KEY);
      if (data != null) {
        final List<dynamic> jsonData = jsonDecode(data);
        return jsonData.map((e) => Exercise.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  // Save water entries locally
  Future<void> saveWaterEntries(List<WaterEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesList = entries.map((e) => {
        'id': e.id,
        'amount': e.amount,
        'timestamp': e.timestamp.millisecondsSinceEpoch
      }).toList();
      await prefs.setString(WATER_ENTRIES_KEY, jsonEncode(entriesList));
    } catch (e) {
      throw e;
    }
  }
  
  // Get water entries from local storage
  Future<List<WaterEntry>> getWaterEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(WATER_ENTRIES_KEY);
      if (data != null) {
        final List<dynamic> jsonData = jsonDecode(data);
        return jsonData.map((e) => WaterEntry(
          id: e['id'],
          amount: e['amount'],
          timestamp: DateTime.fromMillisecondsSinceEpoch(e['timestamp'])
        )).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  // Save sync status
  Future<void> saveSyncStatus({required bool isSuccess, String? error}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SYNC_STATUS_KEY, jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'success': isSuccess,
        'error': error,
      }));
    } catch (e) {
    }
  }
  
  // Get sync status
  Future<Map<String, dynamic>?> getSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(SYNC_STATUS_KEY);
      if (data != null) {
        return jsonDecode(data) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(USER_DATA_KEY);
      await prefs.remove(FOOD_ENTRIES_KEY);
      await prefs.remove(EXERCISE_ENTRIES_KEY);
      await prefs.remove(WATER_ENTRIES_KEY);
    } catch (e) {
      throw e;
    }
  }
  
  // Save a single food entry
  Future<bool> saveFoodEntry(FoodEntry entry) async {
    try {
      // Get existing entries
      List<FoodEntry> entries = await getFoodEntries();
      
      // Check if entry exists already
      int existingIndex = entries.indexWhere((e) => e.id == entry.id);
      
      if (existingIndex >= 0) {
        // Update existing entry
        entries[existingIndex] = entry;
      } else {
        // Add new entry
        entries.add(entry);
      }
      
      // Save updated list
      await saveFoodEntries(entries);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Save a single exercise entry
  Future<bool> saveExerciseEntry(Exercise entry) async {
    try {
      // Get existing entries
      List<Exercise> entries = await getExerciseEntries();
      
      // Check if entry exists already
      int existingIndex = entries.indexWhere((e) => e.id == entry.id);
      
      if (existingIndex >= 0) {
        // Update existing entry
        entries[existingIndex] = entry;
      } else {
        // Add new entry
        entries.add(entry);
      }
      
      // Save updated list
      await saveExerciseEntries(entries);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Save a single water entry
  Future<bool> saveWaterEntry(WaterEntry entry) async {
    try {
      // Get existing entries
      List<WaterEntry> entries = await getWaterEntries();
      
      // Check if entry exists already
      int existingIndex = entries.indexWhere((e) => e.id == entry.id);
      
      if (existingIndex >= 0) {
        // Update existing entry
        entries[existingIndex] = entry;
      } else {
        // Add new entry
        entries.add(entry);
      }
      
      // Save updated list
      await saveWaterEntries(entries);
      return true;
    } catch (e) {
      return false;
    }
  }
} 