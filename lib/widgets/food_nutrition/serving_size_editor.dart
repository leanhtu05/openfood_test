import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';

class ServingSizeEditor extends StatefulWidget {
  final FoodItem foodItem;
  final Function(FoodItem) onServingSizeChanged;

  const ServingSizeEditor({
    Key? key,
    required this.foodItem,
    required this.onServingSizeChanged,
  }) : super(key: key);

  @override
  _ServingSizeEditorState createState() => _ServingSizeEditorState();
}

class _ServingSizeEditorState extends State<ServingSizeEditor> {
  late TextEditingController _servingSizeController;
  bool _isUpdating = false;
  
  @override
  void initState() {
    super.initState();
    _servingSizeController = TextEditingController(text: widget.foodItem.servingSize.toString());
  }
  
  @override
  void dispose() {
    _servingSizeController.dispose();
    super.dispose();
  }
  
  // Cập nhật khẩu phần và đồng bộ dữ liệu
  Future<void> _updateServingSize(double newSize) async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      // Cập nhật item với khẩu phần mới
      final updatedItem = widget.foodItem.copyWith(servingSize: newSize);
      
      // Thông báo cho widget cha về việc thay đổi
      widget.onServingSizeChanged(updatedItem);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Tính toán giá trị dinh dưỡng dựa trên khẩu phần hiện tại
    final servingSize = double.tryParse(_servingSizeController.text) ?? widget.foodItem.servingSize;
    final caloriesPerServing = (widget.foodItem.calories * servingSize / 100).round();
    final proteinPerServing = ((widget.foodItem.protein * servingSize / 100).toDouble()).toStringAsFixed(1);
    final carbsPerServing = ((widget.foodItem.carbs * servingSize / 100).toDouble()).toStringAsFixed(1);
    final fatPerServing = ((widget.foodItem.fat * servingSize / 100).toDouble()).toStringAsFixed(1);
    
    return Container(
      padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nút điều chỉnh số lượng và đơn vị
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                // Nút giảm
                IconButton(
                  icon: Icon(Icons.remove, color: Colors.blue),
                  onPressed: () {
                    final currentValue = double.tryParse(_servingSizeController.text) ?? widget.foodItem.servingSize;
                    final newValue = (currentValue - 10).clamp(10.0, 1000.0); // Thêm .0 để đảm bảo kết quả là double
                    _servingSizeController.text = newValue.toString();
                    _updateServingSize(newValue);
                  },
                ),
                
                // Trường nhập số lượng
                Expanded(
                  child: TextField(
                    controller: _servingSizeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Khẩu phần',
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      final parsedValue = double.tryParse(value);
                      if (parsedValue != null && parsedValue > 0) {
                        setState(() {
                          // Chỉ cập nhật UI, không gọi API ngay
                        });
                      }
                    },
                    onSubmitted: (value) {
                      final parsedValue = double.tryParse(value);
                      if (parsedValue != null && parsedValue > 0) {
                        _updateServingSize(parsedValue.toDouble());
                      }
                    },
                  ),
                ),
                
                // Nút tăng
                IconButton(
                  icon: Icon(Icons.add, color: Colors.blue),
                  onPressed: () {
                    final currentValue = double.tryParse(_servingSizeController.text) ?? widget.foodItem.servingSize;
                    final newValue = (currentValue + 10).clamp(10.0, 1000.0); // Thêm .0 để đảm bảo kết quả là double
                    _servingSizeController.text = newValue.toString();
                    _updateServingSize(newValue);
                  },
                ),
                
                // Đơn vị
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                  ),
                  child: Text(
                    widget.foodItem.servingUnit,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Hiển thị kết quả tính toán dinh dưỡng
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNutritionValue(Icons.local_fire_department, '$caloriesPerServing kcal', Colors.red),
                _buildNutritionValue(Icons.fitness_center, '$proteinPerServing g', Colors.blue),
                _buildNutritionValue(Icons.spa, '$carbsPerServing g', Colors.green),
                _buildNutritionValue(Icons.opacity, '$fatPerServing g', Colors.amber),
              ],
            ),
          ),
          
          // Nút cập nhật
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: () {
                  final parsedValue = double.tryParse(_servingSizeController.text);
                  if (parsedValue != null && parsedValue > 0) {
                    _updateServingSize(parsedValue.toDouble());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(120, 36),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Cập nhật',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNutritionValue(IconData icon, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
} 