import 'package:flutter/material.dart';
import '../../services/firestore_initializer.dart';

class FirestoreAdminScreen extends StatefulWidget {
  const FirestoreAdminScreen({Key? key}) : super(key: key);

  @override
  State<FirestoreAdminScreen> createState() => _FirestoreAdminScreenState();
}

class _FirestoreAdminScreenState extends State<FirestoreAdminScreen> {
  final FirestoreInitializer _firestoreInitializer = FirestoreInitializer();
  bool _isLoading = false;
  String _statusMessage = '';
  
  Future<void> _initializeFirestore() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang khởi tạo cấu trúc Firestore...';
    });
    
    try {
      await _firestoreInitializer.initializeFirestoreCollections();
      setState(() {
        _statusMessage = 'Khởi tạo cấu trúc Firestore thành công!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Firestore'),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Công cụ quản lý Firestore',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Công cụ này sẽ giúp bạn khởi tạo cấu trúc cơ sở dữ liệu Firestore '
              'cho ứng dụng. Nó sẽ tạo các collections cần thiết và thêm dữ liệu mẫu.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Khởi tạo Collections',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sẽ tạo các collections sau:\n'
                      '• users (với subcollection daily_logs)\n'
                      '• food_items\n'
                      '• exercise_types\n'
                      '• meal_plans & latest_meal_plans\n'
                      '• nutrition_cache\n'
                      '• ai_suggestions',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _initializeFirestore,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Khởi tạo Firestore',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            if (_statusMessage.isNotEmpty)
              Card(
                color: _statusMessage.contains('thành công')
                    ? Colors.green.shade50
                    : _statusMessage.contains('Lỗi')
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusMessage.contains('thành công')
                            ? 'Hoàn thành'
                            : _statusMessage.contains('Lỗi')
                                ? 'Lỗi'
                                : 'Đang xử lý',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _statusMessage.contains('thành công')
                              ? Colors.green.shade700
                              : _statusMessage.contains('Lỗi')
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_statusMessage),
                    ],
                  ),
                ),
              ),
            
              const SizedBox(height: 30),
            const Text(
              'Lưu ý: Các collection sẽ chỉ được tạo nếu chưa tồn tại. Dữ liệu hiện có sẽ không bị xóa.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          ),
        ),
      ),
    );
  }
} 