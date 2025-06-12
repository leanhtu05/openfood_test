import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class AgeSelectionPage extends StatefulWidget {
  final bool updateMode;
  
  const AgeSelectionPage({
    Key? key,
    this.updateMode = false
  }) : super(key: key);

  @override
  State<AgeSelectionPage> createState() => _AgeSelectionPageState();
}

class _AgeSelectionPageState extends State<AgeSelectionPage> with SingleTickerProviderStateMixin {
  int age = 30;
  late FixedExtentScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  
  @override
  void initState() {
    super.initState();
    // Khởi tạo ScrollController với vị trí ban đầu là 30-1 = 29
    _scrollController = FixedExtentScrollController(initialItem: 29);
    
    // Khởi tạo AnimationController
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    // Khởi tạo animation kích thước
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    
    // Khởi tạo animation màu sắc
    _colorAnimation = ColorTween(
      begin: OnboardingStyles.primaryColor,
      end: OnboardingStyles.primaryColor,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        age = userData.age;
        
        // Cập nhật vị trí của ScrollController khi có age
        int initialPickerIndex = age - 1; // age 1 = index 0
        _scrollController.jumpToItem(initialPickerIndex);
      });
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _saveAge(int newAge) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.setAge(newAge);
    
    // If in update mode, show success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật tuổi thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Hàm tạo màu sắc theo tuổi
  Color _getAgeColor(int age) {
    if (age < 18) {
      return Colors.lightBlue;
    } else if (age < 30) {
      return Colors.green;
    } else if (age < 50) {
      return OnboardingStyles.primaryColor;
    } else if (age < 70) {
      return Colors.orange;
    } else {
      return Colors.deepOrange;
    }
  }
  
  // Khởi chạy animation khi thay đổi tuổi
  void _animateAgeChange(int newAge) {
    _colorAnimation = ColorTween(
      begin: _colorAnimation.value ?? OnboardingStyles.primaryColor,
      end: _getAgeColor(newAge),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng MaterialOnboardingPage wrapper nếu ở chế độ updateMode
    if (widget.updateMode) {
      return MaterialOnboardingPage(
        title: 'Cập nhật tuổi',
        child: _buildContent(context),
      );
    }
    
    // Trong luồng onboarding thông thường, trả về nội dung
    return _buildContent(context);
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DietAI',
                            style: OnboardingStyles.appTitleStyle,
                          ),
                          const SizedBox(height: 24),
                          
                          // Biểu tượng tuổi tác
                          SizedBox(
                            width: OnboardingStyles.iconSize,
                            height: OnboardingStyles.iconSize,
                            child: Image.asset(
                              'assets/images/age_icon.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.cake,
                                  size: 100,
                                  color: OnboardingStyles.accentColor,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.cake,
                        size: 80,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  const SizedBox(height: 40),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode ? 'Cập nhật tuổi' : 'Bạn bao nhiêu tuổi?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Thay thế CupertinoPicker bằng ListWheelScrollView
                  Container(
                    height: 300,
                    child: ListWheelScrollView.useDelegate(
                      controller: _scrollController,
                      itemExtent: 50,
                      perspective: 0.005,
                      diameterRatio: 1.8,
                      physics: FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (int selectedItemIndex) {
                        setState(() {
                          age = selectedItemIndex + 1; // Chuyển index về tuổi (index 0 = tuổi 1)
                          _animateAgeChange(age);
                        });
                        _saveAge(age);
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 120,
                        builder: (context, index) {
                          final ageValue = index + 1; // index 0 = tuổi 1
                          final isSelected = ageValue == age;
                          
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                            decoration: isSelected 
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  color: Colors.blue.withOpacity(0.1),
                                )
                              : null,
                            alignment: Alignment.center,
                            child: Text(
                              '$ageValue',
                              style: TextStyle(
                                fontSize: isSelected ? 36 : 30,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected 
                                  ? Colors.black 
                                  : Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Thêm chú thích
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Center(
                      child: Text(
                        'Vuốt lên/xuống để chọn tuổi của bạn',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                                  
                ],
              ),
            ),
          ),
        );
      }
    );
  }
} 