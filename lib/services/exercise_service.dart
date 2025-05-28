import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../providers/exercise_provider.dart';

class ExerciseService {
  static const String _exercisesKey = 'exercises_by_date';

  // Lưu bài tập đã chọn
  static Future<void> saveSelectedExercise(Exercise exercise) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedExercise', jsonEncode(exercise.toJson()));
  }
  
  // Lấy bài tập đã chọn
  static Future<Exercise?> getSelectedExercise() async {
    final prefs = await SharedPreferences.getInstance();
    final exerciseJson = prefs.getString('selectedExercise');
    
    if (exerciseJson != null) {
      try {
        final exerciseMap = jsonDecode(exerciseJson);
        return Exercise.fromJson(exerciseMap);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  // Xóa bài tập đã chọn
  static Future<void> clearSelectedExercise() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedExercise');
  }
  
  // Lưu danh sách bài tập
  static Future<void> saveExercises(List<Exercise> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    final exercisesJson = prefs.getString('saved_exercises') ?? '[]';
    List<dynamic> exercisesList = jsonDecode(exercisesJson);
    
    // Thêm bài tập mới vào danh sách
    for (var exercise in exercises) {
      exercisesList.add({
        'name': exercise.name,
        'icon': exercise.icon,
        'minutes': exercise.minutes,
        'intensity': exercise.intensity,
        'calories': exercise.calories,
        'date': exercise.date, // Đảm bảo ngày được lưu đúng
      });
    }
    
    // Lưu lại danh sách
    await prefs.setString('saved_exercises', jsonEncode(exercisesList));
  }
  
  // Lấy tất cả bài tập
  static Future<List<Exercise>> getAllExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final exercisesJson = prefs.getString('saved_exercises') ?? '[]';
    final List<dynamic> exercisesList = jsonDecode(exercisesJson);
    return exercisesList.map((e) => Exercise.fromJson(e)).toList();
  }
  
  // Thêm phương thức xóa bài tập
  static Future<void> removeExercise(Exercise exercise) async {
    try {
      // Lấy tất cả bài tập hiện có
      final allExercises = await getAllExercises();
      
      // Lọc ra danh sách bài tập không bao gồm bài tập cần xóa
      final updatedExercises = allExercises.where((e) => 
        !(e.name == exercise.name && 
          e.date == exercise.date && 
          e.minutes == exercise.minutes)).toList();
      
      // Lưu lại danh sách đã cập nhật
      await saveExercises(updatedExercises);
      
      // Nếu bài tập đang xóa là bài tập đã chọn, xóa bài tập đã chọn
      final selectedExercise = await getSelectedExercise();
      if (selectedExercise != null && 
          selectedExercise.name == exercise.name && 
          selectedExercise.date == exercise.date && 
          selectedExercise.minutes == exercise.minutes) {
        await clearSelectedExercise();
      }
      
    } catch (e) {
      throw e; // Ném lại lỗi để xử lý ở UI
    }
  }
  
  // Cập nhật bài tập
  static Future<void> updateExercise(Exercise oldExercise, Exercise newExercise) async {
    try {
      // Lấy tất cả bài tập hiện có
      final allExercises = await getAllExercises();
      
      // Tìm và cập nhật bài tập
      final index = allExercises.indexWhere((e) => 
        e.name == oldExercise.name && 
        e.date == oldExercise.date && 
        e.minutes == oldExercise.minutes);
      
      if (index != -1) {
        allExercises[index] = newExercise;
        
        // Lưu lại danh sách đã cập nhật
        await saveExercises(allExercises);
        
        // Nếu bài tập đang cập nhật là bài tập đã chọn, cập nhật bài tập đã chọn
        final selectedExercise = await getSelectedExercise();
        if (selectedExercise != null && 
            selectedExercise.name == oldExercise.name && 
            selectedExercise.date == oldExercise.date && 
            selectedExercise.minutes == oldExercise.minutes) {
          await saveSelectedExercise(newExercise);
        }
        
      }
    } catch (e) {
      throw e; // Ném lại lỗi để xử lý ở UI
    }
  }
  
  // Lưu danh sách Exercise theo ngày
  static Future<void> saveExercisesForDate(String date, List<Exercise> exercises) async {
    try {
      // Sử dụng ExerciseProvider để lưu vào cả Firestore và local
      final provider = ExerciseProvider();
      provider.setSelectedDate(date);
      
      // Xóa các bài tập cũ trong ngày này
      final currentExercises = provider.selectedDateExercises;
      for (var exercise in currentExercises) {
        if (exercise.id != null) {
          await provider.deleteExercise(exercise.id!);
        }
      }
      
      // Thêm các bài tập mới
      for (var exercise in exercises) {
        // Đảm bảo exercise có ngày đúng
        final updatedExercise = exercise.copyWith(
          date: exercise.date.contains('T') ? exercise.date : '${exercise.date}T00:00:00.000Z'
        );
        await provider.addExercise(updatedExercise);
      }
      
      // Dưới đây là cách lưu cũ vào SharedPreferences, vẫn giữ lại để đảm bảo tương thích ngược
      final prefs = await SharedPreferences.getInstance();
      
      // Lấy Map hiện tại từ SharedPreferences
      final exercisesMapJson = prefs.getString(_exercisesKey) ?? '{}';
      Map<String, dynamic> exercisesMap = jsonDecode(exercisesMapJson);
      
      // Chuyển danh sách Exercise thành List<Map>
      final exercisesJson = exercises.map((e) => e.toJson()).toList();
      
      // Cập nhật Map với ngày mới
      if (exercises.isEmpty) {
        // Nếu danh sách rỗng, xóa key
        exercisesMap.remove(date);
      } else {
        // Nếu có dữ liệu, cập nhật key
        exercisesMap[date] = exercisesJson;
      }
      
      // Lưu lại vào SharedPreferences
      await prefs.setString(_exercisesKey, jsonEncode(exercisesMap));
      
      debugPrint('✅ Đã lưu ${exercises.length} bài tập cho ngày $date vào cả Firestore và SharedPreferences');
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu bài tập vào Firestore: $e');
      
      // Dùng cách lưu cũ nếu gặp lỗi
      final prefs = await SharedPreferences.getInstance();
      final exercisesMapJson = prefs.getString(_exercisesKey) ?? '{}';
      Map<String, dynamic> exercisesMap = jsonDecode(exercisesMapJson);
      
      // Chuyển danh sách Exercise thành List<Map>
      final exercisesJson = exercises.map((e) => e.toJson()).toList();
      
      // Cập nhật Map với ngày mới
      if (exercises.isEmpty) {
        // Nếu danh sách rỗng, xóa key
        exercisesMap.remove(date);
      } else {
        // Nếu có dữ liệu, cập nhật key
        exercisesMap[date] = exercisesJson;
      }
      
      // Lưu lại vào SharedPreferences
      await prefs.setString(_exercisesKey, jsonEncode(exercisesMap));
    }
  }

  // Lấy danh sách Exercise theo ngày
  static Future<List<Exercise>> getExercisesForDate(String date) async {
    try {
      // Sử dụng ExerciseProvider để lấy dữ liệu từ Firestore
      final provider = ExerciseProvider();
      provider.setSelectedDate(date);
      
      // Đợi tải dữ liệu từ Firestore
      await provider.loadData();
      
      // Lấy danh sách bài tập từ provider
      final exercises = provider.selectedDateExercises;
      
      if (exercises.isNotEmpty) {
        debugPrint('✅ Đã tải ${exercises.length} bài tập từ Firestore qua ExerciseProvider cho ngày $date');
        return exercises;
      } else {
        debugPrint('ℹ️ Không có bài tập nào trên Firestore cho ngày $date, thử đọc từ SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu từ Firestore qua ExerciseProvider: $e');
    }
    
    // Nếu không có dữ liệu từ Firestore hoặc có lỗi, dùng cách cũ đọc từ SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final exercisesMapJson = prefs.getString(_exercisesKey) ?? '{}';
      Map<String, dynamic> exercisesMap = jsonDecode(exercisesMapJson);
      
      // Kiểm tra xem có dữ liệu cho ngày này không
      if (!exercisesMap.containsKey(date)) {
        return [];
      }
      
      // Chuyển đổi dữ liệu từ JSON sang List<Exercise>
      final exercisesJson = exercisesMap[date] as List;
      final localExercises = exercisesJson
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList();
      
      debugPrint('✅ Đã tải ${localExercises.length} bài tập từ SharedPreferences cho ngày $date');
      return localExercises;
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu từ SharedPreferences: $e');
      return [];
    }
  }

  // Lấy tất cả Exercise từ tất cả các ngày
  // Rename this method to be more specific about what it returns
  static Future<Map<String, List<Exercise>>> getAllExercisesByDate() async {
    final prefs = await SharedPreferences.getInstance();
    final exercisesMapJson = prefs.getString(_exercisesKey) ?? '{}';
    Map<String, dynamic> exercisesMap = jsonDecode(exercisesMapJson);
    
    // Chuyển đổi từ Map<String, dynamic> sang Map<String, List<Exercise>>
    Map<String, List<Exercise>> result = {};
    exercisesMap.forEach((date, exercises) {
      final exercisesList = (exercises as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList();
      result[date] = exercisesList;
    });
    
    return result;
  }

  // Xóa một Exercise khỏi danh sách của một ngày
  static Future<void> deleteExercise(Exercise exercise) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final exercisesMapJson = prefs.getString(_exercisesKey) ?? '{}';
      Map<String, dynamic> exercisesMap = jsonDecode(exercisesMapJson);
      
      // Get the date from the exercise
      final date = exercise.date.split('T')[0];
      
      // Check if we have exercises for this date
      if (exercisesMap.containsKey(date)) {
        List<dynamic> exercises = exercisesMap[date];
        
        // Remove the exercise that matches by id if available, otherwise use other properties
        if (exercise.id != null) {
          exercises.removeWhere((e) => e['id'] == exercise.id);
        } else {
          exercises.removeWhere((e) => 
            e['name'] == exercise.name && 
            e['minutes'] == exercise.minutes && 
            e['intensity'] == exercise.intensity
          );
        }
        
        // If the list is empty, remove the date key
        if (exercises.isEmpty) {
          exercisesMap.remove(date);
        } else {
          exercisesMap[date] = exercises;
        }
        
        // Save back to SharedPreferences
        await prefs.setString(_exercisesKey, jsonEncode(exercisesMap));
        
        // Also check and clear selected exercise if it matches
        final selectedExercise = await getSelectedExercise();
        if (selectedExercise != null) {
          bool isMatch = false;
          
          if (exercise.id != null && selectedExercise.id != null) {
            isMatch = exercise.id == selectedExercise.id;
          } else {
            isMatch = selectedExercise.name == exercise.name && 
                      selectedExercise.date == exercise.date && 
                      selectedExercise.minutes == exercise.minutes;
          }
          
          if (isMatch) {
            await clearSelectedExercise();
          }
        }
        
      }
    } catch (e) {
      throw e; // Throw error for UI handling
    }
  }
}