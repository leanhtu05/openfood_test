import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';

class DynamicWaterGoalWidget extends StatelessWidget {
  const DynamicWaterGoalWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterProvider>(
      builder: (context, waterProvider, child) {
        final currentWater = waterProvider.totalWaterToday;
        final goalWater = waterProvider.waterGoal;
        final percentage = waterProvider.getWaterGoalPercentage();
        final remaining = waterProvider.getRemainingWaterNeeded();
        final isGoalAchieved = waterProvider.isGoalAchieved();

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isGoalAchieved
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : [Colors.blue.shade400, Colors.blue.shade600],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '💧 Mục tiêu nước hôm nay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: Colors.white),
                      onPressed: () => _showWaterGoalSettings(context, waterProvider),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Progress Bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã uống',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${currentWater}ml',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Tiến độ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${(percentage * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isGoalAchieved ? 'Hoàn thành!' : 'Còn lại',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          isGoalAchieved ? '🎉' : '${remaining}ml',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Goal info
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mục tiêu: ${goalWater}ml (tính toán dựa trên profile cá nhân)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
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

  void _showWaterGoalSettings(BuildContext context, WaterProvider waterProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int customGoal = waterProvider.waterGoal;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('⚙️ Cài đặt mục tiêu nước'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mục tiêu hiện tại: ${waterProvider.waterGoal}ml',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text('Đặt mục tiêu tùy chỉnh:'),
                  const SizedBox(height: 8),
                  
                  Slider(
                    min: 1000,
                    max: 6000,
                    divisions: 50,
                    value: customGoal.toDouble(),
                    onChanged: (value) {
                      setState(() {
                        customGoal = value.round();
                      });
                    },
                    label: '${customGoal}ml',
                  ),
                  
                  Text(
                    '${customGoal}ml',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.blue.shade50,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '💡 Gợi ý:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Người bình thường: 2000-2500ml\n'
                          '• Người tập thể thao: 3000-4000ml\n'
                          '• Thời tiết nóng: +500-1000ml',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Cập nhật mục tiêu nước từ profile
                    await waterProvider.updateWaterGoal();
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Đã cập nhật mục tiêu từ profile: ${waterProvider.waterGoal}ml'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text('Tính từ Profile'),
                ),
                ElevatedButton(
                  onPressed: () {
                    waterProvider.setCustomWaterGoal(customGoal);
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Đã đặt mục tiêu tùy chỉnh: ${customGoal}ml'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  child: Text('Đặt tùy chỉnh'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
