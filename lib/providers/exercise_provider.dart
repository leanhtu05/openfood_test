import 'package:flutter/foundation.dart';
import '../models/exercise.dart';
import '../models/exercise_entry.dart';
import '../services/exercise_service.dart';
import '../services/exercise_firebase_service.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseProvider with ChangeNotifier {
  Map<String, List<Exercise>> _exercisesByDate = {};
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  bool _isLoading = false;
  final FirebaseAuth _authService;
  final ExerciseFirebaseService _exerciseFirebaseService = ExerciseFirebaseService();

  // Constructor
  ExerciseProvider({FirebaseAuth? authService}) 
      : _authService = authService ?? FirebaseAuth.instance {
    _loadExercisesFromPrefs();
    
    // Listen for auth state changes
    _authService.authStateChanges().listen((User? user) {
      if (user != null) {
        // User logged in, sync data from Firebase
        syncFromFirebase();
      } else {
        // User logged out, clear data
        clearDataOnLogout();
      }
    });
  }

  // Getter cho ngày đã chọn
  String get selectedDate => _selectedDate;
  
  // Getter cho danh sách Exercise của ngày đã chọn
  List<Exercise> get selectedDateExercises {
    return _exercisesByDate[_selectedDate] ?? [];
  }
  
  // Getter cho tất cả Exercise
  Map<String, List<Exercise>> get allExercises => _exercisesByDate;

  // Getter for loading state
  bool get isLoading => _isLoading;
  
  // Cập nhật ngày đã chọn
  void setSelectedDate(String date) {
    if (_selectedDate != date) {
      _selectedDate = date;
      debugPrint('ExerciseProvider: Đã đặt ngày thành $date');
      notifyListeners();
      
      // Tải dữ liệu cho ngày mới
      loadData();
    } else {
      debugPrint('ExerciseProvider: Ngày đã được đặt là $date, không cần thay đổi');
    }
  }
  
  // Tính tổng calories cho ngày đã chọn
  int get totalCalories {
    return selectedDateExercises.fold(0, (sum, exercise) => sum + exercise.calories);
  }

  // Phương thức để nhóm các bài tập theo ngày
  Map<String, List<Exercise>> getExercisesByDay() {
    Map<String, List<Exercise>> grouped = {};
    
    // Duyệt qua tất cả các bài tập đã lưu
    _exercisesByDate.forEach((date, exercises) {
      for (var exercise in exercises) {
        // Xác định key ngày cho bài tập
        final exerciseDate = DateTime.parse(exercise.date);
        final key = _getDateKey(exerciseDate);
        
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        
        grouped[key]!.add(exercise);
      }
    });
    
    // Sắp xếp các bài tập trong mỗi ngày theo thời gian
    grouped.forEach((day, exercises) {
      exercises.sort((a, b) {
        final aDate = DateTime.parse(a.date);
        final bDate = DateTime.parse(b.date);
        return bDate.compareTo(aDate); // Sắp xếp giảm dần (mới nhất trước)
      });
    });
    
    return grouped;
  }
  
  // Helper method để tạo key cho nhóm ngày
  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Hôm nay';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Hôm qua';
    } else {
      return 'Ngày ${date.day} tháng ${date.month}';
    }
  }

  // Tải dữ liệu
  Future<void> loadData() async {
    if (_selectedDate.isEmpty) return;
    
    setState(_isLoading, true);
    debugPrint('🔄 Đang tải dữ liệu bài tập cho ngày $_selectedDate...');
    
    // Tải dữ liệu từ SharedPreferences trước
    await _loadExercisesFromPrefs();
    
    // Đảm bảo có danh sách trống cho ngày đã chọn nếu chưa có
    if (!_exercisesByDate.containsKey(_selectedDate)) {
      _exercisesByDate[_selectedDate] = [];
    }
    
    // Tải dữ liệu từ Firestore nếu người dùng đã đăng nhập
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      try {
        debugPrint('🔄 Truy vấn trực tiếp vào Firestore cho ngày $_selectedDate...');
        
        // Truy vấn trực tiếp vào collection exercises trong Firestore
        final querySnapshot = await FirebaseFirestore.instance
          .collection('exercises')
          .where('user_id', isEqualTo: currentUser.uid)
          .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          debugPrint('✅ Tìm thấy ${querySnapshot.docs.length} bài tập trong Firestore, đang lọc theo ngày $_selectedDate');
          
          // Lọc kết quả theo ngày đã chọn
          final selectedDateExercises = <Exercise>[];
          
          for (var doc in querySnapshot.docs) {
            try {
              final data = doc.data();
              
              // Trích xuất ngày từ dữ liệu
              String? dateStr = data['date'];
              if (dateStr == null || dateStr.isEmpty) {
                // Nếu không có trường date, thử tìm trong các trường khác
                dateStr = data['timestamp'] ?? data['created_at'] ?? data['updated_at'];
              }
              
              if (dateStr != null && dateStr.isNotEmpty) {
                // Lọc theo ngày đã chọn
                String docDate = '';
                if (dateStr.contains('T')) {
                  docDate = dateStr.split('T')[0];
                } else {
                  docDate = dateStr;
                }
                
                if (docDate == _selectedDate) {
                  // Tạo đối tượng Exercise từ dữ liệu Firestore
                  final exercise = Exercise(
                    id: data['id'] ?? doc.id,
                    name: data['name'] ?? 'Không xác định',
                    icon: data['icon'] ?? 'fitness_center',
                    minutes: data['minutes'] ?? data['duration'] ?? 30,
                    calories: data['calories'] ?? 0,
                    date: dateStr,
                    intensity: data['intensity'] ?? data['type'] ?? 'Vừa phải',
                  );
                  
                  selectedDateExercises.add(exercise);
                  debugPrint('  ✅ Tìm thấy bài tập cho ngày $_selectedDate: ${exercise.name}');
                }
              }
            } catch (e) {
              debugPrint('⚠️ Lỗi khi xử lý document ${doc.id}: $e');
            }
          }
          
          if (selectedDateExercises.isNotEmpty) {
            // Cập nhật danh sách bài tập cho ngày đã chọn
            _exercisesByDate[_selectedDate] = selectedDateExercises;
            debugPrint('✅ Đã tải ${selectedDateExercises.length} bài tập cho ngày $_selectedDate');
            
            // Lưu vào SharedPreferences
            await _saveExercisesToPrefs();
          } else {
            debugPrint('ℹ️ Không tìm thấy bài tập nào cho ngày $_selectedDate');
          }
        } else {
          debugPrint('ℹ️ Không tìm thấy bài tập nào trong Firestore');
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi tải dữ liệu bài tập từ Firestore: $e');
      }
    } else {
      debugPrint('ℹ️ Người dùng chưa đăng nhập, sử dụng dữ liệu local');
    }
    
    // Kết thúc trạng thái loading và thông báo UI cập nhật
    setState(_isLoading, false);
    notifyListeners();
  }
        
  // Tải tất cả exercises từ tất cả các ngày
  Future<void> loadAllExercises() async {
    setState(_isLoading, true);
    
    // Tải từ SharedPreferences trước
    await _loadExercisesFromPrefs();
    
    // Nếu người dùng đã đăng nhập, thử tải từ Firebase
    final user = _authService.currentUser;
    if (user != null) {
      try {
        // Ưu tiên lấy dữ liệu từ Firebase
        final allFirebaseExercises = await ApiService.getAllExercisesFromFirebase(user.uid);
        
        if (allFirebaseExercises != null && allFirebaseExercises.isNotEmpty) {
          _exercisesByDate = allFirebaseExercises;
          debugPrint('✅ Đã tải tất cả bài tập từ Firebase');
          
          // Lưu lại vào SharedPreferences
          await _saveExercisesToPrefs();
          notifyListeners();
          setState(_isLoading, false);
          return;
        }
        
        // Lấy tất cả bài tập trực tiếp từ Firestore
        try {
          final exercisesSnapshot = await FirebaseFirestore.instance
              .collection('exercises')
              .where('user_id', isEqualTo: user.uid)
              .get();
          
          if (exercisesSnapshot.docs.isNotEmpty) {
            Map<String, List<Exercise>> exercisesByDate = {};
            
            for (var doc in exercisesSnapshot.docs) {
              final exerciseData = doc.data();
              final exercise = Exercise.fromJson(exerciseData);
              final date = exercise.date.split('T')[0];
              
              if (!exercisesByDate.containsKey(date)) {
                exercisesByDate[date] = [];
              }
              
              exercisesByDate[date]!.add(exercise);
            }
            
            _exercisesByDate = exercisesByDate;
            debugPrint('✅ Đã tải tất cả bài tập từ Firestore');
            
            // Lưu lại vào SharedPreferences
            await _saveExercisesToPrefs();
            notifyListeners();
          } else {
            debugPrint('ℹ️ Không tìm thấy dữ liệu bài tập trực tuyến, sử dụng dữ liệu cục bộ');
          }
        } catch (e) {
          debugPrint('❌ Lỗi khi truy vấn dữ liệu bài tập từ Firestore: $e');
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi tải tất cả bài tập từ Firebase/API: $e');
        debugPrint('ℹ️ Sử dụng dữ liệu cục bộ từ SharedPreferences');
      }
    } else {
      debugPrint('ℹ️ Không có người dùng đăng nhập, sử dụng dữ liệu cục bộ từ SharedPreferences');
    }
    
    setState(_isLoading, false);
  }

  // Helper to update loading state
  void setState(bool currentState, bool newState) {
    if (currentState != newState) {
      _isLoading = newState;
      notifyListeners();
    }
  }

  // Thêm một bài tập mới
  Future<bool> addExercise(Exercise exercise) async {
    try {
      // Đảm bảo exercise có ID
      if (exercise.id == null || exercise.id!.isEmpty) {
        exercise = exercise.copyWith(
          id: FirebaseFirestore.instance.collection('exercises').doc().id
        );
      }
      
      // Đảm bảo date có định dạng ISO 8601
      if (!exercise.date.contains('T')) {
        exercise = exercise.copyWith(
          date: '${exercise.date}T00:00:00.000Z'
        );
      }
      
      // Lấy ngày để phân loại trong bộ nhớ
      final dateKey = exercise.date.split('T')[0];
      debugPrint('🔥 Thêm bài tập mới: ${exercise.name} vào ngày $dateKey');
      
      // Thêm vào danh sách local
      if (!_exercisesByDate.containsKey(dateKey)) {
        _exercisesByDate[dateKey] = [];
      }
      
      // Thêm vào danh sách của ngày tương ứng
      _exercisesByDate[dateKey]!.add(exercise);
      
      // Lưu vào SharedPreferences
      await _saveExercisesToPrefs();
      
      // Lưu vào Firestore nếu đã đăng nhập
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          // Chuẩn bị dữ liệu để lưu vào Firestore
          final exerciseData = {
            ...exercise.toJson(),
            'user_id': userId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          // Lưu trực tiếp vào Firestore
          await FirebaseFirestore.instance
            .collection('exercises')
            .doc(exercise.id)
            .set(exerciseData);
          
          debugPrint('✅ Đã lưu bài tập trực tiếp vào Firestore thành công');
        } catch (firestoreError) {
          debugPrint('❌ Lỗi khi lưu trực tiếp vào Firestore: $firestoreError');
          
          // Thử phương pháp 2: Sử dụng ApiService
          try {
            final success = await ApiService.sendExercise(exercise, userId);
            if (success) {
              debugPrint('✅ Đã lưu bài tập vào Firestore thành công qua ApiService');
            } else {
              debugPrint('❌ Không thể lưu bài tập vào Firestore qua ApiService');
            }
          } catch (apiError) {
            debugPrint('❌ Lỗi khi gọi ApiService.sendExercise: $apiError');
          }
        }
      }
      
      // Thông báo UI cập nhật
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi thêm bài tập: $e');
      return false;
    }
  }

  // Cập nhật một Exercise
  Future<bool> updateExercise(Exercise oldExercise, Exercise newExercise) async {
    try {
      // Xác định ngày của Exercise
      final date = oldExercise.date.split('T')[0];
      
      // Cập nhật Exercise trong danh sách của Provider
      if (_exercisesByDate.containsKey(date)) {
        final index = _exercisesByDate[date]!.indexWhere((e) => 
          e.id == oldExercise.id || 
          (e.name == oldExercise.name && 
          e.minutes == oldExercise.minutes && 
          e.intensity == oldExercise.intensity)
        );
        
        if (index != -1) {
          _exercisesByDate[date]![index] = newExercise;
          notifyListeners();
          
          // Lưu vào SharedPreferences
          await _saveExercisesToPrefs();
          
          // Cập nhật trực tiếp vào Firebase
          final userId = _authService.currentUser?.uid;
          if (userId != null) {
            try {
              // Cập nhật vào Firestore trực tiếp
              await FirebaseFirestore.instance
                  .collection('exercise_entries')
                  .doc(newExercise.id)
                  .update({
                    ...newExercise.toJson(),
                    'user_id': userId,
                  });
              
              debugPrint('✅ Đã cập nhật bài tập trên Firebase thành công');
              
              // Chỉ gửi đến API cho các chức năng phức tạp (nếu cần)
              if (newExercise.needsAdvancedAnalysis) {
                final result = await ApiService.updateExercise(newExercise, userId);
                if (result) {
                  debugPrint('✅ Đã gửi bài tập cập nhật đến API để phân tích nâng cao');
                } else {
                  debugPrint('⚠️ Không thể gửi bài tập cập nhật đến API để phân tích');
                }
              }
              
              return true;
            } catch (e) {
              debugPrint('❌ Lỗi khi cập nhật bài tập trên Firebase: $e');
              return false;
            }
          }
          
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật bài tập: $e');
      return false;
    }
  }

  // Xóa một bài tập
  Future<bool> deleteExercise(String id) async {
    try {
      // Tìm bài tập trong danh sách local
      Exercise? exerciseToDelete;
      String? dateKey;
      
      for (final date in _exercisesByDate.keys) {
        final exercises = _exercisesByDate[date]!;
        final index = exercises.indexWhere((e) => e.id == id);
        
        if (index != -1) {
          exerciseToDelete = exercises[index];
          dateKey = date;
          break;
        }
      }
      
      if (exerciseToDelete == null || dateKey == null) {
        debugPrint('❌ Không tìm thấy bài tập với id: $id');
        return false;
      }
      
      // Xóa khỏi danh sách local
      _exercisesByDate[dateKey]!.removeWhere((e) => e.id == id);
      
      // Nếu danh sách trống, xóa luôn key
      if (_exercisesByDate[dateKey]!.isEmpty) {
        _exercisesByDate.remove(dateKey);
      }
      
      // Lưu vào SharedPreferences
      await _saveExercisesToPrefs();
      
      // Thông báo UI cập nhật
      notifyListeners();
      
      // Xóa trực tiếp trên Firebase nếu đã đăng nhập
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          // Phương pháp 1: Sử dụng ApiService.deleteExercise đã được cập nhật để sử dụng Firestore trực tiếp
          final success = await ApiService.deleteExercise(id, userId);
          
          if (success) {
            debugPrint('✅ Đã xóa bài tập vào Firestore thành công qua ApiService');
          } else {
            debugPrint('⚠️ Không thể xóa bài tập vào Firestore qua ApiService, thử phương pháp 2');
            
            // Phương pháp 2: Sử dụng ExerciseFirebaseService
            final backupSuccess = await _exerciseFirebaseService.deleteExerciseEntry(id);
            
            if (backupSuccess) {
              debugPrint('✅ Đã xóa bài tập trên Firebase thành công qua ExerciseFirebaseService');
            } else {
              debugPrint('❌ Không thể xóa bài tập trên Firebase qua ExerciseFirebaseService');
              
              // Phương pháp 3: Thử xóa trực tiếp từ Firestore
              try {
                // Thử cả hai collection khác nhau để đảm bảo xóa được
                await FirebaseFirestore.instance.collection('exercises').doc(id).delete();
                debugPrint('✅ Đã xóa bài tập trực tiếp từ collection "exercises"');
                
                // Thử xóa thêm từ collection exercise_entries nếu có
                try {
                  await FirebaseFirestore.instance.collection('exercise_entries').doc(id).delete();
                  debugPrint('✅ Đã xóa bài tập trực tiếp từ collection "exercise_entries"');
                } catch (e) {
                  // Không gây lỗi nếu không tìm thấy trong collection này
                }
                
                return true;
              } catch (firestoreError) {
                debugPrint('❌ Lỗi khi xóa trực tiếp từ Firestore: $firestoreError');
              }
            }
          }
          
          return true;
        } catch (e) {
          debugPrint('❌ Lỗi khi xóa bài tập trên Firestore: $e');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa bài tập: $e');
      return false;
    }
  }

  // Trả về toàn bộ exercise entries dưới dạng List<Map<String, dynamic>> để đồng bộ
  List<Map<String, dynamic>> getAllExercisesAsJson() {
    return _exercisesByDate.values.expand((e) => e).map((e) => e.toJson()).toList();
  }
  
  // Lưu dữ liệu bài tập vào SharedPreferences
  Future<void> _saveExercisesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> exercisesMap = {};
      
      _exercisesByDate.forEach((date, exercises) {
        exercisesMap[date] = exercises.map((e) => e.toJson()).toList();
      });
      
      await prefs.setString('exercises_data', jsonEncode(exercisesMap));
      debugPrint('✅ Đã lưu dữ liệu bài tập vào SharedPreferences');
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu dữ liệu bài tập vào SharedPreferences: $e');
    }
  }
  
  // Tải dữ liệu bài tập từ SharedPreferences
  Future<void> _loadExercisesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? exercisesJson = prefs.getString('exercises_data');
      if (exercisesJson != null) {
        final Map<String, dynamic> exercisesMap = jsonDecode(exercisesJson);
        final Map<String, List<Exercise>> loadedExercises = {};
        
        exercisesMap.forEach((date, exercises) {
          loadedExercises[date] = (exercises as List)
              .map((e) => Exercise.fromJson(e))
              .toList();
        });
        
        _exercisesByDate = loadedExercises;
        debugPrint('✅ Đã tải dữ liệu bài tập từ SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu bài tập từ SharedPreferences: $e');
    }
  }

  // Phương thức loadExercises để tương thích với code cũ
  Future<void> loadExercises() async {
    // Gọi đến phương thức loadData mới
    await loadData();
  }
  
  // Đồng bộ dữ liệu từ Firebase khi đăng nhập lại
  Future<void> syncFromFirebase() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    
    try {
      debugPrint('🔄 Đang đồng bộ dữ liệu bài tập từ Firestore...');
      
      // Lấy dữ liệu trực tiếp từ Firestore cho ngày hiện tại
      final today = DateTime.now();
      final todayString = today.toIso8601String().split('T')[0];
      
      try {
        debugPrint('🔄 Truy vấn trực tiếp vào Firestore cho ngày $todayString...');
        
        // Lấy tất cả bài tập của người dùng trước
        final querySnapshot = await FirebaseFirestore.instance
            .collection('exercises')
            .where('user_id', isEqualTo: currentUser.uid)
            .get();
            
        debugPrint('✅ Tìm thấy ${querySnapshot.docs.length} bài tập trong Firestore, đang lọc theo ngày $todayString');
        
        // Lọc bài tập theo ngày sau khi đã lấy từ Firestore
        final filteredExercises = querySnapshot.docs
            .map((doc) => Exercise.fromJson(doc.data()))
            .where((exercise) {
              // Kiểm tra xem bài tập có thuộc ngày đang chọn không
              String exerciseDate = '';
              if (exercise.date.contains('T')) {
                exerciseDate = exercise.date.split('T')[0];
              } else {
                exerciseDate = exercise.date;
              }
              
              debugPrint('  🔍 Kiểm tra bài tập: ${exercise.name}, ngày: $exerciseDate, cần tìm: $todayString');
              return exerciseDate == todayString;
            })
            .toList();
        
        if (filteredExercises.isNotEmpty) {
          // Cập nhật dữ liệu local cho ngày hiện tại
          _exercisesByDate[todayString] = filteredExercises;
          
          // Cập nhật SharedPreferences
          await _saveExercisesToPrefs();
          
          // Thông báo UI cập nhật
          notifyListeners();
          
          debugPrint('✅ Đã đồng bộ ${filteredExercises.length} bài tập từ Firestore cho ngày $todayString');
        } else {
          debugPrint('ℹ️ Không tìm thấy bài tập nào cho ngày $todayString');
          
          // Đồng bộ dữ liệu local lên Firestore nếu có
          final localExercises = _exercisesByDate[todayString] ?? [];
          
          if (localExercises.isNotEmpty) {
            for (var exercise in localExercises) {
              final success = await ApiService.sendExercise(exercise, currentUser.uid);
              if (success) {
                debugPrint('✅ Đã đồng bộ bài tập "${exercise.name}" lên Firestore');
              } else {
                debugPrint('❌ Không thể đồng bộ bài tập "${exercise.name}" lên Firestore');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi truy vấn dữ liệu bài tập từ Firestore: $e');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ dữ liệu bài tập từ Firestore: $e');
    }
  }

  // Method to clear data when user logs out
  Future<void> clearDataOnLogout() async {
    try {
      debugPrint('🧹 ExerciseProvider: Clearing data on logout...');
      
      // Clear all exercise entries
      _exercisesByDate = {};
      
      // Update SharedPreferences
      await _saveExercisesToPrefs();
      
      // Notify UI to update
      notifyListeners();
      
      debugPrint('✅ ExerciseProvider: Data cleared successfully on logout');
    } catch (e) {
      debugPrint('❌ ExerciseProvider: Error clearing data on logout: $e');
    }
  }
}