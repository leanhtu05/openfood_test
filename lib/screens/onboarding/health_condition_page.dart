import 'package:flutter/material.dart';

class HealthConditionPage extends StatefulWidget {
  const HealthConditionPage({Key? key}) : super(key: key);

  @override
  State<HealthConditionPage> createState() => _HealthConditionPageState();
}

class _HealthConditionPageState extends State<HealthConditionPage> {
  List<String> selectedConditions = [];
  
  final List<Map<String, dynamic>> healthConditions = [
    {
      'id': 'none',
      'emoji': '✓',
      'label': 'Không có',
    },
    {
      'id': 'hypertension',
      'emoji': '❤️',
      'label': 'Huyết áp cao',
    },
    {
      'id': 'diabetes',
      'emoji': '🍭',
      'label': 'Bệnh tiểu đường',
    },
    {
      'id': 'high-cholesterol',
      'emoji': '🍟',
      'label': 'Cholesterol cao',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nút quay lại
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Logo và Biểu tượng
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'DietAI',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF24204F),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Biểu tượng sức khỏe
                            Container(
                              width: 150,
                              height: 150,
                              child: Image.asset(
                                'assets/images/health_condition.png',
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.favorite,
                                    size: 100,
                                    color: Colors.indigo,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Tiêu đề
                      const Center(
                        child: Text(
                          'Bạn có bất kỳ tình trạng sức khỏe nào không?',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Lựa chọn các tình trạng sức khỏe
                      ...healthConditions.map((condition) {
                        final bool isSelected = condition['id'] == 'none' 
                          ? selectedConditions.isEmpty || selectedConditions.contains('none')
                          : selectedConditions.contains(condition['id']);
                          
                        return Column(
                          children: [
                            _buildHealthConditionOption(
                              emoji: condition['emoji'],
                              label: condition['label'],
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  if (condition['id'] == 'none') {
                                    selectedConditions = ['none'];
                                  } else {
                                    // Xóa lựa chọn 'không có' nếu có
                                    selectedConditions.remove('none');
                                    
                                    // Toggle lựa chọn hiện tại
                                    if (isSelected) {
                                      selectedConditions.remove(condition['id']);
                                    } else {
                                      selectedConditions.add(condition['id']);
                                    }
                                  }
                                });
                              },
                            ),
                            SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
  
  Widget _buildHealthConditionOption({
    required String emoji,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            
            // Nhãn
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.green.shade700 : Colors.black87,
              ),
            ),
            
            // Use Spacer
            const Spacer(),
            
            // Checkbox nếu đã chọn
            if (isSelected && label == 'Không có')
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
} 