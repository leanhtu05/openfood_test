import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horizontal_picker/horizontal_picker.dart';
import 'package:horizontal_picker/horizontal_picker.dart' show InitialPosition;
import '../../providers/user_data_provider.dart';
import '../../styles/onboarding_styles.dart';
import 'onboarding_screen.dart' show MaterialOnboardingPage;

class TargetWeightPage extends StatefulWidget {
  final bool updateMode;

  const TargetWeightPage({
    Key? key,
    this.updateMode = false
  }) : super(key: key);

  @override
  State<TargetWeightPage> createState() => _TargetWeightPageState();
}

class _TargetWeightPageState extends State<TargetWeightPage> {
  double targetWeightKg = 50.0;
  String unit = 'kg'; // 'kg' hoặc 'lbs'
  double heightCm = 166; // Giả sử đã có từ trang trước đó
  double currentWeightKg = 54; // Giả sử đã có từ trang trước đó
  
  @override
  void initState() {
    super.initState();
    
    // Đặt giá trị mặc định là 50kg ngay từ đầu
    targetWeightKg = 50.0;
    
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        targetWeightKg = userData.targetWeightKg > 0 ? userData.targetWeightKg : 50.0;
        currentWeightKg = userData.weightKg;
        heightCm = userData.heightCm;
      });
    });
    
    // Đảm bảo lưu giá trị mặc định
    _saveTargetWeight();
  }
  
  // Lưu dữ liệu vào provider
  void _saveTargetWeight() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.targetWeightKg = targetWeightKg;

    // If in update mode, show success message
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật cân nặng mục tiêu thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
  
  // Format số thập phân sang chuỗi với dấu phẩy thay dấu chấm
  String formatDecimal(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final isGain = targetWeightKg > currentWeightKg;
    final changeText = isGain
      ? 'Tăng ${percentChange.abs().toStringAsFixed(0)}% cân!'
      : 'Giảm ${percentChange.abs().toStringAsFixed(0)}% cân!';
    final changeAmount = isGain
      ? '${(targetWeightKg - currentWeightKg).toStringAsFixed(1).replaceAll('.', ',')} kg'
      : '${(currentWeightKg - targetWeightKg).toStringAsFixed(1).replaceAll('.', ',')} kg';

    // Sử dụng MaterialOnboardingPage wrapper nếu ở chế độ updateMode
    if (widget.updateMode) {
      return MaterialOnboardingPage(
        title: 'Cập nhật cân nặng mục tiêu',
        child: _buildContent(context, isGain, changeText, changeAmount),
      );
    }

    // Trong luồng onboarding thông thường, trả về nội dung
    return _buildContent(context, isGain, changeText, changeAmount);
  }

  Widget _buildContent(BuildContext context, bool isGain, String changeText, String changeAmount) {
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
                  child: Column(
                    children: [
                      Text(
                        formatDecimal(targetWeightKg),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: OnboardingStyles.accentColor,
                        ),
                      ),
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Thay thế ListWheelScrollView bằng HorizontalPicker
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.grey.shade100,
                        Colors.white,
                        Colors.white,
                        Colors.grey.shade100,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Stack(
                      children: [
                        // Vạch chia
                        Positioned.fill(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Hiển thị các số
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    5,
                                    (index) {
                                      final double value = targetWeightKg - 0.2 + (index * 0.1);
                                      if (value < 40 || value > 150) return const SizedBox.shrink();
                                      return Text(
                                        formatDecimal(value),
                                        style: TextStyle(
                                          fontSize: (value - targetWeightKg).abs() < 0.01 ? 18 : 12,
                                          color: (value - targetWeightKg).abs() < 0.01
                                            ? OnboardingStyles.primaryColor
                                            : Colors.grey.shade400,
                                          fontWeight: (value - targetWeightKg).abs() < 0.01
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
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        
                        // Thay thế HorizontalPicker bằng GestureDetector để kiểm soát chính xác giá trị
                        GestureDetector(
                          // Xử lý trượt ngang
                          onHorizontalDragUpdate: (details) {
                            // Thêm dấu âm để đảo ngược hướng: lướt phải tăng, lướt trái giảm
                            final delta = -details.delta.dx * 0.1;
                            setState(() {
                              double newWeight = targetWeightKg + delta;
                              if (newWeight >= 40 && newWeight <= 150) {
                                targetWeightKg = newWeight;
                              }
                            });
                            _saveTargetWeight();
                          },
                          // Widget trong suốt để bắt sự kiện vuốt
                          child: Container(
                            height: 120,
                            color: Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Thêm chú thích
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Vuốt sang trái/phải để chọn cân nặng mục tiêu',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
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