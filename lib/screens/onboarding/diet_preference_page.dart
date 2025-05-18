import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class DietPreferencePage extends StatefulWidget {
  const DietPreferencePage({Key? key}) : super(key: key);

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
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
                      ),
                      const SizedBox(height: 30),
                      
                      // Tiêu đề
                      Center(
                        child: Text(
                          'Bạn thích loại chế độ ăn uống nào?',
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
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
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