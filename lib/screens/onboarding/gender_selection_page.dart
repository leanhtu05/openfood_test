import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class GenderSelectionPage extends StatefulWidget {
  final bool updateMode;
  
  const GenderSelectionPage({
    Key? key,
    this.updateMode = false
  }) : super(key: key);

  @override
  State<GenderSelectionPage> createState() => _GenderSelectionPageState();
}

class _GenderSelectionPageState extends State<GenderSelectionPage> with SingleTickerProviderStateMixin {
  String? selectedGender;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    // Hiệu ứng phóng to khi chọn
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.gender.isNotEmpty) {
        setState(() {
          // Chuyển đổi từ 'Nam'/'Nữ' sang 'male'/'female' cho UI
          if (userData.gender == 'Nam') {
            selectedGender = 'male';
          } else if (userData.gender == 'Nữ') {
            selectedGender = 'female';
          } else {
            selectedGender = userData.gender;
          }
        });
        
        // Chạy animation nếu đã có gender được chọn
        if (selectedGender != null) {
          _animationController.forward();
        }
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Lưu giới tính vào provider
  void _saveGender(String gender) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.setGender(gender);
    
    // If in update mode, show success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật giới tính thành công!'),
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
        title: 'Cập nhật giới tính',
        child: _buildContent(context),
      );
    }
    
    // Trong luồng onboarding thông thường, trả về nội dung
    return _buildContent(context);
  }
  
  Widget _buildContent(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
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
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo - di chuyển lên cao hơn
                  if (!widget.updateMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Diet',
                            style: OnboardingStyles.appTitleStyle.copyWith(
                              color: OnboardingStyles.titleColor,
                            ),
                          ),
                          Text(
                            'AI',
                            style: OnboardingStyles.appTitleStyle.copyWith(
                              color: OnboardingStyles.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  
                  // Biểu tượng giới tính nhỏ hơn
                  if (!widget.updateMode)
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Image.asset(
                        'assets/images/gender_icon.png',
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.wc,
                            size: 60,
                            color: Colors.black54,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  
                  // Tiêu đề
                  Text(
                    widget.updateMode ? 'Cập nhật giới tính' : 'Giới tính của bạn là gì?',
                    style: OnboardingStyles.pageTitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  
                  // Chọn giới tính - làm to hơn
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Male option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedGender = 'male';
                              _saveGender('Nam');
                            });
                            // Khởi động animation khi chọn
                            _animationController.reset();
                            _animationController.forward();
                          },
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: selectedGender == 'male' ? _scaleAnimation.value : 1.0,
                                child: Container(
                                  height: screenHeight * 0.35, // Chiều cao tăng lên
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                  margin: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selectedGender == 'male'
                                          ? OnboardingStyles.primaryColor
                                          : Colors.grey.shade300,
                                      width: selectedGender == 'male' ? 4 : 2,
                                    ),
                                    boxShadow: selectedGender == 'male'
                                      ? [
                                          BoxShadow(
                                            color: OnboardingStyles.primaryColor.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Cartoon male figure
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            height: screenHeight * 0.22, // Chiều cao tăng lên
                                            padding: EdgeInsets.symmetric(vertical: 10),
                                            child: Image.asset(
                                              'assets/images/male_avatar.png',
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                // Fallback to icon if image not found
                                                return Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.male,
                                                      size: 100,
                                                      color: selectedGender == 'male'
                                                          ? OnboardingStyles.primaryColor
                                                          : Colors.grey,
                                                    ),
                                                    SizedBox(height: 10),
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: selectedGender == 'male'
                                                            ? Colors.blue.shade100
                                                            : Colors.grey.shade200,
                                                      ),
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 50,
                                                        color: selectedGender == 'male'
                                                            ? Colors.blue
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          if (selectedGender == 'male')
                                            Positioned(
                                              bottom: 5,
                                              right: 5,
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: OnboardingStyles.primaryColor,
                                                ),
                                                child: Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      Text(
                                        'Nam',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: selectedGender == 'male'
                                              ? OnboardingStyles.primaryColor
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      // Female option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedGender = 'female';
                              _saveGender('Nữ');
                            });
                            // Khởi động animation khi chọn
                            _animationController.reset();
                            _animationController.forward();
                          },
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: selectedGender == 'female' ? _scaleAnimation.value : 1.0,
                                child: Container(
                                  height: screenHeight * 0.35, // Chiều cao tăng lên
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                  margin: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selectedGender == 'female'
                                          ? OnboardingStyles.primaryColor
                                          : Colors.grey.shade300,
                                      width: selectedGender == 'female' ? 4 : 2,
                                    ),
                                    boxShadow: selectedGender == 'female'
                                      ? [
                                          BoxShadow(
                                            color: OnboardingStyles.primaryColor.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Cartoon female figure
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            height: screenHeight * 0.22, // Chiều cao tăng lên
                                            padding: EdgeInsets.symmetric(vertical: 10),
                                            child: Image.asset(
                                              'assets/images/female_avatar.png',
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                // Fallback to icon if image not found
                                                return Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.female,
                                                      size: 100,
                                                      color: selectedGender == 'female'
                                                          ? OnboardingStyles.primaryColor
                                                          : Colors.grey,
                                                    ),
                                                    SizedBox(height: 10),
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: selectedGender == 'female'
                                                            ? Colors.purple.shade100
                                                            : Colors.grey.shade200,
                                                      ),
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 50,
                                                        color: selectedGender == 'female'
                                                            ? Colors.purple
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          if (selectedGender == 'female')
                                            Positioned(
                                              bottom: 5,
                                              right: 5,
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: OnboardingStyles.primaryColor,
                                                ),
                                                child: Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      Text(
                                        'Nữ',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: selectedGender == 'female'
                                              ? OnboardingStyles.primaryColor
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Văn bản giải thích
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Chúng tôi sử dụng giới tính của bạn để thiết kế kế hoạch ăn kiêng tốt nhất cho bạn. Nếu bạn không xác định mình là bất kỳ lựa chọn nào trong số này, vui lòng chọn giới tính gần nhất với hồ sơ nội tiết tố của bạn.',
                      style: OnboardingStyles.captionStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // Nút hoàn thành nếu cần
                  if (widget.updateMode) ...[
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
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