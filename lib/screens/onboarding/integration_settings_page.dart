import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';
import '../../services/data_integration_service.dart';

class IntegrationSettingsPage extends StatefulWidget {
  final bool updateMode;
  
  const IntegrationSettingsPage({
    Key? key, 
    this.updateMode = false
  }) : super(key: key);

  @override
  State<IntegrationSettingsPage> createState() => _IntegrationSettingsPageState();
}

class _IntegrationSettingsPageState extends State<IntegrationSettingsPage> {
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Khởi tạo dữ liệu khi cần
  }
  
  // Lưu các cài đặt tích hợp
  void _saveSettings() {
    // Xử lý lưu cài đặt tích hợp
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    
    // Lưu dữ liệu và hiển thị thông báo thành công
    if (widget.updateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật cài đặt tích hợp thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
    // Quay lại màn hình trước đó
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt tích hợp'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề
                      Text(
                        'Tích hợp dịch vụ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Danh sách các dịch vụ có thể tích hợp
                      _buildIntegrationOption(
                        title: 'Google Fit',
                        description: 'Đồng bộ dữ liệu với Google Fit',
                        isConnected: false,
                        onConnect: () {
                          // Xử lý kết nối với Google Fit
                        },
                      ),
                      
                      _buildIntegrationOption(
                        title: 'Apple Health',
                        description: 'Đồng bộ dữ liệu với Apple Health',
                        isConnected: false,
                        onConnect: () {
                          // Xử lý kết nối với Apple Health
                        },
                      ),
                      
                      _buildIntegrationOption(
                        title: 'Fitbit',
                        description: 'Đồng bộ dữ liệu với Fitbit',
                        isConnected: false,
                        onConnect: () {
                          // Xử lý kết nối với Fitbit
                        },
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Nút lưu thay đổi
                      Center(
                        child: ElevatedButton(
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OnboardingStyles.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text('Lưu thay đổi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildIntegrationOption({
    required String title,
    required String description,
    required bool isConnected,
    required VoidCallback onConnect,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Icon(
                  isConnected ? Icons.check_circle : Icons.circle_outlined,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(description),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red : OnboardingStyles.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(isConnected ? 'Ngắt kết nối' : 'Kết nối'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}