import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Đăng nhập bằng Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Khởi tạo GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn();
      
      // Đăng xuất Google trước để hiển thị dialog chọn tài khoản
      try {
        await googleSignIn.signOut();
      } catch (e) {
        debugPrint('⚠️ Lỗi khi đăng xuất Google trước khi đăng nhập: $e');
        // Bỏ qua lỗi này, tiếp tục quy trình
      }
      
      // Hiển thị giao diện chọn tài khoản Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      // Nếu người dùng hủy đăng nhập
      if (googleUser == null) {
        _error = 'Đã hủy đăng nhập bằng Google.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Lấy thông tin xác thực Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Tạo credential từ thông tin xác thực
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      try {
        // Đăng nhập Firebase với credential từ Google
        final UserCredential result = await _auth.signInWithCredential(credential);
        _user = result.user;
        
        debugPrint("✅ Đăng nhập Google thành công cho: ${_user?.email}");
        
        // Tạo dữ liệu người dùng cơ bản để tránh lỗi chuyển đổi kiểu
        if (_user != null) {
          try {
            // Lưu thông tin người dùng cơ bản vào Firestore
            final userData = {
              'user_id': _user!.uid,
              'email': _user!.email,
              'display_name': _user!.displayName,
              'photo_url': _user!.photoURL,
              'updated_at': DateTime.now().toIso8601String(),
              'last_login': DateTime.now().toIso8601String(),
            };
            
            // Cập nhật vào Firestore
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_user!.uid)
                .set(userData, SetOptions(merge: true));
            
            debugPrint("✅ Đã lưu thông tin người dùng Google vào Firestore");
          } catch (firestoreError) {
            debugPrint("⚠️ Lỗi khi lưu dữ liệu người dùng Google: $firestoreError");
            // Tiếp tục xử lý đăng nhập ngay cả khi cập nhật Firestore thất bại
          }
          
          // Đồng bộ dữ liệu từ Firebase sau khi đăng nhập thành công
          if (_userService != null) {
            try {
              await _userService!.syncUserDataFromFirebase();
              debugPrint("✅ Đã đồng bộ dữ liệu người dùng từ Firebase");
            } catch (syncError) {
              debugPrint("⚠️ Lỗi khi đồng bộ dữ liệu: $syncError");
              // Tiếp tục xử lý đăng nhập ngay cả khi đồng bộ thất bại
            }
          }
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } catch (authError) {
        // Xử lý lỗi chuyển đổi kiểu đặc biệt
        if (authError.toString().contains('PigeonUserDetails') || 
            authError.toString().contains('type cast') ||
            authError.toString().contains('subtype')) {
          debugPrint("⚠️ Gặp lỗi ép kiểu khi đăng nhập Google: $authError");
          
          // Kiểm tra xem người dùng đã đăng nhập hay chưa
          _user = _auth.currentUser;
          if (_user != null) {
            debugPrint("✅ Xác nhận người dùng đã đăng nhập thành công dù có lỗi ép kiểu");
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
        throw authError; // Ném lỗi nếu không xử lý được
      }
    } catch (e) {
      _error = _getReadableAuthError(e);
      debugPrint("❌ Lỗi đăng nhập với Google: $_error");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
} 