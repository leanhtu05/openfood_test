import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/water_provider.dart';
import '../providers/food_provider.dart';

class DaySelector extends StatelessWidget {
  final int selectedDay;
  final Function(int) onDaySelected;
  final String? selectedDate;
  final Function(String)? onDateChanged;
  final bool useFullDateSelector;
  
  // Add a variable to track selected month and year for synchronization
  static DateTime? _lastSelectedDateTime;

  const DaySelector({
    Key? key,
    required this.selectedDay,
    required this.onDaySelected,
    this.selectedDate,
    this.onDateChanged,
    this.useFullDateSelector = false,
  }) : super(key: key);

  /// Constructor mới hỗ trợ chọn ngày đầy đủ như DateSelector cũ
  factory DaySelector.fullDate({
    required String selectedDate,
    required Function(String) onDateChanged,
  }) {
    final day = DateTime.parse(selectedDate).day;
    return DaySelector(
      selectedDay: day,
      onDaySelected: (_) {}, // Không sử dụng vì chúng ta dùng onDateChanged
      selectedDate: selectedDate,
      onDateChanged: onDateChanged,
      useFullDateSelector: true,
    );
  }

  /// Phương thức tĩnh để lấy DateTime đầy đủ từ ngày đã chọn
  static DateTime getSelectedDateWithDay(int day) {
    final now = DateTime.now();
    
    // Nếu chưa có _lastSelectedDateTime, sử dụng tháng và năm hiện tại
    if (_lastSelectedDateTime == null) {
      return DateTime(now.year, now.month, day);
    }
    
    // Sử dụng tháng và năm từ _lastSelectedDateTime và ngày được chọn
    return DateTime(_lastSelectedDateTime!.year, _lastSelectedDateTime!.month, day);
  }
  
  /// Phương thức tĩnh để cập nhật _lastSelectedDateTime từ bên ngoài
  static void updateSelectedDateTime(DateTime dateTime) {
    _lastSelectedDateTime = dateTime;
    print('DaySelector: Updated _lastSelectedDateTime to ${_lastSelectedDateTime.toString()}');
  }

  void _selectDate(BuildContext context) async {
    if (!useFullDateSelector || selectedDate == null) return;
    
    // Lấy ngày hiện tại để kiểm tra
    final initialDate = DateTime.parse(selectedDate!);
    
    // Đảm bảo lastDate đủ xa trong tương lai
    final currentYear = DateTime.now().year;
    final lastDate = DateTime(currentYear + 5, 12, 31); // Năm hiện tại + 5 năm
    
    // Đảm bảo initialDate không vượt quá lastDate
    final safeInitialDate = initialDate.isAfter(lastDate) ? lastDate : initialDate;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && onDateChanged != null) {
      final newDate = picked.toIso8601String().split('T')[0];
      onDateChanged!(newDate);
      
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      exerciseProvider.setSelectedDate(newDate);
      waterProvider.setSelectedDate(newDate);
      foodProvider.setSelectedDate(newDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (useFullDateSelector && selectedDate != null) {
      return _buildFullDateSelector(context);
    }
    
    // Create a DateTime object from the week containing the selected day
    final now = DateTime.now();
    
    // Track the current month/year - either from class state or use current month
    final currentYear = now.year;
    final currentMonth = now.month;
    
    // Initialize or update our tracking of the selected date including month/year
    if (_lastSelectedDateTime == null) {
      _lastSelectedDateTime = DateTime(currentYear, currentMonth, selectedDay);
    } else if (_lastSelectedDateTime!.day != selectedDay) {
      // If the day changed but we want to keep the previously selected month/year
      _lastSelectedDateTime = DateTime(_lastSelectedDateTime!.year, _lastSelectedDateTime!.month, selectedDay);
    }
    
    // Use our tracked date (with proper month/year) for calculations
    DateTime selectedDateTime = _lastSelectedDateTime!;
    
    // Calculate the first day of the week (Monday) containing the selected day
    int weekday = selectedDateTime.weekday;
    DateTime firstDayOfWeek = selectedDateTime.subtract(Duration(days: weekday - 1));
    
    // Generate the 7 days of the week
    List<DateTime> weekDays = List.generate(
      7, 
      (index) => firstDayOfWeek.add(Duration(days: index))
    );
    
    // Get month name for display - use the middle of the week as the representative
    final monthNames = ['', 'Th1', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6', 'Th7', 'Th8', 'Th9', 'Th10', 'Th11', 'Th12'];
    String monthName = monthNames[selectedDateTime.month];
    
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month and year header with navigation arrows
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: Colors.grey.shade600),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    // Navigate to previous week - directly select the day 7 days before
                    final previousWeekDay = firstDayOfWeek.subtract(Duration(days: 1));
                    // Update our tracking variable to include the month/year
                    _lastSelectedDateTime = previousWeekDay;
                    // Call the callback with just the day
                    onDaySelected(previousWeekDay.day);
                    
                    // Update all related data based on the selected date
                    _updateDataForSelectedDate(context, previousWeekDay);
                  },
                ),
                
