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
            const Text('Thông tin cá nhân', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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