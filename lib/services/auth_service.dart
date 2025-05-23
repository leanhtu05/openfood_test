import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class AuthService extends ChangeNotifier {
  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // User service for Firestore operations
  final UserService _userService = UserService();
  
  // Current user
  User? _user;
  User? get user => _user;

  // Authentication status
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  
  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error message
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Constructor to initialize the service
  AuthService() {
    // Set initial authenticated state based on current user
    _user = _auth.currentUser;
    _isAuthenticated = _user != null;
    
    // Listen for auth state changes
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      _isAuthenticated = user != null;
      
      // Update Firestore user document when user signs in
      if (user != null) {
        try {
          await _userService.createOrUpdateUser(user);
        } catch (e) {
          print('Error updating user in Firestore: $e');
        }
      }
      
      notifyListeners();
    });
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
        await _userService.createOrUpdateUser(_user!);
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
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      _isAuthenticated = true;
      
      // Update user document in Firestore
      if (_user != null) {
        await _userService.createOrUpdateUser(_user!);
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
        await _userService.createOrUpdateUser(_user!);
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
      await _userService.convertAnonymousAccount(
        email: email,
        password: password,
        displayName: displayName,
      );
      
      // Refresh user
      _user = _auth.currentUser;
      
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

  // Handle Firebase Authentication errors
  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'Không tìm thấy tài khoản với email này.';
        break;
      case 'wrong-password':
        _errorMessage = 'Mật khẩu không chính xác.';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Email này đã được sử dụng.';
        break;
      case 'invalid-email':
        _errorMessage = 'Email không hợp lệ.';
        break;
      case 'weak-password':
        _errorMessage = 'Mật khẩu quá yếu. Vui lòng sử dụng mật khẩu mạnh hơn.';
        break;
      case 'operation-not-allowed':
        _errorMessage = 'Phương thức đăng nhập này không được hỗ trợ.';
        break;
      case 'credential-already-in-use':
        _errorMessage = 'Tài khoản này đã được liên kết với người dùng khác.';
        break;
      case 'requires-recent-login':
        _errorMessage = 'Thao tác này nhạy cảm và yêu cầu xác thực gần đây. Vui lòng đăng nhập lại.';
        break;
      default:
        _errorMessage = 'Đã xảy ra lỗi: ${e.message}';
        break;
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
      
      // Save login status locally
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
} 