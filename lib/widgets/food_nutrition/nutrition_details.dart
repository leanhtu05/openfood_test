import 'package:flutter/material.dart';
import '../../models/food_entry.dart';

class NutritionDetails extends StatelessWidget {
  final FoodEntry foodEntry;
  final bool isExpanded;
  final VoidCallback onToggle;

  const NutritionDetails({
    Key? key,
    required this.foodEntry,
    required this.isExpanded,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tính toán tổng calories từ tất cả các items
    double totalCalories = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCarbs = 0;

    for (final item in foodEntry.items) {
      // Đảm bảo giá trị servingSize hợp lệ
      final servingSize = item.servingSize < 0.1 ? 0.1 : item.servingSize;
      
      // Tính toán giá trị dinh dưỡng dựa trên servingSize
      totalCalories += item.calories * servingSize;
      totalProtein += (item.protein ?? 0) * servingSize;
      totalFat += (item.fat ?? 0) * servingSize;
      totalCarbs += (item.carbs ?? 0) * servingSize;
    }

    return Card(
      margin: EdgeInsets.all(0),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thông tin dinh dưỡng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[700],
                  ),
                  onPressed: onToggle,
                ),
              ],
            ),
            
            // Thêm chỉ định nguồn dữ liệu API nếu có
            if (foodEntry.nutritionInfo != null && 
                foodEntry.nutritionInfo!.containsKey('dataSource'))
              Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Dữ liệu từ ${foodEntry.nutritionInfo!['dataSource']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Macro nutrients
            _buildNutrientBar('Calories', totalCalories.toInt().toString(), 
                Colors.red, 'kcal', 2000),
            
            SizedBox(height: 16),
            
            // Grid of nutrients
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.5,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildNutrientCard('Protein', '${totalProtein.toStringAsFixed(1)}g', 
                    Colors.purple, Icons.fitness_center),
                _buildNutrientCard('Carbs', '${totalCarbs.toStringAsFixed(1)}g', 
                    Colors.amber, Icons.grain),
                _buildNutrientCard('Fat', '${totalFat.toStringAsFixed(1)}g', 
                    Colors.blue, Icons.opacity),
              ],
            ),
            
            if (isExpanded) ...[
              SizedBox(height: 24),
              
              Text(
                'Chi tiết dinh dưỡng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              SizedBox(height: 16),
              
              // Additional nutrients from API or calculated from items
              _buildAdditionalNutrients(),
              
              // Hiển thị tất cả các giá trị dinh dưỡng phụ
              SizedBox(height: 16),
              
              // Nhóm các vitamin và khoáng chất
              if (_hasVitaminsAndMinerals())
                Text(
                  'Vitamin & Khoáng chất',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              
              SizedBox(height: 8),
              
              if (_hasVitaminsAndMinerals())
                _buildVitaminsAndMinerals(),
            ],
          ],
        ),
      ),
    );
  }
  
  // Kiểm tra xem có dữ liệu về vitamin và khoáng chất không
  bool _hasVitaminsAndMinerals() {
    if (foodEntry.nutritionInfo == null) return false;
    
    final vitaminsAndMinerals = ['vitaminA', 'vitaminC', 'vitaminD', 'vitaminE', 
                                'calcium', 'iron', 'potassium', 'magnesium'];
    
    for (final nutrient in vitaminsAndMinerals) {
      if (foodEntry.nutritionInfo!.containsKey(nutrient) && 
          foodEntry.nutritionInfo![nutrient] != null) {
        return true;
      }
    }
    
    // Kiểm tra các chất dinh dưỡng bổ sung từ FoodItems
    for (final item in foodEntry.items) {
      if (item.additionalNutrients != null) {
        for (final nutrient in vitaminsAndMinerals) {
          if (item.additionalNutrients!.containsKey(nutrient) && 
              item.additionalNutrients![nutrient] != null) {
            return true;
          }
        }
      }
    }
    
    return false;
  }
  
  // Xây dựng phần hiển thị các chất dinh dưỡng bổ sung
  Widget _buildAdditionalNutrients() {
    final additionalNutrientsList = <Widget>[];
    
    // Danh sách các chất dinh dưỡng cơ bản
    final basicNutrients = ['calories', 'protein', 'fat', 'carbs'];
    final advancedNutrients = ['fiber', 'sugar', 'sodium'];
    
    // Tìm các chất dinh dưỡng từ FoodEntry.nutritionInfo
    if (foodEntry.nutritionInfo != null) {
      // Xử lý các chất dinh dưỡng nâng cao (fiber, sugar, sodium)
      for (final nutrient in advancedNutrients) {
        if (foodEntry.nutritionInfo!.containsKey(nutrient) && 
            foodEntry.nutritionInfo![nutrient] != null) {
          String label;
          String unit;
          
          switch (nutrient) {
            case 'fiber':
              label = 'Chất xơ';
              unit = 'g';
              break;
            case 'sugar':
              label = 'Đường';
              unit = 'g';
              break;
            case 'sodium':
              label = 'Natri';
              unit = 'mg';
              break;
            default:
              label = nutrient.capitalize();
              unit = 'g';
          }
          
          final value = foodEntry.nutritionInfo![nutrient];
          if (value != null) {
            additionalNutrientsList.add(
              _buildDetailRow(label, '${value.toStringAsFixed(1)}$unit')
            );
          }
        }
      }
      
      // Tìm các chất dinh dưỡng khác không nằm trong danh sách cơ bản
      foodEntry.nutritionInfo!.forEach((key, value) {
        if (!basicNutrients.contains(key) && 
            !advancedNutrients.contains(key) &&
            !key.startsWith('vitamin') &&
            !['calcium', 'iron', 'potassium', 'magnesium', 'dataSource', 'timestamp'].contains(key) &&
            value != null) {
          
          String label = key.capitalize();
          String unit = 'g';
          
          if (key.contains('_')) {
            label = key.split('_').map((word) => word.capitalize()).join(' ');
          }
          
          additionalNutrientsList.add(
            _buildDetailRow(label, '${value.toStringAsFixed(1)}$unit')
          );
        }
      });
    }
    
    // Nếu không có chất dinh dưỡng bổ sung nào, hiển thị thông báo
    if (additionalNutrientsList.isEmpty) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Không có thông tin chi tiết bổ sung',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: additionalNutrientsList,
    );
  }
  
  // Xây dựng phần hiển thị vitamin và khoáng chất
  Widget _buildVitaminsAndMinerals() {
    final vitaminsAndMineralsList = <Widget>[];
    final nutrientMap = <String, Map<String, dynamic>>{
      'vitaminA': {'label': 'Vitamin A', 'unit': 'µg', 'rdi': 900},
      'vitaminC': {'label': 'Vitamin C', 'unit': 'mg', 'rdi': 90},
      'vitaminD': {'label': 'Vitamin D', 'unit': 'µg', 'rdi': 20},
      'vitaminE': {'label': 'Vitamin E', 'unit': 'mg', 'rdi': 15},
      'calcium': {'label': 'Canxi', 'unit': 'mg', 'rdi': 1000},
      'iron': {'label': 'Sắt', 'unit': 'mg', 'rdi': 18},
      'potassium': {'label': 'Kali', 'unit': 'mg', 'rdi': 3500},
      'magnesium': {'label': 'Magiê', 'unit': 'mg', 'rdi': 400},
    };
    
    if (foodEntry.nutritionInfo != null) {
      nutrientMap.forEach((key, info) {
        if (foodEntry.nutritionInfo!.containsKey(key) && 
            foodEntry.nutritionInfo![key] != null) {
          final value = foodEntry.nutritionInfo![key];
          final percentage = (value / info['rdi'] * 100).clamp(0, 100).toInt();
          
          vitaminsAndMineralsList.add(
            _buildNutrientProgressRow(
              info['label'], 
              '${value.toStringAsFixed(1)}${info['unit']}',
              percentage,
            ),
          );
        }
      });
    }
    
    // Nếu có items với additionalNutrients
    for (final item in foodEntry.items) {
      if (item.additionalNutrients != null) {
        nutrientMap.forEach((key, info) {
          if (item.additionalNutrients!.containsKey(key) && 
              item.additionalNutrients![key] != null &&
              !foodEntry.nutritionInfo!.containsKey(key)) {
            
            final value = item.additionalNutrients![key] * item.servingSize;
            final percentage = (value / info['rdi'] * 100).clamp(0, 100).toInt();
            
            vitaminsAndMineralsList.add(
              _buildNutrientProgressRow(
                info['label'], 
                '${value.toStringAsFixed(1)}${info['unit']}',
                percentage,
              ),
            );
          }
        });
      }
    }
    
    if (vitaminsAndMineralsList.isEmpty) {
      return SizedBox();
    }
    
    return Column(children: vitaminsAndMineralsList);
  }
  
  // Widget hiển thị một dòng thông tin dinh dưỡng
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget hiển thị thanh dinh dưỡng với phần trăm
  Widget _buildNutrientProgressRow(String label, String value, int percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '$value ($percentage%)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getColorForPercentage(percentage),
            ),
          ),
        ],
      ),
    );
  }
  
  // Lấy màu dựa trên phần trăm
  Color _getColorForPercentage(int percentage) {
    if (percentage < 30) {
      return Colors.red;
    } else if (percentage < 70) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }
  
  // Widget thanh hiển thị thông tin dinh dưỡng chính
  Widget _buildNutrientBar(String label, String value, Color color, 
      String unit, int max) {
    // Phần trăm của RDI (Reference Daily Intake)
    int intValue = int.tryParse(value) ?? 0;
    double percentage = max > 0 ? (intValue / max).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  TextSpan(
                    text: ' (${(percentage * 100).toInt()}%)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
  
  // Widget thẻ hiển thị thông tin dinh dưỡng
  Widget _buildNutrientCard(String label, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// Extension để viết hoa chữ cái đầu
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
} 