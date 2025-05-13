import 'package:flutter/material.dart';

class TargetWeightPage extends StatefulWidget {
  const TargetWeightPage({Key? key}) : super(key: key);

  @override
  State<TargetWeightPage> createState() => _TargetWeightPageState();
}

class _TargetWeightPageState extends State<TargetWeightPage> {
  double targetWeightKg = 60;
  String unit = 'kg'; // 'kg' hoặc 'lbs'
  double heightCm = 166; // Giả sử đã có từ trang trước đó
  double currentWeightKg = 54; // Giả sử đã có từ trang trước đó
  
  double get targetBmi => targetWeightKg / ((heightCm / 100) * (heightCm / 100));
  double get percentChange => ((targetWeightKg - currentWeightKg) / currentWeightKg) * 100;
  
  String get targetBmiCategory {
    if (targetBmi < 18.5) return 'Thiếu cân';
    if (targetBmi < 25) return 'Bình thường';
    if (targetBmi < 30) return 'Thừa cân';
    if (targetBmi < 35) return 'Béo phì';
    return 'Béo phì nguy hiểm';
  }

  @override
  Widget build(BuildContext context) {
    final isGain = targetWeightKg > currentWeightKg;
    final changeText = isGain 
      ? 'Tăng ${percentChange.abs().toStringAsFixed(0)}% cân!'
      : 'Giảm ${percentChange.abs().toStringAsFixed(0)}% cân!';
    final changeAmount = isGain
      ? '${(targetWeightKg - currentWeightKg).toInt()} kg'
      : '${(currentWeightKg - targetWeightKg).toInt()} kg';
      
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                      
                      // Biểu tượng mục tiêu
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: Image.asset(
                          'assets/images/target_flag.png',
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.flag,
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
                    'Cân nặng mục tiêu của bạn là bao nhiêu?',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
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
                
                // Thông báo về thay đổi cân nặng
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.blue,
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
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bạn sẽ ${isGain ? 'tăng' : 'giảm'} $changeAmount để đạt được cân nặng mục tiêu',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // Thanh BMI
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _buildBmiMarker('18.5', 'Thiếu cân'),
                    _buildBmiMarker('25.0', 'Bình thường'),
                    _buildBmiMarker('30.0', 'Thừa cân'),
                    _buildBmiMarker('35.0', 'Béo phì'),
                    _buildBmiMarker('', 'Béo phì nguy hiểm'),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Thanh BMI màu sắc
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.brown],
                          stops: [0.18, 0.40, 0.60, 0.80, 1.0],
                        ),
                      ),
                    ),
                    // Vạch chỉ thị BMI mục tiêu
                    Positioned(
                      left: (targetBmi - 15) / 25 * MediaQuery.of(context).size.width,
                      child: Container(
                        width: 3,
                        height: 16,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Hiển thị cân nặng mục tiêu
                Center(
                  child: Text(
                    '${targetWeightKg.toInt()} kg',
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                
                // Thanh trượt
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.green,
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: Colors.green,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 30.0),
                    trackHeight: 8.0,
                  ),
                  child: Slider(
                    min: 40,
                    max: 120,
                    value: targetWeightKg,
                    onChanged: (value) {
                      setState(() {
                        targetWeightKg = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildBmiMarker(String value, String label) {
    return SizedBox(
      width: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 