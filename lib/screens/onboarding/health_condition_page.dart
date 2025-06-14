import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class HealthConditionPage extends StatefulWidget {
  final bool updateMode;
  
  const HealthConditionPage({
    Key? key, 
    this.updateMode = false
  }) : super(key: key);

  @override
  State<HealthConditionPage> createState() => _HealthConditionPageState();
}

class _HealthConditionPageState extends State<HealthConditionPage> {
  List<String> selectedConditions = [];
  
  final List<Map<String, dynamic>> healthConditions = [
    {
      'id': 'none',
      'emoji': '✓',
      'label': 'Không có',
    },
    {
      'id': 'hypertension',
      'emoji': '❤️',
      'label': 'Huyết áp cao',
    },
    {
      'id': 'diabetes',
      'emoji': '🍭',
      'label': 'Bệnh tiểu đường',
    },
    {
      'id': 'high-cholesterol',
      'emoji': '🍟',
      'label': 'Cholesterol cao',
    },
  ];
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.healthConditions.isNotEmpty) {
        setState(() {
          selectedConditions = userData.healthConditions;
        });
      }
    });
  }
  
  // Lưu dữ liệu vào provider
  void _saveHealthConditions(List<String> conditions) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.healthConditions = conditions;
    
    // If in update mode, show success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật tình trạng sức khỏe thành công!'),
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
        title: 'Cập nhật tình trạng sức khỏe',
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
                        children: [
                          Text(
                            'DietAI',
                            style: OnboardingStyles.appTitleStyle,
                          ),
                          const SizedBox(height: 24),
                          
                          // Biểu tượng sức khỏe
                          SizedBox(
                            width: OnboardingStyles.iconSize,
                            height: OnboardingStyles.iconSize,
                            child: Image.asset(
                              'assets/images/health_condition.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.favorite,
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
                        Icons.favorite,
                        size: 80,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode 
                          ? 'Cập nhật tình trạng sức khỏe' 
                          : 'Bạn có bất kỳ tình trạng sức khỏe nào không?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Lựa chọn các tình trạng sức khỏe
                  ...healthConditions.map((condition) {
                    final bool isSelected = condition['id'] == 'none' 
                      ? selectedConditions.isEmpty || selectedConditions.contains('none')
                      : selectedConditions.contains(condition['id']);
                      
                    return Column(
                      children: [
                        _buildHealthConditionOption(
                          emoji: condition['emoji'],
                          label: condition['label'],
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (condition['id'] == 'none') {
                                selectedConditions = ['none'];
                              } else {
                                // Xóa lựa chọn 'không có' nếu có
                                selectedConditions.remove('none');
                                
                                // Toggle lựa chọn hiện tại
                                if (isSelected) {
                                  selectedConditions.remove(condition['id']);
                                } else {
                                  selectedConditions.add(condition['id']);
                                }
                              }
                            });
                            _saveHealthConditions(selectedConditions);
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
  
  Widget _buildHealthConditionOption({
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
                style: const TextStyle(fontSize: 24),
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
            
            // Spacer
            const Spacer(),
            
            // Checkbox
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OnboardingStyles.primaryColor,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
} 