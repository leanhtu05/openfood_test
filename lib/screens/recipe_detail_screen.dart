import 'package:flutter/material.dart';
import '../models/meal_plan.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Dish dish;

  const RecipeDetailScreen({
    Key? key,
    required this.dish,
  }) : super(key: key);

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  int _currentStep = 0;
  late List<String> _parsedSteps;

  @override
  void initState() {
    super.initState();
    _parseInstructions();
  }

  // Hàm để tách instructions thành các bước riêng biệt
  void _parseInstructions() {
    _parsedSteps = [];

    for (String instruction in widget.dish.instructions) {
      // Tách theo pattern "Bước X:" hoặc theo dấu chấm
      if (instruction.contains(RegExp(r'Bước \d+:'))) {
        // Tách theo "Bước X:"
        List<String> steps = instruction.split(RegExp(r'Bước \d+:'))
            .where((step) => step.trim().isNotEmpty)
            .map((step) => step.trim())
            .toList();
        _parsedSteps.addAll(steps);
      } else {
        // Tách theo dấu chấm
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

        _parsedSteps.addAll(steps);
      }
    }

    // Nếu không tách được gì, giữ nguyên instructions gốc
    if (_parsedSteps.isEmpty) {
      _parsedSteps = widget.dish.instructions;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.dish.name,
          style: TextStyle(
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.green.shade800),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildDishHeader(),
                _buildVideoSection(),
                _buildIngredientsSection(),
                _buildInstructionsSection(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDishHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade600,
            Colors.grey.shade800,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.dish.name,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          if (widget.dish.prepTimeInMinutes != null)
            Text(
              'Thời gian chuẩn bị: ${widget.dish.prepTimeInMinutes} phút',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: Colors.orange.shade700, size: 24),
              SizedBox(width: 8),
              Text(
                'Nguyên liệu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildIngredientsList(),
        ],
      ),
    );
  }

  Widget _buildIngredientsList() {
    // Ưu tiên sử dụng detailedIngredients nếu có
    if (widget.dish.detailedIngredients.isNotEmpty) {
      return Column(
        children: widget.dish.detailedIngredients.map((ingredient) {
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Text(
                  ingredient.amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      // Fallback về ingredients cũ
      return Column(
        children: widget.dish.ingredients.map((ingredient) {
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.orange.shade400),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ingredient,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildInstructionsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_outlined, color: Colors.orange.shade700, size: 24),
              SizedBox(width: 8),
              Text(
                'Các bước thực hiện',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.orange.shade700,
              ),
            ),
            child: Stepper(
              currentStep: _currentStep,
              onStepTapped: (step) {
                setState(() {
                  _currentStep = step;
                });
              },
              controlsBuilder: (context, details) {
                return Row(
                  children: [
                    if (details.stepIndex < _parsedSteps.length - 1)
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Tiếp theo'),
                      ),
                    SizedBox(width: 8),
                    if (details.stepIndex > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: Text(
                          'Quay lại',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                  ],
                );
              },
              onStepContinue: () {
                if (_currentStep < _parsedSteps.length - 1) {
                  setState(() {
                    _currentStep++;
                  });
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() {
                    _currentStep--;
                  });
                }
              },
              steps: _parsedSteps.asMap().entries.map((entry) {
                int index = entry.key;
                String instruction = entry.value;

                return Step(
                  title: Text(
                    'Bước ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  content: Text(
                    instruction,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                  isActive: _currentStep == index,
                  state: _currentStep > index
                      ? StepState.complete
                      : _currentStep == index
                          ? StepState.indexed
                          : StepState.disabled,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.shade600,
                  Colors.orange.shade800,
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.play_circle_filled, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Video hướng dẫn',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildVideoPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade800,
            Colors.grey.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Video không có sẵn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Hướng dẫn video sẽ được cập nhật sớm',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
