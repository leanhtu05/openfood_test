import 'package:flutter/material.dart';
import '../../models/food_entry.dart';

/// Widget hiển thị footer dinh dưỡng và nút lưu
class NutritionFooter extends StatelessWidget {
  final FoodEntry foodEntry;
  final Map<String, double> nutritionValues;
  final VoidCallback onSavePressed;

  const NutritionFooter({
    Key? key,
    required this.foodEntry,
    required this.nutritionValues,
    required this.onSavePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side with nutrition summary - sử dụng Expanded và layout đơn giản
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Total weight - sử dụng totalWeight từ nutritionValues để đồng bộ
                  Row(
                    children: [
                      Icon(Icons.menu, size: 14, color: Colors.grey.shade800),
                      SizedBox(width: 4),
                      Text(
                        "Tổng Cộng: ${(nutritionValues['totalWeight'] ?? foodEntry.totalWeight).toInt()}g",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 4),
                  
                  // Row 2: Nutrition values - giảm khoảng cách và kích thước
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSimpleNutrientIndicator("${nutritionValues['calories']?.toInt() ?? 0}kcal", Colors.red),
                        SizedBox(width: 8),
                        _buildSimpleNutrientIndicator("${nutritionValues['protein']?.toInt() ?? 0}g", Colors.blue),
                        SizedBox(width: 8),
                        _buildSimpleNutrientIndicator("${nutritionValues['fat']?.toInt() ?? 0}g", Colors.amber),
                        SizedBox(width: 8),
                        _buildSimpleNutrientIndicator("${nutritionValues['carbs']?.toInt() ?? 0}g", Colors.green),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(width: 8),
            
            // Right side with compact save button
            ElevatedButton(
              onPressed: onSavePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4CD964),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size(0, 0), // Giảm kích thước tối thiểu
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 12),
                  SizedBox(width: 2),
                  Text(
                    'Đồng ý',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
  
  /// Helper để tạo chỉ báo dinh dưỡng đơn giản với chấm màu
  Widget _buildSimpleNutrientIndicator(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 2),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
} 