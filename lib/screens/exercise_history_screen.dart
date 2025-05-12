import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/exercise.dart';
import '../models/water_entry.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/water_provider.dart';
import 'package:intl/intl.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  static const routeName = '/exercise_history';
  const ExerciseHistoryScreen({Key? key}) : super(key: key);

  @override
  _ExerciseHistoryScreenState createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  bool isLoading = true;
  Map<String, List<Exercise>> exercisesByDate = {};
  Map<String, List<WaterEntry>> waterEntriesByDate = {};
  bool _showEmptyEntries = false;
  
  // Biến lọc loại hoạt động
  Set<String> _selectedFilters = {'Bài tập'};
  bool _showFoodItems = false;
  bool _showFavoriteFoodItems = false;
  bool _showExerciseItems = true;
  bool _showWaterItems = false;

  @override
  void initState() {
    super.initState();
    // Đặt lại bộ lọc mặc định
    _resetFilters();
    _loadExercises();
  }
  
  @override
  void dispose() {
    // Không cần thực hiện gì trong dispose() vì chúng ta đặt lại bộ lọc trong initState()
    super.dispose();
  }
  
  // Phương thức đặt lại bộ lọc về giá trị mặc định
  void _resetFilters() {
    _selectedFilters = {'Bài tập'};
    _showFoodItems = false;
    _showFavoriteFoodItems = false;
    _showExerciseItems = true;
    _showWaterItems = false;
  }

  Future<void> _loadExercises() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Tải dữ liệu bài tập
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      await exerciseProvider.loadExercises();

      // Nhóm các bài tập theo ngày
      final Map<String, List<Exercise>> groupedExercises = {};
      exerciseProvider.allExercises.forEach((date, exercises) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
        if (!groupedExercises.containsKey(formattedDate)) {
          groupedExercises[formattedDate] = [];
        }
        groupedExercises[formattedDate]?.addAll(exercises);
      });
      
      // Tải dữ liệu nước
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      await waterProvider.loadData();
      
      // Nhóm các bản ghi nước theo ngày
      final Map<String, List<WaterEntry>> groupedWaterEntries = {};
      final waterEntries = waterProvider.entries;
      
      for (var entry in waterEntries) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(entry.timestamp);
        if (!groupedWaterEntries.containsKey(formattedDate)) {
          groupedWaterEntries[formattedDate] = [];
        }
        groupedWaterEntries[formattedDate]!.add(entry);
      }

      setState(() {
        exercisesByDate = Map.fromEntries(
            groupedExercises.entries.toList()
              ..sort((a, b) => DateTime.parse(b.key).compareTo(DateTime.parse(a.key)))
        );
        
        waterEntriesByDate = Map.fromEntries(
            groupedWaterEntries.entries.toList()
              ..sort((a, b) => DateTime.parse(b.key).compareTo(DateTime.parse(a.key)))
        );
        
        isLoading = false;
      });
    } catch (e) {
      print('Lỗi khi tải dữ liệu: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Chuyển đổi Map exercises thành danh sách phẳng
      final allExercises = exercisesByDate.values.expand((exercises) => exercises).toList();
      
      final exercisesJson = jsonEncode(allExercises.map((e) => e.toJson()).toList());
      await prefs.setString('saved_exercises', exercisesJson);
    } catch (e) {
      print('Lỗi khi lưu dữ liệu bài tập: $e');
    }
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Xác nhận xóa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bạn có chắc chắn muốn xóa bài tập "${exercise.name}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Hủy'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Xóa',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        // Tìm ngày chứa bài tập cần xóa
        String? dateToUpdate;
        for (var entry in exercisesByDate.entries) {
          if (entry.value.contains(exercise)) {
            dateToUpdate = entry.key;
            break;
          }
        }

        if (dateToUpdate != null) {
          // Cập nhật UI trước
          setState(() {
            exercisesByDate[dateToUpdate]?.remove(exercise);
            
            // Nếu danh sách rỗng, xóa ngày đó khỏi Map
            if (exercisesByDate[dateToUpdate]?.isEmpty ?? true) {
              exercisesByDate.remove(dateToUpdate);
            }
          });

          // Tạo ID duy nhất từ các thuộc tính của exercise
          String exerciseId = exercise.id ?? '${exercise.name}_${exercise.date}_${exercise.minutes}';
          // Sử dụng Provider để xóa bài tập - đồng bộ hóa thời gian thực
          await Provider.of<ExerciseProvider>(context, listen: false).deleteExercise(exerciseId);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Đã xóa bài tập'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        print('Lỗi khi xóa bài tập: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Lỗi khi xóa bài tập: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editExercise(Exercise exercise) async {
    final result = await showDialog<Exercise>(
      context: context,
      builder: (context) => EditExerciseDialog(exercise: exercise),
    );

    if (result != null) {
      try {
        // Tìm ngày chứa bài tập cần cập nhật
        String? dateToUpdate;
        int? indexInList;
        
        for (var entry in exercisesByDate.entries) {
          final index = entry.value.indexOf(exercise);
          if (index != -1) {
            dateToUpdate = entry.key;
            indexInList = index;
            break;
          }
        }

        if (dateToUpdate != null && indexInList != null) {
          // Cập nhật UI trước
          setState(() {
            exercisesByDate[dateToUpdate]![indexInList!] = result;
          });

          // Sử dụng Provider để cập nhật bài tập - đồng bộ hóa thời gian thực
          await Provider.of<ExerciseProvider>(context, listen: false)
              .updateExercise(exercise, result);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã cập nhật bài tập'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Lỗi khi cập nhật bài tập: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật bài tập: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));

    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Hôm nay';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Hôm qua';
    } else {
      return 'tháng ${date.month} ${date.day}';
    }
  }

  int _calculateTotalCalories(List<Exercise> exercises) {
    return exercises.fold(0, (sum, exercise) => sum + exercise.calories);
  }
  
  int _calculateTotalWater(List<WaterEntry> entries) {
    return entries.fold(0, (sum, entry) => sum + entry.amount);
  }
  
  void _showFilterMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.symmetric(vertical: 20),
        title: Text('Chọn loại hiển thị', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMultiFilterOption('Nước'),
            _buildMultiFilterOption('Bài tập'),
            _buildMultiFilterOption('Thực phẩm'),
            _buildMultiFilterOption('Thực phẩm yêu thích'),
          ],
        ),
      ),
    );
  }
  
  // Widget lọc mới cho phép chọn nhiều tùy chọn
  Widget _buildMultiFilterOption(String title) {
    bool isSelected = _selectedFilters.contains(title);
    
    return CheckboxListTile(
      title: Text(title),
      value: isSelected,
      checkColor: Colors.white,
      activeColor: Colors.green,
      onChanged: (value) {
        if (value == true && !isSelected) {
          // Thêm vào danh sách lọc
          setState(() {
            _selectedFilters.add(title);
            
            // Cập nhật các biến tương ứng
            if (title == 'Nước') _showWaterItems = true;
            if (title == 'Bài tập') _showExerciseItems = true;
            if (title == 'Thực phẩm') _showFoodItems = true;
            if (title == 'Thực phẩm yêu thích') _showFavoriteFoodItems = true;
          });
        } else if (value == false && isSelected) {
          // Không cho phép bỏ chọn tất cả các tùy chọn
          if (_selectedFilters.length > 1) {
            setState(() {
              _selectedFilters.remove(title);
              
              // Cập nhật các biến tương ứng
              if (title == 'Nước') _showWaterItems = false;
              if (title == 'Bài tập') _showExerciseItems = false;
              if (title == 'Thực phẩm') _showFoodItems = false;
              if (title == 'Thực phẩm yêu thích') _showFavoriteFoodItems = false;
            });
          } else {
            // Hiển thị thông báo nếu người dùng cố gắng bỏ chọn tùy chọn cuối cùng
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cần chọn ít nhất một loại dữ liệu'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        
        // Đóng dialog và tự động cập nhật UI
        Navigator.of(context).pop();
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
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
        title: Text(
          'Bài tập đã ghi',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.blue),
            onPressed: _showFilterMenu,
          ),
        ],
      ),
      floatingActionButton: _selectedFilters.contains('Nước') 
        ? FloatingActionButton(
            onPressed: _showAddWaterDialog,
            backgroundColor: Colors.blue,
            child: Icon(Icons.water_drop, color: Colors.white),
          )
        : null,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : exercisesByDate.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_run_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có bài tập nào được ghi',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _selectedFilters.contains('Nước') 
                  ? (waterEntriesByDate.length + exercisesByDate.length) 
                  : exercisesByDate.length,
              itemBuilder: (context, index) {
                // Khi chọn "Nước", hiển thị cả dữ liệu nước và dữ liệu bài tập
                if (_selectedFilters.contains('Nước')) {
                  // Tính tổng số lượng ngày duy nhất từ cả hai danh sách
                  final allDates = {...waterEntriesByDate.keys, ...exercisesByDate.keys}.toList()
                    ..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
                  
                  if (index >= allDates.length) return SizedBox();
                  
                  final date = allDates[index];
                  final hasExercises = exercisesByDate.containsKey(date);
                  final hasWaterEntries = waterEntriesByDate.containsKey(date);
                  
                  if (!hasExercises && !hasWaterEntries) return SizedBox();
                  
                  final exercises = exercisesByDate[date] ?? [];
                  final waterEntries = waterEntriesByDate[date] ?? [];
                  final totalCalories = _calculateTotalCalories(exercises);
                  final totalWater = _calculateTotalWater(waterEntries);
                  
                  return _buildDateSection(date, exercises, waterEntries, totalCalories, totalWater);
                } else {
                  // Chỉ hiển thị dữ liệu bài tập
                  final date = exercisesByDate.keys.elementAt(index);
                  final exercises = exercisesByDate[date] ?? [];
                  final totalCalories = _calculateTotalCalories(exercises);
                  
                  return _buildDateSection(date, exercises, [], totalCalories, 0);
                }
              },
            ),
    );
  }

  Widget _buildDateSection(String date, List<Exercise> exercises, List<WaterEntry> waterEntries, int totalCalories, int totalWater) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Hiển thị dữ liệu bài tập nếu có
        if (exercises.isNotEmpty)
          Container(
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Bài tập',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${totalCalories.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} kcal',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: exercises.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Colors.grey.shade200,
                  ),
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                _getExerciseIcon(exercise.name),
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${exercise.name} | ${exercise.intensity} | ${exercise.minutes} phút',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Tập thể dục ${_formatDate(date)}, ${DateFormat('HH:mm').format(DateTime.parse(exercise.date))}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '-${exercise.calories}kcal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editExercise(exercise);
                              } else if (value == 'delete') {
                                _deleteExercise(exercise);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                    SizedBox(width: 8),
                                    Text('Chỉnh sửa'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('Xóa'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
        // Hiển thị dữ liệu nước nếu có
        if (waterEntries.isNotEmpty)
          Container(
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Nước',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${totalWater.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} mL',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: waterEntries.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Colors.grey.shade200,
                  ),
                  itemBuilder: (context, index) {
                    final entry = waterEntries[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.water_drop,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ghi nhận nước',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${DateFormat('HH:mm').format(entry.timestamp)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '+${entry.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} mL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Phương thức helper để lấy icon phù hợp dựa trên tên bài tập
  IconData _getExerciseIcon(String exerciseName) {
    switch (exerciseName.toLowerCase()) {
      case 'đi bộ':
        return Icons.directions_walk;
      case 'chạy':
        return Icons.directions_run;
      case 'đạp xe':
        return Icons.directions_bike;
      case 'nâng tạ':
        return Icons.fitness_center;
      case 'yoga':
        return Icons.self_improvement;
      case 'bơi lội':
        return Icons.pool;
      case 'máy chạy bộ':
        return Icons.directions_run;
      case 'bài tập tại nhà':
        return Icons.home;
      case 'giãn cơ':
        return Icons.accessibility_new;
      case 'hiit':
        return Icons.flash_on;
      case 'pilates':
        return Icons.psychology;
      case 'quần vợt':
        return Icons.sports_tennis;
      case 'bóng rổ':
        return Icons.sports_basketball;
      case 'bóng đá':
        return Icons.sports_soccer;
      default:
        return Icons.fitness_center;
    }
  }

  // Phương thức hiển thị dialog thêm nước
  void _showAddWaterDialog() {
    int waterAmount = 250; // Mặc định 250ml
    String selectedDrinkType = 'water'; // Loại đồ uống mặc định: nước lọc
    bool isCustomAmount = false; // Biến để kiểm soát chế độ nhập tùy chỉnh
    final TextEditingController customAmountController = TextEditingController(text: '250');
    
    // Danh sách loại đồ uống
    final List<Map<String, dynamic>> drinkTypes = [
      {'id': 'water', 'name': 'Nước lọc', 'icon': Icons.water_drop, 'color': Colors.blue},
      {'id': 'tea', 'name': 'Trà', 'icon': Icons.emoji_food_beverage, 'color': Colors.brown.shade300},
      {'id': 'coffee', 'name': 'Cà phê', 'icon': Icons.coffee, 'color': Colors.brown},
      {'id': 'juice', 'name': 'Nước ép', 'icon': Icons.local_drink, 'color': Colors.orange},
    ];
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: StatefulBuilder(
          builder: (context, setState) {
            // Hàm setter cho phép cập nhật waterAmount từ các widget con
            void setWaterAmount(int value) {
              setState(() {
                waterAmount = value;
                customAmountController.text = value.toString();
                isCustomAmount = false;
              });
            }
            
            // Hàm thay đổi loại đồ uống
            void setDrinkType(String drinkId) {
              setState(() {
                selectedDrinkType = drinkId;
              });
            }
            
            // Lấy thông tin đồ uống hiện tại
            Map<String, dynamic> getCurrentDrink() {
              return drinkTypes.firstWhere((drink) => drink['id'] == selectedDrinkType);
            }
            
            return Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header với icon và tiêu đề
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: getCurrentDrink()['color'].withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          getCurrentDrink()['icon'],
                          color: getCurrentDrink()['color'],
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thêm đồ uống',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Theo dõi lượng nước đã uống',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Chọn loại đồ uống
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      itemCount: drinkTypes.length,
                      separatorBuilder: (context, index) => SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final drink = drinkTypes[index];
                        final isSelected = selectedDrinkType == drink['id'];
                        
                        return GestureDetector(
                          onTap: () => setDrinkType(drink['id']),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            width: 56,
                            decoration: BoxDecoration(
                              color: isSelected ? drink['color'] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: drink['color'].withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                )
                              ] : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  drink['icon'],
                                  color: isSelected ? Colors.white : drink['color'],
                                  size: 24,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  drink['name'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Hiển thị lượng nước đã chọn
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: getCurrentDrink()['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (!isCustomAmount) ...[
                              // Hiển thị số lượng đã chọn
                              Text(
                                '$waterAmount',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: getCurrentDrink()['color'],
                                ),
                              ),
                              Text(
                                ' mL',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                  color: getCurrentDrink()['color'],
                                ),
                              ),
                            ] else ...[
                              // Hiển thị ô nhập liệu
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: customAmountController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  autofocus: true,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: getCurrentDrink()['color'],
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '0',
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              Text(
                                ' mL',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                  color: getCurrentDrink()['color'],
                                ),
                              ),
                            ],
                            // Nút để chuyển đổi giữa nhập tùy chỉnh và slider
                            IconButton(
                              icon: Icon(
                                isCustomAmount ? Icons.graphic_eq : Icons.edit,
                                size: 18,
                              ),
                              color: getCurrentDrink()['color'],
                              onPressed: () {
                                setState(() {
                                  if (!isCustomAmount) {
                                    // Chuyển sang chế độ nhập tùy chỉnh
                                    isCustomAmount = true;
                                  } else {
                                    // Chuyển về chế độ slider và cập nhật giá trị
                                    int? value = int.tryParse(customAmountController.text);
                                    if (value != null && value > 0) {
                                      waterAmount = value > 2000 ? 2000 : value;
                                    }
                                    isCustomAmount = false;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        
                        if (!isCustomAmount) ...[
                          SizedBox(height: 8),
                          // Thanh điều chỉnh lượng nước
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                // Nút giảm
                                GestureDetector(
                                  onTap: () {
                                    if (waterAmount > 50) {
                                      setState(() {
                                        waterAmount -= 50;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.remove, color: Colors.grey[700], size: 16),
                                  ),
                                ),
                                
                                // Thanh trượt
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: getCurrentDrink()['color'],
                                      inactiveTrackColor: Colors.grey[200],
                                      thumbColor: Colors.white,
                                      thumbShape: RoundSliderThumbShape(
                                        enabledThumbRadius: 8,
                                        elevation: 4,
                                      ),
                                      overlayColor: getCurrentDrink()['color'].withOpacity(0.2),
                                      trackHeight: 4,
                                    ),
                                    child: Slider(
                                      value: waterAmount.toDouble(),
                                      min: 50,
                                      max: 2000,
                                      onChanged: (value) {
                                        setState(() {
                                          waterAmount = value.round();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                
                                // Nút tăng
                                GestureDetector(
                                  onTap: () {
                                    if (waterAmount < 2000) {
                                      setState(() {
                                        waterAmount += 50;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.add, color: Colors.grey[700], size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Các nút lựa chọn nhanh
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildQuickWaterButton(100, waterAmount, setWaterAmount),
                      _buildQuickWaterButton(200, waterAmount, setWaterAmount),
                      _buildQuickWaterButton(250, waterAmount, setWaterAmount),
                      _buildQuickWaterButton(300, waterAmount, setWaterAmount),
                      _buildQuickWaterButton(500, waterAmount, setWaterAmount),
                    ],
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Nút thao tác
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text('Hủy'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Lấy giá trị cuối cùng khi đang ở chế độ nhập tùy chỉnh
                            if (isCustomAmount) {
                              int? value = int.tryParse(customAmountController.text);
                              if (value != null && value > 0) {
                                waterAmount = value;
                              }
                            }
                            
                            // Thêm bản ghi nước
                            _addWaterEntry(waterAmount);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: getCurrentDrink()['color'],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Lưu',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  // Widget nút lựa chọn nhanh lượng nước
  Widget _buildQuickWaterButton(int amount, int currentAmount, Function(int) updateAmount) {
    // Xác định nếu nút này là nút được chọn
    final bool isSelected = currentAmount == amount;
    
    return GestureDetector(
      onTap: () {
        // Sử dụng callback để cập nhật giá trị từ bên ngoài
        updateAmount(amount);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 3),
            )
          ] : null,
        ),
        child: Text(
          '$amount mL',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  // Phương thức để thêm bản ghi nước
  Future<void> _addWaterEntry(int amount) async {
    try {
      // Sử dụng Provider với listen: false để tránh lỗi setState() during build
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      
      // Tạo bản ghi mới
      final newEntry = WaterEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        timestamp: DateTime.now(),
      );
      
      // Thêm bản ghi thông qua provider
      await waterProvider.addWaterEntry(amount, timestamp: newEntry.timestamp);
      
      // Cập nhật UI sau khi thêm
      _loadExercises();
      
      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $amount mL nước'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thêm nước: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}

class EditExerciseDialog extends StatefulWidget {
  final Exercise exercise;

  const EditExerciseDialog({Key? key, required this.exercise}) : super(key: key);

  @override
  _EditExerciseDialogState createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends State<EditExerciseDialog> {
  late TextEditingController _minutesController;
  late String _selectedIntensity;

  final List<String> _intensityOptions = ['Nhẹ', 'Vừa phải', 'Cao'];

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(text: widget.exercise.minutes.toString());
    _selectedIntensity = widget.exercise.intensity;
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }
  
  // Phương thức helper để lấy icon phù hợp dựa trên tên bài tập
  IconData _getExerciseIcon(String exerciseName) {
    switch (exerciseName.toLowerCase()) {
      case 'đi bộ':
        return Icons.directions_walk;
      case 'chạy':
        return Icons.directions_run;
      case 'đạp xe':
        return Icons.directions_bike;
      case 'nâng tạ':
        return Icons.fitness_center;
      case 'yoga':
        return Icons.self_improvement;
      case 'bơi lội':
        return Icons.pool;
      case 'máy chạy bộ':
        return Icons.directions_run;
      case 'bài tập tại nhà':
        return Icons.home;
      case 'giãn cơ':
        return Icons.accessibility_new;
      case 'hiit':
        return Icons.flash_on;
      case 'pilates':
        return Icons.psychology;
      case 'quần vợt':
        return Icons.sports_tennis;
      case 'bóng rổ':
        return Icons.sports_basketball;
      case 'bóng đá':
        return Icons.sports_soccer;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getExerciseIcon(widget.exercise.name),
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chỉnh sửa ${widget.exercise.name}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            
            // Intensity selector
            Text(
              'Cường độ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: _intensityOptions.map((intensity) {
                  final isSelected = _selectedIntensity == intensity;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIntensity = intensity;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          intensity,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Minutes input
            Text(
              'Thời gian (phút)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                // Decrease button
                GestureDetector(
                  onTap: () {
                    final currentValue = int.tryParse(_minutesController.text) ?? 0;
                    if (currentValue > 5) {
                      setState(() {
                        _minutesController.text = (currentValue - 5).toString();
                      });
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.remove, color: Colors.black),
                  ),
                ),
                
                // Minutes input field
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        suffixText: "phút",
                      ),
                    ),
                  ),
                ),
                
                // Increase button
                GestureDetector(
                  onTap: () {
                    final currentValue = int.tryParse(_minutesController.text) ?? 0;
                    setState(() {
                      _minutesController.text = (currentValue + 5).toString();
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.black),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // Calories info
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "Ước tính: ",
                            style: TextStyle(color: Colors.black, fontSize: 14),
                          ),
                          TextSpan(
                            text: "${_calculateCalories()} kcal",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Hủy'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final minutes = int.tryParse(_minutesController.text) ?? widget.exercise.minutes;

                      if (minutes <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Thời gian phải lớn hơn 0'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final updatedExercise = widget.exercise.copyWith(
                        intensity: _selectedIntensity,
                        minutes: minutes,
                      );

                      Navigator.pop(context, updatedExercise);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Lưu',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  int _calculateCalories() {
    final minutes = int.tryParse(_minutesController.text) ?? widget.exercise.minutes;
    double multiplier = 1.0;
    
    if (_selectedIntensity == 'Nhẹ') {
      multiplier = 0.8;
    } else if (_selectedIntensity == 'Cao') {
      multiplier = 1.3;
    }
    
    return (minutes * widget.exercise.caloriesPerMinute * multiplier).round();
  }
}

