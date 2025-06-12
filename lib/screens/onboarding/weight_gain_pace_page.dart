import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horizontal_picker/horizontal_picker.dart';
import 'package:horizontal_picker/horizontal_picker.dart' show InitialPosition;
import '../../providers/user_data_provider.dart';
import '../../styles/onboarding_styles.dart';

class WeightGainPacePage extends StatefulWidget {
  const WeightGainPacePage({Key? key}) : super(key: key);

  @override
  State<WeightGainPacePage> createState() => _WeightGainPacePageState();
}

class _WeightGainPacePageState extends State<WeightGainPacePage> {
  double _pace = 0.5;
  // Danh sách các giá trị pace chi tiết
  final List<double> paceValues = List.generate(21, (index) => 0.25 + (index * 0.05));

  @override
  void initState() {
    super.initState();
    
    // Đặt giá trị mặc định là 0.5 kg/tuần
    _pace = 0.5;

    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.pace > 0) {
        setState(() {
          // Tìm giá trị gần nhất trong paceValues
          double closestPace = paceValues.reduce((value, element) {
            return (value - userData.pace).abs() < (element - userData.pace).abs() ? value : element;
          });
          _pace = closestPace;
        });
      } else {
        // Nếu không có giá trị trong provider, đặt giá trị mặc định và lưu lại
        Provider.of<UserDataProvider>(context, listen: false).setPace(_pace);
      }
    });
  }

  // Format số thập phân sang chuỗi với dấu phẩy thay dấu chấm
  String formatDecimal(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  // Hàm tìm giá trị pace gần nhất từ slider
  double findClosestPace(double sliderValue) {
    double normalizedValue = sliderValue / 100 * 1.25 + 0.25; // Map 0-100 to 0.25-1.50
    double closestPace = paceValues.reduce((value, element) {
      return (value - normalizedValue).abs() < (element - normalizedValue).abs() ? value : element;
    });
    return closestPace;
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
                      child: Column(
                        children: [
                          Text(
                            formatDecimal(_pace),
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: OnboardingStyles.accentColor,
                            ),
                          ),
                          Text(
                            'kg/tuần',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Stack(
                        children: [
                          // Các vạch chia và số
                          Positioned.fill(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Hiển thị các số
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      5,
                                      (index) {
                                        // Hiển thị 5 giá trị gần với giá trị đã chọn
                                        double baseValue = _pace - 0.1;
                                        if (baseValue < 0.25) baseValue = 0.25;
                                        if (baseValue > 1.00) baseValue = 1.00;

                                        double value = baseValue + (index * 0.05);
                                        if (value < 0.25) return const SizedBox.shrink();
                                        if (value > 1.25) return const SizedBox.shrink();

                                        return Text(
                                          formatDecimal(value),
                                          style: TextStyle(
                                            fontSize: (value - _pace).abs() < 0.01 ? 18 : 12,
                                            color: (value - _pace).abs() < 0.01
                                                ? OnboardingStyles.primaryColor
                                                : Colors.grey.shade400,
                                            fontWeight: (value - _pace).abs() < 0.01
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Tạo các vạch chia
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Các vạch nhỏ
                                    Container(
                                      height: 60,
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      width: double.infinity,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: List.generate(
                                          41,
                                          (index) {
                                            final bool isMainTick = index % 10 == 0;
                                            final bool isMiddleTick = index % 5 == 0 && !isMainTick;
                                            return Container(
                                              width: isMainTick ? 2 : (isMiddleTick ? 1.5 : 1),
                                              height: isMainTick ? 35 : (isMiddleTick ? 20 : 10),
                                              color: Colors.grey.shade300,
                                            );
                                          },
                                        ),
                                      ),
                                    ),

                                    // Vạch hiện tại (đánh dấu vị trí đã chọn)
                                    Center(
                                      child: Container(
                                        width: 3,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: OnboardingStyles.primaryColor,
                                          borderRadius: BorderRadius.circular(1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: OnboardingStyles.primaryColor.withOpacity(0.3),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // HorizontalPicker để xử lý sự kiện vuốt
                          Positioned.fill(
                            child: HorizontalPicker(
                              minValue: 0,
                              maxValue: 100,
                              divisions: 100,
                              height: 120,
                              suffix: "",
                              showCursor: false,
                              backgroundColor: Colors.transparent,
                              activeItemTextColor: Colors.transparent,
                              passiveItemsTextColor: Colors.transparent,
                              onChanged: (value) {
                                double newPace = findClosestPace(value);
                                setState(() {
                                  _pace = newPace;
                                });
                                // Lưu giá trị vào provider
                                Provider.of<UserDataProvider>(context, listen: false).setPace(_pace);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Vuốt sang trái/phải để chọn tốc độ',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
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