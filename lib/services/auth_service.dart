import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';
import 'api_service.dart';
import '../utils/firebase_helpers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:openfood/providers/user_data_provider.dart' as udp;
import '../providers/food_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/water_provider.dart';

class AuthService extends ChangeNotifier {
  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // User service for Firestore operations
  final UserService _userService = UserService();
  
  // Current user
  User? _user;
  User? get user => _user;
  User? get currentUser => _user; // Alias for user property

  // Authentication status
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  
  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error message
  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  
  // Google Play Services availability
  bool _isGooglePlayServicesAvailable = true;
  bool get isGooglePlayServicesAvailable => _isGooglePlayServicesAvailable;

  // Constructor to initialize the service
  AuthService() {
    // Set initial authenticated state based on current user
    _user = _auth.currentUser;
    _isAuthenticated = _user != null;
    
    // Kiểm tra Google Play Services
    _checkGooglePlayServices();
    
    // Listen for auth state changes
    _auth.authStateChanges().listen((User? user) async {
      print('👤 Trạng thái đăng nhập thay đổi: ${user?.uid ?? 'null'}');
      
      // Lưu trạng thái đăng nhập trước đó
      bool wasAuthenticated = _isAuthenticated;
      
      // Cập nhật trạng thái đăng nhập hiện tại
      _user = user;
      _isAuthenticated = user != null;
      
      // Update Firestore user document when user signs in
      if (user != null) {
        try {
          await _userService.createOrUpdateUser(user);
          
          // Đồng bộ với API - không chờ đợi để không chặn UI
          _syncWithApi(user); // Removed await
          
          // Nếu trước đó chưa đăng nhập và giờ đã đăng nhập
          if (!wasAuthenticated) {
            print('🔄 Người dùng vừa đăng nhập: Sẽ tải dữ liệu từ Firestore');
          }
        } catch (e) {
          print('Error updating user in Firestore: $e');
        }
      } else if (wasAuthenticated) {
        // Nếu trước đó đã đăng nhập và giờ đã đăng xuất
        print('🔄 Người dùng vừa đăng xuất: Sẽ ưu tiên dữ liệu từ local');
      }
      
      notifyListeners();
      print('👤 Đã gọi notifyListeners() sau khi trạng thái đăng nhập thay đổi');
    });
  }
  
