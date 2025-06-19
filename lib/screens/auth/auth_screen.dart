import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';

import '../../services/auth_service.dart';
import '../../providers/user_data_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../screens/home_screen.dart';
import '../onboarding/onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isLoginMode;
  final VoidCallback? onAuthSuccess;

  const AuthScreen({
    Key? key,
    this.isLoginMode = true,
    this.onAuthSuccess,
  }) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Trạng thái chung
  final _formKey = GlobalKey<FormState>();
  bool isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';

  // Trạng thái cho Form Email/Mật khẩu
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _showPasswordRequirements = false;

  // Trạng thái cho Form Điện thoại
  bool _isPhoneLogin = false;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showOtpField = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String _verificationId = '';
  String _completePhoneNumber = '';
  String _otp = '';
  bool _otpExpired = false;
  Timer? _resendTimer;
  int _resendTimerSeconds = 0;
  bool _canResend = true;

  @override
  void initState() {
    super.initState();
    isLogin = widget.isLoginMode;
    _passwordController.addListener(_checkPasswordRequirements);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.removeListener(_checkPasswordRequirements);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _toggleForm() {
    setState(() {
      isLogin = !isLogin;
      _errorMessage = '';
    });
  }

  void _checkPasswordRequirements() {
    if (!isLogin && _passwordController.text.isNotEmpty) {
      setState(() {
        _showPasswordRequirements = true;
      });
    } else if (_passwordController.text.isEmpty) {
      setState(() {
        _showPasswordRequirements = false;
      });
    }
  }

  void _showForgotPasswordDialog() {
    final _resetEmailController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigatorContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Đặt lại mật khẩu"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Vui lòng nhập email của bạn để nhận link đặt lại mật khẩu."),
              SizedBox(height: 16),
              TextField(
                controller: _resetEmailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: Color(0xFFE65100)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = _resetEmailController.text.trim();
                if (email.isNotEmpty) {
                  final bool emailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);

                  if (!emailValid) {
                    // Removed snackbar for better UX
                    return;
                  }

                  try {
                    final authService = Provider.of<AuthService>(navigatorContext, listen: false);
                    Navigator.of(dialogContext).pop();
                    // Removed snackbar for better UX
                    final success = await authService.sendPasswordResetEmail(email);

                    if (success) {
                      // Removed snackbar for better UX
                    } else {
                      // Removed snackbar for better UX
                    }
                  } catch (e) {
                    if (Navigator.canPop(dialogContext)) {
                      Navigator.of(dialogContext).pop();
                    }
                    // Removed snackbar for better UX
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE65100),
              ),
              child: Text("Gửi", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _togglePhoneLogin() {
    setState(() {
      _isPhoneLogin = !_isPhoneLogin;
      _errorMessage = '';
      _showOtpField = false;
    });
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimerSeconds = 180;
    });

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        setState(() {
          _resendTimerSeconds--;
        });
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _canResend = true;
          });
        }
      }
    });
  }

  Future<void> _verifyPhoneNumber() async {
    if (_phoneController.text.isEmpty) {
      // Removed snackbar for better UX
      return;
    }

    setState(() {
      _isLoading = true;
      _otpExpired = false;
    });

    _completePhoneNumber = _phoneController.text.trim();
    if (_completePhoneNumber.startsWith('0')) {
      _completePhoneNumber = "+84${_completePhoneNumber.substring(1)}";
    } else if (!_completePhoneNumber.startsWith('+')) {
      _completePhoneNumber = "+84$_completePhoneNumber";
    }

    final authService = Provider.of<AuthService>(context, listen: false);

    await authService.verifyPhoneNumber(
      _completePhoneNumber,
      onVerificationCompleted: () {
        setState(() {
          _isLoading = false;
        });
      },
      onVerificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
        });
        String errorMessage = authService.errorMessage;
        if (errorMessage.isEmpty) {
          errorMessage = 'Xác thực thất bại. Vui lòng thử lại.';
        }
        // Removed snackbar for better UX
      },
      onCodeSent: (String verificationId) {
        setState(() {
          _verificationId = verificationId;
          _showOtpField = true;
          _isLoading = false;
          _otpExpired = false;
        });
        _startResendTimer();
        // Removed snackbar for better UX
      },
      onCodeAutoRetrievalTimeout: (String verificationId) {
        if (mounted && FirebaseAuth.instance.currentUser?.phoneNumber == null) {
          setState(() {
            _otpExpired = true;
            _resendTimerSeconds = 0;
          });
          // Removed snackbar for better UX
        } else {
          print('✅ Firebase đã xác thực tự động hoặc đã đăng nhập thành công, bỏ qua timeout');
        }
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) {
      // Removed snackbar for better UX
      return;
    }

    if (FirebaseAuth.instance.currentUser?.phoneNumber != null) {
      print('✅ Đã đăng nhập tự động với số điện thoại, chuyển hướng đến màn hình chính');
      _onAuthSuccess();
      return;
    }

    if (_otpExpired) {
      // Removed snackbar for better UX
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.signInWithPhoneNumber(_verificationId, _otp);

      setState(() {
        _isVerifying = false;
      });

      if (result) {
        _onAuthSuccess();
      } else {
        String errorMessage = authService.errorMessage;
        if (errorMessage.isEmpty) {
          errorMessage = 'Xác thực thất bại. Vui lòng kiểm tra lại mã OTP.';
        }
        // Removed snackbar for better UX
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
      });
      // Removed snackbar for better UX
    }
  }

  Future<void> _resendOtp() async {
    if (_resendTimerSeconds > 0) {
      return;
    }

    setState(() {
      _isResending = true;
      _otpExpired = false;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      await authService.verifyPhoneNumber(
        _completePhoneNumber,
        onVerificationCompleted: () {
          setState(() {
            _isResending = false;
          });
        },
        onVerificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isResending = false;
          });
          // Removed snackbar for better UX
        },
        onCodeSent: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isResending = false;
            _otpExpired = false;
          });
          _startResendTimer();
          // Removed snackbar for better UX
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _otpExpired = true;
            _resendTimerSeconds = 0;
          });

          if (mounted) {
            // Removed snackbar for better UX
          }
        },
      );
    } catch (e) {
      setState(() {
        _isResending = false;
      });
      // Removed snackbar for better UX
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.signInWithGoogle();

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        _onAuthSuccess();
      } else {
        setState(() {
          _errorMessage = authService.errorMessage.isNotEmpty
              ? authService.errorMessage
              : 'Đăng nhập Google thất bại';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi đăng nhập Google: ${e.toString()}';
      });
    }
  }

  Future<void> _onAuthSuccess() async {
    if (!mounted) return;

    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);

    try {
      print('🔄 Bắt đầu đồng bộ/tải dữ liệu người dùng và kế hoạch bữa ăn...');
      await userDataProvider.syncOrFetchUserData(context);
      print('✅ Hoàn tất đồng bộ/tải dữ liệu người dùng.');

      await mealPlanProvider.initializeAfterLogin();
      print('✅ Hoàn tất tải dữ liệu kế hoạch bữa ăn.');

      if (mounted) {
        // Removed snackbar for better UX
        await _checkUserDataAndNavigate();
      }
    } catch (syncError) {
      print('❌ Lỗi nghiêm trọng khi đồng bộ/tải dữ liệu sau khi xác thực: $syncError');

      if (mounted) {
        // Removed snackbar for better UX
        await _checkUserDataAndNavigate();
      }
    }
  }

  Future<void> _checkUserDataAndNavigate() async {
    try {
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);

      // Kiểm tra trực tiếp xem user có tồn tại trong Firestore không
      bool userExistsInFirestore = await _checkUserExistsInFirestore();

      print('🔍 Kiểm tra user trong Firestore: ${userExistsInFirestore ? "Đã tồn tại" : "Chưa tồn tại"}');

      if (!userExistsInFirestore) {
        print('➡️ Chuyển hướng đến màn hình onboarding vì user chưa có trong Firestore');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      } else {
        print('➡️ Chuyển hướng đến màn hình chính vì user đã có trong Firestore');
        // Load dữ liệu sau khi đã xác nhận user tồn tại
        await userDataProvider.syncOrFetchUserData(context);
        if (mounted) {
          if (widget.onAuthSuccess != null) {
            widget.onAuthSuccess!();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => HomeScreen()),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi khi kiểm tra dữ liệu người dùng: $e');
      // Khi có lỗi, chuyển đến onboarding để đảm bảo an toàn
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  // Kiểm tra trực tiếp xem user có tồn tại trong Firestore không
  Future<bool> _checkUserExistsInFirestore() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        print('❌ Không có user đăng nhập');
        return false;
      }

      print('🔍 Kiểm tra user ${user.uid} trong Firestore...');

      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      bool exists = docSnapshot.exists;
      print('📊 User ${user.uid} ${exists ? "đã tồn tại" : "chưa tồn tại"} trong Firestore');

      return exists;
    } catch (e) {
      print('❌ Lỗi khi kiểm tra user trong Firestore: $e');
      return false;
    }
  }

  // Kiểm tra xem người dùng đã có dữ liệu trong Firestore chưa (backup method)
  bool _hasCompleteOnboardingData(UserDataProvider userDataProvider) {
    // Chỉ kiểm tra xem user đã được tạo trong Firestore chưa
    // Nếu có ít nhất tên hoặc tuổi thì coi như đã có dữ liệu
    bool hasUserData = userDataProvider.name.isNotEmpty || userDataProvider.age > 0;

    print('🔍 Kiểm tra dữ liệu user:');
    print('   - Tên: "${userDataProvider.name}"');
    print('   - Tuổi: ${userDataProvider.age}');
    print('   - Có dữ liệu: $hasUserData');

    return hasUserData;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        bool success;

        if (isLogin) {
          print('🔄 Đang đăng nhập với email: $email');
          success = await authService.loginWithEmailAndPassword(email, password);
          print('✅ Kết quả đăng nhập: $success');

          if (!success && mounted) {
            setState(() {
              _isLoading = false;
            });
            _showFacebookStyleErrorDialog(authService.errorMessage);
            return;
          }
        } else {
          if (password != _confirmPasswordController.text.trim()) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Mật khẩu xác nhận không khớp!';
            });
            // Removed snackbar for better UX
            return;
          }

          final missingRequirements = authService.getMissingPasswordRequirements(password);
          if (missingRequirements.isNotEmpty) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Mật khẩu không đủ mạnh';
            });
            _showPasswordRequirementsDialog(missingRequirements);
            return;
          }

          print('🔄 Đang đăng ký với email: $email');
          success = await authService.registerWithEmailAndPassword(email, password);
          print('✅ Kết quả đăng ký: $success');

          if (!success && mounted) {
            setState(() {
              _isLoading = false;
            });

            if (authService.errorMessage.contains('Email này đã được sử dụng')) {
              _showEmailAlreadyExistsDialog(email);
              return;
            }

            _showFacebookStyleErrorDialog(authService.errorMessage);
            return;
          }
        }

        setState(() {
          _isLoading = false;
        });

        if (success && mounted) {
          final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
          final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);

          try {
            print('🔄 Bắt đầu đồng bộ/tải dữ liệu người dùng và kế hoạch bữa ăn...');
            await userDataProvider.syncOrFetchUserData(context);
            print('✅ Hoàn tất đồng bộ/tải dữ liệu người dùng.');

            await mealPlanProvider.initializeAfterLogin();
            print('✅ Hoàn tất tải dữ liệu kế hoạch bữa ăn.');

            // Removed snackbar for better UX

            // Luôn kiểm tra dữ liệu người dùng sau khi đăng nhập/đăng ký thành công
            print('✅ Kiểm tra dữ liệu người dùng sau khi ${isLogin ? "đăng nhập" : "đăng ký"}');
            await _checkUserDataAndNavigate();
          } catch (syncError) {
            print('❌ Lỗi nghiêm trọng khi đồng bộ/tải dữ liệu sau khi xác thực: $syncError');
            String displayError = 'Đã xảy ra lỗi khi chuẩn bị dữ liệu của bạn. Vui lòng thử lại.';
            if (syncError is FirebaseException) {
              if (syncError.code == 'unavailable') {
                displayError = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng của bạn và thử lại.';
              } else if (syncError.message != null && syncError.message!.isNotEmpty) {
                displayError = 'Lỗi máy chủ: ${syncError.message}';
              }
            } else {
              displayError = 'Lỗi không mong muốn: ${syncError.toString()}';
            }

            if (mounted) {
              // Removed snackbar for better UX
              // Luôn kiểm tra dữ liệu người dùng ngay cả khi có lỗi đồng bộ
              await _checkUserDataAndNavigate();
            }
          }
        } else if (mounted) {
          setState(() {
            _errorMessage = authService.errorMessage;
          });
          // Removed snackbar for better UX
        }
      } catch (e) {
        print('❌ Lỗi khi đăng nhập: $e');

        if (e.toString().contains('PigeonUserDetails')) {
          print('⚠️ Phát hiện lỗi PigeonUserDetails, thử chuyển hướng trực tiếp');
          if (FirebaseAuth.instance.currentUser != null) {
            setState(() {
              _isLoading = false;
              _errorMessage = '';
            });
            // Removed snackbar for better UX
            Future.delayed(Duration(seconds: 1), () async {
              if (mounted) {
                // Luôn kiểm tra dữ liệu người dùng
                await _checkUserDataAndNavigate();
              }
            });
            return;
          }
        }

        setState(() {
          _isLoading = false;
          _errorMessage = 'Có lỗi xảy ra: ${e.toString()}';
        });
        // Removed snackbar for better UX
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.signInAnonymously();

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      await _checkUserDataAndNavigate();
    } else if (mounted) {
      setState(() {
        _errorMessage = authService.errorMessage;
      });
      // Removed snackbar for better UX
    }
  }



  void _showFacebookStyleErrorDialog(String errorMessage) {
    String title = 'Đăng nhập không thành công';
    String message = errorMessage;
    String buttonText = 'Đã hiểu';
    IconData iconData = Icons.error_outline;
    Color iconColor = Colors.red;
    bool showSignInWithGoogle = false;
    bool showSignInWithEmail = false;

    if (errorMessage.contains('Email này đã được sử dụng') ||
        errorMessage.contains('đã đăng ký bằng Google') ||
        errorMessage.contains('phương thức đăng nhập khác')) {

      title = 'Email đã được sử dụng';
      iconData = Icons.account_circle;
      iconColor = Colors.orange;

      if (errorMessage.contains('đăng ký bằng Google') ||
          errorMessage.contains('đăng nhập bằng Google')) {
        showSignInWithGoogle = true;
      }

      if (errorMessage.contains('email và mật khẩu')) {
        showSignInWithEmail = true;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 30,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 15),

            if (showSignInWithGoogle)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.g_translate, size: 24, color: Colors.blue),
                    label: Text('Đăng nhập bằng Google'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _signInWithGoogle();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFE65100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              buttonText,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showPasswordRequirementsDialog(List<String> missingRequirements) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.security,
                color: Colors.orange,
                size: 30,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                'Mật khẩu chưa đủ mạnh',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mật khẩu của bạn chưa đáp ứng các yêu cầu sau:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            ...missingRequirements.map((requirement) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      requirement,
                      style: TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFE65100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Đã hiểu',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailAlreadyExistsDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_circle,
                color: Colors.blue,
                size: 30,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                'Email đã được sử dụng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email $email đã được sử dụng cho một tài khoản khác. Bạn có thể:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 15),

            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.email_outlined, color: Color(0xFFE65100)),
                  label: Text('Đăng nhập với Email'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      isLogin = true;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.g_translate, size: 24, color: Colors.blue),
                  label: Text('Đăng nhập bằng Google'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _signInWithGoogle();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Hủy',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showAlternativeLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 30,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                'Xác thực tạm thời bị chặn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firebase đã tạm thời chặn xác thực số điện thoại từ thiết bị của bạn.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Vui lòng thử phương thức đăng nhập khác hoặc thử lại sau 24 giờ.',
              style: TextStyle(fontSize: 16),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.email_outlined, color: Color(0xFFE65100)),
                  label: Text('Đăng nhập với Email'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isPhoneLogin = false;
                      isLogin = true;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.g_translate, size: 24, color: Colors.blue),
                  label: Text(
                    'Đăng nhập bằng Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Đóng',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SizedBox(height: 40),

              // Logo và tiêu đề
              Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isLogin ? 'Đăng nhập' : 'Đăng ký',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin ? 'Chào mừng bạn quay trở lại!' : 'Tạo tài khoản mới',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Form đăng nhập/đăng ký
              if (_isPhoneLogin)
                _buildPhoneLoginForm()
              else
                _buildEmailLoginForm(),

              const SizedBox(height: 24),

              // Divider với text "hoặc"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'hoặc',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 24),

              // Social login buttons
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          _buildSocialIconButton(
                            icon: Icons.phone,
                            color: Colors.green,
                            onPressed: _togglePhoneLogin,
                            tooltip: 'Đăng nhập bằng số điện thoại',
                            isActive: _isPhoneLogin,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Điện thoại',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isPhoneLogin ? Colors.green : Colors.grey[600],
                              fontWeight: _isPhoneLogin ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          _buildSocialIconButton(
                            icon: Icons.email,
                            color: const Color(0xFFE65100),
                            onPressed: _isPhoneLogin ? _togglePhoneLogin : null,
                            tooltip: 'Đăng nhập bằng email',
                            isActive: !_isPhoneLogin,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isPhoneLogin ? Colors.grey[600] : const Color(0xFFE65100),
                              fontWeight: _isPhoneLogin ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          _buildSocialIconButton(
                            icon: Icons.g_translate, // Better Google icon
                            color: const Color(0xFF4285F4), // Google blue color
                            onPressed: (_isLoading || _isVerifying || _isResending) ? null : _signInWithGoogle,
                            tooltip: 'Đăng nhập bằng Google',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Google',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Nút chuyển đổi đăng nhập/đăng ký
              if (!_isPhoneLogin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin ? 'Chưa có tài khoản?' : 'Đã có tài khoản?',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: _toggleForm,
                      child: Text(
                        isLogin ? 'Đăng ký' : 'Đăng nhập',
                        style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading || _isVerifying || _isResending)
            Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE65100)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getLoadingMessage(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLoadingMessage() {
    if (_isVerifying) {
      return 'Đang xác thực mã OTP...';
    } else if (_isResending) {
      return 'Đang gửi lại mã OTP...';
    } else if (_isPhoneLogin) {
      return 'Đang gửi mã OTP...';
    } else {
      return isLogin ? 'Đang đăng nhập...' : 'Đang đăng ký...';
    }
  }

  Widget _buildEmailLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE65100)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE65100), width: 2),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Email không hợp lệ';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password field
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE65100)),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFFE65100),
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE65100), width: 2),
              ),
            ),
            obscureText: !_isPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mật khẩu';
              }
              if (!isLogin && value.length < 6) {
                return 'Mật khẩu phải có ít nhất 6 ký tự';
              }
              return null;
            },
          ),

          // Password requirements (for registration)
          if (!isLogin && _showPasswordRequirements)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildPasswordRequirementsWidget(),
            ),

          const SizedBox(height: 16),

          // Confirm password field (for registration)
          if (!isLogin)
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Xác nhận mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE65100)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFFE65100),
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE65100), width: 2),
                ),
              ),
              obscureText: !_isConfirmPasswordVisible,
              validator: (value) {
                if (!isLogin && (value == null || value.isEmpty)) {
                  return 'Vui lòng xác nhận mật khẩu';
                }
                if (!isLogin && value != _passwordController.text) {
                  return 'Mật khẩu xác nhận không khớp';
                }
                return null;
              },
            ),

          if (!isLogin) const SizedBox(height: 16),

          // Forgot password (for login)
          if (isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(color: Color(0xFFE65100)),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: (_isLoading || _isVerifying || _isResending) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: (_isLoading || _isVerifying || _isResending)
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                isLogin ? 'Đăng nhập' : 'Đăng ký',
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Error message
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // --- CÁC WIDGET PHỤ ---

  Widget _buildSocialIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isActive = false,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color.withOpacity(0.1) : Colors.white,
        border: Border.all(
          color: isActive ? color : Colors.grey[300]!,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            blurRadius: isActive ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onPressed,
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: Tooltip(
            message: tooltip,
            child: Center(
              child: (_isLoading || _isVerifying || _isResending) && tooltip.contains('Google')
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 28,
                      color: onPressed != null ? color : Colors.grey[400],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirementsWidget() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final password = _passwordController.text;
    final requirements = authService.checkPasswordStrength(password);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yêu cầu mật khẩu:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          _buildRequirementItem(
            requirements['length']!,
            'Ít nhất 8 ký tự',
          ),
          _buildRequirementItem(
            requirements['uppercase']!,
            'Ít nhất một chữ cái in hoa (A-Z)',
          ),
          _buildRequirementItem(
            requirements['lowercase']!,
            'Ít nhất một chữ cái thường (a-z)',
          ),
          _buildRequirementItem(
            requirements['numeric']!,
            'Ít nhất một chữ số (0-9)',
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(bool isMet, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLoginForm() {
    return Column(
      children: [
        IntlPhoneField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Số điện thoại',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          initialCountryCode: 'VN',
        ),
        if (_showOtpField) ...[
          const SizedBox(height: 20),
          Text('Nhập mã xác thực đã được gửi đến $_completePhoneNumber'),
          const SizedBox(height: 15),
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            onChanged: (value) {
              setState(() {
                _otp = value;
              });
            },
            onCompleted: (v) => _verifyOtp(),
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(8),
              activeColor: Colors.orange,
              inactiveColor: Colors.grey.shade300,
              selectedColor: Colors.orange.shade700,
              activeFillColor: Colors.white,
              inactiveFillColor: Colors.grey.shade50,
              selectedFillColor: Colors.white,
            ),
            enableActiveFill: true,
            keyboardType: TextInputType.number,
          ),
          if (_otpExpired)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Mã xác thực đã hết hạn. Vui lòng gửi lại mã mới.',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: _resendTimerSeconds > 0 ? null : _resendOtp,
            child: Text(
              _resendTimerSeconds > 0
                  ? 'Gửi lại mã sau $_resendTimerSeconds giây'
                  : 'Gửi lại mã xác thực',
              style: TextStyle(
                color: _resendTimerSeconds > 0 ? Colors.grey : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: (_isLoading || _isVerifying || _isResending) ? null : (_showOtpField ? _verifyOtp : _verifyPhoneNumber),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: (_isLoading || _isVerifying || _isResending)
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
              _showOtpField ? 'Xác nhận' : 'Gửi mã OTP',
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }


}