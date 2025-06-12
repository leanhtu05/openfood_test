import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';

class AccountLinkingScreen extends StatefulWidget {
  final AuthService authService;

  const AccountLinkingScreen({Key? key, required this.authService}) : super(key: key);

  @override
  _AccountLinkingScreenState createState() => _AccountLinkingScreenState();
}

class _AccountLinkingScreenState extends State<AccountLinkingScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Liên kết tài khoản'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin người dùng
                  _buildUserInfoCard(),
                  
                  SizedBox(height: 20),
                  
                  // Giới thiệu
                  Text(
                    'Phương thức đăng nhập',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Thêm và quản lý các phương thức đăng nhập để bảo vệ tài khoản và đăng nhập dễ dàng hơn.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Danh sách phương thức đăng nhập
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        // Email
                        _buildLinkingOption(
                          icon: Icons.email,
                          title: 'Email & Mật khẩu',
                          subtitle: widget.authService.isLinkedWithEmail() 
                              ? widget.authService.user!.email ?? '' 
                              : 'Thêm mật khẩu để đăng nhập bằng email',
                          isLinked: widget.authService.isLinkedWithEmail(),
                          onTap: () {
                            if (!widget.authService.isLinkedWithEmail()) {
                              _showEmailPasswordLinkingDialog();
                            }
                          },
                        ),
                        
                        Divider(height: 1, indent: 72),
                        
                        // Số điện thoại
                        _buildLinkingOption(
                          icon: Icons.phone_android,
                          title: 'Số điện thoại',
                          subtitle: widget.authService.isLinkedWithPhone() 
                              ? widget.authService.user?.phoneNumber ?? 'Đã liên kết' 
                              : 'Thêm số điện thoại để đăng nhập',
                          isLinked: widget.authService.isLinkedWithPhone(),
                          onTap: () {
                            if (!widget.authService.isLinkedWithPhone()) {
                              _showPhoneLinkingDialog();
                            }
                          },
                        ),
                        
                        Divider(height: 1, indent: 72),
                        
                        // Google
                        _buildLinkingOption(
                          icon: Icons.g_translate,
                          title: 'Google',
                          subtitle: widget.authService.isLinkedWithGoogle() 
                              ? 'Đã liên kết với tài khoản Google' 
                              : 'Đăng nhập nhanh với tài khoản Google',
                          isLinked: widget.authService.isLinkedWithGoogle(),
                          onTap: () {
                            if (!widget.authService.isLinkedWithGoogle()) {
                              _linkWithGoogle();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Lưu ý bảo mật
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Lưu ý bảo mật',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Liên kết nhiều phương thức đăng nhập giúp bảo vệ tài khoản của bạn tốt hơn và giúp khôi phục tài khoản khi cần thiết.',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // Card hiển thị thông tin người dùng
  Widget _buildUserInfoCard() {
    final user = widget.authService.user;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null 
                  ? Text(
                      user?.email?.isNotEmpty == true
                          ? user!.email![0].toUpperCase()
                          : (user?.displayName?.isNotEmpty == true ? user!.displayName![0].toUpperCase() : "A"),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                    )
                  : null,
            ),
            SizedBox(width: 16),
            
            // Thông tin người dùng
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? user?.email?.split('@').first ?? 'Người dùng',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    user?.email ?? (user?.phoneNumber ?? 'Chưa có thông tin liên hệ'),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị tùy chọn liên kết
  Widget _buildLinkingOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLinked,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isLinked ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: isLinked ? Colors.green.shade600 : Colors.blue.shade600,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isLinked)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Đã liên kết',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              Icon(
                Icons.add_circle_outline,
                color: Colors.blue.shade600,
              ),
          ],
        ),
      ),
    );
  }

  // Hiển thị dialog liên kết email & mật khẩu
  void _showEmailPasswordLinkingDialog() {
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    bool _passwordsMatch = true;
    bool _isPasswordValid = true;
    List<String> _passwordRequirements = [];
    
    // Kiểm tra xem đã có email chưa
    bool hasEmail = widget.authService.user?.email != null && widget.authService.user!.email!.isNotEmpty;
    if (hasEmail) {
      _emailController.text = widget.authService.user!.email!;
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: Text(
                hasEmail ? 'Tạo mật khẩu' : 'Thêm email & mật khẩu',
                style: TextStyle(fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasEmail) ...[
                      Text(
                        'Thêm email cho tài khoản để dễ dàng đăng nhập và khôi phục mật khẩu.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 16),
                    ] else ...[
                      Text(
                        'Tạo mật khẩu cho email ${widget.authService.user!.email} để đăng nhập bằng email và mật khẩu.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                      SizedBox(height: 16),
                    ],
                    
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.lock),
                        errorText: !_isPasswordValid ? 'Mật khẩu không đủ mạnh' : null,
                      ),
                      obscureText: true,
                      onChanged: (value) {
                        final requirements = widget.authService.getMissingPasswordRequirements(value);
                        setDialogState(() {
                          _isPasswordValid = requirements.isEmpty;
                          _passwordRequirements = requirements;
                          _passwordsMatch = _passwordController.text == _confirmPasswordController.text;
                        });
                      },
                    ),
                    
                    if (!_isPasswordValid && _passwordRequirements.isNotEmpty) ...[
                      SizedBox(height: 8),
                      ...List.generate(
                        _passwordRequirements.length,
                        (index) => Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, 
                                size: 14, 
                                color: Colors.orange,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _passwordRequirements[index],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.lock_outline),
                        errorText: !_passwordsMatch ? 'Mật khẩu không khớp' : null,
                      ),
                      obscureText: true,
                      onChanged: (value) {
                        setDialogState(() {
                          _passwordsMatch = _passwordController.text == value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Hủy'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: Text('Liên kết'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (_passwordController.text.isEmpty ||
                        (!hasEmail && _emailController.text.isEmpty) ||
                        !_passwordsMatch ||
                        !_isPasswordValid) {
                      return;
                    }
                    
                    final password = _passwordController.text;
                    final email = _emailController.text;
                    Navigator.of(dialogContext).pop();
                    
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    
                    bool success = false;
                    
                    try {
                      if (hasEmail) {
                        // Tạo mật khẩu cho email hiện tại
                        success = await widget.authService.createPassword(password);
                      } else {
                        // Thêm email và mật khẩu
                        success = await widget.authService.addEmail(
                          email,
                          password,
                        );
                      }
                      
                      if (!success) {
                        _errorMessage = widget.authService.errorMessage;
                      }
                    } catch (e) {
                      _errorMessage = e.toString();
                      success = false;
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                    
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Liên kết tài khoản thành công'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Hiển thị dialog liên kết số điện thoại
  void _showPhoneLinkingDialog() {
    final _phoneController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, 
            right: 20, 
            top: 20, 
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Liên kết số điện thoại',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Nhập số điện thoại để liên kết với tài khoản của bạn',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại (có mã quốc gia, ví dụ: +84...)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.phone),
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Gửi mã xác thực',
                  style: TextStyle(fontSize: 16),
                ),
                onPressed: () {
                  if (_phoneController.text.isEmpty) return;
                  
                  _verifyPhoneNumber(_phoneController.text, modalContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Liên kết với Google
  void _linkWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Khởi tạo GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn();
      
      // Đăng xuất trước để hiển thị dialog chọn tài khoản
      try {
        await googleSignIn.signOut();
      } catch (e) {
        debugPrint('Lỗi khi đăng xuất Google trước khi liên kết: $e');
      }
      
      // Hiển thị giao diện chọn tài khoản Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Lấy thông tin xác thực
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Tạo credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Liên kết tài khoản
      final success = await widget.authService.linkWithCredential(credential);
      
      // Cập nhật UI
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = widget.authService.errorMessage;
        }
      });
      
      if (success) {
        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Liên kết tài khoản Google thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Cập nhật lại UI để hiển thị tình trạng liên kết mới
        setState(() {});
        
        // Sau 3 giây, tự động làm mới màn hình để cập nhật UI
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            setState(() {});
          }
        });
      } else {
        // Hiển thị lỗi chi tiết hơn
        String errorMessage = widget.authService.errorMessage;
        if (errorMessage.contains('credential-already-in-use')) {
          errorMessage = 'Tài khoản Google này đã được liên kết với một tài khoản khác.';
        } else if (errorMessage.contains('provider-already-linked')) {
          errorMessage = 'Tài khoản của bạn đã được liên kết với Google.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi liên kết với Google: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Xử lý xác thực số điện thoại
  void _verifyPhoneNumber(String phoneNumber, BuildContext modalContext) async {
    // Đóng bottom sheet hiện tại
    Navigator.pop(modalContext);
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    // Chuẩn hóa số điện thoại
    if (phoneNumber.startsWith('0')) {
      phoneNumber = "+84${phoneNumber.substring(1)}";
    } else if (!phoneNumber.startsWith('+')) {
      phoneNumber = "+84$phoneNumber";
    }
    
    debugPrint('🔄 Đang gửi yêu cầu xác thực đến số: $phoneNumber');
    
    try {
      final success = await widget.authService.linkWithPhoneNumber(
        phoneNumber,
        onCodeSent: (verificationId) {
          setState(() {
            _isLoading = false;
          });
          
          // Hiển thị thông báo mã OTP đã được gửi
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mã xác thực đã được gửi đến $phoneNumber'),
              backgroundColor: Colors.blue,
            ),
          );
          
          // Hiển thị dialog nhập OTP
          _showOTPVerificationDialog(phoneNumber);
        },
        onVerificationFailed: (errorMessage) {
          setState(() {
            _isLoading = false;
          });
          
          // Hiển thị thông báo lỗi thân thiện hơn
          String errorMsg = errorMessage;
          if (errorMessage.contains('blocked all requests')) {
            errorMsg = 'Quá nhiều yêu cầu từ thiết bị này. Vui lòng thử lại sau.';
          } else if (errorMessage.contains('invalid-phone-number')) {
            errorMsg = 'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.';
          }
          
          _errorMessage = errorMsg;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        },
      );
      
      if (!success) {
        setState(() {
          _isLoading = false;
          _errorMessage = widget.authService.errorMessage;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'Không thể gửi mã xác thực'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Hiển thị dialog nhập OTP
  void _showOTPVerificationDialog(String phoneNumber) {
    final _otpController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, 
            right: 20, 
            top: 20, 
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Xác thực OTP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Nhập mã OTP đã được gửi đến $phoneNumber',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _otpController,
                decoration: InputDecoration(
                  labelText: 'Mã OTP',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.lock_outline),
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Xác nhận',
                  style: TextStyle(fontSize: 16),
                ),
                onPressed: () {
                  if (_otpController.text.isEmpty) return;
                  
                  _confirmOTP(_otpController.text, modalContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Xử lý xác nhận OTP
  void _confirmOTP(String otp, BuildContext modalContext) async {
    // Đóng bottom sheet hiện tại
    Navigator.pop(modalContext);
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final success = await widget.authService.confirmPhoneNumberLinking(otp);
      
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = widget.authService.errorMessage;
        }
      });
      
      if (success) {
        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Liên kết số điện thoại thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Cập nhật lại UI để hiển thị tình trạng liên kết mới
        setState(() {});
        
        // Sau 1 giây, tự động làm mới màn hình để cập nhật UI
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            setState(() {});
          }
        });
      } else {
        // Hiển thị thông báo lỗi chi tiết hơn
        String errorMsg = widget.authService.errorMessage;
        if (errorMsg.contains('invalid-verification-code')) {
          errorMsg = 'Mã xác thực không chính xác. Vui lòng kiểm tra lại.';
        } else if (errorMsg.contains('credential-already-in-use')) {
          errorMsg = 'Số điện thoại này đã được liên kết với một tài khoản khác.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xác nhận OTP: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}
