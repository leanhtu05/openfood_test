import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_initializer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

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
  
  // Phương thức kiểm tra và xóa dữ liệu người dùng trùng lặp
  Future<void> _checkAndRemoveDuplicateUsers() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang kiểm tra dữ liệu người dùng trùng lặp...';
    });
    
    try {
      final firestore = FirebaseFirestore.instance;
      final usersCollection = await firestore.collection('users').get();
      
      developer.log('Tìm thấy ${usersCollection.docs.length} người dùng trong Firestore');
      
      // Nhóm các tài liệu theo userID và email
      Map<String, List<DocumentSnapshot>> userIdMap = {};
      Map<String, List<DocumentSnapshot>> emailMap = {};
      List<DocumentSnapshot> duplicateDocs = [];
      
      // Bước 1: Tổ chức dữ liệu theo userID và email
      for (var doc in usersCollection.docs) {
        final data = doc.data();
        final userId = doc.id;
        final email = data['email']?.toString() ?? '';
        
        // Lưu vào map theo ID
        userIdMap.putIfAbsent(userId, () => []).add(doc);
        
        // Nếu có email, lưu vào map theo email
        if (email.isNotEmpty) {
          emailMap.putIfAbsent(email, () => []).add(doc);
        }
      }
      
      // Bước 2: Tìm các bản ghi trùng lặp theo email
      int emailDuplicatesCount = 0;
      for (var entry in emailMap.entries) {
        if (entry.value.length > 1) {
          emailDuplicatesCount++;
          developer.log('Phát hiện ${entry.value.length} bản ghi trùng email: ${entry.key}');
          
          // Sắp xếp theo thời gian cập nhật (mới nhất đầu tiên)
          entry.value.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            
            String timeA = dataA['updated_at']?.toString() ?? '';
            String timeB = dataB['updated_at']?.toString() ?? '';
            
            try {
              if (timeA.isNotEmpty && timeB.isNotEmpty) {
                return DateTime.parse(timeB).compareTo(DateTime.parse(timeA));
              }
            } catch (e) {
              developer.log('Lỗi khi phân tích thời gian: $e');
            }
            return 0;
          });
          
          // Giữ lại bản ghi đầu tiên (mới nhất), đánh dấu các bản ghi còn lại để xóa
          for (int i = 1; i < entry.value.length; i++) {
            duplicateDocs.add(entry.value[i]);
          }
        }
      }
      
      // Bước 3: Xóa các bản ghi trùng lặp
      if (duplicateDocs.isNotEmpty) {
        developer.log('Phát hiện ${duplicateDocs.length} bản ghi trùng lặp cần xóa');
        
        // Xác nhận và xóa các tài liệu trùng lặp
        for (var doc in duplicateDocs) {
          try {
            await firestore.collection('users').doc(doc.id).delete();
            developer.log('Đã xóa tài liệu trùng lặp: ${doc.id}');
          } catch (e) {
            developer.log('Lỗi khi xóa tài liệu ${doc.id}: $e');
          }
        }
        
        setState(() {
          _statusMessage = 'Đã xử lý thành công! ' +
              'Phát hiện $emailDuplicatesCount email trùng lặp. ' +
              'Đã xóa ${duplicateDocs.length} bản ghi trùng lặp.';
        });
      } else {
        developer.log('Không phát hiện dữ liệu trùng lặp');
        setState(() {
          _statusMessage = 'Kiểm tra hoàn tất! Không phát hiện dữ liệu người dùng trùng lặp.';
        });
      }
    } catch (e) {
      developer.log('❌ Lỗi khi kiểm tra dữ liệu trùng lặp: $e');
      setState(() {
        _statusMessage = 'Lỗi khi kiểm tra dữ liệu trùng lặp: $e';
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
            
            // Thêm card kiểm tra dữ liệu trùng lặp
            Card(
              elevation: 4,
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kiểm tra dữ liệu người dùng trùng lặp',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Công cụ này sẽ kiểm tra và tìm ra các dữ liệu người dùng bị trùng lặp trong collection "users". '
                      'Sẽ giữ lại bản mới nhất và xóa các bản trùng lặp. '
                      'Quá trình này không thể hoàn tác, vui lòng cân nhắc trước khi thực hiện.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isLoading ? null : _checkAndRemoveDuplicateUsers,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Kiểm tra & xóa dữ liệu trùng',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ),
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