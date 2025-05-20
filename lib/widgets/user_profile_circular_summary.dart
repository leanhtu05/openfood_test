import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../utils/constants.dart';
import '../screens/sync_settings_screen.dart';

class UserProfileCircularSummary extends StatelessWidget {
  const UserProfileCircularSummary({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      _buildSyncButton(context, userData),
                      const SizedBox(width: 8),
                      _buildSettingsButton(context),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircularInfo(
                    label: 'Giới tính',
                    value: userData.gender == 'male' ? 'Nam' : 'Nữ',
                    icon: userData.gender == 'male' ? Icons.male : Icons.female,
                    color: userData.gender == 'male' ? Colors.blue : Colors.pink,
                  ),
                  _buildCircularInfo(
                    label: 'Tuổi',
                    value: '${userData.age}',
                    icon: Icons.cake,
                    color: Colors.orange,
                  ),
                  _buildCircularInfo(
                    label: 'Chiều cao',
                    value: '${userData.heightCm.toInt()} cm',
                    icon: Icons.height,
                    color: Colors.green,
                  ),
                  _buildCircularInfo(
                    label: 'Cân nặng',
                    value: '${userData.weightKg.toInt()} kg',
                    icon: Icons.monitor_weight,
                    color: Colors.purple,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildGoalCard(
                      label: 'Mục tiêu',
                      value: userData.goal,
                      icon: Icons.flag,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGoalCard(
                      label: 'Mức vận động',
                      value: userData.activityLevel,
                      icon: Icons.directions_run,
                      color: AppColors.exercise,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context, UserDataProvider userData) {
    return IconButton(
      icon: const Icon(Icons.sync, color: AppColors.primary),
      tooltip: 'Đồng bộ dữ liệu',
      onPressed: () async {
        // Hiển thị dialog loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Đang đồng bộ dữ liệu...'),
              ],
            ),
          ),
        );
        
        // Gọi API gửi dữ liệu
        final result = await userData.sendToApi();
        
        // Đóng dialog loading
        Navigator.of(context).pop();
        
        // Hiển thị kết quả
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result 
                  ? 'Đồng bộ dữ liệu thành công!' 
                  : 'Đồng bộ dữ liệu thất bại. Vui lòng thử lại sau.',
            ),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings, size: 20, color: AppColors.primary),
      tooltip: 'Cài đặt đồng bộ',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SyncSettingsScreen(),
          ),
        );
      },
    );
  }

  Widget _buildCircularInfo({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 