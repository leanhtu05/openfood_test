import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';

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
  }

  // Lấy danh sách Exercise theo ngày
  static Future<List<Exercise>> getExercisesForDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final exercisesMapJson = prefs.getString(_exercisesKey) ?? '{}';
    Map<String, dynamic> exercisesMap = jsonDecode(exercisesMapJson);
    
    // Kiểm tra xem có dữ liệu cho ngày này không
    if (!exercisesMap.containsKey(date)) {
      return [];
    }
    
    // Chuyển đổi dữ liệu từ JSON sang List<Exercise>
    final exercisesJson = exercisesMap[date] as List;
    return exercisesJson
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
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