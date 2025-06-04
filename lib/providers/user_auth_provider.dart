import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = false;
  String? _error;
  UserService? _userService;

  UserAuthProvider() {
    // Lắng nghe sự thay đổi trạng thái đăng nhập
    _auth.authStateChanges().listen((User? user) {
      final previousUser = _user;
      _user = user;
      debugPrint("Trạng thái đăng nhập thay đổi: ${user?.uid ?? 'Chưa đăng nhập'}");
      
      // Nếu user thay đổi từ null -> có giá trị, nghĩa là đăng nhập thành công
      if (previousUser == null && user != null && !user.isAnonymous) {
        debugPrint("🔐 Đăng nhập thành công, bắt đầu đồng bộ dữ liệu từ Firebase");
        _onSuccessfulLogin();
      }
      
      notifyListeners();
    });

    // Kiểm tra và thực hiện đăng nhập ẩn danh nếu cần
    _checkAndSignInAnonymously();
  }

  // Cài đặt UserService (được gọi khi provider được khởi tạo)
  void setUserService(UserService userService) {
    _userService = userService;
  }

  // Xử lý khi đăng nhập thành công
  Future<void> _onSuccessfulLogin() async {
    try {
      // Đảm bảo UserService đã được khởi tạo
      if (_userService == null) {
        debugPrint("⚠️ UserService chưa được khởi tạo trong UserAuthProvider");
        return;
      }

      // Đồng bộ dữ liệu từ Firebase sau khi đăng nhập thành công
      await _userService!.syncUserDataFromFirebase();
      debugPrint("✅ Đã đồng bộ dữ liệu người dùng từ Firebase sau đăng nhập");
    } catch (e) {
      debugPrint("❌ Lỗi khi đồng bộ dữ liệu sau đăng nhập: $e");
    }
  }

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null && !_user!.isAnonymous;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAnonymous => _user?.isAnonymous ?? true;

  // Kiểm tra đăng nhập và thực hiện đăng nhập ẩn danh nếu chưa đăng nhập
  Future<void> _checkAndSignInAnonymously() async {
    try {
      _isLoading = true;
      notifyListeners();

      _user = _auth.currentUser;
      
      if (_user == null) {
        debugPrint("Người dùng chưa đăng nhập, đang thực hiện đăng nhập ẩn danh...");
        UserCredential result = await _auth.signInAnonymously();
        _user = result.user;
        debugPrint("Đã đăng nhập ẩn danh thành công: ${_user?.uid}");
      } else {
        debugPrint("Người dùng đã đăng nhập: ${_user?.uid} (${_user!.isAnonymous ? 'Ẩn danh' : 'Đã xác thực'})");
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint("Lỗi khi đăng nhập ẩn danh: $_error");
      
      // Thử đăng nhập lại sau 1 giây
      await Future.delayed(Duration(seconds: 1));
      try {
        UserCredential result = await _auth.signInAnonymously();
        _user = result.user;
        _error = null;
        debugPrint("Đăng nhập ẩn danh lần 2 thành công: ${_user?.uid}");
      } catch (retryError) {
        _error = retryError.toString();
        debugPrint("Lỗi đăng nhập ẩn danh lần 2: $_error");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Thực hiện đăng nhập ẩn danh theo yêu cầu
  Future<bool> signInAnonymously() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      UserCredential result = await _auth.signInAnonymously();
      _user = result.user;
      debugPrint("Đã đăng nhập ẩn danh thành công: ${_user?.uid}");
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint("Lỗi khi đăng nhập ẩn danh: $_error");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Đăng xuất cải tiến với xóa dữ liệu local
  Future<void> signOut({BuildContext? context}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Xóa dữ liệu local trước khi đăng xuất
      if (context != null && _userService != null) {
        debugPrint("🔄 Đang xóa dữ liệu local trước khi đăng xuất...");
        await _userService!.clearLocalUserData();
      } else {
        // Nếu không có context hoặc userService, chỉ xóa dữ liệu SharedPreferences
        debugPrint("🔄 Đang xóa dữ liệu SharedPreferences cơ bản...");
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_data');
      }
      
      await _auth.signOut();
      debugPrint("✅ Đã đăng xuất và xóa dữ liệu local thành công");
      
      // Đăng nhập ẩn danh lại sau khi đăng xuất
      await signInAnonymously();
    } catch (e) {
      _error = e.toString();
      debugPrint("❌ Lỗi khi đăng xuất: $_error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Đăng nhập với email và mật khẩu
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = result.user;
      debugPrint("✅ Đăng nhập thành công với email: $email");
      
      return true;
    } catch (e) {
      _error = _getReadableAuthError(e);
      debugPrint("❌ Lỗi đăng nhập với email: $_error");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Đăng ký với email và mật khẩu
  Future<bool> registerWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = result.user;
      debugPrint("✅ Đăng ký thành công với email: $email");
      
      return true;
    } catch (e) {
      _error = _getReadableAuthError(e);
      debugPrint("❌ Lỗi đăng ký với email: $_error");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Chuyển đổi lỗi Firebase Auth sang thông báo có thể đọc được
  String _getReadableAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'Không tìm thấy tài khoản với email này';
        case 'wrong-password':
          return 'Mật khẩu không chính xác';
        case 'email-already-in-use':
          return 'Email này đã được sử dụng bởi một tài khoản khác';
        case 'weak-password':
          return 'Mật khẩu không đủ mạnh';
        case 'invalid-email':
          return 'Email không hợp lệ';
        case 'user-disabled':
          return 'Tài khoản này đã bị vô hiệu hóa';
        default:
          return 'Lỗi: ${e.message}';
      }
    }
    return e.toString();
  }

  // Xóa thông báo lỗi
  void clearError() {
    _error = null;
    notifyListeners();
  }
} 