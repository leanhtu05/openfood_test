import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class GenderSelectionPage extends StatefulWidget {
  const GenderSelectionPage({Key? key}) : super(key: key);

  @override
  State<GenderSelectionPage> createState() => _GenderSelectionPageState();
}

class _GenderSelectionPageState extends State<GenderSelectionPage> {
  String? selectedGender;

  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.gender.isNotEmpty) {
        setState(() {
          selectedGender = userData.gender;
        });
      }
    });
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
                        
                        // Biểu tượng giới tính
                        SizedBox(
                          width: OnboardingStyles.iconSize,
                          height: OnboardingStyles.iconSize,
                          child: Image.asset(
                            'assets/images/gender_icon.png',
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.wc,
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
                      'Giới tính của bạn là gì?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Lựa chọn giới tính
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Nam
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedGender = 'Nam';
                            });
                            
                            // Cập nhật vào UserDataProvider
                            Provider.of<UserDataProvider>(context, listen: false).gender = 'Nam';
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selectedGender == 'Nam' ? Colors.blue : Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/male_avatar.png',
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.man,
                                      size: 100,
                                      color: Colors.blue[700],
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Nam',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Nữ
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedGender = 'Nữ';
                            });
                            
                            // Cập nhật vào UserDataProvider
                            Provider.of<UserDataProvider>(context, listen: false).gender = 'Nữ';
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selectedGender == 'Nữ' ? Colors.pink : Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/female_avatar.png',
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.woman,
                                      size: 100,
                                      color: Colors.pink,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Nữ',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Văn bản giải thích
                  Text(
                    'Chúng tôi sử dụng giới tính của bạn để thiết kế kế hoạch ăn kiêng tốt nhất cho bạn. Nếu bạn không xác định mình là bất kỳ lựa chọn nào trong số này, vui lòng chọn giới tính gần nhất với hồ sơ nội tiết tố của bạn.',
                    style: OnboardingStyles.captionStyle,
                    textAlign: TextAlign.center,
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