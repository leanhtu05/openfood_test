import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/home_screen.dart';
import '../../providers/user_data_provider.dart';
import '../../providers/meal_plan_provider.dart';

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
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Controllers for form fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    isLogin = widget.isLoginMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleForm() {
    setState(() {
      isLogin = !isLogin;
      _errorMessage = '';
    });
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
          // Login
          print('🔄 Đang đăng nhập với email: $email');
          success = await authService.loginWithEmailAndPassword(email, password);
          print('✅ Kết quả đăng nhập: $success');
        } else {
          // Register
          if (password != _confirmPasswordController.text.trim()) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Mật khẩu xác nhận không khớp!';
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mật khẩu xác nhận không khớp!')),
            );
            return;
          }
          print('🔄 Đang đăng ký với email: $email');
          success = await authService.registerWithEmailAndPassword(email, password);
          print('✅ Kết quả đăng ký: $success');
        }
        
        setState(() {
          _isLoading = false;
        });
        
        if (success && mounted) {
          final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
          final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);
          // final dailyDataNotifier = Provider.of<DailyDataNotifier>(context, listen: false); // Uncomment if needed

          try {
            print('🔄 Bắt đầu đồng bộ/tải dữ liệu người dùng và kế hoạch bữa ăn...');
            await userDataProvider.syncOrFetchUserData(context);
            print('✅ Hoàn tất đồng bộ/tải dữ liệu người dùng.');
            
            await mealPlanProvider.initializeAfterLogin();
            print('✅ Hoàn tất tải dữ liệu kế hoạch bữa ăn.');

            // if (dailyDataNotifier != null) { // Uncomment if needed
            //   await dailyDataNotifier.loadDailyData(DateTime.now());
            //   print('✅ Hoàn tất tải dữ liệu hàng ngày.');
            // }

            // Hiển thị thông báo thành công
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isLogin ? 'Đăng nhập thành công!' : 'Đăng ký thành công!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            
            // Chuyển hướng ngay lập tức
            if (widget.onAuthSuccess != null) {
              print('✅ Gọi onAuthSuccess callback');
              widget.onAuthSuccess!();
            } else {
              print('✅ Chuyển hướng đến màn hình chính');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            }
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(displayError),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 4),
                ),
              );
              
              if (widget.onAuthSuccess != null) {
                widget.onAuthSuccess!(); // Consider passing an error flag or specific error state
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                );
              }
            }
          }
        } else if (mounted) {
          setState(() {
            _errorMessage = authService.errorMessage;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage)),
          );
        }
      } catch (e) {
        print('❌ Lỗi khi đăng nhập: $e');
        
        // Xử lý đặc biệt cho lỗi PigeonUserDetails
        if (e.toString().contains('PigeonUserDetails')) {
          print('⚠️ Phát hiện lỗi PigeonUserDetails, thử chuyển hướng trực tiếp');
          
          // Kiểm tra xem người dùng đã đăng nhập hay chưa
          if (FirebaseAuth.instance.currentUser != null) {
            setState(() {
              _isLoading = false;
              _errorMessage = '';
            });
            
            // Hiển thị thông báo ngắn
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Có lỗi nhẹ xảy ra, nhưng đăng nhập vẫn thành công')),
            );
            
            // Chuyển hướng đến màn hình chính
            Future.delayed(Duration(seconds: 1), () {
              if (mounted) {
                if (widget.onAuthSuccess != null) {
                  widget.onAuthSuccess!();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  );
                }
              }
            });
            return;
          }
        }
        
        // Xử lý lỗi thông thường
        setState(() {
          _isLoading = false;
          _errorMessage = 'Có lỗi xảy ra: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage)),
        );
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
      // Không cần đợi, điều hướng ngay lập tức
      if (widget.onAuthSuccess != null) {
        print('✅ Gọi onAuthSuccess callback cho khách');
        widget.onAuthSuccess!();
      } else {
        print('✅ Đăng nhập khách thành công, đang chuyển hướng đến màn hình chính...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } else if (mounted) {
      setState(() {
        _errorMessage = authService.errorMessage;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: Color(0xFFFFF8F0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Color(0xFFF5E6D8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restaurant,
                    size: 70,
                    color: Color(0xFFE65100),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  isLogin ? 'Chào mừng trở lại!' : 'Tạo tài khoản mới',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  isLogin
                    ? 'Đăng nhập để truy cập tất cả tính năng'
                    : 'Đăng ký để lưu dữ liệu và nhận các quyền lợi đặc biệt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'example@email.com',
                          prefixIcon: Icon(Icons.email_outlined, color: Color(0xFFE65100)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFFE65100), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      
                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFE65100)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFFE65100), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          if (value.length < 6) {
                            return 'Mật khẩu phải có ít nhất 6 ký tự';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      
                      // Confirm Password field (only for register mode)
                      if (!isLogin)
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu',
                            prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFE65100)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFFE65100), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng xác nhận mật khẩu';
                            }
                            if (value != _passwordController.text) {
                              return 'Mật khẩu không trùng khớp';
                            }
                            return null;
                          },
                        ),
                      if (!isLogin) SizedBox(height: 20),
                      
                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading || authService.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFE65100),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading && !authService.isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isLogin ? 'Đăng nhập' : 'Đăng ký',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Toggle form button
                TextButton(
                  onPressed: _toggleForm,
                  child: Text(
                    isLogin
                        ? 'Chưa có tài khoản? Đăng ký ngay'
                        : 'Đã có tài khoản? Đăng nhập',
                    style: TextStyle(
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'hoặc',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(thickness: 1)),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Continue as guest button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: _isLoading || authService.isLoading ? null : _continueAsGuest,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFFE65100)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading && !authService.isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFFE65100),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Tiếp tục với tư cách khách',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFE65100),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthProfileUpdateFlow extends StatelessWidget {
  final String initialStep;
  
  const AuthProfileUpdateFlow({Key? key, required this.initialStep}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This is just a placeholder - you would implement the actual update flow
    return Scaffold(
      appBar: AppBar(
        title: Text('Cập nhật thông tin'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Text('Cập nhật $initialStep'),
      ),
    );
  }
}

