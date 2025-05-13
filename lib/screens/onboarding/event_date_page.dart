import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nút quay lại
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                
                // Logo và Biểu tượng
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'DietAI',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF24204F),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Biểu tượng lịch
                      Container(
                        width: 150,
                        height: 150,
                        child: Image.asset(
                          'assets/images/calendar_icon.png',
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.calendar_today,
                              size: 100,
                              color: Colors.indigo,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // Tiêu đề
                const Center(
                  child: Text(
                    'Sự kiện này sẽ diễn ra khi nào?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 60),
                
                // Bộ chọn ngày tháng năm
                Container(
                  height: 300,
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
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDatePicker({
    required int selectedValue,
    required List<int> visibleValues,
    String prefix = '',
    required Function(int) onValueChanged,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: visibleValues.map((value) {
          final isSelected = value == selectedValue;
          
          return GestureDetector(
            onTap: () => onValueChanged(value),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: isSelected
                  ? BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(30),
                    )
                  : null,
              child: Text(
                '$prefix$value',
                style: TextStyle(
                  fontSize: isSelected ? 26 : 20,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
} 