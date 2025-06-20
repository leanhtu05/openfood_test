import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/food_entry.dart';

class EnhancedFoodCard extends StatelessWidget {
  final FoodEntry foodEntry;
  final double servingSize;
  final double caloriesGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbsGoal;
  final VoidCallback onTap;
  final Function(double)? onServingSizeChanged;
  final VoidCallback? onDelete;

  const EnhancedFoodCard({
    Key? key,
    required this.foodEntry,
    required this.servingSize,
    required this.caloriesGoal,
    required this.proteinGoal,
    required this.fatGoal,
    required this.carbsGoal,
    required this.onTap,
    this.onServingSizeChanged,
    this.onDelete,
  }) : super(key: key);

  // Getter để trả về giá trị servingSize hiệu quả
  double get effectiveServingSize => servingSize <= 0 ? 1.0 : servingSize;

  @override
  Widget build(BuildContext context) {
    // Tính toán giá trị dinh dưỡng
    final nutritionValues = foodEntry.calculateNutritionFromAPI();
    final calories = (nutritionValues['calories']!).toInt();
    final protein = (nutritionValues['protein']!).toInt();
    final fat = (nutritionValues['fat']!).toInt();
    final carbs = (nutritionValues['carbs']!).toInt();
    
    // Chuyển đổi thành % của mục tiêu
    final caloriePercent = (calories / caloriesGoal * 100).clamp(0.0, 100.0);
    final hasImage = foodEntry.imagePath != null && foodEntry.imagePath!.isNotEmpty;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 5),
              spreadRadius: 1,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Phần trên với hình ảnh hoặc gradient
            Container(
              height: 140,
              child: hasImage 
                ? _buildImageSection() 
                : _buildGradientSection(),
            ),
            
            // Phần dưới với thông tin món ăn
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng đầu: Tên món ăn + Loại bữa
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tên món ăn
                      Expanded(
                        child: Text(
                          foodEntry.description,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Loại bữa ăn
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          foodEntry.mealType,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Thời gian
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      SizedBox(width: 4),
                      Text(
                        _formatTimeOnly(foodEntry.dateTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Thông tin dinh dưỡng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Calories
                      _buildCalorieInfo(calories),
                      
                      // Phân cách
                      Container(
                        height: 35,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),
                      
                      // Macros
                      Row(
                        children: [
                          _buildMacroInfo("P", protein, Colors.blue),
                          SizedBox(width: 10),
                          _buildMacroInfo("C", carbs, Colors.green),
                          SizedBox(width: 10),
                          _buildMacroInfo("F", fat, Colors.orange.shade700),
                        ],
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Progress bar calories
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: caloriePercent / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        caloriePercent > 90 ? Colors.red : Colors.green
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget hiển thị hình ảnh
  Widget _buildImageSection() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hình ảnh món ăn
        Image.file(
          File(foodEntry.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGradientSection(),
        ),
        
        // Lớp phủ gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: [0.7, 1.0],
              ),
            ),
          ),
        ),
        
        // Nút xóa ở góc trên bên phải
        if (onDelete != null)
          Positioned(
            top: 8,
            right: 8,
            child: ClipOval(
              child: Material(
                color: Colors.white.withOpacity(0.7),
                child: InkWell(
                  onTap: onDelete,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.delete, size: 16, color: Colors.red.shade700),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  // Widget hiển thị gradient khi không có hình ảnh
  Widget _buildGradientSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFB74D),
            Color(0xFFFF9800),
            Color(0xFFF57C00),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Icon ở trung tâm
          Center(
            child: Icon(
              Icons.restaurant,
              size: 60,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          
          // Nút xóa ở góc trên bên phải
          if (onDelete != null)
            Positioned(
              top: 8,
              right: 8,
              child: ClipOval(
                child: Material(
                  color: Colors.white.withOpacity(0.7),
                  child: InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete, size: 16, color: Colors.red.shade700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Widget hiển thị thông tin calorie
  Widget _buildCalorieInfo(int calories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$calories",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Text(
                " kcal",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          "Đã ăn",
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // Widget hiển thị thông tin macro
  Widget _buildMacroInfo(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          "$value g",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
  
  // Định dạng thời gian
  String _formatTimeOnly(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }
}
