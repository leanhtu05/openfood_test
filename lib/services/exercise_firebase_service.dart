import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/exercise_entry.dart';
import '../utils/firebase_helpers.dart';

class ExerciseFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy collection reference cho exercise entries
  CollectionReference get _exerciseCollection {
    return _firestore.collection('exercise_entries');
  }

  // Lưu một exercise entry vào Firebase
  Future<bool> saveExerciseEntry(ExerciseEntry entry) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint('❌ Không thể lưu exercise entry: Người dùng chưa đăng nhập');
        return false;
      }

      final userId = _auth.currentUser!.uid;
      
      // Chuẩn bị dữ liệu cho Firestore
      final data = FirebaseHelpers.prepareDataForFirestore({
        'id': entry.id,
        'exercise_id': entry.exerciseId,
        'name': entry.name,
        'calories': entry.calories,
        'duration': entry.duration,
        'timestamp': entry.timestamp,
        'type': entry.type,
        'user_id': userId, // Thêm user_id vào dữ liệu
        'createdAt': entry.createdAt,
      });

      // Lưu vào Firestore
      await _exerciseCollection.doc(entry.id).set(data);
      
      debugPrint('✅ Đã lưu exercise entry vào Firebase thành công');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu exercise entry vào Firebase: $e');
      return false;
    }
  }

  // Xóa một exercise entry khỏi Firebase
  Future<bool> deleteExerciseEntry(String entryId) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint('❌ Không thể xóa exercise entry: Người dùng chưa đăng nhập');
        return false;
      }

      await _exerciseCollection.doc(entryId).delete();
      
      debugPrint('✅ Đã xóa exercise entry khỏi Firebase thành công');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa exercise entry khỏi Firebase: $e');
      return false;
    }
  }

  // Lấy tất cả exercise entries cho một ngày cụ thể
  Future<List<ExerciseEntry>> getExerciseEntriesForDate(DateTime date) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint('❌ Không thể lấy exercise entries: Người dùng chưa đăng nhập');
        return [];
      }

      final userId = _auth.currentUser!.uid;
      
      // Tính toán ngày dưới dạng chuỗi ISO để lọc
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // Truy vấn Firestore - chỉ lọc theo user_id
      final snapshot = await _exerciseCollection
          .where('user_id', isEqualTo: userId) // Lọc theo user_id
          .get();

      // Lọc kết quả theo ngày ở phía client
      final entries = snapshot.docs.map((doc) {
        final data = FirebaseHelpers.processFirestoreData(doc.data() as Map<String, dynamic>);
        return ExerciseEntry.fromJson(data);
      }).where((entry) {
        // Lọc theo ngày
        final entryDate = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
        return entryDate == dateString;
      }).toList();

      debugPrint('ℹ️ Tìm thấy ${entries.length} mục nhập bài tập trên Firestore cho ngày $dateString');
      return entries;
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy exercise entries từ Firebase: $e');
      return [];
    }
  }

  // Đồng bộ tất cả exercise entries lên Firebase
  Future<bool> syncAllExerciseEntries(List<ExerciseEntry> entries) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint('❌ Không thể đồng bộ exercise entries: Người dùng chưa đăng nhập');
        return false;
      }

      final userId = _auth.currentUser!.uid;
      
      // Tạo batch để thực hiện nhiều thao tác cùng lúc
      final batch = _firestore.batch();

      // Thêm mỗi entry vào batch
      for (final entry in entries) {
        final data = FirebaseHelpers.prepareDataForFirestore({
          'id': entry.id,
          'exercise_id': entry.exerciseId,
          'name': entry.name,
          'calories': entry.calories,
          'duration': entry.duration,
          'timestamp': entry.timestamp,
          'type': entry.type,
          'user_id': userId, // Thêm user_id vào dữ liệu
          'createdAt': entry.createdAt,
        });

        batch.set(_exerciseCollection.doc(entry.id), data);
      }

      // Commit batch
      await batch.commit();
      
      debugPrint('✅ Đã đồng bộ ${entries.length} exercise entries lên Firebase thành công');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ exercise entries lên Firebase: $e');
      return false;
    }
  }
}
