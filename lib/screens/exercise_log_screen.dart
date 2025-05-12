import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:openfood/providers/exercise_provider.dart';
import 'package:openfood/services/exercise_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/exercise_item_widget.dart';
import '../models/exercise.dart';
import '../utils/constants.dart';

class ExerciseLogScreen extends StatefulWidget {
  const ExerciseLogScreen({Key? key}) : super(key: key);

  @override
  _ExerciseLogScreenState createState() => _ExerciseLogScreenState();
}

class _ExerciseLogScreenState extends State<ExerciseLogScreen> {
  List<Exercise> exercises = [
    Exercise(
      name: 'Đi bộ',
      icon: '🚶',
      intensity: 'Vừa phải',
      minutes: 45,
      caloriesPerMinute: 3.1,
      isSelected: false,
    ),
    Exercise(
      name: 'Chạy',
      icon: '🏃',
      intensity: 'Vừa phải',
      minutes: 30,
      caloriesPerMinute: 8.6,
      isSelected: false,
    ),
    Exercise(
      name: 'Đạp xe',
      icon: '🚴',
      intensity: 'Vừa phải',
      minutes: 45,
      caloriesPerMinute: 7.1,
      isSelected: false,
    ),
    Exercise(
      name: 'Nâng tạ',
      icon: '🏋️',
      intensity: 'Vừa phải',
      minutes: 45,
      caloriesPerMinute: 4.4,
      isSelected: false,
    ),
    Exercise(
      name: 'Yoga',
      icon: '🧘',
      intensity: 'Vừa phải',
      minutes: 60,
      caloriesPerMinute: 2.7,
      isSelected: false,
    ),
    Exercise(
      name: 'Bơi lội',
      icon: '🏊',
      intensity: 'Vừa phải',
      minutes: 45,
      caloriesPerMinute: 7.1,
      isSelected: false,
    ),
    Exercise(
      name: 'Máy chạy bộ',
      icon: '🏃',
      intensity: 'Vừa phải',
      minutes: 40,
      caloriesPerMinute: 5.3,
      isSelected: false,
    ),
    Exercise(
      name: 'Bài tập tại nhà',
      icon: '🏠',
      intensity: 'Vừa phải',
      minutes: 30,
      caloriesPerMinute: 4.0,
      isSelected: false,
    ),
    Exercise(
      name: 'Giãn cơ',
      icon: '🤸',
      intensity: 'Vừa phải',
      minutes: 15,
      caloriesPerMinute: 2.5,
      isSelected: false,
    ),
    Exercise(
      name: 'HIIT',
      icon: '⚡',
      intensity: 'Vừa phải',
      minutes: 20,
      caloriesPerMinute: 8.0,
      isSelected: false,
    ),
    Exercise(
      name: 'Pilates',
      icon: '🧠',
      intensity: 'Vừa phải',
      minutes: 45,
      caloriesPerMinute: 3.1,
      isSelected: false,
    ),
    Exercise(
      name: 'Quần vợt',
      icon: '🎾',
      intensity: 'Vừa phải',
      minutes: 60,
      caloriesPerMinute: 6.2,
      isSelected: false,
    ),
    Exercise(
      name: 'Bóng rổ',
      icon: '🏀',
      intensity: 'Vừa phải',
      minutes: 45,
      caloriesPerMinute: 7.1,
      isSelected: false,
    ),
    Exercise(
      name: 'Bóng đá',
      icon: '⚽',
      intensity: 'Vừa phải',
      minutes: 60,
      caloriesPerMinute: 7.1,
      isSelected: false,
    ),
    Exercise(
      name: 'Khác',
      icon: '🏃',
      intensity: 'Vừa phải',
      minutes: 20,
      caloriesPerMinute: 5.3,
      isSelected: false,
    ),
  ];

  DateTime currentTime = DateTime.now();
  Map<String, int> _exerciseCalories = {}; // Thêm Map để lưu calories
  String selectedDate = DateTime.now().toIso8601String().split('T')[0]; // Thêm biến selectedDate
  TimeOfDay selectedTime = TimeOfDay.now(); // Thêm biến để lưu giờ đã chọn
  
  // Biến để theo dõi hành động thay thế bài tập
  Exercise? exerciseToReplace;
  bool isReplaceMode = false;

