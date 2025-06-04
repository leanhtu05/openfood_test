import 'package:flutter/material.dart';
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

class _HeightSelectionPageState extends State<HeightSelectionPage> {
  double heightCm = 166;
  String unit = 'cm'; // 'cm' hoặc 'ft'

  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        heightCm = userData.heightCm;
      });
    });
  }

  // Chuyển đổi cm sang ft và inch
  String get heightInFeetInches {
    final totalInches = heightCm / 2.54;
    final feet = (totalInches / 12).floor();
    final inches = (totalInches % 12).round();
    return '$feet\'$inches"';
  }

  // Lưu dữ liệu vào provider
  void _saveHeight(double height) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.setHeight(height);
    
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

  @override
  Widget build(BuildContext context) {
    // Nếu đang ở chế độ cập nhật, bọc trong Scaffold
    if (widget.updateMode) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Cập nhật chiều cao'),
          backgroundColor: OnboardingStyles.primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Material(
          color: Colors.white,
          child: _buildContent(context),
        ),
      );
    }
    
    // Trong luồng onboarding thông thường, đã có Scaffold từ OnboardingScreen
    return _buildContent(context);
  }
  
  // Tách nội dung thành phương thức riêng để có thể tái sử dụng
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
                          
                          // Biểu tượng đo chiều cao
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
                  const SizedBox(height: 40),
                  
                  // Chọn đơn vị
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Chọn cm
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                unit = 'cm';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: unit == 'cm' ? OnboardingStyles.primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              child: Text(
                                'cm',
                                style: TextStyle(
                                  color: unit == 'cm' ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          // Chọn ft
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                unit = 'ft';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: unit == 'ft' ? OnboardingStyles.primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              child: Text(
                                'ft',
                                style: TextStyle(
                                  color: unit == 'ft' ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Hiển thị chiều cao đã chọn
                  Center(
                    child: Text(
                      unit == 'cm' ? '${heightCm.toInt()} cm' : heightInFeetInches,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Thanh trượt chiều cao với người hình hoạt họa
                  SizedBox(
                    height: 200,
                    child: Stack(
                      children: [
                        // Thước đo chiều cao
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: SizedBox(
                            width: 40,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                final value = 190 - index * 10;
                                return SizedBox(
                                  height: 20,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 1,
                                        color: Colors.grey,
                                      ),
                                      Text(
                                        '$value',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        
                        // Người hình hoạt họa
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 150,
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      Image.asset(
                                        'assets/images/height_avatar.png',
                                        height: 120,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.person,
                                            size: 100,
                                            color: OnboardingStyles.accentColor,
                                          );
                                        },
                                      ),
                                      // Thanh xanh indicator chiều cao
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          height: 2,
                                          color: OnboardingStyles.accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Thanh trượt - đảm bảo có Material ancestor
                  Material(
                    color: Colors.transparent,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: OnboardingStyles.primaryColor,
                        inactiveTrackColor: Colors.grey.shade300,
                        thumbColor: OnboardingStyles.primaryColor,
                        overlayColor: OnboardingStyles.primaryColor.withOpacity(0.2),
                        valueIndicatorColor: OnboardingStyles.primaryColor,
                        valueIndicatorTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Slider(
                        min: 140,
                        max: 210,
                        divisions: 140,
                        value: heightCm,
                        label: unit == 'cm' ? '${heightCm.toInt()} cm' : heightInFeetInches,
                        onChanged: (value) {
                          setState(() {
                            heightCm = value;
                          });
                          _saveHeight(value);
                        },
                      ),
                    ),
                  ),
                  
                  // Add "Done" button when in update mode
                  if (widget.updateMode) ...[
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OnboardingStyles.primaryColor,
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