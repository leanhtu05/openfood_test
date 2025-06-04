import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../services/api_service.dart';

class SyncSettingsWidget extends StatelessWidget {
  const SyncSettingsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDataProvider>(
      builder: (context, userData, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cài đặt đồng bộ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Switch bật/tắt tự động đồng bộ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tự động đồng bộ dữ liệu'),
                    Switch(
                      value: userData.syncEnabled,
                      onChanged: (value) {
                        userData.syncEnabled = value;
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                const Text(
                  'Khi bật, dữ liệu sẽ tự động được đồng bộ với máy chủ mỗi khi có thay đổi và theo định kỳ mỗi 15 phút.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                
                const SizedBox(height: 16),
                
                // Thông tin đồng bộ tự động
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đồng bộ tự động',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Dữ liệu của bạn được tự động đồng bộ mỗi khi có thay đổi và định kỳ mỗi 15 phút khi kết nối internet.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Hiển thị trạng thái đồng bộ
                Text(
                  'Trạng thái đồng bộ: ${userData.syncEnabled ? "Đang hoạt động" : "Đã tắt"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                
                const SizedBox(height: 4),
                
                // Hiển thị thời gian đồng bộ gần nhất
                Text(
                  'Lần đồng bộ gần nhất: ${userData.getFormattedLastSyncTime()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                
                const SizedBox(height: 4),
                
                // Thông tin API
                Text(
                  'API URL: ${ApiService.userProfileUrl}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 