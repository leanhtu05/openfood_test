import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';

class AgeSelectionPage extends StatefulWidget {
  const AgeSelectionPage({Key? key}) : super(key: key);

  @override
  State<AgeSelectionPage> createState() => _AgeSelectionPageState();
}

class _AgeSelectionPageState extends State<AgeSelectionPage> {
  int selectedAge = 23;
  
  @override
  void initState() {
    super.initState();
    // Lấy tuổi từ provider nếu đã có
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        selectedAge = userData.age;
      });
    });
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 8),
                  
                  // Logo và Biểu tượng
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'DietAI',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24204F),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Biểu tượng bánh sinh nhật
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Image.asset(
                            'assets/images/birthday_cake.png',
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.cake,
                                size: 80,
                                color: Colors.indigo,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Tiêu đề
                  const Center(
                    child: Text(
                      'Bạn bao nhiêu tuổi?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Chọn tuổi - Thiết kế selector
                  Center(
                    child: SizedBox(
                      height: 160,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tuổi trước đó
                          Opacity(
                            opacity: 0.3,
                            child: Text(
                              '${selectedAge - 2}',
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          
                          // Tuổi trước đó
                          Opacity(
                            opacity: 0.5,
                            child: Text(
                              '${selectedAge - 1}',
                              style: const TextStyle(
                                fontSize: 26,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          
                          // Tuổi đã chọn
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue, width: 2),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              '$selectedAge',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          
                          // Tuổi tiếp theo
                          Opacity(
                            opacity: 0.5,
                            child: Text(
                              '${selectedAge + 1}',
                              style: const TextStyle(
                                fontSize: 26,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          
                          // Tuổi tiếp theo
                          Opacity(
                            opacity: 0.3,
                            child: Text(
                              '${selectedAge + 2}',
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Thanh điều chỉnh tuổi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (selectedAge > 12) {
                            setState(() {
                              selectedAge--;
                            });
                            // Lưu giá trị vào provider
                            Provider.of<UserDataProvider>(context, listen: false).setAge(selectedAge);
                          }
                        },
                        icon: const Icon(Icons.remove_circle, size: 32, color: Colors.blue),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.blue,
                            inactiveTrackColor: Colors.grey.shade300,
                            thumbColor: Colors.blue,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
                            trackHeight: 6.0,
                          ),
                          child: Slider(
                            min: 12,
                            max: 80,
                            value: selectedAge.toDouble(),
                            onChanged: (value) {
                              setState(() {
                                selectedAge = value.toInt();
                              });
                              // Lưu giá trị vào provider
                              Provider.of<UserDataProvider>(context, listen: false).setAge(selectedAge);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (selectedAge < 80) {
                            setState(() {
                              selectedAge++;
                            });
                            // Lưu giá trị vào provider
                            Provider.of<UserDataProvider>(context, listen: false).setAge(selectedAge);
                          }
                        },
                        icon: const Icon(Icons.add_circle, size: 32, color: Colors.blue),
                      ),
                    ],
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