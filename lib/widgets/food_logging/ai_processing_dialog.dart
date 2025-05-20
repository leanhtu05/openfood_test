import 'package:flutter/material.dart';

class AIProcessingDialog extends StatelessWidget {
  final int currentStep;
  
  const AIProcessingDialog({
    Key? key,
    required this.currentStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Phân tích bữa ăn bằng AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            _buildAIProcessStep(
              icon: Icons.image,
              title: 'Tiền xử lý ảnh',
              description: 'Chuẩn hóa ảnh, tăng độ tương phản, loại bỏ nhiễu...',
              isActive: currentStep >= 1,
              isProcessing: currentStep == 1,
            ),
            
            _buildStepConnector(),
            
            _buildAIProcessStep(
              icon: Icons.food_bank,
              title: 'Nhận diện món ăn',
              description: 'AI phân tích và nhận diện các loại thực phẩm trong ảnh',
              isActive: currentStep >= 2,
              isProcessing: currentStep == 2,
            ),
            
            _buildStepConnector(),
            
            _buildAIProcessStep(
              icon: Icons.scale,
              title: 'Ước tính khẩu phần',
              description: 'Phân tích kích thước và ước tính khối lượng từng món',
              isActive: currentStep >= 3,
              isProcessing: currentStep == 3,
            ),
            
            _buildStepConnector(),
            
            _buildAIProcessStep(
              icon: Icons.calculate,
              title: 'Tính toán dinh dưỡng',
              description: 'Tính toán calo, protein, carbs, chất béo từ dữ liệu nhận diện',
              isActive: currentStep >= 4,
              isProcessing: currentStep == 4,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAIProcessStep({
    required IconData icon,
    required String title,
    required String description,
    required bool isActive,
    required bool isProcessing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: isProcessing
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                )
              : Icon(
                  isActive ? (isProcessing ? Icons.hourglass_empty : Icons.check) : icon,
                  color: isActive ? Colors.white : Colors.grey,
                ),
        ),
        SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.black : Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.grey[700] : Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStepConnector() {
    return Container(
      margin: EdgeInsets.only(left: 20),
      height: 20,
      width: 2,
      color: Colors.grey.withOpacity(0.3),
    );
  }
} 