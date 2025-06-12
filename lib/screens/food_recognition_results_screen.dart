import 'dart:io';
import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../widgets/food_logging/food_recognition_results.dart';

class FoodRecognitionResultsScreen extends StatelessWidget {
  final List<FoodItem> recognizedFoods;
  final String imagePath;
  final Function(List<FoodItem>)? onConfirm;
  
  const FoodRecognitionResultsScreen({
    Key? key, 
    required this.recognizedFoods,
    required this.imagePath,
    this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kết quả nhận diện'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Hiển thị hình ảnh đã chụp
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              image: DecorationImage(
                image: FileImage(File(imagePath)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Hiển thị kết quả nhận diện
          Expanded(
            child: FoodRecognitionResults(
              recognizedFoods: recognizedFoods,
              onConfirm: (selectedFoods) {
                // Xử lý khi người dùng xác nhận lựa chọn
                if (onConfirm != null) {
                  onConfirm!(selectedFoods);
                }
                
                // Quay lại màn hình trước đó
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
} 