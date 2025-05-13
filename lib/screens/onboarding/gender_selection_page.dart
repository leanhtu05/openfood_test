import 'package:flutter/material.dart';

class GenderSelectionPage extends StatefulWidget {
  const GenderSelectionPage({Key? key}) : super(key: key);

  @override
  State<GenderSelectionPage> createState() => _GenderSelectionPageState();
}

class _GenderSelectionPageState extends State<GenderSelectionPage> {
  String? selectedGender;

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
                  const SizedBox(height: 16),
                  
                  // Logo và Biểu tượng
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                        
                        // Biểu tượng giới tính
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: Image.asset(
                            'assets/images/gender_icon.png',
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.wc,
                                size: 100,
                                color: Colors.indigo,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Tiêu đề
                  const Center(
                    child: Text(
                      'Giới tính của bạn là gì?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Lựa chọn giới tính
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Nam
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedGender = 'Nam';
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selectedGender == 'Nam' ? Colors.blue : Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/male_avatar.png',
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.man,
                                      size: 100,
                                      color: Colors.blue[700],
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Nam',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Nữ
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedGender = 'Nữ';
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selectedGender == 'Nữ' ? Colors.pink : Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/female_avatar.png',
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.woman,
                                      size: 100,
                                      color: Colors.pink,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Nữ',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Văn bản giải thích
                  const Text(
                    'Chúng tôi sử dụng giới tính của bạn để thiết kế kế hoạch ăn kiêng tốt nhất cho bạn. Nếu bạn không xác định mình là bất kỳ lựa chọn nào trong số này, vui lòng chọn giới tính gần nhất với hồ sơ nội tiết tố của bạn.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
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