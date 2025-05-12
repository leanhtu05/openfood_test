import 'package:flutter/material.dart';
import '../../models/food_entry.dart';
import '../../models/food_item.dart';
import 'package:intl/intl.dart';
import 'nutrient_progress_indicator.dart';

class FoodAnalysisResult extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onSave;

  const FoodAnalysisResult({
    Key? key,
    required this.entry,
    this.onEdit,
    this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          
          // Divider
          Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.2)),
          
          // Food items list
          if (entry.items.isNotEmpty) _buildFoodItemsList(),
          
          // Nutritional summary
          _buildNutritionalSummary(context),
          
          // Buttons
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant, color: Colors.green),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy, HH:mm').format(entry.dateTime),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.mealType,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.red, size: 20),
                SizedBox(width: 4),
                Row(
                  children: [
                    Text(
                      'Tổng calories: ',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${entry.totalCalories}',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' kcal',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItemsList() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thực phẩm phát hiện (${entry.items.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          ...entry.items.map((item) => _buildFoodItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildFoodItemCard(FoodItem item) {
    final servingInfo = item.servingSize > 0 
      ? '${item.servingSize} ${item.servingUnit}' 
      : '';
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                item.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (item.brand != null && item.brand!.isNotEmpty)
                  Text(
                    item.brand!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                SizedBox(height: 4),
                Row(
                  children: [
                    _buildNutrientTag('P', '${item.protein.toStringAsFixed(1)}g', Colors.blue),
                    SizedBox(width: 4),
                    _buildNutrientTag('C', '${item.carbs.toStringAsFixed(1)}g', Colors.orange),
                    SizedBox(width: 4),
                    _buildNutrientTag('F', '${item.fat.toStringAsFixed(1)}g', Colors.red),
                    if (servingInfo.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Text(
                        servingInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${item.calories} kcal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientTag(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionalSummary(BuildContext context) {
    // Tính toán % dựa trên nhu cầu dinh dưỡng 2000 calo mặc định
    final proteinPercent = (entry.totalProtein * 4 / 2000 * 100).clamp(0, 100);
    final carbsPercent = (entry.totalCarbs * 4 / 2000 * 100).clamp(0, 100);
    final fatPercent = (entry.totalFat * 9 / 2000 * 100).clamp(0, 100);
    
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tóm tắt dinh dưỡng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NutrientProgressIndicator(
                value: entry.totalProtein,
                maxValue: 50, // khoảng 50g protein mỗi ngày
                label: 'Protein',
                unit: 'g',
                color: Colors.blue,
              ),
              NutrientProgressIndicator(
                value: entry.totalCarbs,
                maxValue: 275, // khoảng 275g carbs mỗi ngày
                label: 'Carbs',
                unit: 'g',
                color: Colors.orange,
              ),
              NutrientProgressIndicator(
                value: entry.totalFat,
                maxValue: 65, // khoảng 65g fat mỗi ngày
                label: 'Chất béo',
                unit: 'g',
                color: Colors.red,
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phân bổ năng lượng',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Protein: ${(proteinPercent).toStringAsFixed(1)}%, Carbs: ${(carbsPercent).toStringAsFixed(1)}%, Chất béo: ${(fatPercent).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (onEdit != null)
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(Icons.edit),
                label: Text('Chỉnh sửa'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onEdit,
              ),
            ),
          if (onEdit != null && onSave != null)
            SizedBox(width: 12),
          if (onSave != null)
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text('Lưu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onSave,
              ),
            ),
        ],
      ),
    );
  }
} 