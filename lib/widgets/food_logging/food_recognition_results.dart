import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_item.dart';
import '../../models/nutrition_info.dart';

class FoodRecognitionResults extends StatefulWidget {
  final List<FoodItem> recognizedFoods;
  final Function(List<FoodItem>) onConfirm;
  
  const FoodRecognitionResults({
    Key? key,
    required this.recognizedFoods,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<FoodRecognitionResults> createState() => _FoodRecognitionResultsState();
}

class _FoodRecognitionResultsState extends State<FoodRecognitionResults> {
  late List<FoodItem> selectedFoods;
  
  @override
  void initState() {
    super.initState();
    // Mặc định chọn tất cả món ăn được nhận diện
    selectedFoods = List.from(widget.recognizedFoods);
  }
  
  // Tính toán tổng dinh dưỡng của các món đã chọn
  Map<String, double> get totalNutrition {
    double calories = 0;
    double protein = 0;
    double fat = 0;
    double carbs = 0;
    
    for (var food in selectedFoods) {
      calories += food.calories;
      protein += food.protein;
      fat += food.fat;
      carbs += food.carbs;
    }
    
    return {
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
  }
  
  // Xử lý khi chọn/bỏ chọn một món
  void _toggleFoodSelection(FoodItem food) {
    setState(() {
      if (selectedFoods.contains(food)) {
        selectedFoods.remove(food);
      } else {
        selectedFoods.add(food);
      }
    });
  }
  
  // Xử lý khi chọn tất cả
  void _selectAll() {
    setState(() {
      selectedFoods = List.from(widget.recognizedFoods);
    });
  }
  
  // Xử lý khi bỏ chọn tất cả
  void _deselectAll() {
    setState(() {
      selectedFoods.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              Text(
                'Kết quả nhận diện',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Hướng dẫn
              Text(
                'Vui lòng xác nhận các món bạn đã ăn. Bỏ chọn nếu bạn không ăn món đó.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Danh sách món ăn
              Expanded(
                child: ListView.builder(
                  itemCount: widget.recognizedFoods.length,
                  itemBuilder: (context, index) {
                    final food = widget.recognizedFoods[index];
                    final isSelected = selectedFoods.contains(food);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => _toggleFoodSelection(food),
                        title: Text(
                          food.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                          ),
                        ),
                        secondary: Text(
                          '${food.calories.round()} kcal',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        activeColor: Theme.of(context).primaryColor,
                        checkColor: Colors.white,
                        controlAffinity: ListTileControlAffinity.leading,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Buttons Chọn tất cả/Bỏ chọn tất cả
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selectAll,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text('Chọn tất cả'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _deselectAll,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text('Bỏ chọn tất cả'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Tổng dinh dưỡng
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng dinh dưỡng (ước tính)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNutrientDisplay('Calo', '${totalNutrition['calories']?.round()} kcal'),
                        _buildNutrientDisplay('Béo', '${totalNutrition['fat']?.round()} g'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNutrientDisplay('Đạm', '${totalNutrition['protein']?.round()} g'),
                        _buildNutrientDisplay('Carb', '${totalNutrition['carbs']?.round()} g'),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Nút Xác nhận
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onConfirm(selectedFoods);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Xác nhận & Ghi lại',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Widget hiển thị thông tin dinh dưỡng
  Widget _buildNutrientDisplay(String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 