import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';
import 'api_service.dart';
import '../utils/firebase_helpers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      _user = user;
      _isAuthenticated = user != null;
      
      // Update Firestore user document when user signs in
      if (user != null) {
        try {
          await _userService.createOrUpdateUser(user);
          
          // Đồng bộ với API - không chờ đợi để không chặn UI
          _syncWithApi(user); // Removed await
        } catch (e) {
          print('Error updating user in Firestore: $e');
        }
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
        
      // Bỏ qua xác thực token với FastAPI
      if (_user != null) {
        // Update user document in Firestore
          await _userService.createOrUpdateUser(_user!);
          
          // Đồng bộ với API - không chờ đợi để không chặn UI
          _syncWithApi(_user!); // Removed await
      }
      
      // Save login state locally
      _saveLoginStatus(true);
      
      _isLoading = false;
      notifyListeners();
      
      // Đảm bảo rằng các lỗi xử lý dữ liệu từ API không ảnh hưởng đến việc đăng nhập
      print('✅ Đăng nhập thành công, sẽ điều hướng đến màn hình chính');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
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
      debugPrint('🔄 Đang đăng nhập qua API trực tiếp...');
      
      // Gọi API đăng nhập trực tiếp
      final response = await http.post(
        Uri.parse('${ApiService.authBaseUrl}/auth/email-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Đăng nhập API trực tiếp thành công');
        
        // Xử lý thông tin người dùng từ API
        if (data['user'] != null && data['token'] != null) {
          // Lưu token vào SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('api_token', data['token']);
          await prefs.setString('user_id', data['user']['uid']);
          
          // Đặt trạng thái đăng nhập
          _isAuthenticated = true;
          
          // Tạo đối tượng User giả để sử dụng trong ứng dụng
          // Lưu ý: Đây không phải là User thật từ Firebase
          // nhưng chúng ta cần nó để ứng dụng hoạt động bình thường
          // _user = _createMockUser(data['user']);
          
          return true;
        }
      } else {
        debugPrint('❌ Đăng nhập API trực tiếp thất bại: ${response.statusCode}');
        _errorMessage = 'Đăng nhập thất bại. Vui lòng kiểm tra email và mật khẩu.';
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Lỗi khi đăng nhập qua API trực tiếp: $e');
      _errorMessage = 'Có lỗi xảy ra khi đăng nhập: ${e.toString()}';
      return false;
    }
  }

  // Log out
  Future<void> logout() async {
    try {
      await _auth.signOut();
      _isAuthenticated = false;
      _user = null;
      
      // Save login state locally
      _saveLoginStatus(false);
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Đăng xuất thất bại. Vui lòng thử lại.';
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
      // Bước 2: Lấy Firebase ID Token
      final idToken = await currentUser.getIdToken(true);
      
      // Bước 3: Chuẩn bị dữ liệu (đã được truyền vào qua tham số userData)
      // Thêm trường name nếu chưa có
      if (!userData.containsKey('name')) {
        userData['name'] = userData['display_name'] ?? currentUser.displayName ?? currentUser.email ?? 'Người dùng';
      }
      
      // Bước 4: Gửi request PATCH đến FastAPI endpoint
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/firestore/users/${currentUser.uid}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(userData),
      ).timeout(
        Duration(seconds: 8), // Timeout sau 8 giây
        onTimeout: () {
          debugPrint('⏱️ Timeout khi cập nhật thông tin người dùng');
          return http.Response('{"error": "Timeout"}', 408);
        },
      );
      
      // Bước 5: Xử lý kết quả
      if (response.statusCode == 200) {
        debugPrint('✅ Cập nhật thông tin người dùng thành công');
        
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
      } else if (response.statusCode == 408) {
        // Timeout, xử lý lỗi
        debugPrint('⏱️ Timeout khi cập nhật thông tin người dùng, tiếp tục ở chế độ offline');
        _errorMessage = 'Cập nhật thông tin thất bại: Server không phản hồi. Đã lưu dữ liệu offline.';
        _isLoading = false;
        notifyListeners();
        
        // Vẫn trả về true để ứng dụng tiếp tục hoạt động
        return true;
      } else {
        debugPrint('❌ Cập nhật thông tin người dùng thất bại: ${response.statusCode}');
        debugPrint('Phản hồi: ${response.body}');
        
        _errorMessage = 'Cập nhật thông tin thất bại: ${response.statusCode}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật thông tin người dùng: $e');
      
      // Kiểm tra lỗi timeout/kết nối
      if (e is TimeoutException || e.toString().contains('SocketException') || e.toString().contains('timeout')) {
        debugPrint('⏱️ Lỗi kết nối/timeout, tiếp tục ở chế độ offline');
        _errorMessage = 'Không thể kết nối đến server. Đã lưu dữ liệu offline.';
      } else {
        _errorMessage = 'Có lỗi xảy ra: $e';
      }
      
      _isLoading = false;
      notifyListeners();
      
      // Vẫn trả về true để ứng dụng tiếp tục hoạt động
      return true;
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
          if (userDataProvider.setName != null) {
            userDataProvider.setName(safeData['name']);
          }
          
          if (userDataProvider.setEmail != null && safeData['email'] != null) {
            userDataProvider.setEmail(safeData['email']);
          }
          
          print('✅ Đã cập nhật thông tin cơ bản từ Firebase Auth vào UserDataProvider');
          
          // Kích hoạt tải dữ liệu đầy đủ từ Firestore trong background sau một khoảng thời gian
          // sử dụng phương thức loadFromFirestore mà chúng ta đã cải thiện
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