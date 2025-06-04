import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/firebase_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_data_provider.dart';
import '../services/user_profile_api.dart';

class UserService {
  final UserProfileAPI _userProfileAPI;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userCollection = 'users';
  
  // API Endpoints - Đã cập nhật để sử dụng FastAPI
  final String _baseApiUrl = 'https://openfood-api.onrender.com'; // URL FastAPI chính
  final String _apiUserEndpoint = '/api/user-profile'; // Endpoint cho user profile
  final String _apiFirestoreEndpoint = '/firestore/users'; // Endpoint cho Firestore

  // Optional UserDataProvider instance để thông báo khi có thay đổi
  final UserDataProvider? _userDataProvider;

  UserService({
    UserProfileAPI? userProfileAPI,
    UserDataProvider? userDataProvider,
  }) : _userProfileAPI = userProfileAPI ?? UserProfileAPI(),
       _userDataProvider = userDataProvider;

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

  /// Xóa tất cả dữ liệu người dùng ở local
  Future<void> clearLocalUserData() async {
    try {
      debugPrint('🧹 UserService: Đang xóa dữ liệu người dùng local...');
      
      // 1. Xóa dữ liệu từ SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      await prefs.remove('user_profile');
      await prefs.remove('water_entries');
      await prefs.remove('exercise_entries');
      await prefs.remove('food_entries');
      await prefs.remove('weight_entries');
      
      // 2. Thông báo cho UserDataProvider nếu có
      if (_userDataProvider != null) {
        _userDataProvider!.resetData();
      }
      
      debugPrint('✅ UserService: Đã xóa tất cả dữ liệu người dùng local thành công');
    } catch (e) {
      debugPrint('❌ UserService: Lỗi khi xóa dữ liệu người dùng local: $e');
      rethrow;
    }
  }

  /// Đồng bộ dữ liệu người dùng từ Firebase sau khi đăng nhập
  Future<void> syncUserDataFromFirebase() async {
    if (!isUserAuthenticated()) {
      debugPrint('⚠️ UserService: Không thể đồng bộ dữ liệu - người dùng chưa đăng nhập hoặc đang ở chế độ ẩn danh');
      return;
    }

    try {
      final userId = getCurrentUserId()!;
      debugPrint('🔄 UserService: Đang đồng bộ dữ liệu người dùng từ Firebase cho $userId...');

      // 1. Lấy thông tin người dùng từ Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      Map<String, dynamic>? userData;
      if (userDoc.exists) {
        userData = userDoc.data();
        debugPrint('✅ UserService: Đã tìm thấy dữ liệu người dùng trên Firestore');
      } else {
        debugPrint('ℹ️ UserService: Không tìm thấy hồ sơ người dùng trên Firestore, sử dụng thông tin từ Firebase Auth');
        // Sử dụng thông tin cơ bản từ Firebase Auth
        userData = {
          'id': userId,
          'email': _auth.currentUser?.email,
          'display_name': _auth.currentUser?.displayName,
          'photo_url': _auth.currentUser?.photoURL,
        };
      }

      // 2. Lưu dữ liệu vào SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(userData));
      
      // 3. Cập nhật UserDataProvider nếu có
      if (_userDataProvider != null) {
        _userDataProvider!.loadUserDataFromMap(userData!);
        debugPrint('✅ UserService: Đã cập nhật UserDataProvider với dữ liệu từ Firebase');
      }

      // 4. Tiến hành tải các loại dữ liệu khác (tùy chỉnh theo ứng dụng)
      await _syncAdditionalUserData(userId);

      debugPrint('✅ UserService: Hoàn tất đồng bộ dữ liệu người dùng từ Firebase');
    } catch (e) {
      debugPrint('❌ UserService: Lỗi khi đồng bộ dữ liệu từ Firebase: $e');
      rethrow;
    }
  }

