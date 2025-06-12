import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import './user_data_provider.dart' as udp;
import 'package:flutter/widgets.dart';

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

  // Đăng xuất và xóa dữ liệu cục bộ
  Future<void> signOut({BuildContext? context}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Xóa dữ liệu người dùng trong SharedPreferences
      if (context != null) {
        final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
        await userDataProvider.clearLocalUserData();
        debugPrint("Đã xóa dữ liệu cục bộ thành công");
      }
      
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

  // Gửi email đặt lại mật khẩu
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _auth.sendPasswordResetEmail(email: email);
      
      debugPrint("Đã gửi email đặt lại mật khẩu đến: $email");
      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Không tìm thấy tài khoản với email này.';
          break;
        case 'invalid-email':
          errorMessage = 'Email không hợp lệ.';
          break;
        default:
          errorMessage = 'Đã xảy ra lỗi: ${e.message}';
      }
      
      _error = errorMessage;
      debugPrint("Lỗi khi gửi email đặt lại mật khẩu: $_error");
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint("Lỗi không xác định khi gửi email đặt lại mật khẩu: $_error");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
    required Function(String) onVerificationFailed,
    Function()? onVerificationCompleted,
  }) async {
    try {
      _isLoading = true;
      _error = null;
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
      
      debugPrint('🔄 Đang gửi yêu cầu xác thực đến số: $phoneNumber');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android-only: Xác thực tự động hoàn tất
          debugPrint('✅ Xác thực số điện thoại tự động hoàn tất');
          
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
          debugPrint('❌ Xác thực số điện thoại thất bại: ${e.message}');
          
          _isLoading = false;
          
          switch (e.code) {
            case 'invalid-phone-number':
              _error = 'Số điện thoại không hợp lệ';
              break;
            case 'too-many-requests':
              _error = 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
              break;
            case 'quota-exceeded':
              _error = 'Vượt quá giới hạn xác thực. Vui lòng thử lại sau.';
              break;
            default:
              if (e.message?.contains('blocked all requests') == true) {
                _error = 'Quá nhiều yêu cầu từ thiết bị này. Vui lòng thử lại sau.';
              } else {
                _error = 'Lỗi xác thực số điện thoại: ${e.message}';
              }
          }
          
          notifyListeners();
          onVerificationFailed(_error ?? 'Lỗi không xác định');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ Mã xác thực đã được gửi đến $phoneNumber');
          
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          notifyListeners();
          
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⌛ Hết thời gian tự động lấy mã xác thực');
          _verificationId = verificationId;
          notifyListeners();
        },
        timeout: Duration(seconds: 120), // Tăng thời gian timeout
        forceResendingToken: _resendToken,
      );
      
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Lỗi khi gửi mã xác thực: ${e.toString()}';
      notifyListeners();
      debugPrint('❌ Lỗi khi xác thực số điện thoại: $_error');
      onVerificationFailed(_error ?? 'Lỗi không xác định');
      return false;
    }
  }
  
  // Xác nhận mã OTP
  Future<bool> confirmOTP(String otp) async {
    if (_verificationId.isEmpty) {
      _error = 'Phiên xác thực đã hết hạn. Vui lòng thử lại.';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
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
          _error = 'Mã xác thực không chính xác';
          break;
        case 'invalid-verification-id':
          _error = 'Phiên xác thực đã hết hạn. Vui lòng thử lại.';
          break;
        default:
          _error = 'Lỗi xác thực: ${e.message}';
      }
      
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Có lỗi xảy ra: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Đăng nhập với PhoneAuthCredential
  Future<bool> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      
      debugPrint('✅ Đăng nhập thành công với số điện thoại: ${_user?.phoneNumber}');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Lỗi khi đăng nhập: ${e.toString()}';
      notifyListeners();
      debugPrint('❌ Lỗi khi đăng nhập với số điện thoại: $_error');
      return false;
    }
  }
  
  // Xóa thông báo lỗi
  void clearError() {
    _error = null;
    notifyListeners();
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
  
  // Lấy danh sách các yêu cầu mật khẩu chưa đáp ứng
  List<String> getMissingPasswordRequirements(String password) {
    final requirements = checkPasswordStrength(password);
    List<String> missing = [];
    
    if (!requirements['length']!) {
      missing.add('Mật khẩu phải có ít nhất 8 ký tự');
    }
    
    if (!requirements['uppercase']!) {
      missing.add('Mật khẩu phải chứa ít nhất một chữ cái in hoa');
    }
    
    if (!requirements['lowercase']!) {
      missing.add('Mật khẩu phải chứa ít nhất một chữ cái thường');
    }
    
    if (!requirements['numeric']!) {
      missing.add('Mật khẩu phải chứa ít nhất một chữ số');
    }
    
    return missing;
  }
  
  // Kiểm tra mật khẩu có đáp ứng yêu cầu Firebase không
  bool isPasswordValid(String password) {
    final requirements = checkPasswordStrength(password);
    
    // Theo thiết lập Firebase: yêu cầu chữ hoa, chữ thường, và số
    return requirements['length']! && 
           requirements['uppercase']! && 
           requirements['lowercase']! && 
           requirements['numeric']!;
  }
  
  // === Phương thức liên kết tài khoản ===
  
  // Liên kết tài khoản hiện tại với credential mới
  Future<bool> linkWithCredential(AuthCredential credential) async {
    if (_user == null) {
      _error = 'Không có người dùng đăng nhập.';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final userCredential = await _user!.linkWithCredential(credential);
      _user = userCredential.user;
      
      debugPrint('✅ Liên kết tài khoản thành công với ${credential.providerId}');
      
      _isLoading = false;
      notifyListeners();
      
      return true;
    } on FirebaseAuthException catch (e) {
      _handleLinkError(e);
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Có lỗi xảy ra khi liên kết tài khoản: ${e.toString()}';
      notifyListeners();
      debugPrint('❌ Lỗi khi liên kết tài khoản: $_error');
      return false;
    }
  }
  
  // Xử lý lỗi khi liên kết tài khoản
  void _handleLinkError(FirebaseAuthException e) {
    _isLoading = false;
    
    switch (e.code) {
      case 'provider-already-linked':
        _error = 'Tài khoản đã được liên kết với phương thức này.';
        break;
      case 'email-already-in-use':
        _error = 'Email này đã được sử dụng bởi một tài khoản khác.';
        break;
      case 'credential-already-in-use':
        _error = 'Thông tin này đã được sử dụng bởi một tài khoản khác.';
        break;
      case 'requires-recent-login':
        _error = 'Vui lòng đăng nhập lại để thực hiện thao tác này.';
        break;
      default:
        _error = 'Có lỗi xảy ra: ${e.message}';
    }
    
    notifyListeners();
    debugPrint('❌ Lỗi khi liên kết tài khoản: $_error');
  }
  
  // Tạo mật khẩu cho tài khoản (với email hiện tại)
  Future<bool> createPassword(String password) async {
    if (_user == null) {
      _error = 'Không có người dùng đăng nhập.';
      notifyListeners();
      return false;
    }
    
    if (_user!.email == null || _user!.email!.isEmpty) {
      _error = 'Tài khoản không có email. Cần thêm email trước khi tạo mật khẩu.';
      notifyListeners();
      return false;
    }
    
    // Kiểm tra độ mạnh mật khẩu
    if (!isPasswordValid(password)) {
      List<String> missingRequirements = getMissingPasswordRequirements(password);
      _error = missingRequirements.join('\n');
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Tạo credential từ email và mật khẩu
      AuthCredential credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: password,
      );
      
      // Liên kết tài khoản với credential
      return await linkWithCredential(credential);
    } catch (e) {
      _isLoading = false;
      _error = 'Có lỗi xảy ra: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Thêm email cho tài khoản (nếu chưa có)
  Future<bool> addEmail(String email, String password) async {
    if (_user == null) {
      _error = 'Không có người dùng đăng nhập.';
      notifyListeners();
      return false;
    }
    
    if (_user!.email != null && _user!.email!.isNotEmpty) {
      _error = 'Tài khoản đã có email.';
      notifyListeners();
      return false;
    }
    
    // Kiểm tra độ mạnh mật khẩu
    if (!isPasswordValid(password)) {
      List<String> missingRequirements = getMissingPasswordRequirements(password);
      _error = missingRequirements.join('\n');
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Tạo credential từ email và mật khẩu
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      // Liên kết tài khoản với credential
      return await linkWithCredential(credential);
    } catch (e) {
      _isLoading = false;
      _error = 'Có lỗi xảy ra: ${e.toString()}';
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
      _error = 'Không có người dùng đăng nhập.';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
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
      
      debugPrint('🔄 Đang gửi yêu cầu xác thực đến số: $phoneNumber để liên kết tài khoản');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Tự động xác thực (Android only)
          debugPrint('✅ Xác thực số điện thoại tự động hoàn tất');
          _isLoading = false;
          notifyListeners();
          
          // Liên kết tài khoản với credential
          await linkWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Xác thực số điện thoại thất bại: ${e.message}');
          _isLoading = false;
          
          switch (e.code) {
            case 'invalid-phone-number':
              _error = 'Số điện thoại không hợp lệ';
              break;
            case 'too-many-requests':
              _error = 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
              break;
            case 'quota-exceeded':
              _error = 'Vượt quá giới hạn xác thực. Vui lòng thử lại sau.';
              break;
            default:
              if (e.message?.contains('blocked all requests') == true) {
                _error = 'Quá nhiều yêu cầu từ thiết bị này. Vui lòng thử lại sau.';
              } else {
                _error = 'Lỗi xác thực số điện thoại: ${e.message}';
              }
          }
          
          notifyListeners();
          onVerificationFailed(_error ?? 'Lỗi không xác định');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ Mã xác thực đã được gửi đến $phoneNumber');
          
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          notifyListeners();
          
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⌛ Hết thời gian tự động lấy mã xác thực');
          _verificationId = verificationId;
          notifyListeners();
        },
        timeout: Duration(seconds: 120),
        forceResendingToken: _resendToken,
      );
      
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Lỗi khi gửi mã xác thực: ${e.toString()}';
      notifyListeners();
      debugPrint('❌ Lỗi khi xác thực số điện thoại: $_error');
      onVerificationFailed(_error ?? 'Lỗi không xác định');
      return false;
    }
  }
  
  // Liên kết với số điện thoại (bước 2: xác nhận OTP)
  Future<bool> confirmPhoneNumberLinking(String otp) async {
    if (_verificationId.isEmpty) {
      _error = 'Phiên xác thực đã hết hạn. Vui lòng thử lại.';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Tạo credential từ mã xác thực
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      
      // Liên kết tài khoản với credential
      return await linkWithCredential(credential);
    } catch (e) {
      _isLoading = false;
      _error = 'Có lỗi xảy ra: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Kiểm tra tài khoản đã có liên kết với phương thức nào
  bool isLinkedWithEmail() {
    if (_user == null) return false;
    
    // Kiểm tra xem người dùng có liên kết với phương thức email/password không
    for (final providerData in _user!.providerData) {
      if (providerData.providerId == 'password') {
        return true;
      }
    }
    
    return false;
  }
  
  bool isLinkedWithPhone() {
    if (_user == null) return false;
    
    // Kiểm tra xem người dùng có liên kết với phương thức phone không
    for (final providerData in _user!.providerData) {
      if (providerData.providerId == 'phone') {
        return true;
      }
    }
    
    return false;
  }
  
  bool isLinkedWithGoogle() {
    if (_user == null) return false;
    
    // Kiểm tra xem người dùng có liên kết với phương thức Google không
    for (final providerData in _user!.providerData) {
      if (providerData.providerId == 'google.com') {
        return true;
      }
    }
    
    return false;
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
}