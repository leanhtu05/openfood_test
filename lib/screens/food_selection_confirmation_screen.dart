// Food Selection Confirmation Screen

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../models/food_entry.dart';
import '../providers/food_provider.dart';
import 'food_nutrition_detail_screen.dart';

class FoodSelectionConfirmationScreen extends StatefulWidget {
  final List<FoodItem> recognizedFoods;
  final String imagePath;
  final Function(List<FoodItem>) onConfirm;
  
  const FoodSelectionConfirmationScreen({
    Key? key,
    required this.recognizedFoods,
    required this.imagePath,
    required this.onConfirm,
  }) : super(key: key);
  
  @override
  _FoodSelectionConfirmationScreenState createState() => _FoodSelectionConfirmationScreenState();
}

class _FoodSelectionConfirmationScreenState extends State<FoodSelectionConfirmationScreen> {
  // Danh sách món ăn được chọn
  late List<bool> _selectedItems;
  
  // Thông tin dinh dưỡng tổng hợp
  int _totalCalories = 0;
  double _totalProtein = 0;
  double _totalCarbs = 0;
  double _totalFat = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Ban đầu chọn tất cả các món được nhận diện
    _selectedItems = List.generate(widget.recognizedFoods.length, (index) => true);
    _calculateTotalNutrition();
  }
  
  // Tính tổng dinh dưỡng dựa trên các món đã chọn
  void _calculateTotalNutrition() {
    _totalCalories = 0;
    _totalProtein = 0;
    _totalCarbs = 0;
    _totalFat = 0;
    
    for (int i = 0; i < widget.recognizedFoods.length; i++) {
      if (_selectedItems[i]) {
        final food = widget.recognizedFoods[i];
        _totalCalories += food.calories.toInt();
        _totalProtein += food.protein;
        _totalCarbs += food.carbs;
        _totalFat += food.fat;
      }
    }
    
    setState(() {});
  }
  
  // Chọn/bỏ chọn món ăn
  void _toggleSelection(int index) {
    setState(() {
      _selectedItems[index] = !_selectedItems[index];
      _calculateTotalNutrition();
    });
  }
  
  // Danh sách món ăn đã chọn
  List<FoodItem> get _selectedFoodItems {
    return widget.recognizedFoods
        .asMap()
        .entries
        .where((entry) => _selectedItems[entry.key])
        .map((entry) => entry.value)
        .toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Xác nhận món ăn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Hình ảnh được bo tròn
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Tiêu đề và mô tả
                  Text(
                    'Kết quả nhận diện',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Vui lòng xác nhận các món bạn đã ăn. Bỏ chọn nếu bạn không ăn món đó.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 24),

                  // Danh sách món ăn
                  ...widget.recognizedFoods.asMap().entries.map((entry) {
                    final index = entry.key;
                    final food = entry.value;
                    return _buildFoodItem(food, index);
                  }).toList(),

                  SizedBox(height: 16),

                  // Nút chọn tất cả / bỏ chọn tất cả
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _selectAll,
                          child: Text('Chọn tất cả'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _deselectAll,
                          child: Text('Bỏ chọn tất cả'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Tổng dinh dưỡng
                  _buildNutritionSummary(),
                ],
              ),
            ),
          ),

          // Nút xác nhận cố định ở dưới
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                final selectedFoods = _selectedFoodItems;

                // Tạo FoodEntry từ các món đã chọn
                final entry = _createFoodEntryFromSelectedItems(selectedFoods);

                // Chuyển đến màn hình chi tiết dinh dưỡng
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FoodNutritionDetailScreen(
                      foodEntry: entry,
                      onSave: (updatedEntry) {
                        // Xử lý khi lưu từ màn hình chi tiết
                        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                        foodProvider.addFoodEntry(updatedEntry);

                        // Gọi callback onConfirm nếu có
                        if (widget.onConfirm != null) {
                          widget.onConfirm(selectedFoods);
                        }
                      },
                      heroTag: 'food_image_${DateTime.now().millisecondsSinceEpoch}',
                    ),
                  ),
                );
              },
              child: Text(
                'Xác nhận & Ghi lại',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B35), // Orange color
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget cho từng món ăn
  Widget _buildFoodItem(FoodItem food, int index) {
    final isSelected = _selectedItems[index];

    return GestureDetector(
      onTap: () => _toggleSelection(index),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon check
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFFFF6B35) : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),

            SizedBox(width: 16),

            // Tên món ăn
            Expanded(
              child: Text(
                food.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),

            // Calories
            Text(
              '${food.calories.toInt()} kcal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Chọn tất cả
  void _selectAll() {
    setState(() {
      _selectedItems = List.generate(widget.recognizedFoods.length, (index) => true);
      _calculateTotalNutrition();
    });
  }

  // Bỏ chọn tất cả
  void _deselectAll() {
    setState(() {
      _selectedItems = List.generate(widget.recognizedFoods.length, (index) => false);
      _calculateTotalNutrition();
    });
  }

  // Widget tổng dinh dưỡng
  Widget _buildNutritionSummary() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng dinh dưỡng (ước tính)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          SizedBox(height: 16),

          // Grid dinh dưỡng
          Row(
            children: [
              Expanded(
                child: _buildNutritionItem('Calo', '$_totalCalories kcal'),
              ),
              Expanded(
                child: _buildNutritionItem('Béo', '${_totalFat.toInt()} g'),
              ),
            ],
          ),

          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildNutritionItem('Đạm', '${_totalProtein.toInt()} g'),
              ),
              Expanded(
                child: _buildNutritionItem('Carb', '${_totalCarbs.toInt()} g'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget cho từng thông tin dinh dưỡng
  Widget _buildNutritionItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
  
  // Tạo FoodEntry từ danh sách món ăn đã chọn
  FoodEntry _createFoodEntryFromSelectedItems(List<FoodItem> selectedFoods) {
    // Tạo mô tả từ tên các món ăn
    final description = selectedFoods.map((food) => food.name).join(', ');
    
    // Tính tổng các giá trị dinh dưỡng
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    
    for (final food in selectedFoods) {
      totalCalories += food.calories;
      totalProtein += food.protein;
      totalCarbs += food.carbs;
      totalFat += food.fat;
    }
    
    // Xác định loại bữa ăn dựa vào thời gian hiện tại
    String mealType = _getMealTypeBasedOnTime();
    
    // Tạo FoodEntry mới
    return FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: description,
      dateTime: DateTime.now(),
      calories: totalCalories,
      mealType: mealType,
      items: selectedFoods,
      imageUrl: widget.imagePath,
      needsNutritionAnalysis: false,
      nutritionInfo: {
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fat': totalFat,
        'calories': totalCalories,
        'dataSource': 'AI Recognition',
      },
    );
  }
  
  // Xác định loại bữa ăn dựa vào thời gian hiện tại
  String _getMealTypeBasedOnTime() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour >= 5 && hour < 10) {
      return 'Bữa sáng';
    } else if (hour >= 10 && hour < 14) {
      return 'Bữa trưa';
    } else if (hour >= 14 && hour < 17) {
      return 'Bữa phụ';
    } else if (hour >= 17 && hour < 21) {
      return 'Bữa tối';
    } else {
      return 'Bữa phụ';
    }
  }
}
