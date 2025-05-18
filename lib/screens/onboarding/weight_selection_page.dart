import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class WeightSelectionPage extends StatefulWidget {
  const WeightSelectionPage({Key? key}) : super(key: key);

  @override
  State<WeightSelectionPage> createState() => _WeightSelectionPageState();
}

class _WeightSelectionPageState extends State<WeightSelectionPage> {
  double weightKg = 54;
  String unit = 'kg'; // 'kg' hoặc 'lbs'
  double heightCm = 166; // Giả sử đã có từ trang trước đó
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        // Ensure weight is within valid range (40-150)
        weightKg = userData.weightKg;
        if (weightKg < 40) weightKg = 40;
        if (weightKg > 150) weightKg = 150;
        heightCm = userData.heightCm;
      });
    });
  }
  
  // Lưu dữ liệu vào provider
  void _saveWeight() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.weightKg = weightKg;
  }
  
  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));
  
  String get bmiCategory {
    if (bmi < 18.5) return 'Thiếu cân';
    if (bmi < 25) return 'Bình thường';
    if (bmi < 30) return 'Thừa cân';
    if (bmi < 35) return 'Béo phì';
    return 'Béo phì nguy hiểm';
  }
  
  Color get bmiColor {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return OnboardingStyles.primaryColor;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
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
                        
                        // Biểu tượng cân
                        SizedBox(
                          width: OnboardingStyles.iconSize,
                          height: OnboardingStyles.iconSize,
                          child: Image.asset(
                            'assets/images/weight_scale.png',
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.monitor_weight_outlined,
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
                      'Cân nặng của bạn là bao nhiêu?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
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
                                // Chuyển đổi kg sang lbs nếu cần
                                if (unit == 'lbs') {
                                  weightKg = weightKg * 0.453592;
                                }
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
                  
                  // Hiển thị chỉ số BMI
                  Center(
                    child: Container(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Chỉ số khối cơ thể (BMI) của bạn là',
                            style: OnboardingStyles.captionStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${bmi.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: bmiColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children: [
                              Text(
                                'BMI của bạn cho thấy bạn đang',
                                style: OnboardingStyles.bodyTextStyle.copyWith(
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bmiCategory.toLowerCase() + '!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: bmiColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          
                          // Hiển thị cân nặng đã chọn
                          Text(
                            '${weightKg.toInt()} kg',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: OnboardingStyles.accentColor,
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
                              value: weightKg,
                              label: '${weightKg.toInt()} kg',
                              onChanged: (double value) {
                                setState(() {
                                  weightKg = value;
                                });
                                _saveWeight();
                              },
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