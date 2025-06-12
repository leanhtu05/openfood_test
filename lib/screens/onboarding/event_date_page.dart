import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class EventDatePage extends StatefulWidget {
  const EventDatePage({Key? key}) : super(key: key);

  @override
  State<EventDatePage> createState() => _EventDatePageState();
}

class _EventDatePageState extends State<EventDatePage> with SingleTickerProviderStateMixin {
  int selectedDay = 10;
  int selectedMonth = 8;
  int selectedYear = 2025;
  
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Khởi tạo ScrollControllers
    _dayController = FixedExtentScrollController(initialItem: 9); // 10 - 1
    _monthController = FixedExtentScrollController(initialItem: 7); // 8 - 1
    _yearController = FixedExtentScrollController(initialItem: 5); // 2025 - 2020
    
    // Khởi tạo AnimationController
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    // Khởi tạo animation
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.eventDay > 0) {
        setState(() {
          selectedDay = userData.eventDay;
          selectedMonth = userData.eventMonth;
          selectedYear = userData.eventYear;
          
          // Cập nhật vị trí của ScrollController
          _dayController.jumpToItem(selectedDay - 1);
          _monthController.jumpToItem(selectedMonth - 1);
          _yearController.jumpToItem(selectedYear - 2020);
        });
      }
      
      // Chạy hiệu ứng ngay khi trang được khởi tạo
      _animationController.forward();
    });
  }
  
  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  // Lưu dữ liệu vào provider
  void _saveEventDate() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.eventDay = selectedDay;
    userData.eventMonth = selectedMonth;
    userData.eventYear = selectedYear;
    
    // Kích hoạt animation khi ngày tháng năm được cập nhật
    _animationController.forward(from: 0);
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
                children: [
                  // Logo và Biểu tượng
                  Center(
                    child: Column(
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
                        
                        // Biểu tượng lịch với hiệu ứng
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: SizedBox(
                                width: 80,
                                height: 80,
                                child: Image.asset(
                                  'assets/images/calendar_icon.png',
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.calendar_today,
                                      size: 80,
                                      color: Colors.black54,
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      'Sự kiện này sẽ diễn ra khi nào?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Hiển thị ngày tháng năm đã chọn
                  Center(
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: OnboardingStyles.primaryColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: OnboardingStyles.primaryColor.withOpacity(0.2),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            '$selectedDay tháng $selectedMonth $selectedYear',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: OnboardingStyles.primaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Pickers ngày tháng năm đẹp hơn
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Chọn ngày
                        Expanded(
                          child: _buildBeautifulPicker(
                            controller: _dayController,
                            items: List.generate(31, (index) => index + 1),
                            selectedValue: selectedDay,
                            onValueChanged: (value) {
                              setState(() {
                                selectedDay = value;
                                _saveEventDate();
                              });
                            },
                            labelText: 'Ngày',
                          ),
                        ),
                        
                        // Đường phân cách
                        Container(
                          width: 1,
                          height: 150,
                          color: Colors.grey.shade300,
                        ),
                        
                        // Chọn tháng
                        Expanded(
                          child: _buildBeautifulPicker(
                            controller: _monthController,
                            items: List.generate(12, (index) => index + 1),
                            selectedValue: selectedMonth,
                            onValueChanged: (value) {
                              setState(() {
                                selectedMonth = value;
                                _saveEventDate();
                              });
                            },
                            labelText: 'Tháng',
                          ),
                        ),
                        
                        // Đường phân cách
                        Container(
                          width: 1,
                          height: 150,
                          color: Colors.grey.shade300,
                        ),
                        
                        // Chọn năm
                        Expanded(
                          child: _buildBeautifulPicker(
                            controller: _yearController,
                            items: List.generate(10, (index) => 2020 + index),
                            selectedValue: selectedYear,
                            onValueChanged: (value) {
                              setState(() {
                                selectedYear = value;
                                _saveEventDate();
                              });
                            },
                            labelText: 'Năm',
                          ),
                        ),
                      ],
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
  
  // Widget để tạo một bộ chọn đẹp
  Widget _buildBeautifulPicker({
    required FixedExtentScrollController controller,
    required List<int> items,
    required int selectedValue,
    required Function(int) onValueChanged,
    String labelText = '',
  }) {
    return Container(
      height: 160,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        children: [
          // Thanh chỉ báo vùng đang được chọn
          Positioned.fill(
            child: Center(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: OnboardingStyles.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          // Tên nhãn
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                labelText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          
          // CupertinoPicker
          CupertinoPicker(
            magnification: 1.2,
            squeeze: 1.0,
            useMagnifier: true,
            selectionOverlay: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(width: 1, color: Colors.transparent),
                  bottom: BorderSide(width: 1, color: Colors.transparent),
                ),
              ),
            ),
            itemExtent: 50.0,
            scrollController: controller,
            onSelectedItemChanged: (int selectedItemIndex) {
              onValueChanged(items[selectedItemIndex]);
            },
            children: List<Widget>.generate(items.length, (int index) {
              final value = items[index];
              final isSelected = value == selectedValue;
              
              return Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected 
                      ? OnboardingStyles.primaryColor 
                      : (value % 5 == 0) 
                          ? Colors.black54 
                          : Colors.black38,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
} 