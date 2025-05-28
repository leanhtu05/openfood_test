import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = false;
  String? _error;

  UserAuthProvider() {
    // Chỉ lắng nghe sự thay đổi trạng thái đăng nhập
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      debugPrint("Trạng thái đăng nhập thay đổi: ${user?.uid ?? 'Chưa đăng nhập'}");
      notifyListeners();
    });

    // Lấy user hiện tại mà KHÔNG tự động đăng nhập ẩn danh
    _user = _auth.currentUser;
  }

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Kiểm tra đăng nhập và thực hiện đăng nhập ẩn danh nếu chưa đăng nhập
  // Xóa hoặc comment phương thức _checkAndSignInAnonymously
  // Future<void> _checkAndSignInAnonymously() async {
  //   // Bỏ phương thức này
  // }

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

  // Đăng xuất
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signOut();
      debugPrint("Đã đăng xuất thành công");
      
      // Đăng nhập ẩn danh lại sau khi đăng xuất
      await signInAnonymously();
    } catch (e) {
      _error = e.toString();
      debugPrint("Lỗi khi đăng xuất: $_error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Xóa thông báo lỗi
  void clearError() {
    _error = null;
    notifyListeners();
  }
}