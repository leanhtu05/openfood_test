import 'package:flutter/material.dart';
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

class _AgeSelectionPageState extends State<AgeSelectionPage> {
  int selectedAge = 23;
  
  @override
  void initState() {
    super.initState();
    // Lấy tuổi từ provider nếu đã có
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        selectedAge = userData.age;
      });
    });
  }
  
  // Lưu dữ liệu vào provider
  void _saveAge(int age) {
    Provider.of<UserDataProvider>(context, listen: false).setAge(age);
    
    // If in update mode, show a success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật tuổi thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
                          
                          // Biểu tượng bánh sinh nhật
                          SizedBox(
                            width: OnboardingStyles.iconSize,
                            height: OnboardingStyles.iconSize,
                            child: Image.asset(
                              'assets/images/birthday_cake.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.cake,
                                  size: 80,
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
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode ? 'Cập nhật tuổi của bạn' : 'Bạn bao nhiêu tuổi?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Chọn tuổi - Thiết kế selector
                  Center(
                    child: SizedBox(
                      height: 160,
                      child: SingleChildScrollView(
                        physics: NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tuổi trước đó
                            Opacity(
                              opacity: 0.3,
                              child: Text(
                                '${selectedAge - 2}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            
                            // Tuổi trước đó
                            Opacity(
                              opacity: 0.5,
                              child: Text(
                                '${selectedAge - 1}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            
                            // Tuổi đã chọn
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: OnboardingStyles.accentColor, width: 2),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                '$selectedAge',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: OnboardingStyles.accentColor,
                                ),
                              ),
                            ),
                            
                            // Tuổi tiếp theo
                            Opacity(
                              opacity: 0.5,
                              child: Text(
                                '${selectedAge + 1}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            
                            // Tuổi tiếp theo
                            Opacity(
                              opacity: 0.3,
                              child: Text(
                                '${selectedAge + 2}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Thanh điều chỉnh tuổi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (selectedAge > 12) {
                            setState(() {
                              selectedAge--;
                            });
                            // Lưu giá trị vào provider
                            _saveAge(selectedAge);
                          }
                        },
                        icon: Icon(Icons.remove_circle, size: 32, color: OnboardingStyles.accentColor),
                      ),
                      Expanded(
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
                            trackHeight: 6.0,
                          ),
                          child: Slider(
                            min: 12,
                            max: 80,
                            divisions: 68,
                            value: selectedAge.toDouble(),
                            label: '$selectedAge tuổi',
                            onChanged: (value) {
                              setState(() {
                                selectedAge = value.toInt();
                              });
                              // Lưu giá trị vào provider
                              _saveAge(selectedAge);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (selectedAge < 80) {
                            setState(() {
                              selectedAge++;
                            });
                            // Lưu giá trị vào provider
                            _saveAge(selectedAge);
                          }
                        },
                        icon: Icon(Icons.add_circle, size: 32, color: OnboardingStyles.accentColor),
                      ),
                    ],
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