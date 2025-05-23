import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import '../../styles/onboarding_styles.dart';

class WeightGainPacePage extends StatefulWidget {
  const WeightGainPacePage({Key? key}) : super(key: key);

  @override
  State<WeightGainPacePage> createState() => _WeightGainPacePageState();
}

class _WeightGainPacePageState extends State<WeightGainPacePage> {
  double _pace = 0.5;
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.pace > 0) {
        setState(() {
          _pace = userData.pace;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    final isWeightGain = userData.goal == 'Tăng cân';
    final isWeightLoss = userData.goal == 'Giảm cân';

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
                        
                        // Biểu tượng tốc độ
                        SizedBox(
                          width: OnboardingStyles.iconSize,
                          height: OnboardingStyles.iconSize,
                          child: Image.asset(
                            'assets/images/pace_icon.png',
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                isWeightGain ? Icons.trending_up : Icons.trending_down,
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
                      isWeightGain
                          ? 'Bạn muốn tăng bao nhiêu kg mỗi tuần?'
                          : isWeightLoss
                              ? 'Bạn muốn giảm bao nhiêu kg mỗi tuần?'
                              : 'Bạn muốn duy trì cân nặng hiện tại?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Center(
                    child: Text(
                      isWeightGain
                          ? 'Tăng cân quá nhanh có thể không tốt cho sức khỏe'
                          : isWeightLoss
                              ? 'Giảm cân quá nhanh có thể không tốt cho sức khỏe'
                              : 'Duy trì cân nặng hiện tại là một lựa chọn tốt',
                      style: OnboardingStyles.captionStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (isWeightGain || isWeightLoss) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        '${_pace.toStringAsFixed(2)} kg/tuần',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: OnboardingStyles.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: OnboardingStyles.primaryColor,
                        inactiveTrackColor: Colors.grey.shade300,
                        thumbColor: OnboardingStyles.primaryColor,
                        overlayColor: OnboardingStyles.primaryColor.withAlpha(51),
                        valueIndicatorColor: OnboardingStyles.primaryColor,
                        valueIndicatorTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        trackHeight: 8.0,
                      ),
                      child: Slider(
                        value: _pace,
                        min: 0.25,
                        max: 1.0,
                        divisions: 3,
                        label: _pace.toStringAsFixed(2),
                        onChanged: (value) {
                          setState(() => _pace = value);
                          // Lưu giá trị vào provider
                          Provider.of<UserDataProvider>(context, listen: false).setPace(_pace);
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Thông tin về tốc độ
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: OnboardingStyles.primaryColorLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tốc độ thay đổi cân nặng an toàn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: OnboardingStyles.primaryColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Các chuyên gia khuyến nghị tốc độ ${isWeightGain ? "tăng" : "giảm"} cân từ 0.25 đến 1kg mỗi tuần để duy trì sức khỏe và đạt kết quả bền vững.',
                            style: OnboardingStyles.bodyTextStyle,
                          ),
                        ],
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