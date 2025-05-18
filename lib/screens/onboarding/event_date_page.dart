import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class EventDatePage extends StatefulWidget {
  const EventDatePage({Key? key}) : super(key: key);

  @override
  State<EventDatePage> createState() => _EventDatePageState();
}

class _EventDatePageState extends State<EventDatePage> {
  int selectedDay = 10;
  int selectedMonth = 8;
  int selectedYear = 2025;
  
  final List<int> visibleDays = [9, 10, 11];
  final List<int> visibleMonths = [7, 8, 9];
  final List<int> visibleYears = [2024, 2025, 2026];
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.eventDay > 0) {
        setState(() {
          selectedDay = userData.eventDay;
          selectedMonth = userData.eventMonth;
          selectedYear = userData.eventYear;
          
          // Cập nhật các giá trị hiển thị
          visibleDays[0] = selectedDay - 1;
          visibleDays[1] = selectedDay;
          visibleDays[2] = selectedDay + 1;
          
          visibleMonths[0] = selectedMonth - 1;
          visibleMonths[1] = selectedMonth;
          visibleMonths[2] = selectedMonth + 1;
          
          visibleYears[0] = selectedYear - 1;
          visibleYears[1] = selectedYear;
          visibleYears[2] = selectedYear + 1;
        });
      }
    });
  }
  
  // Lưu dữ liệu vào provider
  void _saveEventDate() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.eventDay = selectedDay;
    userData.eventMonth = selectedMonth;
    userData.eventYear = selectedYear;
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
                        Text(
                          'DietAI',
                          style: OnboardingStyles.appTitleStyle,
                        ),
                        const SizedBox(height: 24),
                        
                        // Biểu tượng lịch
                        SizedBox(
                          width: OnboardingStyles.iconSize,
                          height: OnboardingStyles.iconSize,
                          child: Image.asset(
                            'assets/images/calendar_icon.png',
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.calendar_today,
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
                      'Sự kiện này sẽ diễn ra khi nào?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 60),
                  
                  // Bộ chọn ngày tháng năm
                  SizedBox(
                    height: 250,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Chọn ngày
                        _buildDatePicker(
                          selectedValue: selectedDay,
                          visibleValues: visibleDays,
                          onValueChanged: (value) {
                            setState(() {
                              selectedDay = value;
                            });
                            _saveEventDate();
                          },
                        ),
                        
                        // Chọn tháng
                        _buildDatePicker(
                          selectedValue: selectedMonth,
                          visibleValues: visibleMonths,
                          prefix: 'tháng ',
                          onValueChanged: (value) {
                            setState(() {
                              selectedMonth = value;
                            });
                            _saveEventDate();
                          },
                        ),
                        
                        // Chọn năm
                        _buildDatePicker(
                          selectedValue: selectedYear,
                          visibleValues: visibleYears,
                          onValueChanged: (value) {
                            setState(() {
                              selectedYear = value;
                            });
                            _saveEventDate();
                          },
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
  
  Widget _buildDatePicker({
    required int selectedValue,
    required List<int> visibleValues,
    String prefix = '',
    required Function(int) onValueChanged,
  }) {
    return Expanded(
      child: Container(
        height: 250,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: visibleValues.map((value) {
            final isSelected = value == selectedValue;
            
            return GestureDetector(
              onTap: () => onValueChanged(value),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: OnboardingStyles.accentColor, width: 2),
                        borderRadius: BorderRadius.circular(30),
                      )
                    : null,
                child: Text(
                  '$prefix$value',
                  style: TextStyle(
                    fontSize: isSelected ? 26 : 20,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? OnboardingStyles.accentColor : Colors.grey,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
} 