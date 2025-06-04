import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/water_entry.dart';
import '../utils/firebase_helpers.dart';

class WaterFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy collection reference cho water entries
  CollectionReference get _waterCollection {
    return _firestore.collection('water_entries');
  }

  // Lưu một water entry vào Firebase
  Future<bool> saveWaterEntry(WaterEntry entry) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint('❌ Không thể lưu water entry: Người dùng chưa đăng nhập');
        return false;
      }

      final userId = _auth.currentUser!.uid;
      
      // Chuẩn bị dữ liệu cho Firestore
      final data = FirebaseHelpers.prepareDataForFirestore({
        'id': entry.id,
        'amount': entry.amount,
        'timestamp': entry.timestamp,
        'user_id': userId, // Thêm user_id vào dữ liệu
        'date': entry.timestamp.toIso8601String().split('T')[0], // Thêm trường date dạng 'YYYY-MM-DD' để dễ truy vấn
      });

      debugPrint('✏️ Lưu water entry vào Firebase: id=${entry.id}, amount=${entry.amount}ml, date=${data['date']}');
      
      // Lưu vào Firestore
      await _waterCollection.doc(entry.id).set(data);
      
      debugPrint('✅ Đã lưu water entry vào Firebase thành công');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu water entry vào Firebase: $e');
      return false;
    }
  }

  // Xóa một water entry khỏi Firebase
  Future<bool> deleteWaterEntry(String entryId) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint('❌ Không thể xóa water entry: Người dùng chưa đăng nhập');
        return false;
      }

      await _waterCollection.doc(entryId).delete();
      
      debugPrint('✅ Đã xóa water entry khỏi Firebase thành công');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa water entry khỏi Firebase: $e');
      return false;
    }
  }

  // Lấy tất cả water entries cho một ngày cụ thể
  Future<List<WaterEntry>> getWaterEntriesForDate(DateTime date) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint('❌ Không thể lấy water entries: Người dùng chưa đăng nhập');
        return [];
      }

      final userId = _auth.currentUser!.uid;
      
      // Tạo thời gian bắt đầu và kết thúc của ngày
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
      
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      debugPrint('🔍 Tìm các bản ghi nước cho ngày $dateString');
      
      // Phương pháp 1: Sử dụng trường date thay vì timestamp để tránh cần composite index
      try {
        final snapshot = await _waterCollection
            .where('user_id', isEqualTo: userId)
            .where('date', isEqualTo: dateString)
            .get();
            
        debugPrint('📊 Thử phương pháp 1: Tìm thấy ${snapshot.docs.length} bản ghi');
        
        if (snapshot.docs.isNotEmpty) {
          final entries = snapshot.docs.map((doc) {
            final data = FirebaseHelpers.processFirestoreData(doc.data() as Map<String, dynamic>);
            return WaterEntry(
              id: data['id'] ?? doc.id,
              amount: data['amount'] ?? 0,
              timestamp: data['timestamp'] is DateTime 
                  ? data['timestamp'] 
                  : (data['timestamp'] is String ? DateTime.parse(data['timestamp']) : DateTime.now()),
            );
          }).toList();
          
          return entries;
        }
      } catch (e) {
        debugPrint('⚠️ Phương pháp 1 thất bại: $e, thử phương pháp 2...');
      }
      
      // Phương pháp 2: Chỉ lọc theo user_id và lọc thêm theo timestamp phía client
      final snapshot = await _waterCollection
          .where('user_id', isEqualTo: userId)
          .get();
      
      debugPrint('📊 Thử phương pháp 2: Tìm thấy ${snapshot.docs.length} bản ghi tổng, đang lọc theo ngày');
      
      final entries = snapshot.docs.map((doc) {
        final data = FirebaseHelpers.processFirestoreData(doc.data() as Map<String, dynamic>);
        return WaterEntry(
          id: data['id'] ?? doc.id,
          amount: data['amount'] ?? 0,
          timestamp: data['timestamp'] is DateTime 
              ? data['timestamp'] 
              : (data['timestamp'] is String ? DateTime.parse(data['timestamp']) : DateTime.now()),
        );
      }).where((entry) {
        // Lọc bản ghi trong khoảng ngày chỉ định
        return entry.timestamp.isAfter(startOfDay.subtract(Duration(seconds: 1))) && 
               entry.timestamp.isBefore(endOfDay.add(Duration(seconds: 1)));
      }).toList();
      
      debugPrint('✅ Tìm thấy ${entries.length} bản ghi nước trên Firebase cho ngày ${startOfDay.day}/${startOfDay.month}/${startOfDay.year}');
      return entries;
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy water entries từ Firebase: $e');
      return [];
    }
  }

  // Đồng bộ tất cả water entries lên Firebase
  Future<bool> syncAllWaterEntries(List<WaterEntry> entries) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint('❌ Không thể đồng bộ water entries: Người dùng chưa đăng nhập');
        return false;
      }

      final userId = _auth.currentUser!.uid;
      
      // Tạo batch để thực hiện nhiều thao tác cùng lúc
      final batch = _firestore.batch();

      // Thêm mỗi entry vào batch
      for (final entry in entries) {
        final data = FirebaseHelpers.prepareDataForFirestore({
          'id': entry.id,
          'amount': entry.amount,
          'timestamp': entry.timestamp,
          'user_id': userId, // Thêm user_id vào dữ liệu
        });

        batch.set(_waterCollection.doc(entry.id), data);
      }

      // Commit batch
      await batch.commit();
      
      debugPrint('✅ Đã đồng bộ ${entries.length} water entries lên Firebase thành công');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ water entries lên Firebase: $e');
      return false;
    }
  }
}
