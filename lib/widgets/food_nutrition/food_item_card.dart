import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/food_entry.dart';
import 'package:uuid/uuid.dart';

class FoodItemCard extends StatefulWidget {
  final FoodItem item;
  final int index;
  final ValueChanged<FoodEntry> onFoodEntryChanged;
  final FoodEntry foodEntry;
  final VoidCallback onDeletePressed;

  const FoodItemCard({
    Key? key,
    required this.item,
    required this.index,
    required this.onFoodEntryChanged,
    required this.foodEntry,
    required this.onDeletePressed,
  }) : super(key: key);

  @override
  _FoodItemCardState createState() => _FoodItemCardState();
}

class _FoodItemCardState extends State<FoodItemCard> {
  late FoodItem _item;
  late FoodEntry _foodEntry;

  @override
  void initState() {
    super.initState();
    // Tạo bản sao hoàn toàn mới của item để tránh ảnh hưởng đến các item khác
    _item = widget.item.copyWith(
      id: Uuid().v4(),
      servingSize: widget.item.servingSize > 0 ? widget.item.servingSize : 1.0,
    );
    _foodEntry = widget.foodEntry;
  }

  @override
  Widget build(BuildContext context) {
    // Đảm bảo servingSize không nhỏ hơn hoặc bằng 0
    final effectiveServingSize = _item.servingSize <= 0 ? 1.0 : _item.servingSize;
    
    // Tính toán số gram từ servingSize (1 serving = 100g)
    final gramsDisplay = (effectiveServingSize * 100).toStringAsFixed(0);
    
    // Xác định đơn vị hiển thị
    final displayUnit = _item.servingUnit.isNotEmpty ? _item.servingUnit : 'g';
    
    // Cấu hình tính toán giá trị dinh dưỡng chính xác
    final nutritionInfo = _foodEntry.nutritionInfo;
    double caloriesPerServing, proteinPerServing, carbsPerServing, fatPerServing;
    
    if (nutritionInfo != null && nutritionInfo.containsKey('calories')) {
      // Nếu FoodEntry có nutritionInfo, sử dụng giá trị từ API
      final servingRatio = effectiveServingSize / (nutritionInfo['servingSize'] ?? 1.0);
      caloriesPerServing = (nutritionInfo['calories'] as num).toDouble() * servingRatio;
      proteinPerServing = (nutritionInfo['protein'] as num).toDouble() * servingRatio;
      carbsPerServing = (nutritionInfo['carbs'] as num).toDouble() * servingRatio;
      fatPerServing = (nutritionInfo['fat'] as num).toDouble() * servingRatio;
    } else {
      // Nếu không có nutritionInfo, tính từ FoodItem
      caloriesPerServing = _item.calories * effectiveServingSize;
      proteinPerServing = _item.protein * effectiveServingSize;
      carbsPerServing = _item.carbs * effectiveServingSize;
      fatPerServing = _item.fat * effectiveServingSize;
    }
    
    // Định dạng kết quả
    final calories = caloriesPerServing.toInt();
    final protein = proteinPerServing.toStringAsFixed(1);
    final carbs = carbsPerServing.toStringAsFixed(1);
    final fat = fatPerServing.toStringAsFixed(1);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // First row - name, brand, and quantity controls
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tên thực phẩm
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_item.brand != null && _item.brand!.isNotEmpty)
                      Text(
                        _item.brand!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              
              // Quantity controls
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                      constraints: BoxConstraints(maxWidth: 32, maxHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (_item.servingSize > 0.1) {
                          _updateServingSize(_item.servingSize - 0.1);
                        }
                      },
                    ),
                    Flexible(
                      child: Text(
                        '$gramsDisplay$displayUnit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: Colors.green),
                      constraints: BoxConstraints(maxWidth: 32, maxHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _updateServingSize(_item.servingSize + 0.1);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Second row - nutrition info
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Calories
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, size: 16, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      '$calories kcal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 8),
                // Protein
                _buildNutrientInfo(
                  'P', 
                  protein + 'g', 
                  Colors.blue
                ),
                SizedBox(width: 8),
                // Carbs
                _buildNutrientInfo(
                  'C', 
                  carbs + 'g', 
                  Colors.orange
                ),
                SizedBox(width: 8),
                // Fat
                _buildNutrientInfo(
                  'F', 
                  fat + 'g', 
                  Colors.green
                ),
              ],
            ),
          ),
          
          SizedBox(height: 8),
          
          // Delete button
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                // Hiển thị dialog xác nhận
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Xác nhận xóa'),
                      content: Text('Bạn có chắc chắn muốn xóa "${_item.name}" khỏi danh sách không?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onDeletePressed();
                          },
                          child: Text('Xóa', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientInfo(String label, String value, Color color) {
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
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 2),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateServingSize(double newSize) {
    setState(() {
      // Giới hạn servingSize trong khoảng từ 0.1 đến 5.0 (tương đương 10g đến 500g)
      final clampedSize = newSize.clamp(0.1, 5.0);
      
      // Tạo bản sao hoàn toàn mới của item với servingSize mới
      final updatedItem = FoodItem(
        id: _item.id,
        name: _item.name,
        brand: _item.brand,
        imageUrl: _item.imageUrl,
        calories: _item.calories,
        protein: _item.protein,
        fat: _item.fat,
        carbs: _item.carbs,
        servingSize: clampedSize,
        servingUnit: _item.servingUnit.isNotEmpty ? _item.servingUnit : 'g',
        fiber: _item.fiber,
        sugar: _item.sugar,
        sodium: _item.sodium,
        additionalNutrients: _item.additionalNutrients != null 
            ? Map<String, dynamic>.from(_item.additionalNutrients!) 
            : null,
      );
      
      // Cập nhật item trong state
      _item = updatedItem;
      
      // Tạo bản sao mới hoàn toàn của danh sách items
      final updatedItems = _foodEntry.items.map((item) {
        if (item.id == _item.id) {
          return updatedItem; // Sử dụng item đã cập nhật
        } else {
          // Tạo bản sao mới cho các item khác
          return FoodItem(
            id: item.id,
            name: item.name,
            brand: item.brand,
            imageUrl: item.imageUrl,
            calories: item.calories,
            protein: item.protein,
            fat: item.fat,
            carbs: item.carbs,
            servingSize: item.servingSize,
            servingUnit: item.servingUnit,
            fiber: item.fiber,
            sugar: item.sugar,
            sodium: item.sodium,
            additionalNutrients: item.additionalNutrients != null 
                ? Map<String, dynamic>.from(item.additionalNutrients!) 
                : null,
          );
        }
      }).toList();
      
      // Tạo bản sao mới của nutritionInfo nếu có
      Map<String, dynamic>? updatedNutritionInfo;
      if (_foodEntry.nutritionInfo != null) {
        updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
      }
      
      // Tạo FoodEntry mới với items đã cập nhật
      final updatedFoodEntry = FoodEntry(
        id: _foodEntry.id,
        description: _foodEntry.description,
        imagePath: _foodEntry.imagePath,
        audioPath: _foodEntry.audioPath,
        dateTime: _foodEntry.dateTime,
        isFavorite: _foodEntry.isFavorite,
        barcode: _foodEntry.barcode,
        calories: _foodEntry.calories,
        nutritionInfo: updatedNutritionInfo,
        mealType: _foodEntry.mealType,
        items: updatedItems,
      );
      
      // Cập nhật foodEntry trong state
      _foodEntry = updatedFoodEntry;
      
      // Thông báo thay đổi lên widget cha
      widget.onFoodEntryChanged(updatedFoodEntry);
    });
  }
} 