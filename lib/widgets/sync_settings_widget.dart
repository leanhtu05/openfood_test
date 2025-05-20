import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../services/user_profile_api.dart';

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
                
                // Nút đồng bộ thủ công
                OutlinedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Đồng bộ ngay'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    
                    // Hiển thị snackbar đang đồng bộ
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Đang đồng bộ dữ liệu...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    
                    // Gọi API
                    final result = await userData.sendToApi();
                    
                    // Hiển thị kết quả
                    scaffoldMessenger.showSnackBar(
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
                ),
                
                const SizedBox(height: 8),
                
                // Thông tin về lần đồng bộ gần nhất
                Text(
                  'API URL: ${UserProfileApi.getApiUrl()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                
                const SizedBox(height: 4),
                
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
              ],
            ),
          ),
        );
      },
    );
  }
} 