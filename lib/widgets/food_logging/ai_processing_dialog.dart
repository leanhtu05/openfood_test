import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/food_item.dart';

class AIProcessingDialog extends StatelessWidget {
  final String currentStep;
  final String? imagePath;
  final bool isProcessing;
  final String status;
  final List<FoodItem>? recognizedFoods;
  final Function(List<FoodItem>)? onComplete;
  final VoidCallback? onCancel;
  
  const AIProcessingDialog({
    Key? key,
    required this.currentStep,
    this.imagePath,
    this.isProcessing = true,
    this.status = 'Đang xử lý...',
    this.recognizedFoods,
    this.onComplete,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Đang phân tích thức ăn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            
            _buildProgressIndicator(),
            SizedBox(height: 20),
            
            _buildStepText(),
            SizedBox(height: 20),
            
            if (imagePath != null && imagePath!.isNotEmpty)
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: FileImage(File(imagePath!)),
                    fit: BoxFit.cover,
                  ),
                ),
                margin: EdgeInsets.only(bottom: 20),
              ),
              
            TextButton(
              onPressed: onCancel,
              child: Text('Hủy'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    int step = int.tryParse(currentStep) ?? 0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepIndicator('1', step),
        _buildStepConnector(step >= 2),
        _buildStepIndicator('2', step),
        _buildStepConnector(step >= 3),
        _buildStepIndicator('3', step),
        _buildStepConnector(step >= 4),
        _buildStepIndicator('4', step),
      ],
    );
  }
  
  Widget _buildStepIndicator(String step, int currentStep) {
    final isActive = currentStep >= int.parse(step);
    final isCurrentStep = currentStep.toString() == step;
    
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.green : Colors.grey.shade300,
        border: isCurrentStep 
            ? Border.all(color: Colors.green.shade700, width: 3)
            : null,
      ),
      child: Center(
        child: Text(
          step,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 30,
      height: 4,
      color: isActive ? Colors.green : Colors.grey.shade300,
    );
  }
  
  Widget _buildStepText() {
    String message;
    
    switch (currentStep) {
      case '1':
        message = 'Đang phân tích hình ảnh...';
        break;
      case '2':
        message = 'Đang nhận diện các món ăn...';
        break;
      case '3':
        message = 'Đang phân tích thông tin dinh dưỡng...';
        break;
      case '4':
        message = 'Hoàn thành!';
        break;
      default:
        message = 'Đang khởi tạo...';
    }
    
    return Text(
      message,
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey.shade800,
      ),
    );
  }
} 