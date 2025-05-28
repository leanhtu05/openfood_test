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
      });

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
      
      // Tính toán ngày dưới dạng chuỗi ISO để lọc
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // Truy vấn Firestore - chỉ lọc theo user_id
      final snapshot = await _waterCollection
          .where('user_id', isEqualTo: userId) // Lọc theo user_id
          .get();

      // Lọc kết quả theo ngày ở phía client
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
        // Lọc theo ngày
        final entryDate = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
        return entryDate == dateString;
      }).toList();

      debugPrint('ℹ️ Tìm thấy ${entries.length} mục nhập nước trên Firestore cho ngày $dateString');
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
