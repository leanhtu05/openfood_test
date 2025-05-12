import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';

// Tạo một class quản lý dữ liệu bài tập với ChangeNotifier để thông báo thay đổi
class ExerciseDataManager extends ChangeNotifier {
  static final ExerciseDataManager _instance = ExerciseDataManager._internal();
  
  // Singleton pattern
  factory ExerciseDataManager() {
    return _instance;
  }
  
  ExerciseDataManager._internal();
  
  List<Exercise> _exercises = [];
  Exercise? _selectedExercise;
  
  // Getter cho danh sách bài tập
  List<Exercise> get exercises => _exercises;
  
  // Getter cho bài tập đã chọn
  Exercise? get selectedExercise => _selectedExercise;
  
  // Phương thức tải dữ liệu từ SharedPreferences
  Future<void> loadExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final exercisesJson = prefs.getString('saved_exercises') ?? '[]';
    
    try {
      final List<dynamic> exercisesList = jsonDecode(exercisesJson);
      _exercises = exercisesList.map((e) => Exercise.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      print('Lỗi khi tải dữ liệu bài tập: $e');
    }
  }
  
  // Phương thức tải bài tập đã chọn
  Future<void> loadSelectedExercise() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedExerciseJson = prefs.getString('selectedExercise');
    
    if (selectedExerciseJson != null) {
      try {
        final exerciseMap = jsonDecode(selectedExerciseJson);
        _selectedExercise = Exercise.fromJson(exerciseMap);
        notifyListeners();
      } catch (e) {
        print('Lỗi khi tải bài tập đã chọn: $e');
      }
    }
  }
  
  // Phương thức lưu bài tập đã chọn
  Future<void> saveSelectedExercise(Exercise exercise) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedExercise', jsonEncode(exercise.toJson()));
    
    _selectedExercise = exercise;
    notifyListeners();
  }
  
  // Phương thức xóa bài tập đã chọn
  Future<void> clearSelectedExercise() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedExercise');
    
    _selectedExercise = null;
    notifyListeners();
  }
  
  // Phương thức thêm bài tập mới
  Future<void> addExercise(Exercise exercise) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Thêm vào danh sách
    _exercises.add(exercise);
    
    // Lưu vào SharedPreferences
    await prefs.setString('saved_exercises', jsonEncode(_exercises.map((e) => e.toJson()).toList()));
    
    notifyListeners();
  }
  
  // Phương thức thêm nhiều bài tập
  Future<void> addExercises(List<Exercise> newExercises) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Thêm vào danh sách
    _exercises.addAll(newExercises);
    
    // Lưu vào SharedPreferences
    await prefs.setString('saved_exercises', jsonEncode(_exercises.map((e) => e.toJson()).toList()));
    
    notifyListeners();
  }
  
  // Phương thức xóa bài tập theo index
  Future<void> removeExerciseAt(int index) async {
    if (index < 0 || index >= _exercises.length) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Lấy bài tập sắp xóa
    final removedExercise = _exercises[index];
    
    // Xóa khỏi danh sách
    _exercises.removeAt(index);
    
    // Lưu lại danh sách vào SharedPreferences
    await prefs.setString('saved_exercises', jsonEncode(_exercises.map((e) => e.toJson()).toList()));
    
    // Nếu bài tập đã chọn trùng với bài tập vừa xóa, xóa luôn bài tập đã chọn
    if (_selectedExercise != null && 
        _selectedExercise!.name == removedExercise.name &&
        _selectedExercise!.date == removedExercise.date) {
      await clearSelectedExercise();
    }
    
    notifyListeners();
  }
  
  // Phương thức xóa bài tập theo ID (nếu có)
  Future<void> removeExerciseById(String id) async {
    // Since Exercise doesn't have an id field, we need to use a different approach
    // For example, we could use a combination of name and date as a unique identifier
    final index = _exercises.indexWhere((exercise) => 
      '${exercise.name}_${exercise.date}' == id);
    
    if (index != -1) {
      await removeExerciseAt(index);
    }
  }
}