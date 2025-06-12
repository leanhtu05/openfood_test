import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class DietGoalPage extends StatefulWidget {
  final bool updateMode;
  
  const DietGoalPage({
    Key? key,
    this.updateMode = false
  }) : super(key: key);

  @override
  State<DietGoalPage> createState() => _DietGoalPageState();
}

class _DietGoalPageState extends State<DietGoalPage> {
  String? selectedGoal;
  
  @override
  void initState() {
    super.initState();
    // Lấy mục tiêu từ provider nếu đã có
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        selectedGoal = userData.goal;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng MaterialOnboardingPage wrapper nếu ở chế độ updateMode
    if (widget.updateMode) {
      return MaterialOnboardingPage(
        title: 'Cập nhật mục tiêu chế độ ăn',
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
                  // Nút quay lại
                  if (!widget.updateMode)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Logo và Biểu tượng
                  if (!widget.updateMode)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
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
                          const SizedBox(height: 24),
                          
                          // Biểu tượng mục tiêu
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: Image.asset(
                              'assets/images/target_icon.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.track_changes,
                                  size: 80,
                                  color: Colors.black54,
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
                        Icons.track_changes,
                        size: 80,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode ? 'Cập nhật mục tiêu chế độ ăn' : 'Mục tiêu chính về chế độ ăn uống của bạn là gì?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Lựa chọn mục tiêu
                  _buildGoalOption(
                    icon: Icons.balance,
                    emoji: '⚖️',
                    label: 'Giảm cân',
                    isSelected: selectedGoal == 'Giảm cân',
                    onTap: () => _selectGoal('Giảm cân'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildGoalOption(
                    icon: Icons.spa,
                    emoji: '🌱',
                    label: 'Duy trì cân nặng',
                    isSelected: selectedGoal == 'Duy trì cân nặng',
                    onTap: () => _selectGoal('Duy trì cân nặng'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildGoalOption(
                    icon: Icons.fitness_center,
                    emoji: '💪',
                    label: 'Tăng cân',
                    isSelected: selectedGoal == 'Tăng cân',
                    onTap: () => _selectGoal('Tăng cân'),
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
                  ] else ...[
                  ],
                ],
              ),
            ),
          ),
        );
      }
    );
  }
  
  // Phương thức xây dựng một tùy chọn mục tiêu
  Widget _buildGoalOption({
    required IconData icon,
    required String emoji,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? OnboardingStyles.primaryColor : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
            ? [
                BoxShadow(
                  color: OnboardingStyles.primaryColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected ? OnboardingStyles.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? OnboardingStyles.primaryColor : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: OnboardingStyles.primaryColor,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
  
  // Phương thức để chọn mục tiêu và lưu vào provider
  void _selectGoal(String goal) {
    setState(() {
      selectedGoal = goal;
    });
    // Lưu mục tiêu vào provider
    Provider.of<UserDataProvider>(context, listen: false).setGoal(goal);
    
    // If in update mode, show success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật mục tiêu thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
} 