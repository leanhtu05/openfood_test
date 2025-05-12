import 'package:flutter/foundation.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import 'package:intl/intl.dart';

class ExerciseProvider with ChangeNotifier {
  Map<String, List<Exercise>> _exercisesByDate = {};
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  bool _isLoading = false;

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
    _selectedDate = date;
    notifyListeners();
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

  // Tải exercise cho ngày hiện tại
  Future<void> loadExercises() async {
    setState(_isLoading, true);
    
    try {
      final exercises = await ExerciseService.getExercisesForDate(_selectedDate);
      // Sửa lỗi: Thay vì gán cho _selectedDateExercises, gán cho _exercisesByDate[_selectedDate]
      _exercisesByDate[_selectedDate] = exercises;
      
      setState(_isLoading, false);
    } catch (e) {
      // Sửa lỗi: Thay vì gán cho _selectedDateExercises, gán cho _exercisesByDate[_selectedDate]
      _exercisesByDate[_selectedDate] = [];
      
      setState(_isLoading, false);
    }
  }

  // Tải tất cả exercises từ tất cả các ngày
  Future<void> loadAllExercises() async {
    setState(_isLoading, true);
    
    try {
      // Sử dụng service để lấy tất cả bài tập theo ngày
      _exercisesByDate = await ExerciseService.getAllExercisesByDate();
      
      setState(_isLoading, false);
    } catch (e) {
      _exercisesByDate = {};
      
      setState(_isLoading, false);
    }
  }

  // Helper to update loading state
  void setState(bool currentState, bool newState) {
    if (currentState != newState) {
      _isLoading = newState;
      notifyListeners();
    }
  }

  // Lưu danh sách Exercise cho ngày đã chọn
  Future<void> saveExercisesForSelectedDate(List<Exercise> exercises) async {
    try {
      // Cập nhật danh sách trong Provider
      _exercisesByDate[_selectedDate] = exercises;
      
      // Lưu vào SharedPreferences
      await ExerciseService.saveExercisesForDate(_selectedDate, exercises);
      
      notifyListeners();
    } catch (e) {
      print('Lỗi khi lưu bài tập: $e');
    }
  }

  // Xóa một Exercise
  Future<void> deleteExercise(String id) async {
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
        
        // Lấy danh sách bài tập mới cho ngày đã chọn
        final updatedExercises = _exercisesByDate[dateOfExercise] ?? [];
        
        // Lưu danh sách đã cập nhật vào SharedPreferences
        await ExerciseService.saveExercisesForDate(dateOfExercise, updatedExercises);
        
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi xóa bài tập: $e');
    }
  }

  // Cập nhật một Exercise
  Future<void> updateExercise(Exercise oldExercise, Exercise newExercise) async {
    try {
      // Xác định ngày của Exercise
      final date = oldExercise.date.split('T')[0];
      
      // Cập nhật Exercise trong danh sách của Provider
      if (_exercisesByDate.containsKey(date)) {
        final index = _exercisesByDate[date]!.indexWhere((e) => 
          e.name == oldExercise.name && 
          e.minutes == oldExercise.minutes && 
          e.intensity == oldExercise.intensity
        );
        
        if (index != -1) {
          _exercisesByDate[date]![index] = newExercise;
          
          // Lưu thay đổi vào SharedPreferences
          await ExerciseService.saveExercisesForDate(date, _exercisesByDate[date]!);
          
          notifyListeners();
        }
      }
    } catch (e) {
      print('Lỗi khi cập nhật bài tập: $e');
    }
  }
}