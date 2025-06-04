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
  int age = 30;
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        age = userData.age;
      });
    });
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
                  const SizedBox(height: 40),
                  
                  // Age Selector
                  Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: OnboardingStyles.primaryColor,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$age',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Selector buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Decrease age button
                      IconButton(
                        onPressed: () {
                          if (age > 1) {
                            setState(() {
                              age--;
                            });
                            _saveAge(age);
                          }
                        },
                        icon: Icon(Icons.remove_circle, size: 40),
                        color: OnboardingStyles.primaryColor,
                      ),
                      const SizedBox(width: 20),
                      
                      // Age slider - đảm bảo có Material ancestor
                      Expanded(
                        child: Material(
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
                              min: 1,
                              max: 120,
                              divisions: 119,
                              value: age.toDouble(),
                              label: '$age',
                              onChanged: (value) {
                                setState(() {
                                  age = value.toInt();
                                });
                                _saveAge(age);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      
                      // Increase age button
                      IconButton(
                        onPressed: () {
                          if (age < 120) {
                            setState(() {
                              age++;
                            });
                            _saveAge(age);
                          }
                        },
                        icon: Icon(Icons.add_circle, size: 40),
                        color: OnboardingStyles.primaryColor,
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