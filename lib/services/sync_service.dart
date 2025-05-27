import 'package:flutter/material.dart';
import './local_storage_service.dart';
import './firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_entry.dart';
import '../models/exercise.dart';
import '../models/water_entry.dart';
import 'package:flutter/foundation.dart';

class SyncService extends ChangeNotifier {
  final LocalStorageService _localStorage = LocalStorageService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;
  
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // Load sync status when initializing
  SyncService() {
    _loadSyncStatus();
  }
  
  Future<void> _loadSyncStatus() async {
    try {
      final status = await _localStorage.getSyncStatus();
      if (status != null && status['timestamp'] != null) {
        _lastSyncTime = DateTime.parse(status['timestamp']);
        _lastSyncError = status['error'];
        notifyListeners();
      }
    } catch (e) {
      // Xóa debugPrint
    }
  }
  
  // Sync local data to Firestore (when user logs in)
  Future<bool> syncLocalDataToFirestore() async {
    if (_auth.currentUser == null) {
      _lastSyncError = 'Không thể đồng bộ: Người dùng chưa đăng nhập';
      notifyListeners();
      return false;
    }
    
    if (_auth.currentUser!.isAnonymous) {
      // No need to sync for anonymous users
      _lastSyncError = 'Không thể đồng bộ: Đang trong chế độ khách';
      notifyListeners();
      return false;
    }
    
    try {
      _isSyncing = true;
      _lastSyncError = null;
      notifyListeners();
      
      // Get user data from local storage
      final userData = await _localStorage.getUserData();
      if (userData != null) {
        // Save to Firestore
        await _firestoreService.saveUserProfile(userData);
        // Xóa debugPrint
      }
      
      // Sync food entries
      final foodEntries = await _localStorage.getFoodEntries();
      for (var entry in foodEntries) {
        if (entry.id.isNotEmpty) {
          await _firestoreService.updateFoodEntry(entry);
        } else {
          String newId = await _firestoreService.addFoodEntry(entry);
          // Store the new entry with updated ID
          entry = entry.updateId(newId);
          // Update the entry in local storage with the new ID
          await _localStorage.saveFoodEntry(entry);
        }
      }
      // Xóa debugPrint
      
      // Sync exercise entries
      final exerciseEntries = await _localStorage.getExerciseEntries();
      for (var entry in exerciseEntries) {
        if (entry.id != null && entry.id!.isNotEmpty) {
          // Update existing entry
          // Note: You'll need to add updateExerciseEntry to FirestoreService
        } else {
          // Add new entry
          String newId = await _firestoreService.addExerciseEntry(entry);
          // Update local ID
          final updatedEntry = entry.updateId(newId);
          // Cập nhật lại trong local storage
          await _localStorage.saveExerciseEntry(updatedEntry);
        }
      }
      // Xóa debugPrint
      
      // Sync water entries
      final waterEntries = await _localStorage.getWaterEntries();
      for (var entry in waterEntries) {
        // Add water entry to Firestore
        // Note: You'll need to add addWaterEntry to FirestoreService if it doesn't exist
        String newId = await _firestoreService.addWaterEntry(entry);
        // Cập nhật ID mới và lưu lại vào local storage
        final updatedEntry = entry.updateId(newId);
        await _localStorage.saveWaterEntry(updatedEntry);
      }
      // Xóa debugPrint
      
      _lastSyncTime = DateTime.now();
      await _localStorage.saveSyncStatus(isSuccess: true);
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastSyncError = 'Lỗi đồng bộ: $e';
      await _localStorage.saveSyncStatus(isSuccess: false, error: _lastSyncError);
      _isSyncing = false;
      notifyListeners();
      // Xóa debugPrint
      return false;
    }
  }
  
  // Fetch data from Firestore to local (when app starts or user logs in)
  Future<bool> fetchDataFromFirestore() async {
    if (_auth.currentUser == null || _auth.currentUser!.isAnonymous) {
      _lastSyncError = 'Không thể đồng bộ: Người dùng chưa đăng nhập hoặc đang trong chế độ khách';
      notifyListeners();
      return false;
    }
    
    try {
      _isSyncing = true;
      _lastSyncError = null;
      notifyListeners();
      
      // Fetch user profile
      final firestoreUserData = await _firestoreService.getUserProfile();
      if (firestoreUserData.isNotEmpty) {
        // Get existing local data for merging if needed
        final localUserData = await _localStorage.getUserData();
        
        // If we have local data, merge it with Firestore data
        Map<String, dynamic> mergedData = firestoreUserData;
        if (localUserData != null) {
          // Prioritize Firestore data but keep any local fields not in Firestore
          mergedData = {...localUserData, ...firestoreUserData};
        }
        
        // Save merged data locally
        await _localStorage.saveUserData(mergedData);
        // Xóa debugPrint
      }
      
      // Fetch food entries for the last 30 days
      DateTime now = DateTime.now();
      DateTime thirtyDaysAgo = now.subtract(Duration(days: 30));
      
      // You would need to implement a method to get entries by date range in FirestoreService
      // This is just a placeholder example
      List<FoodEntry> foodEntries = [];
      for (int i = 0; i < 30; i++) {
        DateTime date = now.subtract(Duration(days: i));
        var entries = await _firestoreService.getFoodEntriesByDate(date);
        foodEntries.addAll(entries);
      }
      
      if (foodEntries.isNotEmpty) {
        // Save to local storage
        await _localStorage.saveFoodEntries(foodEntries);
        // Xóa debugPrint
      }
      
      // Fetch exercise entries (implementation depends on your API design)
      // Similar code for exercise and water entries...
      
      _lastSyncTime = DateTime.now();
      await _localStorage.saveSyncStatus(isSuccess: true);
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastSyncError = 'Lỗi đồng bộ: $e';
      await _localStorage.saveSyncStatus(isSuccess: false, error: _lastSyncError);
      _isSyncing = false;
      notifyListeners();
      // Xóa debugPrint
      return false;
    }
  }
  
  // Handle sync when auth status changes (login, logout, etc.)
  Future<void> handleAuthStatusChange({
    required bool wasAuthenticated, 
    required bool wasGuest,
    required bool isAuthenticated, 
    required bool isGuest
  }) async {
    // If user converted from guest to registered user
    if (wasGuest && isAuthenticated && !isGuest) {
      // Xóa debugPrint
      await syncLocalDataToFirestore();
    } 
    // If user just signed in (not as guest)
    else if (!wasAuthenticated && isAuthenticated && !isGuest) {
      // Xóa debugPrint
      await fetchDataFromFirestore();
    }
    // If user logged out
    else if (wasAuthenticated && !isAuthenticated) {
      // Do nothing here, as we want to keep local data
      // Xóa debugPrint
    }
  }
  
  // Force manual sync (can be called from UI)
  Future<bool> forceSync() async {
    if (_auth.currentUser == null) {
      return false;
    }
    
    if (_auth.currentUser!.isAnonymous) {
      return false;
    }
    
    return await syncLocalDataToFirestore();
  }
} 