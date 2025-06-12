import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class MealDetailCard extends StatefulWidget {
  final Meal meal;
  final String mealType;
  final String dayOfWeek;
  final Function()? onReplace;
  final Function()? onLog;
  final bool hideTitle;

  const MealDetailCard({
    Key? key,
    required this.meal,
    required this.mealType,
    required this.dayOfWeek,
    this.onReplace,
    this.onLog,
    this.hideTitle = false,
  }) : super(key: key);

  @override
  State<MealDetailCard> createState() => _MealDetailCardState();
}

class _MealDetailCardState extends State<MealDetailCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Hàm để tách instruction string thành list các bước
  List<String> _parseInstructionSteps(List<String> instructions) {
    List<String> allSteps = [];

    for (String instruction in instructions) {
      // Tách theo dấu chấm để tạo các bước riêng biệt
      List<String> steps = instruction.split('. ')
          .where((step) => step.trim().isNotEmpty)
          .map((step) => step.trim())
          .toList();

      // Thêm dấu chấm nếu chưa có
      for (int i = 0; i < steps.length; i++) {
        if (!steps[i].endsWith('.') && !steps[i].endsWith('!') && !steps[i].endsWith('?')) {
          steps[i] += '.';
        }
      }

      allSteps.addAll(steps);
    }

    return allSteps;
  }

  @override
  Widget build(BuildContext context) {
    bool hasDishes = widget.meal.dishes.isNotEmpty;
    
    // Nếu không có dishes hoặc chỉ có 1 dish, hiển thị chính Meal như là một món
    if (!hasDishes) {
      return _buildSingleDishCard(
        widget.meal.name,
        widget.meal.description,
        widget.meal.nutrition,
        widget.meal.ingredients,
        widget.meal.instructions,
        widget.meal.imageUrl,
      );
    }
    
    // Có nhiều dishes, sử dụng PageView
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hiển thị tên bữa ăn chính
        if (!widget.hideTitle)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mealType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      Text(
                        '${widget.meal.dishes.length} món cho bữa ăn này',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dinh dưỡng tổng
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.meal.nutrition['calories']?.toInt() ?? 0} kcal',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    Text(
                      'P: ${widget.meal.nutrition['protein']?.toInt() ?? 0}g | F: ${widget.meal.nutrition['fat']?.toInt() ?? 0}g | C: ${widget.meal.nutrition['carbs']?.toInt() ?? 0}g',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        // PageView cho các món ăn
        Container(
          height: 400, // Điều chỉnh chiều cao phù hợp
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.meal.dishes.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final dish = widget.meal.dishes[index];
              return _buildDishDetailView(dish, index);
            },
          ),
        ),
        
        // Page indicator
        if (widget.meal.dishes.length > 1)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: widget.meal.dishes.length,
                effect: WormEffect(
                  activeDotColor: Colors.deepOrange,
                  dotHeight: 8,
                  dotWidth: 8,
                  type: WormType.thin,
                ),
              ),
            ),
          ),
        
        // Nút thao tác
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (widget.onReplace != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onReplace,
                    icon: Icon(Icons.refresh, color: Colors.blue, size: 18),
                    label: Text(
                      'Thay thế bằng AI',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),

                ),
              SizedBox(width: widget.onReplace != null && widget.onLog != null ? 8.0 : 0),
              if (widget.onLog != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onLog,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Ghi nhận'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.lightBlueAccent,
                      side: const BorderSide(color: Colors.lightBlueAccent),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDishDetailView(Dish dish, int index) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tên món và số thứ tự
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/recipe_detail',
                        arguments: dish,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dish.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
              ],
            ),
            
            // Thời gian nấu nếu có
            if (dish.preparationTime != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'Thời gian nấu: ${dish.preparationTime}',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
            
            // Dinh dưỡng của món
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNutritionItem('Calories', '${dish.nutrition['calories']?.toInt() ?? 0}', 'kcal'),
                  _buildNutritionItem('Protein', '${dish.nutrition['protein']?.toInt() ?? 0}', 'g'),
                  _buildNutritionItem('Chất béo', '${dish.nutrition['fat']?.toInt() ?? 0}', 'g'),
                  _buildNutritionItem('Carbs', '${dish.nutrition['carbs']?.toInt() ?? 0}', 'g'),
                ],
              ),
            ),
            
            // Mô tả
            if (dish.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  dish.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            
            // Lợi ích sức khỏe nếu có
            if (dish.healthBenefits != null && dish.healthBenefits!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Lợi ích sức khỏe',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...dish.healthBenefits!.map((benefit) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            
            // Nguyên liệu
            if (dish.ingredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Nguyên liệu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...dish.ingredients.map((ingredient) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 12, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(ingredient),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            
            // Hướng dẫn
            if (dish.instructions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Cách làm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              () {
                // Tách instructions thành các bước riêng biệt
                List<String> steps = _parseInstructionSteps(dish.instructions);
                return Column(
                  children: List.generate(steps.length, (i) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              steps[i],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              }(),
            ],
          ],
        ),
      ),
    );
  }
  
  // Hiển thị khi không có dishes hoặc chỉ truy cập thẳng vào Meal
  Widget _buildSingleDishCard(
    String name,
    String description,
    Map<String, double> nutrition,
    List<String> ingredients,
    List<String> instructions,
    String? imageUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Tạo một Dish object từ thông tin meal để truyền vào RecipeDetailScreen
                    final dish = Dish(
                      name: name,
                      description: description,
                      nutrition: nutrition,
                      ingredients: ingredients,
                      instructions: instructions,
                      imageUrl: imageUrl,
                    );
                    Navigator.pushNamed(
                      context,
                      '/recipe_detail',
                      arguments: dish,
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${nutrition['calories']?.toInt() ?? 0} kcal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  Text(
                    'P: ${nutrition['protein']?.toInt() ?? 0}g | F: ${nutrition['fat']?.toInt() ?? 0}g | C: ${nutrition['carbs']?.toInt() ?? 0}g',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Content
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mô tả
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              
              // Nguyên liệu
              if (ingredients.isNotEmpty) ...[
                Text(
                  'Nguyên liệu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                ...ingredients.map((ingredient) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.fiber_manual_record, size: 12, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(child: Text(ingredient)),
                      ],
                    ),
                  );
                }).toList(),
                SizedBox(height: 16),
              ],
              
              // Hướng dẫn
              if (instructions.isNotEmpty) ...[
                Text(
                  'Cách làm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                () {
                  // Tách instructions thành các bước riêng biệt
                  List<String> steps = _parseInstructionSteps(instructions);
                  return Column(
                    children: List.generate(steps.length, (i) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                steps[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                }(),
              ],
            ],
          ),
        ),
        
        // Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (widget.onReplace != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onReplace,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Thay thế bằng AI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              SizedBox(width: widget.onReplace != null && widget.onLog != null ? 8.0 : 0),
              if (widget.onLog != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onLog,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Ghi nhận'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildNutritionItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          '$value$unit',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 