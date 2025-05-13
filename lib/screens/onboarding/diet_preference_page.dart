import 'package:flutter/material.dart';

class DietPreferencePage extends StatefulWidget {
  const DietPreferencePage({Key? key}) : super(key: key);

  @override
  State<DietPreferencePage> createState() => _DietPreferencePageState();
}

class _DietPreferencePageState extends State<DietPreferencePage> {
  String? selectedDiet;
  
  final List<Map<String, dynamic>> dietPreferences = [
    {
      'id': 'dash',
      'emoji': '🥦',
      'label': 'Dash',
    },
    {
      'id': 'low-carb',
      'emoji': '🚫',
      'label': 'Ít carb',
    },
    {
      'id': 'high-protein',
      'emoji': '💪',
      'label': 'Nhiều protein',
    },
    {
      'id': 'low-fat',
      'emoji': '🚫',
      'label': 'Ít béo',
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
                            
                            // Biểu tượng thực phẩm
                            Container(
                              width: 150,
                              height: 150,
                              child: Image.asset(
                                'assets/images/diet_preference.png',
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.restaurant_menu,
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
                          'Bạn thích loại chế độ ăn uống nào?',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Lựa chọn các loại chế độ ăn uống
                      ...dietPreferences.map((preference) {
                        final bool isSelected = selectedDiet == preference['id'];
                          
                        return Column(
                          children: [
                            _buildDietPreferenceOption(
                              emoji: preference['emoji'],
                              label: preference['label'],
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  selectedDiet = preference['id'];
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
  
  Widget _buildDietPreferenceOption({
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
            
            // Info icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100,
              ),
              child: Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 