  // Tính tổng calories từ các bài tập đã chọn
  int get totalCalories {
    return _exerciseCalories.values.fold(0, (sum, calories) => sum + calories);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.directions_run, color: Colors.black, size: 12),
            SizedBox(width: 5),
            Text(
              'Ghi nhật ký bài tập',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 10),
            child: ElevatedButton.icon(
              onPressed: () {
                // Thêm bài tập mới
              },
              icon: Icon(Icons.add, color: AppColors.secondary, size: 12),
              label: Text(
                'Thêm mới',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                return ExerciseItemWidget(
                  exercise: exercises[index],
                  onSelectionChanged: (isSelected) {
                    setState(() {
                      // Tạo bản sao mới với isSelected được cập nhật
                      exercises[index] = exercises[index].copyWith(isSelected: isSelected);
                      // Gọi phương thức cập nhật _exerciseCalories khi chọn/bỏ chọn bài tập
                      updateExerciseCalories(exercises[index], isSelected);
                    });
                  },
                  onMinutesChanged: (minutes) {
                    // Sử dụng updateExerciseMinutes để cập nhật minutes
                    updateExerciseMinutes(exercises[index], minutes);
                  },
                );
              },
            ),
          ),
          _buildBottomSummary(),
        ],
      ),
    );
  }

  // Cập nhật phương thức updateExerciseMinutes để sử dụng copyWith
  void updateExerciseMinutes(Exercise exercise, int minutes) {
    setState(() {
      final index = exercises.indexOf(exercise);
      if (index != -1) {
        // Tạo bản sao mới với minutes được cập nhật
        final updatedExercise = exercise.copyWith(minutes: minutes);
        exercises[index] = updatedExercise;
        
        if (updatedExercise.isSelected) {
          // Cập nhật calories dựa trên thời gian mới
          _exerciseCalories[updatedExercise.name] = updatedExercise.calculatedCalories;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    
    // Reset all exercises to unselected state
    for (int i = 0; i < exercises.length; i++) {
      exercises[i] = exercises[i].copyWith(isSelected: false);
    }
    
    // Clear any previously stored calories
    _exerciseCalories.clear();
    
    // Get any arguments passed from previous screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      
      if (args != null) {
        if (args is String) {
          // If argument is just a string date
          setState(() {
            selectedDate = args;
            isReplaceMode = false;
          });
        } else if (args is Map<String, dynamic>) {
          // Handle map arguments with date and possibly an exercise to replace
          final date = args['date'] as String?;
          final replaceExercise = args['replace'] as Exercise?;
          
          if (date != null) {
            setState(() {
              selectedDate = date;
            });
          }
          
          // If we're replacing an exercise, store it
          if (replaceExercise != null) {
            // Lấy giờ từ bài tập cần thay thế
            final exerciseDateTime = DateTime.parse(replaceExercise.date);
            
            setState(() {
              exerciseToReplace = replaceExercise;
              isReplaceMode = true;
              // Đặt giờ mặc định là giờ của bài tập cần thay thế
              selectedTime = TimeOfDay(hour: exerciseDateTime.hour, minute: exerciseDateTime.minute);
            });
            
            // Find matching exercise in our list and select only it
            for (int i = 0; i < exercises.length; i++) {
              // Khi đến màn hình exercise log thì không cần chọn sẵn bài tập
              // Chỉ lưu exerciseToReplace để sau này xử lý
              exercises[i] = exercises[i].copyWith(isSelected: false);
            }
                
            // Show a message that we're replacing an exercise
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chọn hoạt động thay thế cho ${replaceExercise.name}'),
                  duration: Duration(seconds: 3),
                ),
              );
            });
          }
        }
      }
    });
  }
  
  bool _didInitialLoad = false;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Chỉ tải dữ liệu một lần khi widget được tạo
    if (!_didInitialLoad) {
      // Lấy ngày đã chọn từ arguments
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null) {
        if (args is String) {
          selectedDate = args;
        } else if (args is Map<String, dynamic>) {
          // Handle map arguments
          final date = args['date'] as String?;
          if (date != null) {
            selectedDate = date;
          }
          // Exercise replacement is handled in initState
        }
      }
      
      // Tải các bài tập đã lưu cho ngày này
      _loadSavedExercises();
      
      // Đánh dấu đã tải dữ liệu
      _didInitialLoad = true;
    }
  }
  
  // Thêm phương thức để tải các bài tập đã lưu
  Future<void> _loadSavedExercises() async {
    try {
      // Lấy danh sách bài tập đã lưu cho ngày đã chọn
      final savedExercises = await ExerciseService.getExercisesForDate(selectedDate);
      
      // Chỉ lấy dữ liệu minutes và intensity, không đánh dấu là đã chọn
      if (savedExercises.isNotEmpty && !isReplaceMode) {
        setState(() {
          for (var exercise in exercises) {
            final savedExercise = savedExercises.firstWhere(
              (e) => e.name == exercise.name,
              orElse: () => exercise,
            );
            
            // Chỉ cập nhật minutes và intensity, không đánh dấu isSelected
            final index = exercises.indexWhere((e) => e.name == exercise.name);
            if (index != -1) {
              exercises[index] = exercise.copyWith(
                isSelected: false, // Luôn đặt là false để không có bài tập nào được chọn sẵn
                minutes: savedExercise.minutes,
                intensity: savedExercise.intensity,
              );
            }
          }
        });
      }
    } catch (e) {
      print('Lỗi khi tải bài tập đã lưu: $e');
    }
  }

  // Cập nhật Map _exerciseCalories khi người dùng chọn/bỏ chọn bài tập
  void updateExerciseCalories(Exercise exercise, bool isSelected) {
    setState(() {
      if (isSelected) {
        _exerciseCalories[exercise.name] = exercise.calculatedCalories;
      } else {
        _exerciseCalories.remove(exercise.name);
      }
    });
  }

  // Cập nhật Map _exerciseCalories khi người dùng thay đổi thời gian

  Widget _buildBottomSummary() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
              SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final TimeOfDay? time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.green,
                          ),
                        ),
                        child: child!,
                      );
                    }
                  );
                  if (time != null) {
                    setState(() {
                      selectedTime = time;
                    });
                  }
                },
                child: Row(
                  children: [
                    Text(
                      'Hôm nay ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.edit, size: 16, color: AppColors.secondary),
                  ],
                ),
              ),
              Spacer(),
              Row(
                children: [
                  Icon(Icons.menu, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Tổng: ${totalCalories} kcal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: exercises.any((e) => e.isSelected) ? () async {
                try {
                  // Tạo DateTime kết hợp ngày và giờ đã chọn
                  final selectedDateObj = DateTime.parse(selectedDate);
                  final dateTimeWithSelectedTime = DateTime(
                    selectedDateObj.year,
                    selectedDateObj.month,
                    selectedDateObj.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  ).toIso8601String();
                  
                  List<Exercise> selectedExercises = exercises
                      .where((exercise) => exercise.isSelected)
                      .map((exercise) => exercise.copyWith(
                            date: dateTimeWithSelectedTime,
                            minutes: exercise.minutes,
                            icon: exercise.icon,
                            intensity: exercise.intensity,
                            id: exercise.id ?? exercise.generateId(),
                          ))
                      .toList();
                  
                  if (selectedExercises.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Vui lòng chọn ít nhất một bài tập')),
                    );
                    return;
                  }

                  // Lấy danh sách bài tập hiện có cho ngày này
                  final existingExercises = await ExerciseService.getExercisesForDate(selectedDate);
                  
                  if (isReplaceMode && exerciseToReplace != null) {
                    // Chế độ thay thế: Lấy bài tập đầu tiên được chọn để thay thế
                    if (selectedExercises.length > 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Chỉ một hoạt động đầu tiên sẽ được dùng để thay thế')),
                      );
                    }
                    
                    // Lấy bài tập đầu tiên trong danh sách
                    final replacementExercise = selectedExercises.first;
                    
                    // Tìm và thay thế bài tập cần thay thế
                    final newExercises = existingExercises.map((e) {
                      // Nếu đây là bài tập cần thay thế, thay thế nó
                      if (e.id == exerciseToReplace!.id) {
                        // Giữ nguyên ID của bài tập gốc để đảm bảo tính liên tục
                        return replacementExercise.copyWith(
                          id: exerciseToReplace!.id,
                          date: dateTimeWithSelectedTime,
                        );
                      }
                      // Giữ nguyên các bài tập khác
                      return e;
                    }).toList();
                    
                    // Lưu danh sách mới
                    await ExerciseService.saveExercisesForDate(selectedDate, newExercises);
                    
                    // Hiển thị thông báo thành công
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã cập nhật hoạt động thành công')),
                    );
                  } else {
                    // Chế độ thông thường: Thêm mới tất cả
                    final List<Exercise> allExercises = [...existingExercises];
                    
                    // Thêm mới tất cả các bài tập đã chọn
                    for (var exercise in selectedExercises) {
                      exercise = exercise.copyWith(date: dateTimeWithSelectedTime);
                      allExercises.add(exercise);
                    }
                    
                    // Lưu tất cả bài tập vào SharedPreferences
                    await ExerciseService.saveExercisesForDate(selectedDate, allExercises);
                    
                    // Hiển thị thông báo thành công
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã lưu bài tập thành công')),
                    );
                  }
                  
                  // Cập nhật Provider và đợi hoàn thành
                  final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
                  exerciseProvider.setSelectedDate(selectedDate);
                  await exerciseProvider.loadExercises();
                  
                  // Quay về màn hình chính và trigger cập nhật
                  Navigator.of(context).pop(true);
                } catch (e) {
                  print('Lỗi khi lưu bài tập: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Có lỗi xảy ra khi lưu bài tập')),
                  );
                }
              } : null,
              child: Text(
                'Đồng ý',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: exercises.any((e) => e.isSelected) ? AppColors.primary : Colors.grey[300],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
