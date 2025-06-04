import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class DietPreferencePage extends StatefulWidget {
  final bool updateMode;
  
  const DietPreferencePage({
    Key? key,
    this.updateMode = false
  }) : super(key: key);

  @override
  State<DietPreferencePage> createState() => _DietPreferencePageState();
}

class _DietPreferencePageState extends State<DietPreferencePage> {
  String? selectedDiet;
  
  final List<Map<String, dynamic>> dietPreferences = [
    {
      'id': 'dash',
      'emoji': '🥦',
      'label': 'Dash',
    },
    {
      'id': 'low-carb',
      'emoji': '🚫',
      'label': 'Ít carb',
    },
    {
      'id': 'high-protein',
      'emoji': '💪',
      'label': 'Nhiều protein',
    },
    {
      'id': 'low-fat',
      'emoji': '🚫',
      'label': 'Ít béo',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.dietPreference.isNotEmpty) {
        setState(() {
          selectedDiet = userData.dietPreference;
        });
      }
    });
  }

  // Lưu dữ liệu vào provider
  void _saveDietPreference(String preference) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.dietPreference = preference;
    
    // If in update mode, show success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật chế độ ăn thành công!'),
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
        title: 'Cập nhật chế độ ăn',
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
                          
                          // Biểu tượng thực phẩm
                          SizedBox(
                            width: OnboardingStyles.iconSize,
                            height: OnboardingStyles.iconSize,
                            child: Image.asset(
                              'assets/images/diet_preference.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.restaurant_menu,
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
                        Icons.restaurant_menu,
                        size: 80,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode 
                          ? 'Cập nhật chế độ ăn' 
                          : 'Bạn thích loại chế độ ăn uống nào?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Lựa chọn các loại chế độ ăn uống
                  ...dietPreferences.map((preference) {
                    final bool isSelected = selectedDiet == preference['id'];
                      
                    return Column(
                      children: [
                        _buildDietPreferenceOption(
                          emoji: preference['emoji'],
                          label: preference['label'],
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              selectedDiet = preference['id'];
                            });
                            _saveDietPreference(preference['id']);
                          },
                        ),
                        SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                  
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
  
  Widget _buildDietPreferenceOption({
    required String emoji,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? OnboardingStyles.primaryColorLight : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? OnboardingStyles.primaryColor : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            
            // Nhãn
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? OnboardingStyles.primaryColor : Colors.black87,
              ),
            ),
            
            // Use Spacer
            const Spacer(),
            
            // Info icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100,
              ),
              child: Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 