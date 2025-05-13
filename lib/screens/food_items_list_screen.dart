import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/food_item.dart';
import '../providers/food_provider.dart';
import 'package:provider/provider.dart';

class FoodItemsListScreen extends StatefulWidget {
  final Function(FoodItem) onFoodItemSelected;

  const FoodItemsListScreen({
    Key? key,
    required this.onFoodItemSelected,
  }) : super(key: key);

  @override
  _FoodItemsListScreenState createState() => _FoodItemsListScreenState();
}

class _FoodItemsListScreenState extends State<FoodItemsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _foodItems = [];
  List<FoodItem> _filteredFoodItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFoodItems() async {
    try {
      // Trong thực tế, chúng ta sẽ lấy dữ liệu từ cơ sở dữ liệu hoặc API
      // Đây là dữ liệu mẫu
      await Future.delayed(Duration(seconds: 1)); // Giả lập thời gian tải
      
      _foodItems = [
        FoodItem(
          id: Uuid().v4(),
          name: 'Thịt bò',
          servingSize: 1.0,
          calories: 250,
          protein: 26,
          fat: 17,
          carbs: 0,

        ),
        FoodItem(
          id: Uuid().v4(),
          name: 'Cơm trắng',
          servingSize: 1.0,
          calories: 200,
          protein: 4,
          fat: 0,
          carbs: 45,

        ),
        FoodItem(
          id: Uuid().v4(),
          name: 'Thịt gà',
          servingSize: 1.0,
          calories: 165,
          protein: 31,
          fat: 3.6,
          carbs: 0,

        ),
        FoodItem(
          id: Uuid().v4(),
          name: 'Cá hồi',
          servingSize: 1.0,
          calories: 206,
          protein: 22,
          fat: 13,
          carbs: 0,
        ),
        FoodItem(
          id: Uuid().v4(),
          name: 'Trứng',
          servingSize: 1.0,
          calories: 78,
          protein: 6,
          fat: 5,
          carbs: 0.6,

        ),
      ];
      
      _filteredFoodItems = List.from(_foodItems);
      
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      print('Lỗi khi tải danh sách thực phẩm: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterFoodItems(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredFoodItems = List.from(_foodItems);
      });
      return;
    }
    
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredFoodItems = _foodItems.where((item) {
        return item.name.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    });
  }

  void _addNewFoodItem() {
    showDialog(
      context: context,
      builder: (context) {
        String name = '';
        double calories = 0;
        double protein = 0;
        double fat = 0;
        double carbs = 0;
        
        return AlertDialog(
          title: Text('Thêm thực phẩm mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Tên thực phẩm',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => name = value,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Calories (kcal)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => calories = double.tryParse(value) ?? 0,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Protein (g)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => protein = double.tryParse(value) ?? 0,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Chất béo (g)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => fat = double.tryParse(value) ?? 0,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Carbs (g)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => carbs = double.tryParse(value) ?? 0,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                // Tạo FoodItem mới
                final newFoodItem = FoodItem(
                  id: Uuid().v4(),
                  name: name,
                  servingSize: 1.0,
                  calories: calories,
                  protein: protein,
                  fat: fat,
                  carbs: carbs,

                );
                
                // Thêm vào danh sách
                setState(() {
                  _foodItems.add(newFoodItem);
                  _filterFoodItems(_searchController.text);
                });
                
                // Đóng dialog
                Navigator.pop(context);
                
                // Thông báo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã thêm thực phẩm mới: $name'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Danh sách thực phẩm'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addNewFoodItem,
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm thực phẩm...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: _filterFoodItems,
            ),
          ),
          
          // Danh sách thực phẩm
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _filteredFoodItems.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy thực phẩm nào',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFoodItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredFoodItems[index];
                      return _buildFoodItemCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFoodItemCard(FoodItem item) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () {
          widget.onFoodItemSelected(item);
          Navigator.pop(context);
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food name
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              // Nutrition info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNutrientInfo(
                    'Calo', 
                    '${item.calories.toStringAsFixed(0)} kcal', 
                    Color(0xFFFF5722)
                  ),
                  _buildNutrientInfo(
                    'Protein', 
                    '${item.protein.toStringAsFixed(1)}g', 
                    Color(0xFF2196F3)
                  ),
                  _buildNutrientInfo(
                    'Chất béo', 
                    '${item.fat.toStringAsFixed(1)}g', 
                    Color(0xFFFFA726)
                  ),
                  _buildNutrientInfo(
                    'Carbs', 
                    '${item.carbs.toStringAsFixed(1)}g', 
                    Color(0xFF4CAF50)
                  ),
                ],
              ),
            ],
          ),
        ),
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
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 