import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../utils/constants.dart';

class FoodItemRow extends StatelessWidget {
  final FoodItem item;
  final bool showDivider;
  final VoidCallback? onTap;

  const FoodItemRow({
    Key? key,
    required this.item,
    this.showDivider = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Food icon or image
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.foodLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFoodIcon(item.name),
                color: AppColors.food,
                size: 18,
              ),
            ),
            
            SizedBox(width: 12),
            
            // Food name and quantity
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${item.servingSize} ${item.servingUnit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Nutritional information badges
            Wrap(
              spacing: 6,
              children: [
                _buildNutrientBadge(
                  value: item.calories.toString(),
                  label: 'kcal',
                  color: AppColors.food,
                ),
                _buildNutrientBadge(
                  value: item.protein.toInt().toString(),
                  label: 'P',
                  color: Colors.blue,
                ),
                _buildNutrientBadge(
                  value: item.carbs.toInt().toString(),
                  label: 'C',
                  color: Colors.orange,
                ),
                _buildNutrientBadge(
                  value: item.fat.toInt().toString(),
                  label: 'F',
                  color: Colors.yellow.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNutrientBadge({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 11),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            TextSpan(
              text: label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();
    
    if (name.contains('cơm') || name.contains('gạo') || name.contains('rice')) {
      return Icons.rice_bowl;
    } else if (name.contains('thịt') || name.contains('meat')) {
      return Icons.lunch_dining;
    } else if (name.contains('cá') || name.contains('fish')) {
      return Icons.set_meal;
    } else if (name.contains('rau') || name.contains('vegetable')) {
      return Icons.eco;
    } else if (name.contains('trái cây') || name.contains('fruit')) {
      return Icons.apple;
    } else if (name.contains('trứng') || name.contains('egg')) {
      return Icons.egg;
    } else if (name.contains('sữa') || name.contains('milk')) {
      return Icons.coffee;
    } else if (name.contains('bánh') || name.contains('bread')) {
      return Icons.bakery_dining;
    }
    
    return Icons.restaurant;
  }
} 