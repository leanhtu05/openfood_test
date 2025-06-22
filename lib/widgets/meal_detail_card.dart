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

  // 🎨 ENHANCED ACTION BUTTONS WITH BETTER UX
  Widget _buildEnhancedActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header với icon và text
          Row(
            children: [
              Icon(
                Icons.touch_app,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Thao tác với bữa ăn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons grid
          Row(
            children: [
              // 🍳 Xem hướng dẫn nấu ăn
              Expanded(
                child: _buildActionButton(
                  icon: Icons.menu_book,
                  label: 'Hướng dẫn',
                  color: Colors.orange,
                  onTap: () => _showCookingInstructions(context),
                  tooltip: 'Xem hướng dẫn nấu ăn chi tiết',
                ),
              ),

              const SizedBox(width: 8),

              // 🔄 Thay thế món ăn
              if (widget.onReplace != null)
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.refresh,
                    label: 'Thay thế',
                    color: Colors.blue,
                    onTap: widget.onReplace!,
                    tooltip: 'Thay thế bằng món ăn khác',
                  ),
                ),

              if (widget.onReplace != null) const SizedBox(width: 8),

              // ✅ Ghi nhận vào food log
              if (widget.onLog != null)
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.check_circle,
                    label: 'Ghi nhận',
                    color: Colors.green,
                    onTap: widget.onLog!,
                    tooltip: 'Ghi nhận vào nhật ký ăn uống',
                  ),
                ),

              if (widget.onLog != null) const SizedBox(width: 8),

              // 📊 Xem chi tiết dinh dưỡng
              Expanded(
                child: _buildActionButton(
                  icon: Icons.analytics,
                  label: 'Dinh dưỡng',
                  color: Colors.purple,
                  onTap: () => _showNutritionDetails(context),
                  tooltip: 'Xem thông tin dinh dưỡng chi tiết',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🎨 BUILD INDIVIDUAL ACTION BUTTON
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
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
            color: Colors.blue.shade50,
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
                          color: Colors.blue,
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
                        color: Colors.blue,
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
                  activeDotColor: Colors.blue,
                  dotHeight: 8,
                  dotWidth: 8,
                  type: WormType.thin,
                ),
              ),
            ),
          ),
        
        // 🎨 ENHANCED ACTION BUTTONS WITH BETTER UX
        _buildEnhancedActionButtons(),
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
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
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
                      const Icon(Icons.fiber_manual_record, size: 12, color: Colors.green),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
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
          color: Colors.blue.shade50,
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
                      color: Colors.blue,
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
                        Icon(Icons.fiber_manual_record, size: 12, color: Colors.green),
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
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
                      backgroundColor: Colors.blue,
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
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
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

  // 🍳 SHOW COOKING INSTRUCTIONS DIALOG
  void _showCookingInstructions(BuildContext context) {
    // Lấy tất cả instructions từ các dishes
    List<String> allInstructions = [];

    if (widget.meal.dishes.isNotEmpty) {
      for (int i = 0; i < widget.meal.dishes.length; i++) {
        final dish = widget.meal.dishes[i];
        allInstructions.add('${dish.name}:');
        allInstructions.addAll(dish.instructions);
        if (i < widget.meal.dishes.length - 1) {
          allInstructions.add(''); // Thêm dòng trống giữa các món
        }
      }
    } else {
      allInstructions = widget.meal.instructions;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.menu_book,
                        color: Colors.orange.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hướng dẫn nấu ăn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meal name
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.restaurant,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${widget.mealType} - ${widget.meal.name}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Instructions
                        if (allInstructions.isNotEmpty) ...[
                          Text(
                            'Các bước thực hiện:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),

                          ...allInstructions.asMap().entries.map((entry) {
                            int index = entry.key;
                            String instruction = entry.value;

                            if (instruction.isEmpty) {
                              return const SizedBox(height: 8);
                            }

                            // Check if this is a dish name (ends with :)
                            bool isDishName = instruction.endsWith(':');

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: isDishName
                                  ? Text(
                                      instruction,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade400,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            instruction,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            );
                          }).toList(),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Chưa có hướng dẫn nấu ăn chi tiết cho món này.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check),
                        label: const Text('Đã hiểu'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 📊 SHOW NUTRITION DETAILS DIALOG
  void _showNutritionDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: Colors.purple.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Thông tin dinh dưỡng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: Colors.purple.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meal name
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.restaurant,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${widget.mealType} - ${widget.meal.name}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Main nutrition info
                        _buildNutritionCard(
                          'Thông tin dinh dưỡng chính',
                          [
                            _buildNutritionRow('Calories', '${widget.meal.nutrition['calories']?.toInt() ?? 0}', 'kcal', Colors.red),
                            _buildNutritionRow('Protein', '${widget.meal.nutrition['protein']?.toInt() ?? 0}', 'g', Colors.blue),
                            _buildNutritionRow('Chất béo', '${widget.meal.nutrition['fat']?.toInt() ?? 0}', 'g', Colors.orange),
                            _buildNutritionRow('Carbohydrate', '${widget.meal.nutrition['carbs']?.toInt() ?? 0}', 'g', Colors.green),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Detailed nutrition per dish
                        if (widget.meal.dishes.isNotEmpty) ...[
                          Text(
                            'Dinh dưỡng từng món:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),

                          ...widget.meal.dishes.map((dish) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: _buildNutritionCard(
                                dish.name,
                                [
                                  _buildNutritionRow('Calories', '${dish.nutrition['calories']?.toInt() ?? 0}', 'kcal', Colors.red),
                                  _buildNutritionRow('Protein', '${dish.nutrition['protein']?.toInt() ?? 0}', 'g', Colors.blue),
                                  _buildNutritionRow('Chất béo', '${dish.nutrition['fat']?.toInt() ?? 0}', 'g', Colors.orange),
                                  _buildNutritionRow('Carbs', '${dish.nutrition['carbs']?.toInt() ?? 0}', 'g', Colors.green),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check),
                        label: const Text('Đóng'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.purple.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method for nutrition card
  Widget _buildNutritionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // Helper method for nutrition row
  Widget _buildNutritionRow(String label, String value, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          Text(
            '$value $unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}