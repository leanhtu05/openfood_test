import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';

class WeightSelectionPage extends StatefulWidget {
  const WeightSelectionPage({Key? key}) : super(key: key);

  @override
  State<WeightSelectionPage> createState() => _WeightSelectionPageState();
}

class _WeightSelectionPageState extends State<WeightSelectionPage> {
  double weightKg = 54;
  String unit = 'kg'; // 'kg' hoặc 'lbs'
  double heightCm = 166; // Giả sử đã có từ trang trước đó
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        weightKg = userData.weightKg;
        heightCm = userData.heightCm;
      });
    });
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
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
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
                        
                        // Biểu tượng cân
                        Container(
                          width: 150,
                          height: 150,
                          child: Image.asset(
                            'assets/images/weight_scale.png',
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.monitor_weight_outlined,
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
                      'Cân nặng của bạn là bao nhiêu?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
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
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: unit == 'kg' ? Colors.green : Colors.transparent,
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
                                // Chuyển đổi kg sang lbs nếu cần
                                if (unit == 'lbs') {
                                  weightKg = weightKg * 0.453592;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: unit == 'lbs' ? Colors.green : Colors.transparent,
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
                  
                  // Hiển thị chỉ số BMI
                  Center(
                    child: Container(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Chỉ số khối cơ thể (BMI) của bạn là',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${bmi.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children: [
                              Text(
                                'BMI của bạn cho thấy bạn đang',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bmiCategory.toLowerCase() + '!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: bmiColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          
                          // Hiển thị cân nặng đã chọn
                          Text(
                            '${weightKg.toInt()} kg',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
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
                              min: 30,
                              max: 150,
                              value: weightKg,
                              onChanged: (value) {
                                setState(() {
                                  weightKg = value;
                                });
                              },
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
  
  Widget _buildBmiMarker(String value, String label, Color color, double position) {
    return Container(
      width: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 