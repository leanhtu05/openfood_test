import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingApi = false;
  Map<String, dynamic>? _apiStatus;

  Future<void> _checkApiConnection() async {
    setState(() {
      _isCheckingApi = true;
      _apiStatus = null;
    });

    try {
      final result = await ApiService.checkApiConnectionDetailed();
      
      setState(() {
        _apiStatus = result;
        _isCheckingApi = false;
      });
    } catch (e) {
      setState(() {
        _apiStatus = {
          'success': false,
          'message': 'Lỗi không xác định: $e',
        };
        _isCheckingApi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kết nối API',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isCheckingApi ? null : _checkApiConnection,
                      child: _isCheckingApi
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Đang kiểm tra...'),
                              ],
                            )
                          : Text('Kiểm tra kết nối API'),
                    ),
                    SizedBox(height: 16),
                    if (_apiStatus != null) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _apiStatus!['success'] == true
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _apiStatus!['success'] == true
                                ? Colors.green
                                : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _apiStatus!['success'] == true
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _apiStatus!['success'] == true
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _apiStatus!['message'] ?? 'Không có thông báo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_apiStatus!['status_code'] != null) ...[
                              SizedBox(height: 8),
                              Text('Mã trạng thái: ${_apiStatus!['status_code']}'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            // Các cài đặt khác ở đây
          ],
        ),
      ),
    );
  }
} 