  // Kiểm tra Google Play Services
  Future<void> _checkGooglePlayServices() async {
    try {
      _isGooglePlayServicesAvailable = await FirebaseHelpers.isGooglePlayServicesAvailable();
      if (!_isGooglePlayServicesAvailable) {
        debugPrint('⚠️ Google Play Services không khả dụng, sẽ sử dụng phương thức đăng nhập thay thế');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra Google Play Services: $e');
      _isGooglePlayServicesAvailable = false;
    }
  }

  // Lấy Firebase ID Token
  Future<String?> getIdToken() async {
    try {
      if (_user == null) return null;
      return await _user!.getIdToken();
    } catch (e) {
      print('Error getting ID token: $e');
      return null;
    }
  }
  
  // Lấy token hiện tại để gọi API
  Future<String?> getCurrentToken() async {
    try {
      if (_user == null) return null;
      return await _user!.getIdToken(true); // Force refresh token
    } catch (e) {
      print('Error getting current token: $e');
      return null;
    }
  }
  
  // Đồng bộ với API khi đăng nhập
  Future<void> _syncWithApi(User user) async {
    // Thực hiện đồng bộ trong một Future riêng biệt để không chặn UI
    // Sử dụng unawaited để đảm bảo không chặn luồng chính
    Future(() async {
      try {
        print('🔄 Bắt đầu xác thực token với API trong background');
        
        // Lấy token
        String? idToken;
        try {
          idToken = await user.getIdToken(true); // Force refresh token
        } catch (tokenError) {
          print('⚠️ Không thể lấy Firebase ID token: $tokenError');
          print('ℹ️ Tiếp tục sử dụng Firebase mà không có xác thực từ API');
          return;
        }
        
        // Nếu không lấy được token, bỏ qua xác thực API
        if (idToken == null) {
          print('⚠️ ID token là null, không thể xác thực với API');
          print('ℹ️ Tiếp tục sử dụng Firebase mà không có xác thực từ API');
          return;
            }
        
        // Bỏ qua hoàn toàn phần xác thực API vì API không còn hỗ trợ hoặc không cần thiết
        print('ℹ️ Bỏ qua xác thực token với API, sử dụng Firebase trực tiếp');
        
      } catch (e) {
        print('❌ Lỗi khi xác thực token với API: $e');
        print('ℹ️ Tiếp tục sử dụng Firebase mà không có xác thực từ API');
      }
    });
    
    // Không chờ đợi Future hoàn thành, trả về ngay lập tức
    return;
  }
  
  // Phương thức đơn giản hóa - chỉ tạo dữ liệu cơ bản từ thông tin người dùng Firebase
  Future<Map<String, dynamic>> _getBasicUserData(User user) async {
    return {
        'user_id': user.uid,
      'email': user.email,
        'display_name': user.displayName,
        'photo_url': user.photoURL,
      'is_authenticated': true,
      'name': user.displayName ?? user.email ?? 'Người dùng',
      'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      _isAuthenticated = true;
      
      // Create user document in Firestore
      if (_user != null) {
        // Bỏ qua xác thực token với FastAPI, chỉ tạo user trong Firestore
        await _userService.createOrUpdateUser(_user!);
        
        // Đồng bộ với API - không chờ đợi để không chặn UI
        _syncWithApi(_user!); // Removed await
      }
      
      // Save login state locally
      _saveLoginStatus(true);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Có lỗi xảy ra. Vui lòng thử lại sau.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login with email and password
  Future<bool> loginWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      // Luôn coi như Google Play Services khả dụng
      _isGooglePlayServicesAvailable = true;
      
      // Đăng nhập bình thường qua Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      _isAuthenticated = true;
      
      // Save login state locally ngay lập tức sau khi đăng nhập thành công
      _saveLoginStatus(true);
      
      // Bỏ qua xác thực token với FastAPI
      if (_user != null) {
        try {
          // Update user document in Firestore - bỏ qua lỗi nếu có
          await _userService.createOrUpdateUser(_user!).catchError((error) {
            print('⚠️ Lỗi khi cập nhật thông tin người dùng: $error');
            // Không throw lỗi, tiếp tục đăng nhập
          });
          
          // Đồng bộ với API trong background, không chờ đợi kết quả
          Future(() {
            try {
              _syncWithApi(_user!);
            } catch (syncError) {
              print('⚠️ Lỗi khi đồng bộ dữ liệu với API: $syncError');
              // Không ảnh hưởng đến luồng đăng nhập
            }
          });
        } catch (userError) {
          // Chỉ ghi log lỗi, không ảnh hưởng đến việc đăng nhập
          print('⚠️ Lỗi khi xử lý dữ liệu người dùng: $userError');
        }
      }
      
      _isLoading = false;
      notifyListeners();
      
      // Luôn trả về true nếu đăng nhập Firebase thành công, bất kể có lỗi đồng bộ dữ liệu hay không
      print('✅ Đăng nhập thành công, sẽ điều hướng đến màn hình chính');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      // Xử lý đặc biệt cho lỗi PigeonUserDetails
      if (e.toString().contains('PigeonUserDetails')) {
        print('⚠️ Phát hiện lỗi PigeonUserDetails trong quá trình đăng nhập');
        
        // Kiểm tra xem người dùng đã đăng nhập hay chưa
        if (_auth.currentUser != null) {
          _user = _auth.currentUser;
          _isAuthenticated = true;
          _saveLoginStatus(true);
          _isLoading = false;
          notifyListeners();
          
          print('✅ Đăng nhập vẫn thành công mặc dù có lỗi PigeonUserDetails');
          return true;
        }
      }
      
      _errorMessage = 'Có lỗi xảy ra: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Phương thức để xác thực token với FastAPI
  Future<bool> validateTokenWithFastApi() async {
    // Không cần xác thực với FastAPI nữa, luôn trả về true
    print('ℹ️ Bỏ qua xác thực token với FastAPI, sử dụng Firebase trực tiếp');
    return true;
  }
  
  // Phương thức đăng nhập thay thế qua API trực tiếp (không qua Firebase)
  Future<bool> _loginViaApi(String email, String password) async {
    try {
      debugPrint('🔄 Bỏ qua đăng nhập qua API, sử dụng Firebase trực tiếp...');
      
      // Sử dụng Firebase trực tiếp thay vì gọi API
      try {
        // Đăng nhập bằng Firebase Authentication
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Kiểm tra kết quả đăng nhập
        if (userCredential.user != null) {
          debugPrint('✅ Đăng nhập Firebase trực tiếp thành công');
          
          // Cập nhật trạng thái đăng nhập
          _user = userCredential.user;
          _isAuthenticated = true;
          
          // Lưu trạng thái đăng nhập vào SharedPreferences
          await _saveLoginStatus(true);
          
          // Thông báo thay đổi
          notifyListeners();
          
          return true;
        } else {
          debugPrint('❌ Đăng nhập Firebase trực tiếp thất bại: Không có người dùng');
          _errorMessage = 'Đăng nhập thất bại. Vui lòng kiểm tra email và mật khẩu.';
          return false;
        }
      } catch (firebaseError) {
        debugPrint('❌ Lỗi khi đăng nhập qua Firebase trực tiếp: $firebaseError');
        
        // Xử lý lỗi đăng nhập Firebase
        if (firebaseError is FirebaseAuthException) {
          _handleAuthError(firebaseError);
        } else {
          _errorMessage = 'Có lỗi xảy ra khi đăng nhập: ${firebaseError.toString()}';
        }
        
        return false;
      }
    } catch (e) {
      debugPrint('❌ Lỗi tổng thể khi đăng nhập: $e');
      _errorMessage = 'Có lỗi xảy ra khi đăng nhập: ${e.toString()}';
      return false;
    }
  }

  // Log out
  Future<void> logout({BuildContext? context}) async {
    try {
      debugPrint('🔄 AuthService: Đang đăng xuất...');
      
      // 1. Xóa dữ liệu local trước khi đăng xuất khỏi Firebase
      try {
        if (context != null) {
          debugPrint('🧹 AuthService: Đang xóa dữ liệu local thông qua context...');
          
          // Xóa dữ liệu từ UserDataProvider
          final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
          await userDataProvider.clearLocalUserData();
          
          // Xóa dữ liệu từ các providers khác nếu có
          try {
            // Food Provider
            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
            await foodProvider.clearDataOnLogout();
            
            // Exercise Provider
            final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
            await exerciseProvider.clearDataOnLogout();
            
            // Water Provider
            final waterProvider = Provider.of<WaterProvider>(context, listen: false);
            await waterProvider.clearDataOnLogout();
            
            debugPrint('✅ AuthService: Đã xóa dữ liệu từ tất cả các providers');
          } catch (providerError) {
            debugPrint('⚠️ AuthService: Không thể xóa dữ liệu từ một số providers: $providerError');
            // Tiếp tục quá trình đăng xuất
          }
        } else {
          // Nếu không có context, xóa dữ liệu từ SharedPreferences trực tiếp
          debugPrint('🧹 AuthService: Không có context, xóa dữ liệu local từ SharedPreferences...');
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          debugPrint('✅ AuthService: Đã xóa dữ liệu từ SharedPreferences');
        }
      } catch (clearError) {
        debugPrint('⚠️ AuthService: Lỗi khi xóa dữ liệu local: $clearError');
        // Tiếp tục quá trình đăng xuất ngay cả khi không thể xóa dữ liệu local
      }
      
      // 2. Đăng xuất khỏi Firebase
      await _auth.signOut();
      _isAuthenticated = false;
      _user = null;
      
      // 3. Lưu trạng thái đăng nhập
      _saveLoginStatus(false);
      
      notifyListeners();
      debugPrint('✅ AuthService: Đăng xuất thành công! Trạng thái đăng nhập đã được cập nhật.');
    } catch (e) {
      _errorMessage = 'Đăng xuất thất bại. Vui lòng thử lại.';
      debugPrint('❌ AuthService: Lỗi khi đăng xuất: $e');
      notifyListeners();
    }
  }
  
  // Check if user is authenticated
  Future<bool> checkAuthStatus() async {
    final user = _auth.currentUser;
    _isAuthenticated = user != null;
    _user = user;
    
    // Update user document in Firestore if authenticated
    if (_user != null) {
      await _userService.createOrUpdateUser(_user!);
      
      // Đồng bộ với API - không chờ đợi để không chặn UI
      _syncWithApi(_user!); // Removed await
    }
    
    notifyListeners();
    return _isAuthenticated;
  }
  
  // Sign in anonymously for demo access
  Future<bool> signInAnonymously() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final userCredential = await _auth.signInAnonymously();
      _user = userCredential.user;
      _isAuthenticated = true;
      
      // Create user document in Firestore
      if (_user != null) {
        // Bỏ qua xác thực token với FastAPI cho tài khoản ẩn danh
        await _userService.createOrUpdateUser(_user!);
        
        // Đồng bộ với API - không chờ đợi để không chặn UI
        _syncWithApi(_user!); // Removed await
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Có lỗi xảy ra. Vui lòng thử lại sau.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Convert anonymous account to permanent account
  Future<bool> convertAnonymousAccount(String email, String password, String? displayName) async {
    if (_user == null || !_user!.isAnonymous) {
      _errorMessage = 'Không thể thực hiện chuyển đổi tài khoản.';
      return false;
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      // Chuyển đổi tài khoản ẩn danh trực tiếp qua Firebase
      await _userService.convertAnonymousAccount(
        email: email,
        password: password,
        displayName: displayName,
      );
      
      // Refresh user
      _user = _auth.currentUser;
      
      // Bỏ qua xác thực token với FastAPI sau khi chuyển đổi
      // Đã chuyển đổi tài khoản thành công trong Firebase
      debugPrint('✅ Đã chuyển đổi tài khoản ẩn danh thành tài khoản email thành công');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Có lỗi xảy ra. Vui lòng thử lại sau.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Handle Firebase authentication errors
  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'Không tìm thấy người dùng với email này.';
        break;
      case 'wrong-password':
        _errorMessage = 'Mật khẩu không chính xác.';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Email này đã được sử dụng.';
        break;
      case 'weak-password':
        _errorMessage = 'Mật khẩu quá yếu.';
        break;
      case 'invalid-email':
        _errorMessage = 'Email không hợp lệ.';
        break;
      case 'admin-restricted-operation':
        _errorMessage = 'Thao tác này bị hạn chế. Vui lòng đăng nhập bằng email và mật khẩu.';
        break;
      default:
        _errorMessage = 'Có lỗi xảy ra: ${e.message}';
    }
    _isLoading = false;
    notifyListeners();
  }
  
  // Save login status to SharedPreferences for persistence
  Future<void> _saveLoginStatus(bool isLoggedIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', isLoggedIn);
    } catch (e) {
      debugPrint('Error saving login status: $e');
    }
  }
  
  // Check if user is premium (has account and is not anonymous)
  bool isPremiumUser() {
    return _isAuthenticated && !(_user?.isAnonymous ?? true);
  }
  
  // Update profile data
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    if (_user == null) {
      _errorMessage = 'Không có người dùng đăng nhập.';
      return false;
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      await _userService.updateUserProfile(
        displayName: displayName,
        photoURL: photoURL,
      );
      
      // Refresh user
      _user = _auth.currentUser;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể cập nhật hồ sơ: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Delete user account
  Future<bool> deleteAccount() async {
    if (_user == null) {
      _errorMessage = 'Không có người dùng đăng nhập.';
      return false;
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      await _userService.deleteUserAccount();
      
      _isLoading = false;
      _isAuthenticated = false;
      _user = null;
      
      // Save login state locally
      _saveLoginStatus(false);
      
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Có lỗi xảy ra. Vui lòng thử lại sau.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Cập nhật thông tin người dùng thông qua API
  Future<bool> updateUserProfileViaApi(Map<String, dynamic> userData) async {
    // Bước 1: Xác thực người dùng
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _errorMessage = 'Không có người dùng đăng nhập.';
      return false;
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      debugPrint('🔄 Bỏ qua API, đang cập nhật thông tin người dùng trực tiếp vào Firebase...');
      
      // Bước 2: Chuẩn bị dữ liệu (đã được truyền vào qua tham số userData)
      // Thêm trường name nếu chưa có
      if (!userData.containsKey('name')) {
        userData['name'] = userData['display_name'] ?? currentUser.displayName ?? currentUser.email ?? 'Người dùng';
      }
      
      // Thêm thời gian cập nhật
      userData['updated_at'] = DateTime.now().toIso8601String();
      
      // Bước 3: Lưu trực tiếp vào Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(userData, SetOptions(merge: true));
      
      debugPrint('✅ Đã đồng bộ dữ liệu người dùng trực tiếp lên Firebase thành công');
      
      // Cập nhật thông tin người dùng trong Firebase Auth nếu cần
      if (userData.containsKey('displayName') && userData['displayName'] != null) {
        await currentUser.updateDisplayName(userData['displayName']);
      }
      
      if (userData.containsKey('photoURL') && userData['photoURL'] != null) {
        await currentUser.updatePhotoURL(userData['photoURL']);
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật thông tin người dùng vào Firebase: $e');
      
      // Xử lý lỗi cụ thể
      if (e.toString().contains('permission-denied')) {
        _errorMessage = 'Không có quyền cập nhật dữ liệu. Vui lòng đăng nhập lại.';
      } else {
        _errorMessage = 'Có lỗi xảy ra khi cập nhật dữ liệu: $e';
      }
      
      _isLoading = false;
      notifyListeners();
      
      // Vẫn trả về true để ứng dụng tiếp tục hoạt động trong trường hợp lỗi không nghiêm trọng
      return false;
    }
  }
  
  // Cập nhật toàn bộ thông tin người dùng
  Future<bool> updateFullUserProfile({
    String? displayName,
    String? photoURL,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    String? activityLevel,
    String? goal,
    double? pace,
    List<String>? dietRestrictions,
    List<String>? healthConditions,
    String? measurementSystem,
    Map<String, dynamic>? nutritionGoals,
  }) async {
    // Bước 1: Xác thực người dùng
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _errorMessage = 'Không có người dùng đăng nhập.';
      return false;
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      // Bước 2: Chuẩn bị dữ liệu
      final Map<String, dynamic> userData = {
        'updated_at': DateTime.now().toIso8601String(),
        'name': displayName ?? currentUser.displayName ?? currentUser.email ?? 'Người dùng',
      };
      
      // Thêm các thông tin cần cập nhật nếu có
      if (displayName != null) userData['display_name'] = displayName;
      if (photoURL != null) userData['photo_url'] = photoURL;
      if (age != null) userData['age'] = age;
      if (gender != null) userData['gender'] = gender;
      if (heightCm != null) userData['height_cm'] = heightCm;
      if (weightKg != null) userData['weight_kg'] = weightKg;
      if (targetWeightKg != null) userData['target_weight_kg'] = targetWeightKg;
      if (activityLevel != null) userData['activity_level'] = activityLevel;
      if (goal != null) userData['goal'] = goal;
      if (pace != null) userData['pace'] = pace;
      if (dietRestrictions != null) userData['diet_restrictions'] = dietRestrictions;
      if (healthConditions != null) userData['health_conditions'] = healthConditions;
      if (measurementSystem != null) userData['measurement_system'] = measurementSystem;
      if (nutritionGoals != null) userData['nutrition_goals'] = nutritionGoals;
      
      // Bước 3: Lưu dữ liệu trực tiếp vào Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set(userData, SetOptions(merge: true));
        
        debugPrint('✅ Cập nhật thông tin người dùng vào Firestore thành công');
        
        // Cập nhật thông tin người dùng trong Firebase Auth nếu cần
        if (displayName != null) {
          await currentUser.updateDisplayName(displayName);
        }
        
        if (photoURL != null) {
          await currentUser.updatePhotoURL(photoURL);
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } catch (firestoreError) {
        debugPrint('❌ Lỗi khi cập nhật thông tin người dùng vào Firestore: $firestoreError');
        _errorMessage = 'Lỗi khi lưu dữ liệu: $firestoreError';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật thông tin người dùng: $e');
      
      _errorMessage = 'Có lỗi xảy ra: $e';
      _isLoading = false;
      notifyListeners();
      
      return false;
    }
  }

  // Phương thức để lấy dữ liệu người dùng từ Firebase trực tiếp
  Future<Map<String, dynamic>> getUserDataFromFirebase() async {
    try {
      if (_user == null) {
        print('❌ Không thể lấy dữ liệu: Không có người dùng đăng nhập');
        return {};
      }
      
      print('🔄 Đang lấy dữ liệu người dùng từ Firebase cho: ${_user!.uid}');
      
      // Lấy dữ liệu trực tiếp từ Firestore thay vì qua API
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();
        
        if (docSnapshot.exists && docSnapshot.data() != null) {
          final userData = docSnapshot.data()!;
          print('✅ Đã lấy dữ liệu người dùng từ Firebase thành công');
          
          // Đảm bảo các trường quan trọng không bị null
          userData['user_id'] = userData['user_id'] ?? _user!.uid;
          userData['email'] = userData['email'] ?? _user!.email;
          userData['is_authenticated'] = true;
          
          // Đảm bảo trường name có giá trị
          if (!userData.containsKey('name') || userData['name'] == null || userData['name'].toString().isEmpty) {
            userData['name'] = _user!.displayName ?? _user!.email ?? 'Người dùng';
          }
          
          return userData;
        } else {
          print('⚠️ Không tìm thấy dữ liệu người dùng trên Firebase');
        }
      } catch (firestoreError) {
        print('❌ Lỗi khi đọc dữ liệu trực tiếp từ Firestore: $firestoreError');
      }
      
      // Tạo dữ liệu cơ bản từ Firebase Auth nếu không tìm thấy trong Firestore
      return {
        'user_id': _user!.uid,
        'email': _user!.email,
        'display_name': _user!.displayName,
        'photo_url': _user!.photoURL,
        'is_authenticated': true,
        'name': _user!.displayName ?? _user!.email ?? 'Người dùng',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Lỗi khi lấy dữ liệu người dùng từ Firebase: $e');
      
      // Trả về dữ liệu cơ bản nếu có lỗi
      return {
        'user_id': _user?.uid,
        'email': _user?.email,
        'display_name': _user?.displayName,
        'photo_url': _user?.photoURL,
        'is_authenticated': true,
        'name': _user?.displayName ?? _user?.email ?? 'Người dùng',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }

  // Phương thức đọc dữ liệu người dùng từ Firebase và cập nhật vào UserDataProvider
  Future<void> syncUserDataToProvider(dynamic userDataProvider) async {
    try {
      if (_user == null || userDataProvider == null) {
        print('❌ Không thể đọc dữ liệu: Không có người dùng hoặc UserDataProvider');
        return;
      }
      
      print('🔄 Bắt đầu đọc dữ liệu từ Firebase cho người dùng: ${_user!.uid}');
      
      // Chỉ cập nhật thông tin cơ bản từ Firebase Auth để tránh lỗi PigeonUserDetails
      try {
        // Tạo đối tượng dữ liệu an toàn từ thông tin Firebase Auth
        Map<String, dynamic> safeData = {
          'name': _user!.displayName ?? _user!.email ?? 'Người dùng',
          'email': _user!.email,
          'photo_url': _user!.photoURL,
          'user_id': _user!.uid,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
          
        // Cập nhật thông tin cơ bản an toàn vào UserDataProvider
        try {
          // Sử dụng phương thức setter thay vì truy cập trực tiếp
          userDataProvider.setName(safeData['name']);
          
          if (safeData['email'] != null) {
            userDataProvider.setEmail(safeData['email']);
          }
          
          // Đặt userId để có thể tải dữ liệu đầy đủ sau
          userDataProvider.setUserId(_user!.uid);
          
          print('✅ Đã cập nhật thông tin cơ bản từ Firebase Auth vào UserDataProvider');
          
          // Kích hoạt tải dữ liệu đầy đủ từ Firestore trong background sau một khoảng thời gian
          Future.delayed(Duration(seconds: 1), () {
            try {
              // Gọi phương thức loadFromFirestore đã được cải thiện
              userDataProvider.loadFromFirestore();
            } catch (delayedError) {
              print('⚠️ Không thể tải toàn bộ dữ liệu trong background: $delayedError');
            }
          });
          
        } catch (e) {
          print('❌ Lỗi khi cập nhật thông tin cơ bản: $e');
        }
      } catch (authError) {
        print('❌ Lỗi khi lấy thông tin từ Firebase Auth: $authError');
      }
    } catch (e) {
      print('❌ Lỗi tổng thể khi đồng bộ dữ liệu người dùng: $e');
    }
  }
}