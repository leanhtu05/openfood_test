import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/water_entry.dart';
import '../models/exercise.dart';

class CombinedHistoryScreen extends StatefulWidget {
  static const routeName = '/combined_history';

  @override
  _CombinedHistoryScreenState createState() => _CombinedHistoryScreenState();
}

class _CombinedHistoryScreenState extends State<CombinedHistoryScreen> {
  bool _isLoading = true;
  Map<String, List<dynamic>> _combinedEntriesByDate = {};
  DateTime _startDate = DateTime(2020, 1, 1);
  DateTime _endDate = DateTime.now();
  bool _isFilteringByDate = false;
  
  // Filter options
  Set<String> _selectedFilters = {'Nước', 'Bài tập', 'Thực phẩm'};
  bool _showWaterItems = true;
  bool _showExerciseItems = true;
  bool _showFoodItems = true;

  @override
  void initState() {
    super.initState();
    
    // Apply route arguments if available (for filtering)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final filterType = args['filter'] as String?;
        if (filterType != null) {
          setState(() {
            // Reset all filters
            _selectedFilters = {};
            _showWaterItems = false;
            _showExerciseItems = false;
            _showFoodItems = false;
            
            // Apply selected filter
            if (filterType == 'water') {
              _selectedFilters.add('Nước');
              _showWaterItems = true;
            } else if (filterType == 'exercise') {
              _selectedFilters.add('Bài tập');
              _showExerciseItems = true;
            } else if (filterType == 'food') {
              _selectedFilters.add('Thực phẩm');
              _showFoodItems = true;
            } else if (filterType == 'all') {
              _selectedFilters.add('Nước');
              _selectedFilters.add('Bài tập');
              _selectedFilters.add('Thực phẩm');
              _showWaterItems = true;
              _showExerciseItems = true;
              _showFoodItems = true;
            }
          });
        }
      }
    });
    
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load water data
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      await waterProvider.loadData();
      
      // Load exercise data
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      await exerciseProvider.loadAllExercises();
      
      // Combine data
      _combineData(waterProvider, exerciseProvider);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu: $e'))
      );
    }
  }

  void _combineData(WaterProvider waterProvider, ExerciseProvider exerciseProvider) {
    Map<String, List<dynamic>> combined = {};
    
    final startDateFormatted = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateFormatted = DateFormat('yyyy-MM-dd').format(_endDate.add(Duration(days: 1)));
    
    // Process water entries
    if (_showWaterItems) {
      for (var entry in waterProvider.entries) {
        final date = DateFormat('yyyy-MM-dd').format(entry.timestamp);
        // Nếu không áp dụng bộ lọc ngày hoặc mục nằm trong phạm vi ngày đã chọn
        if (!_isFilteringByDate || (date.compareTo(startDateFormatted) >= 0 && date.compareTo(endDateFormatted) < 0)) {
          if (!combined.containsKey(date)) {
            combined[date] = [];
          }
          combined[date]!.add({
            'type': 'water',
            'data': entry,
            'timestamp': entry.timestamp,
          });
        }
      }
    }
    
    // Process exercise entries
    if (_showExerciseItems) {
      exerciseProvider.allExercises.forEach((date, exercises) {
        for (var exercise in exercises) {
          final formattedDate = exercise.date.split('T')[0];
          // Nếu không áp dụng bộ lọc ngày hoặc mục nằm trong phạm vi ngày đã chọn
          if (!_isFilteringByDate || (formattedDate.compareTo(startDateFormatted) >= 0 && formattedDate.compareTo(endDateFormatted) < 0)) {
            if (!combined.containsKey(formattedDate)) {
              combined[formattedDate] = [];
            }
            combined[formattedDate]!.add({
              'type': 'exercise',
              'data': exercise,
              'timestamp': DateTime.parse(exercise.date),
            });
          }
        }
      });
    }
    
    // Sort entries by timestamp for each date
    combined.forEach((date, entries) {
      entries.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    });
    
    // Sort dates by most recent first
    final sortedCombined = Map.fromEntries(
      combined.entries.toList()
        ..sort((a, b) => DateTime.parse(b.key).compareTo(DateTime.parse(a.key)))
    );
    
    setState(() {
      _combinedEntriesByDate = sortedCombined;
    });
  }
  
  void _showFilterOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.symmetric(vertical: 20),
        title: Text('Chọn loại hiển thị', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('Nước'),
            _buildFilterOption('Bài tập'),
            _buildFilterOption('Thực phẩm'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterOption(String title) {
    bool isSelected = _selectedFilters.contains(title);
    
    return CheckboxListTile(
      title: Text(title),
      value: isSelected,
      checkColor: Colors.white,
      activeColor: Colors.green,
      onChanged: (value) {
        if (value == true && !isSelected) {
          setState(() {
            _selectedFilters.add(title);
            
            if (title == 'Nước') _showWaterItems = true;
            if (title == 'Bài tập') _showExerciseItems = true;
            if (title == 'Thực phẩm') _showFoodItems = true;
          });
        } else if (value == false && isSelected) {
          if (_selectedFilters.length > 1) {
            setState(() {
              _selectedFilters.remove(title);
              
              if (title == 'Nước') _showWaterItems = false;
              if (title == 'Bài tập') _showExerciseItems = false;
              if (title == 'Thực phẩm') _showFoodItems = false;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cần chọn ít nhất một loại dữ liệu'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        
        Navigator.of(context).pop();
        
        // Reload data with new filters
        _loadAllData();
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
  
  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _isFilteringByDate ? _startDate : DateTime.now().subtract(Duration(days: 30)),
        end: _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isFilteringByDate = true;  // Đánh dấu đã áp dụng bộ lọc ngày
      });
      _loadAllData();
      
      // Hiển thị thông báo cho người dùng biết dữ liệu đã được lọc
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hiển thị dữ liệu từ ${DateFormat('dd/MM/yyyy').format(picked.start)} đến ${DateFormat('dd/MM/yyyy').format(picked.end)}'
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dateRangeText = _isFilteringByDate 
        ? DateFormat('dd/MM').format(_startDate) + ' - ' + DateFormat('dd/MM').format(_endDate)
        : 'Tất cả';
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _getAppBarTitle(),
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 5),
                _getAppBarIcon(),
              ],
            ),
            Row(
              children: [
                Text(
                  dateRangeText,
                  style: TextStyle(
                    color: Colors.grey[600], 
                    fontSize: 12,
                    fontWeight: FontWeight.normal
                  ),
                ),
                if (_isFilteringByDate)
                  GestureDetector(
                    onTap: _clearDateFilter,
                    child: Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(
                        Icons.clear,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.black),
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: Icon(Icons.date_range, color: Colors.black),
            onPressed: _showDateRangePicker,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildCombinedList(),
    );
  }
  
  Widget _buildCombinedList() {
    if (_combinedEntriesByDate.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Không có dữ liệu để hiển thị',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              _isFilteringByDate 
                ? 'Không có hoạt động nào từ ${DateFormat('dd/MM/yyyy').format(_startDate)} đến ${DateFormat('dd/MM/yyyy').format(_endDate)}' 
                : 'Chưa có hoạt động nào được ghi nhận',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _combinedEntriesByDate.length,
      itemBuilder: (context, index) {
        final date = _combinedEntriesByDate.keys.elementAt(index);
        final entries = _combinedEntriesByDate[date]!;
        final dateTime = DateTime.parse(date);
        
        // Tính tổng số calories từ bài tập và tổng lượng nước trong ngày
        int totalCalories = 0;
        int totalWater = 0;
        int exerciseCount = 0;
        int waterCount = 0;
        
        for (var entry in entries) {
          if (entry['type'] == 'exercise') {
            totalCalories += (entry['data'] as Exercise).calories;
            exerciseCount++;
          } else if (entry['type'] == 'water') {
            totalWater += (entry['data'] as WaterEntry).amount;
            waterCount++;
          }
        }
        
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and summary
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateHeader(date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _getFullDateFormatted(date),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        if (totalCalories > 0)
                          Chip(
                            label: Text(
                              '${totalCalories} kcal',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: Colors.orange,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        SizedBox(width: 8),
                        if (totalWater > 0)
                          Chip(
                            label: Text(
                              '${totalWater} ml',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: Colors.blue,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                    if (exerciseCount > 0 || waterCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (exerciseCount > 0)
                              Row(
                                children: [
                                  Icon(
                                    Icons.fitness_center,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '$exerciseCount hoạt động',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            if (exerciseCount > 0 && waterCount > 0)
                              SizedBox(width: 16),
                            if (waterCount > 0)
                              Row(
                                children: [
                                  Icon(
                                    Icons.water_drop,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '$waterCount lần uống nước',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // List of activities
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(0),
                itemCount: entries.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  
                  if (entry['type'] == 'water' && _showWaterItems) {
                    return _buildWaterEntryListItem(entry['data'] as WaterEntry);
                  } else if (entry['type'] == 'exercise' && _showExerciseItems) {
                    return _buildExerciseListItem(entry['data'] as Exercise);
                  } else {
                    return SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildWaterEntryListItem(WaterEntry entry) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.water_drop,
          color: Colors.blue,
          size: 20,
        ),
      ),
      title: Text(
        'Nước uống: ${entry.amount} ml',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        DateFormat('HH:mm').format(entry.timestamp),
        style: TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _deleteWaterEntry(entry),
      ),
    );
  }
  
  Widget _buildExerciseListItem(Exercise exercise) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getExerciseIcon(exercise.name),
          color: Colors.orange,
          size: 20,
        ),
      ),
      title: Text(
        exercise.name,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${exercise.minutes} phút - ${exercise.calories} kcal - ${exercise.intensity}',
            style: TextStyle(fontSize: 12),
          ),
          Text(
            DateFormat('HH:mm').format(DateTime.parse(exercise.date)),
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
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
    );
  }
  
  Future<void> _deleteWaterEntry(WaterEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa bản ghi này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await Provider.of<WaterProvider>(context, listen: false).deleteWaterEntry(entry.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa bản ghi')),
        );
        _loadAllData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa bản ghi: $e')),
        );
      }
    }
  }
  
  Future<void> _deleteExercise(Exercise exercise) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa bản ghi này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        // Sử dụng ID nếu có, nếu không thì tạo ID từ các thuộc tính
        String exerciseId = exercise.id ?? '${exercise.name}_${exercise.date}_${exercise.minutes}';
        
        await Provider.of<ExerciseProvider>(context, listen: false).deleteExercise(exerciseId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa bản ghi')),
        );
        _loadAllData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa bản ghi: $e')),
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
        // Đảm bảo result giữ nguyên ID của exercise gốc
        final updatedExercise = result.copyWith(id: exercise.id);
        
        await Provider.of<ExerciseProvider>(context, listen: false)
            .updateExercise(exercise, updatedExercise);
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật bài tập')),
        );
        _loadAllData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật bài tập: $e')),
        );
      }
    }
  }
  
  String _formatDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Hôm nay';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Hôm qua';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
  
  String _getFullDateFormatted(String dateStr) {
    final date = DateTime.parse(dateStr);
    try {
      return DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(date);
    } catch (e) {
      // Fallback if Vietnamese locale is not available
      return DateFormat('EEEE, dd/MM/yyyy').format(date);
    }
  }
  
  String _getAppBarTitle() {
    List<String> titles = [];
    if (_showWaterItems) titles.add('Nước');
    if (_showExerciseItems) titles.add('Bài tập');
    if (_showFoodItems) titles.add('Thực phẩm');
    
    return titles.join(' & ');
  }
  
  Widget _getAppBarIcon() {
    if (_showWaterItems && _showExerciseItems) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image(
            image: AssetImage('assets/images/confetti.png'),
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.celebration, size: 24, color: Colors.amber);
            },
          ),
          SizedBox(width: 8),
          Icon(Icons.water_drop, color: Colors.blue, size: 18),
          Icon(Icons.fitness_center, color: Colors.orange, size: 18),
        ],
      );
    } else if (_showWaterItems) {
      return Icon(Icons.water_drop, color: Colors.blue, size: 18);
    } else if (_showExerciseItems) {
      return Icon(Icons.fitness_center, color: Colors.orange, size: 18);
    } else {
      return Icon(Icons.fastfood, color: Colors.green, size: 18);
    }
  }

  void _clearDateFilter() {
    setState(() {
      _isFilteringByDate = false;
      _startDate = DateTime(2020, 1, 1);
      _endDate = DateTime.now();
    });
    _loadAllData();
    
    // Hiển thị thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hiển thị tất cả hoạt động'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
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
  late TimeOfDay _selectedTime;

  final List<String> _intensityOptions = ['Nhẹ', 'Vừa phải', 'Cao'];

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(text: widget.exercise.minutes.toString());
    _selectedIntensity = widget.exercise.intensity;
    
    // Lấy giờ từ exercise date
    final dateTime = DateTime.parse(widget.exercise.date);
    _selectedTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Chỉnh sửa bài tập'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tên bài tập: ${widget.exercise.name}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Cường độ:'),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedIntensity,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _intensityOptions.map((intensity) {
                return DropdownMenuItem(
                  value: intensity,
                  child: Text(intensity),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedIntensity = value;
                  });
                }
              },
            ),
            SizedBox(height: 16),
            Text('Thời gian (phút):'),
            SizedBox(height: 8),
            TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            SizedBox(height: 16),
            Text('Giờ hoạt động:'),
            SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final TimeOfDay? time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
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
                    _selectedTime = time;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 16),
                    ),
                    Icon(Icons.access_time, color: Colors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy'),
        ),
        ElevatedButton(
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

            // Tạo đối tượng DateTime mới với giờ đã cập nhật
            final originalDate = DateTime.parse(widget.exercise.date);
            final updatedDateTime = DateTime(
              originalDate.year,
              originalDate.month,
              originalDate.day,
              _selectedTime.hour,
              _selectedTime.minute,
            );
            
            final updatedExercise = widget.exercise.copyWith(
              intensity: _selectedIntensity,
              minutes: minutes,
              date: updatedDateTime.toIso8601String(),
            );

            Navigator.pop(context, updatedExercise);
          },
          child: Text('Lưu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
} 