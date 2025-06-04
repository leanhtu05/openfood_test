import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class DietRestrictionPage extends StatefulWidget {
  final bool updateMode;
  
  const DietRestrictionPage({
    Key? key,
    this.updateMode = false
  }) : super(key: key);

  @override
  State<DietRestrictionPage> createState() => _DietRestrictionPageState();
}

class _DietRestrictionPageState extends State<DietRestrictionPage> {
  List<String> selectedRestrictions = [];
  
  final List<Map<String, dynamic>> dietRestrictions = [
    {
      'id': 'none',
      'emoji': '✓',
      'label': 'Không có',
    },
    {
      'id': 'vegetarian',
      'emoji': '🌱',
      'label': 'Ăn chay',
    },
    {
      'id': 'vegan',
      'emoji': '🌿',
      'label': 'Thuần chay',
    },
    {
      'id': 'gluten-free',
      'emoji': '🚫',
      'label': 'Không chứa gluten',
    },
  ];
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.dietRestrictions.isNotEmpty) {
        setState(() {
          selectedRestrictions = userData.dietRestrictions;
        });
      }
    });
  }
  
  // Lưu dữ liệu vào provider
  void _saveDietRestrictions(List<String> restrictions) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.dietRestrictions = restrictions;
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng MaterialOnboardingPage wrapper nếu ở chế độ updateMode
    if (widget.updateMode) {
      return MaterialOnboardingPage(
        title: 'Cập nhật hạn chế ăn uống',
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
                  // Logo
                  if (!widget.updateMode)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'DietAI',
                            style: OnboardingStyles.appTitleStyle,
                          ),
                          const SizedBox(height: 24),
                          
                          // Biểu tượng giới hạn ăn uống
                          SizedBox(
                            width: OnboardingStyles.iconSize,
                            height: OnboardingStyles.iconSize,
                            child: Image.asset(
                              'assets/images/diet_restriction.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.no_food,
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
                        Icons.no_food,
                        size: 80,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode 
                        ? 'Cập nhật hạn chế ăn uống' 
                        : 'Bạn có bất kỳ hạn chế về chế độ ăn uống, dị ứng hoặc thực phẩm nào bạn muốn tránh không?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Danh sách các lựa chọn
                  ...dietRestrictions.map((restriction) {
                    final bool isSelected = restriction['id'] == 'none' 
                      ? selectedRestrictions.isEmpty || selectedRestrictions.contains('none')
                      : selectedRestrictions.contains(restriction['id']);
                      
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildRestrictionOption(
                        emoji: restriction['emoji'],
                        label: restriction['label'],
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (restriction['id'] == 'none') {
                              selectedRestrictions = ['none'];
                            } else {
                              // Xóa lựa chọn 'không có' nếu có
                              selectedRestrictions.remove('none');
                              
                              // Toggle lựa chọn hiện tại
                              if (isSelected) {
                                selectedRestrictions.remove(restriction['id']);
                              } else {
                                selectedRestrictions.add(restriction['id']);
                              }
                            }
                          });
                          _saveDietRestrictions(selectedRestrictions);
                          
                          // Show success message if in update mode
                          if (widget.updateMode) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã cập nhật hạn chế ăn uống thành công!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        showInfoIcon: restriction['id'] != 'none',
                      ),
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
  
  Widget _buildRestrictionOption({
    required String emoji,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool showInfoIcon = false,
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
            // Emoji hoặc Icon
            SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Nhãn
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? OnboardingStyles.primaryColor : Colors.black87,
                ),
              ),
            ),
            
            // Nút info hoặc checkbox
            if (showInfoIcon)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade100,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 18,
                ),
              )
            else if (isSelected)
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