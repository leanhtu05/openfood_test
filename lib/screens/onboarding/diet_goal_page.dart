import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';

class DietGoalPage extends StatefulWidget {
  const DietGoalPage({Key? key}) : super(key: key);

  @override
  State<DietGoalPage> createState() => _DietGoalPageState();
}

class _DietGoalPageState extends State<DietGoalPage> {
  String? selectedGoal;
  
  @override
  void initState() {
    super.initState();
    // Lấy mục tiêu từ provider nếu đã có
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        selectedGoal = userData.goal;
      });
    });
  }

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
                          mainAxisSize: MainAxisSize.min,
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
                            
                            // Biểu tượng mục tiêu
                            SizedBox(
                              width: 150,
                              height: 150,
                              child: Image.asset(
                                'assets/images/target_icon.png',
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.track_changes,
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
                          'Mục tiêu chính về chế độ ăn uống của bạn là gì?',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Lựa chọn mục tiêu
                      _buildGoalOption(
                        icon: Icons.balance,
                        emoji: '⚖️',
                        label: 'Giảm cân',
                        isSelected: selectedGoal == 'Giảm cân',
                        onTap: () => _selectGoal('Giảm cân'),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildGoalOption(
                        icon: Icons.spa,
                        emoji: '🌱',
                        label: 'Sức khỏe được cải thiện',
                        isSelected: selectedGoal == 'Sức khỏe được cải thiện',
                        onTap: () => _selectGoal('Sức khỏe được cải thiện'),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildGoalOption(
                        icon: Icons.fitness_center,
                        emoji: '💪',
                        label: 'Tăng cân',
                        isSelected: selectedGoal == 'Tăng cân',
                        onTap: () => _selectGoal('Tăng cân'),
                      ),
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
  
  // Phương thức để chọn mục tiêu và lưu vào provider
  void _selectGoal(String goal) {
    setState(() {
      selectedGoal = goal;
    });
    // Lưu mục tiêu vào provider
    Provider.of<UserDataProvider>(context, listen: false).setGoal(goal);
  }
  
  Widget _buildGoalOption({
    required IconData icon,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji hoặc Icon
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 12),
            
            // Nhãn - Sử dụng Expanded để tránh tràn
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.green.shade700 : Colors.black87,
                ),
              ),
            ),
            
            // Nút chọn
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                child: const Icon(
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