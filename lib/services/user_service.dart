import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/firebase_helpers.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userCollection = 'users';
  
  // API Endpoints - Đã cập nhật để sử dụng FastAPI
  final String _baseApiUrl = 'https://openfood-api.onrender.com'; // URL FastAPI chính
  final String _apiUserEndpoint = '/api/user-profile'; // Endpoint cho user profile
  final String _apiFirestoreEndpoint = '/firestore/users'; // Endpoint cho Firestore

  // Get Firestore reference to user document
  DocumentReference _getUserDocRef(String uid) {
    return _firestore.collection(_userCollection).doc(uid);
  }

  // Get user document after sign in/up, create if not exists
  Future<AppUser> createOrUpdateUser(User firebaseUser) async {
    try {
      // Check if user exists in Firestore
      final docRef = _getUserDocRef(firebaseUser.uid);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        // Get existing user data
        final userData = docSnapshot.data() as Map<String, dynamic>;
        
        // Xử lý dữ liệu từ Firestore
        final processedData = FirebaseHelpers.processFirestoreData(userData);
        
        final existingUser = AppUser(
          uid: firebaseUser.uid,
          displayName: processedData['display_name'] ?? firebaseUser.displayName,
          email: processedData['email'] ?? firebaseUser.email,
          photoURL: processedData['photo_url'] ?? firebaseUser.photoURL,
          isAnonymous: processedData['is_anonymous'] ?? firebaseUser.isAnonymous,
          createdAt: FirebaseHelpers.toDateTime(processedData['created_at']) ?? DateTime.now(),
          lastLoginAt: DateTime.now(), // Luôn cập nhật thời gian đăng nhập
        );
        
        // Cập nhật thời gian đăng nhập mới nhất
        try {
          await docRef.update({
            'last_login_at': FirebaseHelpers.toISOString(DateTime.now()),
            'updated_at': FirebaseHelpers.toISOString(DateTime.now()),
          });
          debugPrint('✅ Đã cập nhật thời gian đăng nhập');
        } catch (e) {
          debugPrint('❌ Lỗi khi cập nhật thời gian đăng nhập: $e');
          // Không throw lỗi ở đây để tiếp tục xử lý
        }
        
        debugPrint('✅ Found existing user in Firestore');
        return existingUser;
      } else {
        // Create new user model
        final newUser = AppUser.fromAuth(
          uid: firebaseUser.uid,
          displayName: firebaseUser.displayName,
          email: firebaseUser.email,
          photoURL: firebaseUser.photoURL,
          isAnonymous: firebaseUser.isAnonymous,
        );
        
        // Tạo dữ liệu mới để lưu vào Firestore
        final userData = {
          'uid': firebaseUser.uid,
          'display_name': firebaseUser.displayName,
          'email': firebaseUser.email,
          'photo_url': firebaseUser.photoURL,
          'is_anonymous': firebaseUser.isAnonymous,
          'created_at': FirebaseHelpers.toISOString(DateTime.now()),
          'last_login_at': FirebaseHelpers.toISOString(DateTime.now()),
          'updated_at': FirebaseHelpers.toISOString(DateTime.now()),
        };
        
        // Lưu vào Firestore
        try {
          await docRef.set(userData);
          debugPrint('✅ Đã tạo người dùng mới trong Firestore');
        } catch (e) {
          debugPrint('❌ Lỗi khi tạo người dùng mới trong Firestore: $e');
          // Không throw lỗi ở đây để tiếp tục xử lý
        }
        
        debugPrint('✅ Tạo người dùng mới thành công');
        return newUser;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi xử lý thông tin người dùng: $e');
      // Tạo user cơ bản nếu có lỗi
      return AppUser.fromAuth(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName,
        email: firebaseUser.email,
        photoURL: firebaseUser.photoURL,
        isAnonymous: firebaseUser.isAnonymous,
      );
    }
  }

  // Get current user data from Firestore
  Future<AppUser?> getCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    
    try {
      // Fetch user data from Firestore
      final docSnapshot = await _getUserDocRef(currentUser.uid).get();
      
      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        debugPrint('✅ Got user from Firestore');
        
        // Xử lý dữ liệu trước khi sử dụng
        final processedData = FirebaseHelpers.processFirestoreData(userData);
        
        // Convert Firestore data to AppUser
        return AppUser(
          uid: currentUser.uid,
          displayName: processedData['display_name'] ?? currentUser.displayName,
          email: processedData['email'] ?? currentUser.email,
          photoURL: processedData['photo_url'] ?? currentUser.photoURL,
          isAnonymous: processedData['is_anonymous'] ?? false,
          createdAt: FirebaseHelpers.toDateTime(processedData['created_at']) ?? DateTime.now(),
          lastLoginAt: FirebaseHelpers.toDateTime(processedData['last_login_at']) ?? DateTime.now(),
        );
      }
      
      // If no data found, return basic user info without writing to Firestore
      return AppUser.fromAuth(
        uid: currentUser.uid,
        displayName: currentUser.displayName,
        email: currentUser.email,
        photoURL: currentUser.photoURL,
        isAnonymous: currentUser.isAnonymous,
      );
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      return null;
    }
  }

  // Get user profile data (read-only)
  Future<Map<String, dynamic>?> getUserProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    
    try {
      final docSnapshot = await _getUserDocRef(currentUser.uid).get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        debugPrint('✅ Read user profile from Firestore');
        return userData;
      }
      return null;
    } catch (e) {
      debugPrint('Error reading user profile: $e');
      return null;
    }
  }

  // Get user settings (read-only)
  Future<Map<String, dynamic>?> getUserSettings() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    
    try {
      final docSnapshot = await _getUserDocRef(currentUser.uid).get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        final settings = userData['settings'] as Map<String, dynamic>?;
        debugPrint('✅ Read user settings from Firestore');
        return settings;
      }
      return null;
    } catch (e) {
      debugPrint('Error reading user settings: $e');
      return null;
    }
  }

  // Get user preferences (read-only)
  Future<Map<String, dynamic>?> getUserPreferences() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    
    try {
      final docSnapshot = await _getUserDocRef(currentUser.uid).get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        final preferences = userData['preferences'] as Map<String, dynamic>?;
        debugPrint('✅ Read user preferences from Firestore');
        return preferences;
      }
      return null;
    } catch (e) {
      debugPrint('Error reading user preferences: $e');
      return null;
    }
  }
  
  // Get user nutrition goals (read-only)
  Future<Map<String, dynamic>?> getUserNutritionGoals() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    
    try {
      final docSnapshot = await _getUserDocRef(currentUser.uid).get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        
        // Try to get nutrition goals from different possible locations in the document
        Map<String, dynamic>? nutritionGoals;
        
        if (userData.containsKey('nutritionGoals')) {
          nutritionGoals = userData['nutritionGoals'] as Map<String, dynamic>?;
        } else if (userData.containsKey('nutrition_goals')) {
          nutritionGoals = userData['nutrition_goals'] as Map<String, dynamic>?;
        } else if (userData.containsKey('settings') && 
                  userData['settings'] is Map &&
                  (userData['settings'] as Map).containsKey('nutritionGoals')) {
          nutritionGoals = (userData['settings'] as Map)['nutritionGoals'] as Map<String, dynamic>?;
        }
        
        debugPrint('✅ Read user nutrition goals from Firestore');
        return nutritionGoals;
      }
      return null;
    } catch (e) {
      debugPrint('Error reading user nutrition goals: $e');
      return null;
    }
  }
  
  // Get user physical data (height, weight, etc.) (read-only)
  Future<Map<String, dynamic>?> getUserPhysicalData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    
    try {
      final docSnapshot = await _getUserDocRef(currentUser.uid).get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        
        // Create a map with physical data
        Map<String, dynamic> physicalData = {};
        
        // Extract physical data from user document
        if (userData.containsKey('heightCm')) {
          physicalData['heightCm'] = userData['heightCm'];
        }
        
        if (userData.containsKey('weightKg')) {
          physicalData['weightKg'] = userData['weightKg'];
        }
        
        if (userData.containsKey('age')) {
          physicalData['age'] = userData['age'];
        }
        
        if (userData.containsKey('gender')) {
          physicalData['gender'] = userData['gender'];
        }
        
        if (userData.containsKey('activityLevel')) {
          physicalData['activityLevel'] = userData['activityLevel'];
        }
        
        if (userData.containsKey('goal')) {
          physicalData['goal'] = userData['goal'];
        }
        
        debugPrint('✅ Read user physical data from Firestore');
        return physicalData.isNotEmpty ? physicalData : null;
      }
      return null;
    } catch (e) {
      debugPrint('Error reading user physical data: $e');
      return null;
    }
  }

  // Update user profile via API (for external updates)
  Future<bool> updateUserProfileViaAPI(Map<String, dynamic> userData) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    
    try {
      // Get ID token for authentication
      final idToken = await currentUser.getIdToken();
      
      // Prepare API endpoint
      final endpoint = '$_baseApiUrl$_apiFirestoreEndpoint/${currentUser.uid}';
      
      // Make API call with PATCH method
      final response = await http.patch(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(userData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        debugPrint('✅ Successfully updated user profile via API');
        return true;
      } else {
        debugPrint('❌ Failed to update user profile via API: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        
        // Thử endpoint thay thế nếu endpoint chính thất bại
        final alternativeEndpoint = '$_baseApiUrl$_apiUserEndpoint';
        debugPrint('⚠️ Trying alternative endpoint: $alternativeEndpoint');
        
        final alternativeResponse = await http.put(
          Uri.parse(alternativeEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'user_id': currentUser.uid,
            ...userData,
          }),
        );
        
        if (alternativeResponse.statusCode == 200 || alternativeResponse.statusCode == 201 || alternativeResponse.statusCode == 204) {
          debugPrint('✅ Successfully updated user profile via alternative API endpoint');
          return true;
        } else {
          debugPrint('❌ Failed to update user profile via alternative API endpoint: ${alternativeResponse.statusCode}');
          debugPrint('Response body: ${alternativeResponse.body}');
          return false;
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating user profile via API: $e');
      return false;
    }
  }
  
  // Update user nutrition goals via API
  Future<bool> updateNutritionGoalsViaAPI(Map<String, dynamic> nutritionGoals) async {
    final userData = {
      'nutritionGoals': nutritionGoals,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    return await updateUserProfileViaAPI(userData);
  }
  
  // Update user physical data via API
  Future<bool> updatePhysicalDataViaAPI({
    double? height,
    double? weight,
    int? age,
    String? gender,
    String? activityLevel,
    String? goal,
  }) async {
    final userData = {
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (activityLevel != null) 'activityLevel': activityLevel,
      if (goal != null) 'goal': goal,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    return await updateUserProfileViaAPI(userData);
  }

  // Check if user is authenticated
  bool isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Check if user is anonymous
  bool isUserAnonymous() {
    return _auth.currentUser?.isAnonymous ?? true;
  }
  
  // Update user profile - reimplemented to use API
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');
    
    try {
      // Update in Firebase Auth
      if (displayName != null) await currentUser.updateDisplayName(displayName);
      if (photoURL != null) await currentUser.updatePhotoURL(photoURL);
      
      // Update in API
      final userData = {
        if (displayName != null) 'display_name': displayName,
        if (photoURL != null) 'photo_url': photoURL,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Chuẩn bị dữ liệu trước khi gửi
      final preparedData = FirebaseHelpers.prepareDataForFirestore(userData);
      
      // Gửi dữ liệu đã xử lý
      final success = await updateUserProfileViaAPI(preparedData);
      
      if (!success) {
        debugPrint('⚠️ Failed to update user profile via API, but Firebase Auth was updated');
      } else {
        debugPrint('✅ Updated user profile via API');
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
  
  // Delete user account - reimplemented to use API
  Future<void> deleteUserAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');
    
    try {
      // Mark account as deleted in API
      final userData = {
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      };
      
      // Chuẩn bị dữ liệu trước khi gửi
      final preparedData = FirebaseHelpers.prepareDataForFirestore(userData);
      
      final success = await updateUserProfileViaAPI(preparedData);
      
      if (!success) {
        debugPrint('⚠️ Failed to mark user as deleted in API');
      }
      
      // Delete from Firebase Auth
      await currentUser.delete();
      debugPrint('✅ User account deleted from Firebase Auth');
    } catch (e) {
      debugPrint('Error deleting user account: $e');
      rethrow;
    }
  }
  
  // Convert anonymous account to permanent account - reimplemented to use API
  Future<void> convertAnonymousAccount({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');
    if (!currentUser.isAnonymous) throw Exception('User is not anonymous');
    
    try {
      // Create credential
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      // Link anonymous account with credential
      final userCredential = await currentUser.linkWithCredential(credential);
      
      // Update user data in Firebase Auth
      if (displayName != null) {
        await userCredential.user?.updateDisplayName(displayName);
      }
      
      // Update in API
      final userData = {
        'email': email,
        'display_name': displayName,
        'is_anonymous': false,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Chuẩn bị dữ liệu trước khi gửi
      final preparedData = FirebaseHelpers.prepareDataForFirestore(userData);
      
      final success = await updateUserProfileViaAPI(preparedData);
      
      if (!success) {
        debugPrint('⚠️ Failed to update user profile in API after converting anonymous account');
      } else {
        debugPrint('✅ User account converted and updated in API');
      }
    } catch (e) {
      debugPrint('Error converting anonymous account: $e');
      rethrow;
    }
  }
} 