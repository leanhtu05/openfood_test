import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class NameInputPage extends StatefulWidget {
  final bool updateMode;
  
  const NameInputPage({
    Key? key,
    this.updateMode = false
  }) : super(key: key);

  @override
  State<NameInputPage> createState() => _NameInputPageState();
}

class _NameInputPageState extends State<NameInputPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isNameValid = false;
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.name.isNotEmpty) {
        setState(() {
          _nameController.text = userData.name;
          _validateName(_nameController.text);
        });
      }
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Kiểm tra tính hợp lệ của tên
  void _validateName(String value) {
    setState(() {
      _isNameValid = value.trim().length >= 2;
    });
  }

  // Lưu dữ liệu vào provider
  void _saveName(String name) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.setName(name);
    
    // If in update mode, show success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật tên thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng MaterialOnboardingPage wrapper nếu ở chế độ updateMode
    if (widget.updateMode) {
      return MaterialOnboardingPage(
        title: 'Cập nhật thông tin cá nhân',
        child: _buildContent(context),
      );
    }
    
    // Trong luồng onboarding thông thường, trả về Scaffold
    return Scaffold(
      body: SafeArea(
        child: _buildContent(context),
      ),
    );
  }
  
  Widget _buildContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: OnboardingStyles.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo và Biểu tượng
                  if (!widget.updateMode)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'DietAI',
                            style: OnboardingStyles.appTitleStyle,
                          ),
                          const SizedBox(height: 24),
                          
                          // Biểu tượng người dùng
                          SizedBox(
                            width: OnboardingStyles.iconSize,
                            height: OnboardingStyles.iconSize,
                            child: Icon(
                              Icons.person,
                              size: 100,
                              color: OnboardingStyles.accentColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode 
                          ? 'Cập nhật tên của bạn' 
                          : 'Tên của bạn là gì?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Mô tả
                  Center(
                    child: Text(
                      'Chúng tôi sẽ sử dụng tên này để gọi bạn trong ứng dụng',
                      style: OnboardingStyles.captionStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Trường nhập tên
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isNameValid 
                            ? OnboardingStyles.primaryColor 
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tên của bạn',
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: OnboardingStyles.primaryColor,
                        ),
                        suffixIcon: _nameController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _nameController.clear();
                                    _validateName('');
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        _validateName(value);
                        if (_isNameValid) {
                          _saveName(value.trim());
                        }
                      },
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        fontSize: 18,
                        color: OnboardingStyles.textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Thông báo lỗi (nếu có)
                  if (_nameController.text.isNotEmpty && !_isNameValid)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        'Tên phải có ít nhất 2 ký tự',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  
                  // Add "Done" button when in update mode
                  if (widget.updateMode) ...[
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isNameValid
                            ? () {
                                Navigator.of(context).pop();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OnboardingStyles.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: Text(
                          'Hoàn thành',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
    );
  }
} 