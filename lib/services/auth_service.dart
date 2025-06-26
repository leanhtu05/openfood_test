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
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/chat_api.dart';

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

  // === Xác thực bằng số điện thoại ===
  
  // Lưu trữ thông tin xác thực số điện thoại
  String _verificationId = '';
  int? _resendToken;
  String _phoneNumber = '';
  
  // Lấy số điện thoại hiện tại đang xác thực
  String get phoneNumber => _phoneNumber;
  
  // Bắt đầu quá trình xác thực số điện thoại
  Future<bool> verifyPhoneNumber(String phoneNumber, {
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    Function()? onVerificationCompleted,
    Function(String)? onCodeAutoRetrievalTimeout,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    _phoneNumber = phoneNumber;
    notifyListeners();
    
    // Chuẩn hóa số điện thoại Việt Nam
    if (phoneNumber.startsWith('0')) {
      // Nếu số bắt đầu bằng 0, thay bằng +84
      phoneNumber = "+84${phoneNumber.substring(1)}";
    } else if (!phoneNumber.startsWith('+')) {
      // Nếu không có mã quốc tế, thêm +84
      phoneNumber = "+84$phoneNumber";
    }

    try {
      // Thêm delay nhỏ để tránh gọi quá nhiều request liên tiếp
      await Future.delayed(Duration(milliseconds: 1500));
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android-only: Xác thực tự động hoàn tất

          _isLoading = false;
          notifyListeners();
          
          // Đăng nhập với credential đã nhận được
          final result = await _signInWithCredential(credential);
          
          if (onVerificationCompleted != null && result) {
            onVerificationCompleted();
          }
          
          // Không trả về giá trị từ hàm này vì kiểu trả về là Future<void>
        },
        verificationFailed: (FirebaseAuthException e) {

          _isLoading = false;
          
          switch (e.code) {
            case 'invalid-phone-number':
              _errorMessage = 'Số điện thoại không hợp lệ';
              break;
            case 'too-many-requests':
              _errorMessage = 'Quá nhiều yêu cầu. Vui lòng thử lại sau 1-2 giờ hoặc sử dụng phương thức đăng nhập khác (Google, Email).';
              break;
            case 'quota-exceeded':
              _errorMessage = 'Vượt quá giới hạn xác thực. Vui lòng thử lại sau 1-2 giờ hoặc sử dụng phương thức đăng nhập khác.';
              break;
            default:
              if (e.message?.contains('blocked all requests') == true) {
                _errorMessage = 'Firebase đã tạm khóa xác thực từ thiết bị này. Vui lòng:\n1. Thử lại sau 24 giờ\n2. Sử dụng phương thức đăng nhập khác (Google hoặc Email)\n3. Sử dụng thiết bị khác nếu cần gấp';
              } else {
                _errorMessage = 'Lỗi xác thực số điện thoại: ${e.message}';
              }
          }
          
          notifyListeners();
          onVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {

          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          notifyListeners();
          
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {

          _verificationId = verificationId;
          
          // Gọi callback nếu được cung cấp
          if (onCodeAutoRetrievalTimeout != null) {
            onCodeAutoRetrievalTimeout(verificationId);
          }
          
          notifyListeners();
        },
        timeout: Duration(seconds: 120), // Sửa thành 2 phút để tuân thủ giới hạn của Firebase
        forceResendingToken: _resendToken,
      );
      
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi gửi mã xác thực: ${e.toString()}';
      notifyListeners();

      return false;
    }
  }
  
  // Xác nhận mã OTP
  Future<bool> confirmOTP(String otp) async {
    if (_verificationId.isEmpty) {
      _errorMessage = 'Phiên xác thực đã hết hạn. Vui lòng thử lại.';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      // Tạo credential từ mã xác thực
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      
      // Đăng nhập với credential
      return await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      
      switch (e.code) {
        case 'invalid-verification-code':
          _errorMessage = 'Mã xác thực không chính xác. Vui lòng kiểm tra lại và thử lại.';
          break;
        case 'invalid-verification-id':
          _errorMessage = 'Phiên xác thực đã hết hạn. Vui lòng thử lại với mã mới.';
          // Reset _verificationId để ngăn việc sử dụng lại mã đã hết hạn
          _verificationId = '';
          break;
        case 'session-expired':
          _errorMessage = 'firebase_auth/session-expired';
          // Reset _verificationId để ngăn việc sử dụng lại mã đã hết hạn
          _verificationId = '';

          break;
        default:
          if (e.message?.contains('expired') == true) {
            _errorMessage = 'firebase_auth/session-expired';
            // Reset _verificationId để ngăn việc sử dụng lại mã đã hết hạn
            _verificationId = '';

          } else {
            _errorMessage = 'Lỗi xác thực: ${e.message}';

          }
      }
      
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Có lỗi xảy ra: ${e.toString()}';

      notifyListeners();
      return false;
    }
  }
  
  // Đăng nhập với PhoneAuthCredential
  Future<bool> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      _isAuthenticated = true;
      
      // Lưu trạng thái đăng nhập
      _saveLoginStatus(true);
      
      // Lấy token xác thực và lưu vào SharedPreferences
      if (_user != null) {
        final idToken = await _user!.getIdToken();
        // Lưu token bằng ChatApi
        await _saveAuthToken(idToken);
        
        // Cập nhật thông tin người dùng trong Firestore
        await _userService.createOrUpdateUser(_user!);
        
        // Đồng bộ với API nếu cần
        _syncWithApi(_user!);
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi đăng nhập: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Lưu token xác thực
  Future<void> _saveAuthToken(String? token) async {
    if (token != null && token.isNotEmpty) {
      try {
        // Lưu token bằng phương thức trong ChatApi
        await ChatApi.saveAuthToken(token);

      } catch (e) {

      }
    }
  }
  
  // Constructor to initialize the service
  AuthService() {
    // Set initial authenticated state based on current user
    _user = _auth.currentUser;
    _isAuthenticated = _user != null;
    
    // Kiểm tra Google Play Services
    _checkGooglePlayServices();
    
    // Listen for auth state changes
    _auth.authStateChanges().listen((User? user) async {

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

          }
        } catch (e) {

        }
      } else if (wasAuthenticated) {
        // Nếu trước đó đã đăng nhập và giờ đã đăng xuất

      }
      
      notifyListeners();

    });
  }
  
  // Kiểm tra Google Play Services
  Future<void> _checkGooglePlayServices() async {
    try {
      _isGooglePlayServicesAvailable = await FirebaseHelpers.isGooglePlayServicesAvailable();
      if (!_isGooglePlayServicesAvailable) {

      }
    } catch (e) {

      _isGooglePlayServicesAvailable = false;
    }
  }

  // Lấy Firebase ID Token
  Future<String?> getIdToken() async {
    try {
      if (_user == null) return null;
      return await _user!.getIdToken();
    } catch (e) {

      return null;
    }
  }
  
  // Lấy token hiện tại để gọi API
  Future<String?> getCurrentToken() async {
    try {
      if (_user == null) return null;
      return await _user!.getIdToken(true); // Force refresh token
    } catch (e) {

      return null;
    }
  }
  
  // Đồng bộ với API khi đăng nhập
  Future<void> _syncWithApi(User user) async {
    // Thực hiện đồng bộ trong một Future riêng biệt để không chặn UI
    // Sử dụng unawaited để đảm bảo không chặn luồng chính
    Future(() async {
      try {

        // Lấy token
        String? idToken;
        try {
          idToken = await user.getIdToken(true); // Force refresh token
        } catch (tokenError) {

          return;
        }
        
        // Nếu không lấy được token, bỏ qua xác thực API
        if (idToken == null) {

          return;
            }
        
        // Bỏ qua hoàn toàn phần xác thực API vì API không còn hỗ trợ hoặc không cần thiết

      } catch (e) {

      }
    });
    
    // Không chờ đợi Future hoàn thành, trả về ngay lập tức
    return;
  }
  
  // === Phương thức lấy thông tin cơ bản của người dùng từ Firebase Auth ===
  Future<Map<String, dynamic>> _getBasicUserData(User user) async {
    return {
      'uid': user.uid,
      'display_name': user.displayName,
      'email': user.email,
      'photo_url': user.photoURL,
      'is_anonymous': user.isAnonymous,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_login_at': FieldValue.serverTimestamp(),
    };
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    // Kiểm tra mật khẩu theo chính sách Firebase trước khi gửi lên server
    if (!isPasswordValid(password)) {
      List<String> missingRequirements = getMissingPasswordRequirements(password);
      _errorMessage = missingRequirements.join('\n');
      _isLoading = false;
      notifyListeners();
      return false;
    }
    
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

      _saveLoginStatus(true);
      
      // Lấy và lưu token xác thực
      if (_user != null) {
        try {
          // Lấy token và lưu vào SharedPreferences
          final idToken = await _user!.getIdToken();
          await _saveAuthToken(idToken);
          
          // Update user document in Firestore - bỏ qua lỗi nếu có
          await _userService.createOrUpdateUser(_user!).catchError((error) {

            // Không throw lỗi, tiếp tục đăng nhập
          });
          
          // Đồng bộ với API trong background, không chờ đợi kết quả
          Future(() {
            try {
              _syncWithApi(_user!);
            } catch (syncError) {

              // Không ảnh hưởng đến luồng đăng nhập
            }
          });
        } catch (userError) {

        }
      }
      
      _isLoading = false;
      notifyListeners();
      
      // Luôn trả về true nếu đăng nhập Firebase thành công, bất kể có lỗi đồng bộ dữ liệu hay không

      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      // Xử lý đặc biệt cho lỗi PigeonUserDetails
      if (e.toString().contains('PigeonUserDetails')) {

        // Kiểm tra xem người dùng đã đăng nhập hay chưa
        if (_auth.currentUser != null) {
          _user = _auth.currentUser;
          _isAuthenticated = true;
          _saveLoginStatus(true);
          
          // Lấy token và lưu vào SharedPreferences
          try {
            final idToken = await _user!.getIdToken();
            await _saveAuthToken(idToken);
          } catch (tokenError) {

          }
          
          _isLoading = false;
          notifyListeners();

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

    return true;
  }
  
  // Phương thức đăng nhập thay thế qua API trực tiếp (không qua Firebase)
  Future<bool> _loginViaApi(String email, String password) async {
    try {

      // Sử dụng Firebase trực tiếp thay vì gọi API
      try {
        // Đăng nhập bằng Firebase Authentication
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Kiểm tra kết quả đăng nhập
        if (userCredential.user != null) {

          // Cập nhật trạng thái đăng nhập
          _user = userCredential.user;
          _isAuthenticated = true;
          
          // Lưu trạng thái đăng nhập vào SharedPreferences
          await _saveLoginStatus(true);
          
          // Thông báo thay đổi
          notifyListeners();
          
          return true;
        } else {

          _errorMessage = 'Đăng nhập thất bại. Vui lòng kiểm tra email và mật khẩu.';
          return false;
        }
      } catch (firebaseError) {

        // Xử lý lỗi đăng nhập Firebase
        if (firebaseError is FirebaseAuthException) {
          _handleAuthError(firebaseError);
        } else {
          _errorMessage = 'Có lỗi xảy ra khi đăng nhập: ${firebaseError.toString()}';
        }
        
        return false;
      }
    } catch (e) {

      _errorMessage = 'Có lỗi xảy ra khi đăng nhập: ${e.toString()}';
      return false;
    }
  }

  Future<void> logout({BuildContext? context}) async {
    try {

      // 1. Xóa dữ liệu local trước khi đăng xuất khỏi Firebase
      try {
        if (context != null) {

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

          } catch (providerError) {

            // Tiếp tục quá trình đăng xuất
          }
        } else {
          // Nếu không có context, xóa dữ liệu từ SharedPreferences trực tiếp

          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

        }
      } catch (clearError) {

        // Tiếp tục quá trình đăng xuất ngay cả khi không thể xóa dữ liệu local
      }
      
      // 2. Đăng xuất khỏi Firebase
      await _auth.signOut();
      _isAuthenticated = false;
      _user = null;
      
      // 3. Lưu trạng thái đăng nhập
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
        _errorMessage = 'Email này đã được sử dụng. Bạn đã đăng ký bằng Google hoặc phương thức khác? Vui lòng thử đăng nhập.';
        break;
      case 'account-exists-with-different-credential':
        _errorMessage = 'Email này đã được sử dụng với phương thức đăng nhập khác. Vui lòng đăng nhập bằng email và mật khẩu.';
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

  Future<void> _saveLoginStatus(bool isLoggedIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', isLoggedIn);
    } catch (e) {

    }
  }
  
  // Kiểm tra xem người dùng có phải là người dùng premium không
  bool isPremiumUser() {
    return _user != null && !_user!.isAnonymous;
  }
  
  // Kiểm tra xem người dùng đã liên kết với email chưa
  bool isLinkedWithEmail() {
    if (_user == null) return false;
    
    // Kiểm tra xem email có tồn tại không
    final hasEmail = _user!.email != null && _user!.email!.isNotEmpty;
    
    // Kiểm tra xem có phương thức đăng nhập bằng email/password không
    final hasEmailProvider = _user!.providerData
        .any((userInfo) => userInfo.providerId == 'password');
    
    return hasEmail && hasEmailProvider;
  }
  
  // Kiểm tra xem người dùng đã liên kết với số điện thoại chưa
  bool isLinkedWithPhone() {
    if (_user == null) return false;
    
    // Kiểm tra xem số điện thoại có tồn tại không
    final hasPhone = _user!.phoneNumber != null && _user!.phoneNumber!.isNotEmpty;
    
    // Kiểm tra xem có phương thức đăng nhập bằng số điện thoại không
    final hasPhoneProvider = _user!.providerData
        .any((userInfo) => userInfo.providerId == 'phone');
    
    return hasPhone || hasPhoneProvider;
  }
  
  // Kiểm tra xem người dùng đã liên kết với Google chưa
  bool isLinkedWithGoogle() {
    if (_user == null) return false;

    return _user!.providerData
        .any((userInfo) => userInfo.providerId == 'google.com');
  }

  // 🔧 FIX: Method để refresh user state
  void refreshUser() {
    _user = _auth.currentUser;
    notifyListeners();
  }
  
  // Kiểm tra xem người dùng đã liên kết với Facebook chưa
  bool isLinkedWithFacebook() {
    if (_user == null) return false;
    
    return _user!.providerData
        .any((userInfo) => userInfo.providerId == 'facebook.com');
  }
  
  // Thêm email và mật khẩu cho tài khoản hiện tại
  Future<bool> addEmail(String email, String password) async {
    if (_user == null) {
      _errorMessage = 'Người dùng chưa đăng nhập';
      return false;
    }
    
    try {
      _isLoading = true;
      notifyListeners();
      
      // Tạo credential cho email/password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      // Liên kết tài khoản
      await _user!.linkWithCredential(credential);
      
      // Cập nhật user trong Firestore
      await _userService.createOrUpdateUser(_user!);
      
      _isLoading = false;
      notifyListeners();
      
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      
      switch (e.code) {
        case 'email-already-in-use':
          _errorMessage = 'Email này đã được sử dụng bởi tài khoản khác';
          break;
        case 'invalid-email':
          _errorMessage = 'Email không hợp lệ';
          break;
        case 'weak-password':
          _errorMessage = 'Mật khẩu không đủ mạnh';
          break;
        default:
          _errorMessage = 'Lỗi: ${e.message}';
      }
      
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Tạo mật khẩu cho tài khoản đã có email
  Future<bool> createPassword(String password) async {
    if (_user == null) {
      _errorMessage = 'Người dùng chưa đăng nhập';
      return false;
    }
    
    if (_user!.email == null || _user!.email!.isEmpty) {
      _errorMessage = 'Tài khoản không có email';
      return false;
    }
    
    try {
      _isLoading = true;
      notifyListeners();
      
      // Tạo credential cho email/password
      final credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: password,
      );
      
      // Liên kết tài khoản
      await _user!.linkWithCredential(credential);
      
      // Cập nhật user trong Firestore
      await _userService.createOrUpdateUser(_user!);
      
      _isLoading = false;
      notifyListeners();
      
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      
      switch (e.code) {
        case 'provider-already-linked':
          _errorMessage = 'Tài khoản đã được liên kết với email/password';
          break;
        case 'weak-password':
          _errorMessage = 'Mật khẩu không đủ mạnh';
          break;
        default:
          _errorMessage = 'Lỗi: ${e.message}';
      }
      
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Kiểm tra yêu cầu mật khẩu
  List<String> getMissingPasswordRequirements(String password) {
    List<String> requirements = [];
    
    if (password.length < 8) {
      requirements.add('Mật khẩu phải có ít nhất 8 ký tự');
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      requirements.add('Mật khẩu phải chứa ít nhất một chữ hoa');
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      requirements.add('Mật khẩu phải chứa ít nhất một chữ thường');
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      requirements.add('Mật khẩu phải chứa ít nhất một chữ số');
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      requirements.add('Mật khẩu phải chứa ít nhất một ký tự đặc biệt');
    }
    
    return requirements;
  }
  
  // Kiểm tra độ mạnh của mật khẩu theo chính sách Firebase
  Map<String, bool> checkPasswordStrength(String password) {
    Map<String, bool> requirements = {
      'length': password.length >= 8,
      'uppercase': password.contains(RegExp(r'[A-Z]')),
      'lowercase': password.contains(RegExp(r'[a-z]')),
      'numeric': password.contains(RegExp(r'[0-9]')),
      'special': password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    };
    
    return requirements;
  }
  
  // Kiểm tra mật khẩu có đáp ứng yêu cầu Firebase không (theo thiết lập của bạn)
  bool isPasswordValid(String password) {
    final requirements = checkPasswordStrength(password);
    
    // Theo thiết lập Firebase của bạn: yêu cầu chữ hoa, chữ thường, và số
    return requirements['length']! && 
           requirements['uppercase']! && 
           requirements['lowercase']! && 
           requirements['numeric']!;
  }
  
  // === Phương thức liên kết tài khoản ===
  
  // Liên kết tài khoản hiện tại với credential mới
  Future<bool> linkWithCredential(AuthCredential credential) async {
    if (_user == null) {
      _errorMessage = 'Người dùng chưa đăng nhập';
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Liên kết tài khoản
      final userCredential = await _user!.linkWithCredential(credential);

      // 🔧 FIX: Cập nhật user reference sau khi liên kết
      _user = userCredential.user ?? _auth.currentUser;

      // Cập nhật user trong Firestore
      try {
        await _userService.createOrUpdateUser(_user!);
      } catch (firestoreError) {
        debugPrint('⚠️ Lỗi khi cập nhật Firestore: $firestoreError');
        // Không fail toàn bộ quá trình nếu Firestore lỗi
      }

      _isLoading = false;
      notifyListeners();

      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'provider-already-linked':
          _errorMessage = 'Tài khoản đã được liên kết với phương thức này';
          break;
        case 'credential-already-in-use':
          _errorMessage = 'Phương thức đăng nhập này đã được liên kết với tài khoản khác';
          break;
        default:
          _errorMessage = 'Lỗi: ${e.message}';
      }

      notifyListeners();
      return false;
    } catch (e) {
      // 🔧 FIX: Xử lý đặc biệt cho lỗi Pigeon
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('type cast') ||
          e.toString().contains('subtype')) {
        debugPrint('🔧 Phát hiện lỗi Pigeon, kiểm tra trạng thái user...');

        // Kiểm tra xem liên kết có thành công không
        _user = _auth.currentUser;
        if (_user != null) {
          // Kiểm tra xem credential đã được liên kết chưa
          bool isLinked = false;
          if (credential.providerId == 'google.com') {
            isLinked = isLinkedWithGoogle();
          } else if (credential.providerId == 'phone') {
            isLinked = isLinkedWithPhone();
          } else if (credential.providerId == 'password') {
            isLinked = isLinkedWithEmail();
          }

          if (isLinked) {
            debugPrint('✅ Liên kết thành công mặc dù có lỗi Pigeon');
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }

      _isLoading = false;
      _errorMessage = 'Lỗi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Liên kết với số điện thoại (bước 1: gửi OTP)
  Future<bool> linkWithPhoneNumber(String phoneNumber, {
    required Function(String) onCodeSent,
    required Function(String) onVerificationFailed,
  }) async {
    if (_user == null) {
      _errorMessage = 'Người dùng chưa đăng nhập';
      return false;
    }
    
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Tự động xác thực trên Android
          try {
            await _user!.linkWithCredential(credential);
            _isLoading = false;
            notifyListeners();
          } catch (e) {
            _isLoading = false;
            _errorMessage = 'Lỗi khi liên kết: ${e.toString()}';
            notifyListeners();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _isLoading = false;
          String errorMessage = 'Lỗi xác thực: ${e.message ?? e.code}';
          _errorMessage = errorMessage;
          notifyListeners();
          onVerificationFailed(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          notifyListeners();
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();
        },
        timeout: Duration(seconds: 120),
      );
      
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Xác nhận OTP để liên kết số điện thoại
  Future<bool> confirmPhoneNumberLinking(String smsCode) async {
    if (_user == null) {
      _errorMessage = 'Người dùng chưa đăng nhập';
      return false;
    }

    if (_verificationId.isEmpty) {
      _errorMessage = 'Không có mã xác thực';
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Tạo credential từ mã OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );

      // 🔧 FIX: Sử dụng method linkWithCredential đã được cải thiện
      final success = await linkWithCredential(credential);

      if (success) {
        // Reset verification ID sau khi thành công
        _verificationId = '';
      }

      return success;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      if (e.code == 'invalid-verification-code') {
        _errorMessage = 'Mã OTP không hợp lệ';
      } else if (e.code == 'credential-already-in-use') {
        _errorMessage = 'Số điện thoại này đã được liên kết với tài khoản khác';
      } else {
        _errorMessage = 'Lỗi: ${e.message}';
      }

      notifyListeners();
      return false;
    } catch (e) {
      // 🔧 FIX: Xử lý đặc biệt cho lỗi Pigeon
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('type cast') ||
          e.toString().contains('subtype')) {
        debugPrint('🔧 Phát hiện lỗi Pigeon trong confirmPhoneNumberLinking');

        // Kiểm tra xem liên kết có thành công không
        _user = _auth.currentUser;
        if (_user != null && isLinkedWithPhone()) {
          debugPrint('✅ Liên kết số điện thoại thành công mặc dù có lỗi Pigeon');
          _verificationId = '';
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _isLoading = false;
      _errorMessage = 'Lỗi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Xử lý lỗi khi liên kết tài khoản
  void _handleLinkError(FirebaseAuthException e) {
    switch (e.code) {
      case 'provider-already-linked':
        _errorMessage = 'Tài khoản đã được liên kết với phương thức này.';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Email này đã được sử dụng bởi một tài khoản khác.';
        break;
      case 'credential-already-in-use':
        _errorMessage = 'Thông tin này đã được sử dụng bởi một tài khoản khác.';
        break;
      case 'requires-recent-login':
        _errorMessage = 'Vui lòng đăng nhập lại để thực hiện thao tác này.';
        break;
      default:
        _errorMessage = 'Có lỗi xảy ra: ${e.message}';
    }
    _isLoading = false;
    notifyListeners();
  }
  
  // Lấy danh sách các phương thức liên kết
  List<String> getLinkedProviders() {
    if (_user == null) return [];
    
    List<String> providers = [];
    
    for (final providerData in _user!.providerData) {
      switch (providerData.providerId) {
        case 'password':
          providers.add('email');
          break;
        case 'phone':
          providers.add('phone');
          break;
        case 'google.com':
          providers.add('google');
          break;
        default:
          providers.add(providerData.providerId);
      }
    }
    
    return providers;
  }

  // === Phương thức đồng bộ dữ liệu từ Firebase đến UserDataProvider ===
  Future<void> syncUserDataToProvider(udp.UserDataProvider userDataProvider) async {
    if (_user == null) {

      throw Exception('Người dùng chưa đăng nhập');
    }
    
    try {

      final firestoreData = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      
      if (firestoreData.exists && firestoreData.data() != null) {

        await userDataProvider.loadFromFirestoreData(firestoreData.data()!);

      } else {

        // Tạo dữ liệu cơ bản từ thông tin Firebase nếu không có trong Firestore
        final basicData = await _getBasicUserData(_user!);
        
        // Sử dụng named parameters thay vì positional parameters
        await userDataProvider.updateUserData(
          name: basicData['display_name'] as String?,
        );
        
        // Lưu dữ liệu cơ bản vào Firestore
        await _userService.updateUserProfileToFirebase(basicData);
      }
    } catch (e) {

      // Có thể throw lỗi lại để UI biết và xử lý
      throw Exception('Không thể đồng bộ dữ liệu người dùng: ${e.toString()}');
    }
  }

  // === Phương thức cập nhật đầy đủ thông tin profile người dùng ===
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
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      if (_user == null) {
        _errorMessage = 'Người dùng chưa đăng nhập';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Chuẩn bị dữ liệu cập nhật
      Map<String, dynamic> userData = {};
      
      // Chỉ thêm các trường không null vào userData
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
      
      // Thêm thời gian cập nhật
      userData['updated_at'] = FieldValue.serverTimestamp();
      
      // Cập nhật thông tin người dùng trong Firestore
      bool success = await _userService.updateUserProfileToFirebase(userData);
      
      _isLoading = false;
      notifyListeners();

      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi cập nhật thông tin: ${e.toString()}';
      notifyListeners();

      return false;
    }
  }
  
  // === Phương thức gửi email đặt lại mật khẩu ===
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      
      switch (e.code) {
        case 'invalid-email':
          _errorMessage = 'Email không hợp lệ';
          break;
        case 'user-not-found':
          _errorMessage = 'Không tìm thấy tài khoản với email này';
          break;
        default:
          _errorMessage = 'Lỗi khi gửi email đặt lại mật khẩu: ${e.message}';
      }
      
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi không xác định: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // === Phương thức đăng nhập bằng Google ===
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      // Khởi tạo GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn();

      try {
        await googleSignIn.signOut();
      } catch (e) {

        // Bỏ qua lỗi này, tiếp tục quy trình
      }
      
      // Hiển thị giao diện chọn tài khoản Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        _errorMessage = 'Đã hủy đăng nhập bằng Google.';
        notifyListeners();
        return false;
      }
      
      // Lấy thông tin xác thực từ tài khoản Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Tạo AuthCredential từ thông tin xác thực Google
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      try {
        // Đăng nhập với Firebase Auth sử dụng credential
        final userCredential = await _auth.signInWithCredential(credential);
        _user = userCredential.user;
        _isAuthenticated = true;
        
        // Lưu trạng thái đăng nhập
        _saveLoginStatus(true);
        
        // Lấy và lưu token xác thực
        if (_user != null) {
          try {
            // Lấy token từ Firebase
            final idToken = await _user!.getIdToken();
            // Lưu token vào SharedPreferences
            await _saveAuthToken(idToken);

          } catch (tokenError) {

            // Không ảnh hưởng đến quy trình đăng nhập
          }
          
          // Cập nhật thông tin người dùng trong Firestore
          // Tạo dữ liệu cơ bản để tránh lỗi chuyển đổi kiểu
          Map<String, dynamic> userData = {
            'user_id': _user!.uid,
            'email': _user!.email,
            'name': _user!.displayName ?? '',
            'photo_url': _user!.photoURL,
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          // Cập nhật vào Firestore
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_user!.uid)
                .set(userData, SetOptions(merge: true));

          } catch (firestoreError) {

            // Tiếp tục xử lý đăng nhập ngay cả khi không thể lưu vào Firestore
          }
        }
        
        _isLoading = false;
        notifyListeners();
        
        return true;
      } catch (firebaseError) {
        // Xử lý lỗi đặc biệt là type cast error từ PigeonUserDetails
        if (firebaseError.toString().contains('PigeonUserDetails') || 
            firebaseError.toString().contains('type cast') ||
            firebaseError.toString().contains('subtype')) {

          // Kiểm tra xem người dùng đã đăng nhập hay chưa
          _user = _auth.currentUser;
          if (_user != null) {
            _isAuthenticated = true;
            _saveLoginStatus(true);
            
            // Lấy và lưu token xác thực
            try {
              final idToken = await _user!.getIdToken();
              await _saveAuthToken(idToken);

            } catch (tokenError) {

            }
            
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
        throw firebaseError;
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Có lỗi xảy ra khi đăng nhập với Google: ${e.toString()}';

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Phương thức đăng nhập bằng số điện thoại (xác thực OTP)
  Future<bool> signInWithPhoneNumber(String verificationId, String smsCode) async {
    try {
      // Kiểm tra xem đã đăng nhập hay chưa
      if (FirebaseAuth.instance.currentUser?.phoneNumber != null) {

        notifyListeners();
        return true;
      }

      // Nếu chưa đăng nhập, tiến hành xác thực OTP
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Đăng nhập với credential
      await _auth.signInWithCredential(credential);
      
      // Xác thực thành công, cập nhật trạng thái
      _errorMessage = '';
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {

      switch (e.code) {
        case 'invalid-verification-code':
          _errorMessage = 'Mã xác thực không hợp lệ. Vui lòng kiểm tra lại.';
          break;
        case 'invalid-verification-id':
          _errorMessage = 'ID xác thực không hợp lệ. Vui lòng thử gửi lại mã.';
          break;
        case 'session-expired':
          _errorMessage = 'Phiên xác thực đã hết hạn. Vui lòng thử gửi lại mã.';
          break;
        default:
          _errorMessage = e.message ?? 'Đã xảy ra lỗi khi xác thực.';
      }
      notifyListeners();
      return false;
    } catch (e) {

      _errorMessage = 'Đã xảy ra lỗi khi xác thực. Vui lòng thử lại sau.';
      notifyListeners();
      return false;
    }
  }
}