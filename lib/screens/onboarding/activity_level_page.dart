import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class ActivityLevelPage extends StatefulWidget {
  const ActivityLevelPage({Key? key}) : super(key: key);

  @override
  _ActivityLevelPageState createState() => _ActivityLevelPageState();
}

class _ActivityLevelPageState extends State<ActivityLevelPage> {
  String? selectedActivityLevel;
  
  final List<Map<String, String>> activityLevels = [
    {
      'title': 'Ít vận động',
      'description': 'Làm việc văn phòng, ít tập thể dục',
      'value': 'Ít vận động',
      'icon': '🧘‍♂️',
    },
    {
      'title': 'Hoạt động nhẹ',
      'description': 'Tập thể dục 1-3 lần/tuần',
      'value': 'Hoạt động nhẹ',
      'icon': '🚶‍♂️',
    },
    {
      'title': 'Hoạt động vừa phải',
      'description': 'Tập thể dục 3-5 lần/tuần',
      'value': 'Hoạt động vừa phải',
      'icon': '🏃‍♂️',
    },
    {
      'title': 'Rất năng động',
      'description': 'Tập thể dục 6-7 lần/tuần',
      'value': 'Rất năng động',
      'icon': '🏋️‍♂️',
    },
  ];
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.activityLevel.isNotEmpty) {
        setState(() {
          selectedActivityLevel = userData.activityLevel;
        });
      }
    });
  }
  
  // Lưu dữ liệu vào provider
  void _saveActivityLevel(String level) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.setActivityLevel(level);
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
                        
                        // Biểu tượng hoạt động
                        SizedBox(
                          width: OnboardingStyles.iconSize,
                          height: OnboardingStyles.iconSize,
                          child: Image.asset(
                            'assets/images/activity_level.png',
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.directions_run,
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
                    child: Column(
                      children: [
                        Text(
                          'Mức độ hoạt động của bạn?',
                          style: OnboardingStyles.pageTitleStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chọn mức độ hoạt động phù hợp với lối sống của bạn',
                          style: OnboardingStyles.captionStyle,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Danh sách lựa chọn
                  ...activityLevels.map((activity) {
                    final isSelected = selectedActivityLevel == activity['value'];
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedActivityLevel = activity['value'];
                        });
                        _saveActivityLevel(activity['value']!);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? OnboardingStyles.primaryColorLight : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? OnboardingStyles.primaryColor : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: Text(
                                activity['icon'] ?? '🏃',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Title & Description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity['title']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isSelected ? OnboardingStyles.primaryColor : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    activity['description']!,
                                    style: OnboardingStyles.captionStyle,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Checkbox
                            if (isSelected) 
                              Icon(
                                Icons.check_circle,
                                color: OnboardingStyles.primaryColor,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
} 