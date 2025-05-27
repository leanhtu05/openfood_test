import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/home_screen.dart';
import '../../providers/user_data_provider.dart';
import '../../services/api_service.dart';

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
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      bool success;
      
      if (isLogin) {
        // Login
        success = await authService.loginWithEmailAndPassword(email, password);
        
        // API authentication will happen in the background via AuthService._syncWithApi
        // We don't need to wait for it here
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
        success = await authService.registerWithEmailAndPassword(email, password);
        
        // API user creation will happen in the background via AuthService._syncWithApi
        // We don't need to wait for it here
      }
      
      setState(() {
        _isLoading = false;
      });
      
      if (success && mounted) {
        // Không cần đợi, điều hướng ngay lập tức
        if (widget.onAuthSuccess != null) {
          print('✅ Gọi onAuthSuccess callback');
          widget.onAuthSuccess!();
        } else {
          // Thêm debug print để theo dõi
          print('✅ Đăng nhập thành công, đang chuyển hướng đến màn hình chính...');
          
          // Chuyển hướng đến màn hình home
          _navigateToHomeScreen();
        }
        
        // Bỏ qua việc xác thực với backend, không cần thiết nữa
        print('ℹ️ Bỏ qua xác thực token với backend, sử dụng Firebase trực tiếp');
      } else if (mounted) {
        setState(() {
          _errorMessage = authService.errorMessage;
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
    
    // API sync will happen in the background via AuthService._syncWithApi
    // We don't need to wait for it here
    
    setState(() {
      _isLoading = false;
    });
    
    if (success && mounted) {
      // Không cần đợi, điều hướng ngay lập tức
      if (widget.onAuthSuccess != null) {
        print('✅ Gọi onAuthSuccess callback cho khách');
        widget.onAuthSuccess!();
      } else {
        // Thêm debug print để theo dõi
        print('✅ Đăng nhập khách thành công, đang chuyển hướng đến màn hình chính...');
        
        // Chuyển hướng đến màn hình home
        _navigateToHomeScreen();
      }
      
      // Bỏ qua việc xác thực với backend, không cần thiết nữa
      print('ℹ️ Bỏ qua xác thực token ẩn danh với backend, sử dụng Firebase trực tiếp');
    } else if (mounted) {
      setState(() {
        _errorMessage = authService.errorMessage;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage)),
      );
    }
  }

  // Xác thực với backend sử dụng Firebase ID token
  Future<bool> _authenticateWithBackend() async {
    // Không cần xác thực với backend nữa, luôn trả về true
    print('ℹ️ Bỏ qua xác thực token với backend, sử dụng Firebase trực tiếp');
        return true;
  }

  // Phương thức riêng để điều hướng đến màn hình chính
  void _navigateToHomeScreen() async {
    print('✅ Thực hiện chuyển hướng đến màn hình chính');
    
    // Điều hướng NGAY LẬP TỨC đến màn hình chính
    // KHÔNG chờ đợi đồng bộ dữ liệu
    try {
    // Kiểm tra mounted trước khi thực hiện điều hướng
    if (!mounted) {
      print('⚠️ Widget không còn mounted, không thể điều hướng');
      return;
    }
    
      print('✅ Đang thực hiện Navigator.pushReplacement');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
      
      // Sau khi điều hướng thành công, đồng bộ dữ liệu trong background
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          final authService = Provider.of<AuthService>(context, listen: false);
          final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
          
          // Đồng bộ dữ liệu từ Firebase vào UserDataProvider
          await authService.syncUserDataToProvider(userDataProvider);
          print('✅ Đã đồng bộ dữ liệu từ Firebase trong background');
        } catch (e) {
          print('⚠️ Lỗi khi đồng bộ dữ liệu trong background: $e');
          // Lỗi này không ảnh hưởng đến việc điều hướng vì đã thực hiện trước đó
        }
      });
    } catch (e) {
      print('❌ Lỗi khi điều hướng đến HomeScreen: $e');
      
      // Thử phương án thay thế
      try {
        print('🔄 Thử phương án thay thế với pushNamedAndRemoveUntil');
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } catch (fallbackError) {
        print('❌ Lỗi khi sử dụng pushNamedAndRemoveUntil: $fallbackError');
        
        // Hiển thị thông báo cho người dùng
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể chuyển đến màn hình chính. Vui lòng khởi động lại ứng dụng.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading || authService.isLoading
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