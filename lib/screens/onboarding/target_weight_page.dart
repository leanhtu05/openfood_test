import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class TargetWeightPage extends StatefulWidget {
  const TargetWeightPage({Key? key}) : super(key: key);

  @override
  State<TargetWeightPage> createState() => _TargetWeightPageState();
}

class _TargetWeightPageState extends State<TargetWeightPage> {
  double targetWeightKg = 60;
  String unit = 'kg'; // 'kg' hoặc 'lbs'
  double heightCm = 166; // Giả sử đã có từ trang trước đó
  double currentWeightKg = 54; // Giả sử đã có từ trang trước đó
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        targetWeightKg = userData.targetWeightKg > 0 ? userData.targetWeightKg : 60;
        currentWeightKg = userData.weightKg;
        heightCm = userData.heightCm;
      });
    });
  }
  
  // Lưu dữ liệu vào provider
  void _saveTargetWeight() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.targetWeightKg = targetWeightKg;
  }
  
  double get targetBmi => targetWeightKg / ((heightCm / 100) * (heightCm / 100));
  double get percentChange => ((targetWeightKg - currentWeightKg) / currentWeightKg) * 100;
  
  String get targetBmiCategory {
    if (targetBmi < 18.5) return 'Thiếu cân';
    if (targetBmi < 25) return 'Bình thường';
    if (targetBmi < 30) return 'Thừa cân';
    if (targetBmi < 35) return 'Béo phì';
    return 'Béo phì nguy hiểm';
  }
  
  Color get targetBmiColor {
    if (targetBmi < 18.5) return Colors.blue;
    if (targetBmi < 25) return OnboardingStyles.primaryColor;
    if (targetBmi < 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isGain = targetWeightKg > currentWeightKg;
    final changeText = isGain 
      ? 'Tăng ${percentChange.abs().toStringAsFixed(0)}% cân!'
      : 'Giảm ${percentChange.abs().toStringAsFixed(0)}% cân!';
    final changeAmount = isGain
      ? '${(targetWeightKg - currentWeightKg).toInt()} kg'
      : '${(currentWeightKg - targetWeightKg).toInt()} kg';
      
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
                        
                        // Biểu tượng mục tiêu
                        SizedBox(
                          width: OnboardingStyles.iconSize,
                          height: OnboardingStyles.iconSize,
                          child: Image.asset(
                            'assets/images/target_flag.png',
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.flag,
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
                      'Cân nặng mục tiêu của bạn là bao nhiêu?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
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
                          // Chọn kg
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                unit = 'kg';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: unit == 'kg' ? OnboardingStyles.primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              child: Text(
                                'kg',
                                style: TextStyle(
                                  color: unit == 'kg' ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          // Chọn lbs
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                unit = 'lbs';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: unit == 'lbs' ? OnboardingStyles.primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              child: Text(
                                'lbs',
                                style: TextStyle(
                                  color: unit == 'lbs' ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Thông báo về thay đổi cân nặng
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: OnboardingStyles.primaryColorLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isGain ? Icons.trending_up : Icons.trending_down,
                            color: OnboardingStyles.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                changeText,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: OnboardingStyles.primaryColor,
                                ),
                              ),
                              Text(
                                'Thay đổi $changeAmount từ cân nặng hiện tại',
                                style: OnboardingStyles.captionStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Hiển thị cân nặng đã chọn
                  Center(
                    child: Text(
                      '${targetWeightKg.toInt()} kg',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
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
                      min: 40,
                      max: 150,
                      divisions: 110,
                      value: targetWeightKg,
                      label: '${targetWeightKg.toInt()} kg',
                      onChanged: (double value) {
                        setState(() {
                          targetWeightKg = value;
                        });
                        _saveTargetWeight();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Hiển thị BMI mục tiêu
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BMI mục tiêu của bạn sẽ là',
                            style: OnboardingStyles.captionStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${targetBmi.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: targetBmiColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            targetBmiCategory,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: targetBmiColor,
                            ),
                          ),
                        ],
                      ),
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