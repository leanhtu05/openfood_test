import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class HeightSelectionPage extends StatefulWidget {
  final bool updateMode;
  
  const HeightSelectionPage({
    Key? key,
    this.updateMode = false
  }) : super(key: key);

  @override
  State<HeightSelectionPage> createState() => _HeightSelectionPageState();
}

class _HeightSelectionPageState extends State<HeightSelectionPage> with SingleTickerProviderStateMixin {
  double heightCm = 170; // Giá trị mặc định
  late FixedExtentScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    // Khởi tạo ScrollController với vị trí ban đầu là 170-140 = 30 (index 30)
    _scrollController = FixedExtentScrollController(initialItem: 30);

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
        heightCm = userData.heightCm;

        // Cập nhật vị trí của ScrollController khi có height
        int initialPickerIndex = (heightCm - 140).round(); // height 140 = index 0
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

  void _saveHeight(double newHeight) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.setHeight(newHeight);

    // If in update mode, show success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật chiều cao thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Hàm tạo màu sắc theo chiều cao
  Color _getHeightColor(double height) {
    if (height < 150) {
      return Colors.lightBlue;
    } else if (height < 160) {
      return Colors.green;
    } else if (height < 170) {
      return OnboardingStyles.primaryColor;
    } else if (height < 180) {
      return Colors.orange;
    } else {
      return Colors.deepOrange;
    }
  }

  // Khởi chạy animation khi thay đổi chiều cao
  void _animateHeightChange(double newHeight) {
    _colorAnimation = ColorTween(
      begin: _colorAnimation.value ?? OnboardingStyles.primaryColor,
      end: _getHeightColor(newHeight),
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
        title: 'Cập nhật chiều cao',
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

                          // Biểu tượng chiều cao
                          SizedBox(
                            width: OnboardingStyles.iconSize,
                            height: OnboardingStyles.iconSize,
                            child: Image.asset(
                              'assets/images/height_icon.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.height,
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
                        Icons.height,
                        size: 80,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  const SizedBox(height: 40),

                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode ? 'Cập nhật chiều cao' : 'Chiều cao của bạn là bao nhiêu?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Thay thế phần kéo thả bằng ListWheelScrollView
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
                          heightCm = 140 + selectedItemIndex.toDouble(); // Chuyển index về chiều cao (index 0 = 140cm)
                          _animateHeightChange(heightCm);
                        });
                        _saveHeight(heightCm);
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 91, // 140cm đến 230cm = 91 giá trị
                        builder: (context, index) {
                          final heightValue = 140 + index; // index 0 = 140cm
                          final isSelected = heightValue.toDouble() == heightCm;

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
                              '$heightValue cm',
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
                        'Vuốt lên/xuống để chọn chiều cao của bạn',
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