import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';

class UserProfileSummaryCard extends StatelessWidget {
  const UserProfileSummaryCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Thông tin cá nhân', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _buildSyncButton(context, userData),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Giới tính', userData.gender == 'male' ? 'Nam' : 'Nữ'),
            _buildInfoRow('Tuổi', '${userData.age}'),
            _buildInfoRow('Chiều cao', '${userData.heightCm} cm'),
            _buildInfoRow('Cân nặng', '${userData.weightKg} kg'),
            _buildInfoRow('Mục tiêu', userData.goal),
            _buildInfoRow('Mức vận động', userData.activityLevel),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context, UserDataProvider userData) {
    return TextButton.icon(
      icon: const Icon(Icons.sync, size: 16),
      label: const Text('Đồng bộ', style: TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: const Size(0, 30),
      ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label, 
              style: TextStyle(color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Flexible(
            flex: 1,
            child: Text(
              value, 
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
} 