                GestureDetector(
                  onTap: () => _showDatePickerDialog(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      "$monthName, ${selectedDateTime.year}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                IconButton(
                  icon: Icon(Icons.chevron_right, color: Colors.grey.shade600),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    // Navigate to next week - directly select the day 7 days ahead
                    final nextWeekDay = weekDays.last.add(Duration(days: 1));
                    // Update our tracking variable to include the month/year
                    _lastSelectedDateTime = nextWeekDay;
                    // Call the callback with just the day
                    onDaySelected(nextWeekDay.day);
                    
                    // Update all related data based on the selected date
                    _updateDataForSelectedDate(context, nextWeekDay);
                  },
                ),
              ],
            ),
          ),
          
          // Days row with T2-CN labels and numbers
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: weekDays.map((day) {
                final dayLabels = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                final dayLabel = dayLabels[day.weekday];
                final isSelected = day.day == selectedDay && 
                                  day.month == selectedDateTime.month && 
                                  day.year == selectedDateTime.year;
                
                return _buildSimpleDayItem(
                  context,  // Pass context to _buildSimpleDayItem
                  dayLabel, 
                  day.day.toString(), 
                  day.day,
                  isSelected: isSelected,
                  isCurrentMonth: day.month == selectedDateTime.month
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullDateSelector(BuildContext context) {
    final today = DateTime.now();
    final weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final List<DateTime> dates = [];
    
    // Lấy ngày được chọn hiện tại
    final DateTime selectedDateTime = DateTime.parse(selectedDate!);
    
    // Tìm ngày đầu tuần
    final currentWeekday = selectedDateTime.weekday;
    final firstDayOfWeek = selectedDateTime.subtract(Duration(days: currentWeekday - 1));
    
    // Tạo danh sách 7 ngày
    for (int i = 0; i < 7; i++) {
      dates.add(firstDayOfWeek.add(Duration(days: i)));
    }
    
    // Định dạng tháng/năm
    final startMonth = dates.first.month;
    final endMonth = dates.last.month;
    final startYear = dates.first.year;
    final endYear = dates.last.year;
    
    // Danh sách tên tháng ngắn gọn
    final monthNames = [
      '', 'Th1', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6',
      'Th7', 'Th8', 'Th9', 'Th10', 'Th11', 'Th12'
    ];
    
    // Tạo chuỗi hiển thị tháng nhỏ gọn
    String monthDisplay;
    if (startMonth == endMonth && startYear == endYear) {
      monthDisplay = '${monthNames[startMonth]}, $startYear';
    } else if (startYear == endYear) {
      monthDisplay = '${monthNames[startMonth]} - ${monthNames[endMonth]}, $startYear';
    } else {
      monthDisplay = '${monthNames[startMonth]}/$startYear - ${monthNames[endMonth]}/$endYear';
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Layout tháng năm và nút điều hướng trong cùng một hàng
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nút mũi tên trái
                IconButton(
                  icon: Icon(Icons.chevron_left, color: Colors.black54, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    if (onDateChanged != null) {
                      final newDate = selectedDateTime.subtract(Duration(days: 7));
                      final newDateString = newDate.toIso8601String().split('T')[0];
                      onDateChanged!(newDateString);
                      
                      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
                      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
                      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                      
                      exerciseProvider.setSelectedDate(newDateString);
                      waterProvider.setSelectedDate(newDateString);
                      foodProvider.setSelectedDate(newDateString);
                    }
                  },
                ),
                
                // Phần hiển thị tháng và năm ở giữa
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        monthDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                
                // Nút mũi tên phải
                IconButton(
                  icon: Icon(Icons.chevron_right, color: Colors.black54, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    if (onDateChanged != null) {
                      final newDate = selectedDateTime.add(Duration(days: 7));
                      final newDateString = newDate.toIso8601String().split('T')[0];
                      onDateChanged!(newDateString);
                      
                      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
                      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
                      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                      
                      exerciseProvider.setSelectedDate(newDateString);
                      waterProvider.setSelectedDate(newDateString);
                      foodProvider.setSelectedDate(newDateString);
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Phần ngày trong tuần
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final currentDate = dates[index];
                final dateString = currentDate.toIso8601String().split('T')[0];
                final isSelected = dateString == selectedDate;
                final isToday = currentDate.day == today.day && 
                              currentDate.month == today.month && 
                              currentDate.year == today.year;
                final isDifferentMonth = selectedDateTime.month != currentDate.month;
                
                return GestureDetector(
                  onTap: () {
                    if (onDateChanged != null) {
                      final newDateString = currentDate.toIso8601String().split('T')[0];
                      onDateChanged!(newDateString);
                      
                      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
                      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
                      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                      
                      exerciseProvider.setSelectedDate(newDateString);
                      waterProvider.setSelectedDate(newDateString);
                      foodProvider.setSelectedDate(newDateString);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tên ngày
                      Text(
                        weekdays[index],
                        style: TextStyle(
                          color: isSelected 
                            ? AppColors.secondary 
                            : (isDifferentMonth ? Colors.grey.shade400 : Colors.grey),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      // Số ngày
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.secondary : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected 
                            ? Border.all(color: AppColors.secondary, width: 1.5)
                            : null,
                        ),
                        child: Center(
                          child: Text(
                            '${currentDate.day}',
                            style: TextStyle(
                              color: isSelected 
                                  ? Colors.white 
                                  : (isToday 
                                     ? AppColors.secondary 
                                     : (isDifferentMonth ? Colors.grey.shade400 : Colors.black87)),
                              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Show date picker dialog when tapping on month/year
  void _showDatePickerDialog(BuildContext context) async {
    final now = DateTime.now();
    
    // Use our tracked date with correct month/year for initializing the picker
    final initialDate = _lastSelectedDateTime ?? DateTime(now.year, now.month, selectedDay);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.secondary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      // Update our tracking variable to include the selected month/year
      _lastSelectedDateTime = picked;
      // Call the callback with just the day
      onDaySelected(picked.day);
      
      // Update all related data based on the selected date
      _updateDataForSelectedDate(context, picked);
    }
  }

  // Method to synchronize data with the selected date
  void _updateDataForSelectedDate(BuildContext context, DateTime selectedDate) {
    // Format the date string for providers
    final dateString = selectedDate.toIso8601String().split('T')[0];
    
    // Update all providers with the new selected date
    final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    // Set the selected date in all providers to update their data
    exerciseProvider.setSelectedDate(dateString);
    waterProvider.setSelectedDate(dateString);
    foodProvider.setSelectedDate(dateString);
    
    // If there's a specific callback for date changes, call it
    if (onDateChanged != null) {
      onDateChanged!(dateString);
    }
  }

  Widget _buildSimpleDayItem(
    BuildContext context,  // Add context parameter
    String dayLabel, 
    String dayNumber, 
    int day, 
    {required bool isCurrentMonth, bool isSelected = false}
  ) {
    return GestureDetector(
      onTap: () {
        // When a day is tapped, we need to:
        // 1. Create a new DateTime with the correct month and year
        // 2. Update our tracking variable
        // 3. Call the onDaySelected callback
        
        if (_lastSelectedDateTime != null) {
          // If the day is from a different month than the displayed month,
          // adjust the month accordingly
          DateTime selectedDate;
          if (!isCurrentMonth) {
            // Find the date for this specific day, considering it could be previous or next month
            // This logic assumes the week always has 7 days
            int diff = day - _lastSelectedDateTime!.day;
            if (diff > 15) {
              // This is probably from the previous month
              selectedDate = DateTime(_lastSelectedDateTime!.year, _lastSelectedDateTime!.month - 1, day);
            } else if (diff < -15) {
              // This is probably from the next month
              selectedDate = DateTime(_lastSelectedDateTime!.year, _lastSelectedDateTime!.month + 1, day);
            } else {
              // This is from the current month
              selectedDate = DateTime(_lastSelectedDateTime!.year, _lastSelectedDateTime!.month, day);
            }
          } else {
            selectedDate = DateTime(_lastSelectedDateTime!.year, _lastSelectedDateTime!.month, day);
          }
          
          // Update our tracking variable
          _lastSelectedDateTime = selectedDate;
          
          // Call the callback with just the day
          onDaySelected(day);
          
          // Update all related data based on the selected date
          _updateDataForSelectedDate(context, selectedDate);
        } else {
          // Fallback if no tracking variable is available
          onDaySelected(day);
        }
      },
      child: Container(
        width: 40,
        child: Column(
          children: [
            Text(
              dayLabel,
              style: TextStyle(
                color: isSelected 
                    ? AppColors.secondary 
                    : (isCurrentMonth ? Colors.grey : Colors.grey.shade300),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  dayNumber,
                  style: TextStyle(
                    color: isSelected 
                        ? Colors.white 
                        : (isCurrentMonth ? Colors.black : Colors.grey.shade400),
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}