  /// Đồng bộ dữ liệu bổ sung của người dùng (thực phẩm, nước uống, bài tập,...)
  Future<void> _syncAdditionalUserData(String userId) async {
    try {
      debugPrint('🔄 UserService: Đang đồng bộ dữ liệu bổ sung...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Đồng bộ dữ liệu nước uống
      try {
        final waterData = await _userProfileAPI.getUserWaterEntries(userId);
        if (waterData != null && waterData.isNotEmpty) {
          await prefs.setString('water_entries', jsonEncode(waterData));
          debugPrint('✅ UserService: Đã đồng bộ ${waterData.length} bản ghi nước uống');
        }
      } catch (e) {
        debugPrint('⚠️ UserService: Lỗi khi đồng bộ dữ liệu nước uống: $e');
      }
      
      // Đồng bộ dữ liệu bài tập
      try {
        final exerciseData = await _userProfileAPI.getUserExerciseEntries(userId);
        if (exerciseData != null && exerciseData.isNotEmpty) {
          await prefs.setString('exercise_entries', jsonEncode(exerciseData));
          debugPrint('✅ UserService: Đã đồng bộ ${exerciseData.length} bản ghi bài tập');
        }
      } catch (e) {
        debugPrint('⚠️ UserService: Lỗi khi đồng bộ dữ liệu bài tập: $e');
      }
      
      // Đồng bộ dữ liệu thực phẩm
      try {
        final foodData = await _userProfileAPI.getUserFoodEntries(userId);
        if (foodData != null && foodData.isNotEmpty) {
          await prefs.setString('food_entries', jsonEncode(foodData));
          debugPrint('✅ UserService: Đã đồng bộ ${foodData.length} bản ghi thực phẩm');
        }
      } catch (e) {
        debugPrint('⚠️ UserService: Lỗi khi đồng bộ dữ liệu thực phẩm: $e');
      }
      
      debugPrint('✅ UserService: Đã đồng bộ xong dữ liệu bổ sung');
    } catch (e) {
      debugPrint('❌ UserService: Lỗi khi đồng bộ dữ liệu bổ sung: $e');
    }
  }

  /// Cập nhật thông tin người dùng lên Firebase
  Future<bool> updateUserProfileToFirebase(Map<String, dynamic> userData) async {
    if (!isUserAuthenticated()) {
      debugPrint('⚠️ UserService: Không thể cập nhật thông tin - người dùng chưa đăng nhập');
      return false;
    }

    try {
      final userId = getCurrentUserId()!;
      debugPrint('🔄 UserService: Đang cập nhật thông tin người dùng lên Firebase...');
      
      // Cập nhật thông tin người dùng trên Firestore
      await _firestore.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: true),
      );
      
      // Cập nhật displayName và photoURL trên Firebase Auth nếu có
      if (userData.containsKey('display_name') || userData.containsKey('photo_url')) {
        await _auth.currentUser!.updateProfile(
          displayName: userData['display_name'],
          photoURL: userData['photo_url'],
        );
      }
      
      debugPrint('✅ UserService: Đã cập nhật thông tin người dùng lên Firebase thành công');
      return true;
    } catch (e) {
      debugPrint('❌ UserService: Lỗi khi cập nhật thông tin người dùng: $e');
      return false;
    }
  }

  /// Kiểm tra và tạo hồ sơ người dùng mới nếu chưa tồn tại
  Future<void> checkAndCreateUserProfile() async {
    if (!isUserAuthenticated()) return;
    
    try {
      final userId = getCurrentUserId()!;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('🆕 UserService: Tạo hồ sơ người dùng mới cho $userId');
        
        // Tạo hồ sơ mới với thông tin cơ bản
        await _firestore.collection('users').doc(userId).set({
          'id': userId,
          'email': _auth.currentUser!.email,
          'display_name': _auth.currentUser!.displayName,
          'photo_url': _auth.currentUser!.photoURL,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        debugPrint('✅ UserService: Đã tạo hồ sơ người dùng mới thành công');
      }
    } catch (e) {
      debugPrint('❌ UserService: Lỗi khi kiểm tra/tạo hồ sơ người dùng: $e');
    }
  }
} 