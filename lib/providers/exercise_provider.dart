import 'package:flutter/foundation.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
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

  // Constructor
  ExerciseProvider({FirebaseAuth? authService}) 
      : _authService = authService ?? FirebaseAuth.instance {
    _loadExercisesFromPrefs();
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
    
    // Tải dữ liệu từ SharedPreferences trước
    await _loadExercisesFromPrefs();
    
    // Nếu người dùng đã đăng nhập, thử tải từ Firebase
    final user = _authService.currentUser;
    if (user != null) {
      try {
        // Ưu tiên lấy dữ liệu từ Firestore trực tiếp
        try {
          final firestore = FirebaseFirestore.instance;
          final querySnapshot = await firestore
              .collection('exercise_entries')
              .where('user_id', isEqualTo: user.uid)
              .where('date', isEqualTo: _selectedDate)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
            // Chỉ cập nhật exercises cho ngày được chọn
            if (_exercisesByDate.containsKey(_selectedDate)) {
              _exercisesByDate[_selectedDate]!.clear();
            } else {
              _exercisesByDate[_selectedDate] = [];
            }
            
            // Chuyển đổi dữ liệu từ Firestore sang Exercise
            final firestoreExercises = querySnapshot.docs.map((doc) {
              final data = doc.data();
              return Exercise.fromJson(data);
            }).toList();
            
            _exercisesByDate[_selectedDate]!.addAll(firestoreExercises);
            debugPrint('✅ Đã tải ${firestoreExercises.length} bài tập từ Firestore trực tiếp');
            
            // Lưu vào bộ nhớ cục bộ
            await _saveExercisesToPrefs();
            setState(_isLoading, false);
            notifyListeners();
            return;
          }
        } catch (firestoreError) {
          debugPrint('⚠️ Lỗi khi lấy dữ liệu từ Firestore trực tiếp: $firestoreError');
        }
        
        // Nếu không thể lấy từ Firestore trực tiếp, thử lấy từ API
        final firebaseExercises = await ApiService.getExercisesFromFirebase(user.uid, _selectedDate);
        
        if (firebaseExercises != null && firebaseExercises.isNotEmpty) {
          // Chỉ cập nhật exercises cho ngày được chọn
          if (_exercisesByDate.containsKey(_selectedDate)) {
            _exercisesByDate[_selectedDate]!.clear();
          } else {
            _exercisesByDate[_selectedDate] = [];
          }
          
          _exercisesByDate[_selectedDate]!.addAll(firebaseExercises);
          debugPrint('✅ Đã tải ${firebaseExercises.length} bài tập từ API');
          
          // Lưu vào bộ nhớ cục bộ
          await _saveExercisesToPrefs();
          setState(_isLoading, false);
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi tải dữ liệu từ Firebase: $e');
      }
    }
    
    // Nếu không thể tải từ Firebase hoặc API, sử dụng dữ liệu cục bộ
    debugPrint('ℹ️ Sử dụng dữ liệu bài tập cục bộ cho ngày $_selectedDate');
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
        
        // Nếu không có dữ liệu từ Firebase, thử lấy từ API
        final allApiExercises = await ApiService.getAllExercises(user.uid);
        if (allApiExercises != null) {
          _exercisesByDate = allApiExercises;
          debugPrint('✅ Đã tải tất cả bài tập từ API');
          
          // Lưu lại vào SharedPreferences
          await _saveExercisesToPrefs();
          notifyListeners();
        } else {
          debugPrint('ℹ️ Không tìm thấy dữ liệu bài tập trực tuyến, sử dụng dữ liệu cục bộ');
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

  // Thêm bài tập mới
  Future<bool> addExercise(Exercise exercise) async {
    try {
      // Thêm vào danh sách local
      if (!_exercisesByDate.containsKey(exercise.date.split('T')[0])) {
        _exercisesByDate[exercise.date.split('T')[0]] = [];
      }
      _exercisesByDate[exercise.date.split('T')[0]]!.add(exercise);
      notifyListeners();
      
      // Lưu vào SharedPreferences
      await _saveExercisesToPrefs();
      
      // Gửi đến API
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          final result = await ApiService.sendExercise(exercise, userId);
          if (result) {
            debugPrint('✅ Đã gửi bài tập đến API thành công');
          } else {
            debugPrint('⚠️ Không thể gửi bài tập đến API');
          }
          return result;
        } catch (e) {
          debugPrint('❌ Lỗi khi gửi bài tập đến API: $e');
          return false;
        }
      }
      
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
          
          // Gửi đến API
          final userId = _authService.currentUser?.uid;
          if (userId != null) {
            try {
              final result = await ApiService.updateExercise(newExercise, userId);
              if (result) {
                debugPrint('✅ Đã cập nhật bài tập trên API thành công');
              } else {
                debugPrint('⚠️ Không thể cập nhật bài tập trên API');
              }
              return result;
            } catch (e) {
              debugPrint('❌ Lỗi khi cập nhật bài tập trên API: $e');
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

  // Xóa một Exercise
  Future<bool> deleteExercise(String id) async {
    try {
      // Tìm bài tập theo id
      Exercise? exerciseToDelete;
      String? dateOfExercise;
      
      for (var date in _exercisesByDate.keys) {
        final index = _exercisesByDate[date]!.indexWhere((e) => 
          e.id == id || '${e.name}_${e.date}_${e.minutes}' == id);
          
        if (index != -1) {
          exerciseToDelete = _exercisesByDate[date]![index];
          dateOfExercise = date;
          break;
        }
      }
      
      if (exerciseToDelete != null && dateOfExercise != null) {
        // Xóa Exercise khỏi danh sách trong Provider
        _exercisesByDate[dateOfExercise]!.remove(exerciseToDelete);
        
        // Nếu danh sách rỗng, xóa key
        if (_exercisesByDate[dateOfExercise]!.isEmpty) {
          _exercisesByDate.remove(dateOfExercise);
        }
        
        notifyListeners();
        
        // Lưu vào SharedPreferences
        await _saveExercisesToPrefs();
        
        // Xóa trên API
        final userId = _authService.currentUser?.uid;
        if (userId != null) {
          try {
            final result = await ApiService.deleteExercise(id, userId);
            if (result) {
              debugPrint('✅ Đã xóa bài tập trên API thành công');
            } else {
              debugPrint('⚠️ Không thể xóa bài tập trên API');
            }
            return result;
          } catch (e) {
            debugPrint('❌ Lỗi khi xóa bài tập trên API: $e');
            return false;
          }
        }
        
        return true;
      }
      return false;
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
}