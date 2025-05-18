import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class HeightSelectionPage extends StatefulWidget {
  const HeightSelectionPage({Key? key}) : super(key: key);

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
  void _saveHeight() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.heightCm = heightCm;
  }

  @override
  Widget build(BuildContext context) {
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
                  ),
                  const SizedBox(height: 40),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      'Chiều cao của bạn là bao nhiêu?',
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
                  
                  // Thanh trượt
                  SliderTheme(
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
                        _saveHeight();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
} 