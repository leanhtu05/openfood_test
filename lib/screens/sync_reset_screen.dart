import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_data_provider.dart';

class SyncResetScreen extends StatefulWidget {
  const SyncResetScreen({Key? key}) : super(key: key);

  @override
  _SyncResetScreenState createState() => _SyncResetScreenState();
}

class _SyncResetScreenState extends State<SyncResetScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  bool _success = false;

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khắc phục lỗi đồng bộ'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin hiện tại:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('TDEE hiện tại:', '${userData.tdeeCalories.round()} kcal'),
                    _buildInfoRow('Mục tiêu calo:', '${userData.nutritionGoals['calories']?.round() ?? 0} kcal'),
                    _buildInfoRow('Đồng bộ đã bật:', userData.syncEnabled ? 'Có' : 'Không'),
                    _buildInfoRow('Lần đồng bộ cuối:', userData.lastSyncTime?.toString() ?? 'Chưa đồng bộ'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Các giải pháp khắc phục:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Đọc dữ liệu từ bộ nhớ cục bộ',
              subtitle: 'Buộc đọc dữ liệu từ bộ nhớ điện thoại thay vì Firestore',
              onPressed: _resetSyncFlags,
              icon: Icons.storage,
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              title: 'Tính toán lại TDEE',
              subtitle: 'Tính lại TDEE dựa trên thông tin hiện tại và lưu vào bộ nhớ',
              onPressed: () => _recalculateTDEE(userData),
              icon: Icons.calculate,
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              title: 'Đồng bộ lên Firestore',
              subtitle: 'Gửi dữ liệu cục bộ lên Firestore để cập nhật',
              onPressed: () => _forceSyncToFirestore(userData),
              icon: Icons.cloud_upload,
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              title: 'Khắc phục toàn diện',
              subtitle: 'Thực hiện tất cả các bước trên một lúc',
              onPressed: () => _fixSyncIssues(userData),
              icon: Icons.build,
              isHighlighted: true,
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              title: 'Kiểm tra dữ liệu trong bộ nhớ',
              subtitle: 'Hiển thị tất cả dữ liệu đang lưu trong bộ nhớ cục bộ',
              onPressed: () => _debugLocalStorage(userData),
              icon: Icons.search,
              isHighlighted: false,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            if (_statusMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _success ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _success ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _success ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required Function onPressed,
    required IconData icon,
    bool isHighlighted = false,
  }) {
    return Card(
      elevation: isHighlighted ? 3 : 1,
      color: isHighlighted ? Colors.green.shade50 : null,
      child: InkWell(
        onTap: _isLoading ? null : () => onPressed(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isHighlighted ? Colors.green.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  icon,
                  color: isHighlighted ? Colors.green.shade800 : Colors.grey.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isHighlighted ? Colors.green.shade800 : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Phương thức xóa cờ đồng bộ để ưu tiên đọc dữ liệu từ local
  Future<void> _resetSyncFlags() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Xóa cờ đã tải dữ liệu từ Firestore
      await prefs.remove('data_loaded_from_firestore');
      await prefs.setBool('data_loaded_from_firestore', false);
      
      // Đặt cờ ưu tiên dữ liệu local
      await prefs.setBool('use_firebase_data', false);
      
      // Đặt cờ dữ liệu đã thay đổi
      await prefs.setBool('data_changed', true);
      
      // Cập nhật thời gian thay đổi
      await prefs.setString('last_local_update', DateTime.now().toIso8601String());

      setState(() {
        _isLoading = false;
        _statusMessage = '✅ Đã đặt lại cờ đồng bộ. App sẽ ưu tiên đọc dữ liệu từ bộ nhớ local.';
        _success = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Lỗi khi đặt lại cờ đồng bộ: $e';
        _success = false;
      });
    }
  }

  // Phương thức buộc tính toán lại TDEE
  Future<void> _recalculateTDEE(UserDataProvider userData) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // Xóa TDEE cũ
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_tdee_calories');
      await prefs.remove('user_tdee_protein');
      await prefs.remove('user_tdee_carbs');
      await prefs.remove('user_tdee_fat');
      
      // Tính toán lại TDEE
      await userData.forceRecalculateTDEE();
      
      setState(() {
        _isLoading = false;
        _statusMessage = '✅ Đã tính toán lại TDEE: ${userData.tdeeCalories.round()} kcal';
        _success = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Lỗi khi tính toán lại TDEE: $e';
        _success = false;
      });
    }
  }

  // Phương thức buộc đồng bộ lên Firestore
  Future<void> _forceSyncToFirestore(UserDataProvider userData) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // Đảm bảo cờ đồng bộ được bật
      userData.syncEnabled = true;
      
      // Buộc đồng bộ lên Firestore
      final result = await userData.syncToFirebase();
      
      setState(() {
        _isLoading = false;
        if (result) {
          _statusMessage = '✅ Đã đồng bộ dữ liệu lên Firestore thành công';
          _success = true;
        } else {
          _statusMessage = '⚠️ Không thể đồng bộ lên Firestore. Kiểm tra kết nối mạng và đăng nhập.';
          _success = false;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Lỗi khi đồng bộ lên Firestore: $e';
        _success = false;
      });
    }
  }

  // Phương thức khắc phục toàn diện
  Future<void> _fixSyncIssues(UserDataProvider userData) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // Bước 1: Đặt lại cờ đồng bộ
      await _resetSyncFlags();
      
      // Bước 2: Tính toán lại TDEE
      await _recalculateTDEE(userData);
      
      // Bước 3: Đồng bộ lên Firestore
      await _forceSyncToFirestore(userData);
      
      // Bước 4: Tải lại dữ liệu người dùng từ local
      await userData.loadUserData();
      
      setState(() {
        _isLoading = false;
        _statusMessage = '✅ Đã khắc phục toàn diện vấn đề đồng bộ. TDEE mới: ${userData.tdeeCalories.round()} kcal, đã đồng bộ lên Firestore.';
        _success = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Lỗi khi khắc phục vấn đề đồng bộ: $e';
        _success = false;
      });
    }
  }

  Future<void> _debugLocalStorage(UserDataProvider userData) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // Gọi phương thức debug từ UserDataProvider
      final localData = await userData.debugLocalStorage();
      
      // Tạo chuỗi hiển thị dữ liệu
      String displayData = '';
      
      // Hiển thị TDEE data
      displayData += '📊 TDEE Data:\n';
      localData['tdee_data'].forEach((key, value) {
        displayData += '  - $key: $value\n';
      });
      
      // Hiển thị Sync data
      displayData += '\n🔄 Sync Data:\n';
      localData['sync_data'].forEach((key, value) {
        displayData += '  - $key: $value\n';
      });
      
      // Hiển thị Flags data
      displayData += '\n🚩 Flags Data:\n';
      localData['flags_data'].forEach((key, value) {
        displayData += '  - $key: $value\n';
      });
      
      // Hiển thị User info
      displayData += '\n👤 User Info:\n';
      localData['user_info'].forEach((key, value) {
        displayData += '  - $key: $value\n';
      });
      
      setState(() {
        _isLoading = false;
        _statusMessage = '✅ Dữ liệu trong local storage:\n\n$displayData';
        _success = true;
      });
      
      // Hiển thị dialog với thông tin chi tiết
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.storage, color: Colors.blue),
              SizedBox(width: 8),
              Text('Dữ liệu trong bộ nhớ cục bộ'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLocalStorageSection('TDEE Data', localData['tdee_data'], Colors.green),
                SizedBox(height: 16),
                _buildLocalStorageSection('Sync Data', localData['sync_data'], Colors.blue),
                SizedBox(height: 16),
                _buildLocalStorageSection('Flags Data', localData['flags_data'], Colors.orange),
                SizedBox(height: 16),
                _buildLocalStorageSection('User Info', localData['user_info'], Colors.purple),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Lỗi khi kiểm tra dữ liệu trong bộ nhớ: $e';
        _success = false;
      });
    }
  }

  Widget _buildLocalStorageSection(String title, Map<String, dynamic> data, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 8),
        ...data.entries.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${entry.key}:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }
} 