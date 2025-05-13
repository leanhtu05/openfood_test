import 'package:flutter/material.dart';

class HeightSelectionPage extends StatefulWidget {
  const HeightSelectionPage({Key? key}) : super(key: key);

  @override
  State<HeightSelectionPage> createState() => _HeightSelectionPageState();
}

class _HeightSelectionPageState extends State<HeightSelectionPage> {
  double heightCm = 166;
  String unit = 'cm'; // 'cm' hoặc 'ft'

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
                        
                        // Biểu tượng đo chiều cao
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: Image.asset(
                            'assets/images/height_icon.png',
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.height,
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
                      'Chiều cao của bạn là bao nhiêu?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
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
                          // Chọn cm
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                unit = 'cm';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: unit == 'cm' ? Colors.green : Colors.transparent,
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              child: Text(
                                'cm',
                                style: TextStyle(
                                  color: unit == 'cm' ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          // Chọn ft
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                unit = 'ft';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: unit == 'ft' ? Colors.green : Colors.transparent,
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              child: Text(
                                'ft',
                                style: TextStyle(
                                  color: unit == 'ft' ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Hiển thị chiều cao đã chọn
                  Center(
                    child: Text(
                      '${heightCm.toInt()} cm',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Thanh trượt chiều cao với người hình hoạt họa
                  SizedBox(
                    height: 200,
                    child: Stack(
                      children: [
                        // Thước đo chiều cao
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: SizedBox(
                            width: 40,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                final value = 190 - index * 10;
                                return SizedBox(
                                  height: 20,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 1,
                                        color: Colors.grey,
                                      ),
                                      Text(
                                        '$value',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        
                        // Người hình hoạt họa
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 150,
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      Image.asset(
                                        'assets/images/height_avatar.png',
                                        height: 120,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.person,
                                            size: 100,
                                            color: Colors.blue,
                                          );
                                        },
                                      ),
                                      // Thanh xanh indicator chiều cao
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          height: 2,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Thanh trượt
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: Colors.blue,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 30.0),
                      trackHeight: 8.0,
                    ),
                    child: Slider(
                      min: 140,
                      max: 200,
                      value: heightCm,
                      onChanged: (value) {
                        setState(() {
                          heightCm = value;
                        });
                      },
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