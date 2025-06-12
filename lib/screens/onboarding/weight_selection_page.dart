import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';
import 'dart:async'; // Thêm import Timer

// Import thêm InitialPosition từ package horizontal_picker
import 'package:horizontal_picker/horizontal_picker.dart' show InitialPosition;


class WeightSelectionPage extends StatefulWidget {
  final bool updateMode;
  
  const WeightSelectionPage({
    Key? key, 
    this.updateMode = false
  }) : super(key: key);

  @override
  State<WeightSelectionPage> createState() => _WeightSelectionPageState();
}

class _WeightSelectionPageState extends State<WeightSelectionPage> with SingleTickerProviderStateMixin {
  double weightKg = 50.0;
  String unit = 'kg'; // 'kg' hoặc 'lbs'
  double heightCm = 166; // Giả sử đã có từ trang trước đó
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  double _currentScale = 1.0;
  bool _isInitialized = false;
  Timer? _debounceTimer; // Thêm timer để debounce thông báo
  
  @override
  void initState() {
    super.initState();
    
    // Đặt giá trị mặc định là 50kg ngay từ đầu
    weightKg = 50.0;
    
    // Khởi tạo AnimationController cho animation nhân vật
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    // Khởi tạo animation kích thước nhân vật
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final userData = Provider.of<UserDataProvider>(context, listen: false);
          if (mounted) {
            setState(() {
              // Đảm bảo cân nặng có giá trị trong khoảng hợp lệ (40-150)
              weightKg = userData.weightKg > 0 ? userData.weightKg : 50.0;
              if (weightKg < 40) weightKg = 40;
              if (weightKg > 150) weightKg = 150;
              heightCm = userData.heightCm;

              // Thiết lập kích thước ban đầu
              _calculateScaleFactor(weightKg);
            });
          }
        } catch (e) {
          // Fallback nếu không thể truy cập Provider
          print('Error accessing UserDataProvider: $e');
          if (mounted) {
            setState(() {
              weightKg = 50.0;
              heightCm = 170.0;
              _calculateScaleFactor(weightKg);
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Khởi tạo dữ liệu từ provider một lần duy nhất
    if (!_isInitialized) {
      try {
        final userData = context.read<UserDataProvider>();
        setState(() {
          // Đảm bảo cân nặng có giá trị trong khoảng hợp lệ (40-150)
          weightKg = userData.weightKg > 0 ? userData.weightKg : 50.0;
          if (weightKg < 40) weightKg = 40;
          if (weightKg > 150) weightKg = 150;
          heightCm = userData.heightCm;

          // Thiết lập kích thước ban đầu
          _calculateScaleFactor(weightKg);
          _isInitialized = true;
        });

        // Lưu giá trị ban đầu vào provider (không hiển thị message)
        userData.setWeight(weightKg);
      } catch (e) {
        print('Error initializing weight data: $e');
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }
  
  // Format số thập phân sang chuỗi với dấu phẩy thay dấu chấm
  String formatDecimal(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
  
  // Hàm tính toán kích thước thay đổi theo cân nặng
  void _calculateScaleFactor(double weight) {
    // Tính toán kích thước dựa trên phạm vi cân nặng (40kg-150kg)
    // Ánh xạ phạm vi cân nặng vào phạm vi kích thước (0.8 đến 1.3)
    double newScale = 0.8 + ((weight - 40) / (150 - 40)) * 0.5;
    
    // Thiết lập animation mới
    _scaleAnimation = Tween<double>(
      begin: _currentScale,
      end: newScale,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Lưu kích thước mới
    _currentScale = newScale;
    
    // Thực hiện animation
    _animationController.forward(from: 0);
  }
  
  // Lưu dữ liệu vào provider
  void _saveWeight(double weight, {bool showMessage = false}) {
    if (!mounted) return;

    // Sử dụng context.read thay vì Provider.of để tránh lỗi
    try {
      context.read<UserDataProvider>().setWeight(weight);

      // Chỉ hiển thị thông báo khi ở chế độ update và được yêu cầu rõ ràng
      // Thêm debounce để tránh thông báo liên tục
      if (widget.updateMode && showMessage && mounted) {
        // Hủy timer cũ nếu có
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã cập nhật cân nặng thành công!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1), // Giảm thời gian hiển thị
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Error saving weight: $e');
      // Optionally show error message
      if (widget.updateMode && showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi khi cập nhật cân nặng'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
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

  // Hàm tính toán vị trí tương đối của marker BMI trên thang đo
  double _getBmiPosition(double containerWidth) {
    // Các mốc BMI và vị trí tương ứng
    const double minBmi = 15.0;
    const double maxBmi = 40.0;
    
    // Tính tỷ lệ vị trí dựa trên BMI
    double percentage = (bmi - minBmi) / (maxBmi - minBmi);
    percentage = percentage.clamp(0.0, 1.0);
    
    // Chuyển đổi thành vị trí thực tế (pixel) trên container
    return percentage * containerWidth;
  }

  // Hàm chuyển đổi kg sang lbs
  String get weightInLbs {
    return (weightKg * 2.20462).toStringAsFixed(1);
  }
  
  // Hàm hiển thị cân nặng theo đơn vị đã chọn
  String get displayWeight {
    if (unit == 'kg') {
      return formatDecimal(weightKg);
    } else {
      return '${weightInLbs.replaceAll('.', ',')} lbs';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nếu đang ở chế độ cập nhật, bọc trong Scaffold
    if (widget.updateMode) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Cập nhật cân nặng'),
          backgroundColor: OnboardingStyles.primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Material(
          color: Colors.white,
          child: _buildContent(context),
        ),
      );
    }
    
    // Trong luồng onboarding thông thường, đã có Scaffold từ OnboardingScreen
    return _buildContent(context);
  }
  
  // Tách nội dung thành phương thức riêng để có thể tái sử dụng
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Diet',
                                style: OnboardingStyles.appTitleStyle.copyWith(
                                  color: OnboardingStyles.titleColor,
                                ),
                              ),
                              Text(
                                'AI',
                                style: OnboardingStyles.appTitleStyle.copyWith(
                                  color: OnboardingStyles.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Biểu tượng cân
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: Image.asset(
                              'assets/images/weight_scale.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.monitor_weight_outlined,
                                  size: 80,
                                  color: Colors.black54,
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
                        Icons.monitor_weight_outlined,
                        size: 80,
                        color: OnboardingStyles.accentColor,
                      ),
                    ),
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      widget.updateMode ? 'Cập nhật cân nặng' : 'Cân nặng của bạn là bao nhiêu?',
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
                                // Khi đổi đơn vị, cần rebuild để cập nhật suffix
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
                                // Khi đổi đơn vị, cần rebuild để cập nhật suffix
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
                  const SizedBox(height: 30),
                  
                  // Hiển thị BMI
                  if (heightCm > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Chỉ số khối cơ thể (BMI) của bạn là',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bmi.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: OnboardingStyles.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'BMI của bạn cho thấy bạn đang ${bmiCategory.toLowerCase()}!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Hiển thị thang đo BMI
                          SizedBox(
                            height: 30,
                            child: Stack(
                              children: [
                                // Thanh nền
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue,       // Thiếu cân
                                        Colors.green,      // Bình thường
                                        Colors.orange,     // Thừa cân
                                        Colors.red,        // Béo phì
                                        Colors.red.shade900, // Béo phì nguy hiểm
                                      ],
                                      stops: const [0.14, 0.4, 0.6, 0.8, 1.0], // Thiếu cân (<18.5), Bình thường (18.5-25), Thừa cân (25-30), Béo phì (30-35), Béo phì nguy hiểm (>35)
                                    ),
                                  ),
                                ),
                                
                                // Marker vị trí BMI hiện tại
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Positioned(
                                      left: _getBmiPosition(constraints.maxWidth),
                                      top: 0,
                                      child: Container(
                                        width: 8,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: bmiColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: bmiColor.withOpacity(0.6),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                ),
                                
                                // Các giá trị tham chiếu
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('<18.5', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text('25', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text('30', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text('35', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text('40', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Thiếu cân', style: TextStyle(fontSize: 10, color: Colors.blue)),
                              Text('Bình thường', style: TextStyle(fontSize: 10, color: OnboardingStyles.primaryColor)),
                              Text('Thừa cân', style: TextStyle(fontSize: 10, color: Colors.orange)),
                              Text('Béo phì', style: TextStyle(fontSize: 10, color: Colors.red)),
                              Text('Béo phì nghiêm trọng', style: TextStyle(fontSize: 10, color: Colors.red.shade900)),
                            ],
                          ),
                        ],
                      ),
                    ),
              
                
                  const SizedBox(height: 10),
                  
                  // Hiển thị cân nặng đã chọn
                  Text(
                    displayWeight,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: OnboardingStyles.accentColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Thay thế CupertinoPicker đơn giản bằng phiên bản có màu sắc đẹp hơn
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
                                      final double value = weightKg - 0.2 + (index * 0.1);
                                      return Text(
                                        formatDecimal(value),
                                        style: TextStyle(
                                          fontSize: (value - weightKg).abs() < 0.01 ? 18 : 12,
                                          color: (value - weightKg).abs() < 0.01 
                                              ? OnboardingStyles.primaryColor 
                                              : Colors.grey.shade400,
                                          fontWeight: (value - weightKg).abs() < 0.01 
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
                        
                        // HorizontalPicker trong suốt để xử lý thao tác vuốt
                        Positioned.fill(
                          child: GestureDetector(
                            // Xử lý trượt ngang
                            onHorizontalDragUpdate: (details) {
                              // Thêm dấu âm để đảo ngược hướng: lướt phải tăng, lướt trái giảm
                              final delta = -details.delta.dx * 0.1;
                              setState(() {
                                double newWeight = weightKg + delta;
                                if (newWeight >= 40 && newWeight <= 150) {
                                  weightKg = newWeight;
                                  _calculateScaleFactor(weightKg);
                                }
                              });
                              _saveWeight(weightKg, showMessage: widget.updateMode);
                            },
                            // Widget trong suốt để bắt sự kiện vuốt
                            child: Container(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Thêm chú thích
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Vuốt sang trái/phải để chọn cân nặng',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
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
  
  // Phương thức để chuyển đến trang tiếp theo
  void _continueToNextStep() {
    // Lưu cân nặng một lần nữa trước khi chuyển trang
    _saveWeight(weightKg, showMessage: true);
    
    // Chuyển tới bước tiếp theo trong quy trình onboarding

  }

} 