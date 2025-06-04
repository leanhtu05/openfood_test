import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../models/water_entry.dart';
import '../utils/constants.dart';
import '../providers/exercise_provider.dart';
import '../models/exercise.dart';

class WaterHistoryScreen extends StatefulWidget {
  static const routeName = '/water-history';

  @override
  _WaterHistoryScreenState createState() => _WaterHistoryScreenState();
}

class _WaterHistoryScreenState extends State<WaterHistoryScreen> {
  bool _isLoading = true;
  bool _showEmptyEntries = false;
  
  // Biến lọc loại hoạt động
  Set<String> _selectedFilters = {'Nước'};
  bool _showFoodItems = false;
  bool _showFavoriteFoodItems = false;
  bool _showExerciseItems = false;
  bool _showWaterItems = true;

  @override
  void initState() {
    super.initState();
    // Đặt lại bộ lọc mặc định
    _resetFilters();
    // Tải dữ liệu khi màn hình được khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    // Không cần thực hiện gì trong dispose() vì chúng ta đã đặt lại bộ lọc trong initState()
    super.dispose();
  }

  // Phương thức đặt lại bộ lọc về giá trị mặc định
  void _resetFilters() {
    _selectedFilters = {'Nước'};
    _showFoodItems = false;
    _showFavoriteFoodItems = false;
    _showExerciseItems = false;
    _showWaterItems = true;
  }

  Future<void> _loadData() async {
    // Chỉ cập nhật trạng thái khi widget đã mount
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 WaterHistoryScreen: Đang tải dữ liệu nước và bài tập...');
      
      // Tạo một danh sách các Future để tải song song
      final futures = <Future>[];
      
      // Tải dữ liệu nước
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      futures.add(waterProvider.loadData());
      
      // Tải dữ liệu tập thể dục
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      futures.add(exerciseProvider.loadExercises());
      
      // Đợi tất cả các Future hoàn thành
      await Future.wait(futures);
      
      debugPrint('✅ WaterHistoryScreen: Tải dữ liệu hoàn tất - ${waterProvider.entries.length} bản ghi nước');
    } catch (e) {
      debugPrint('❌ WaterHistoryScreen: Lỗi khi tải dữ liệu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: Không thể tải dữ liệu. $e')),
        );
      }
    } finally {
      // Chỉ cập nhật trạng thái khi widget vẫn còn mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearAllWaterEntries() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa tất cả'),
        content: Text('Bạn có chắc chắn muốn xóa tất cả dữ liệu nước uống? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Provider.of<WaterProvider>(context, listen: false).clearAllWaterEntries();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã xóa tất cả dữ liệu nước uống')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Không thể xóa dữ liệu: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }

  void _toggleShowEmptyEntries() {
    setState(() {
      _showEmptyEntries = !_showEmptyEntries;
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconFromFilters(),
              color: Colors.indigo[900], 
              size: 24
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                _getTitleFromFilters(),
                style: TextStyle(
                  color: Colors.indigo[900],
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.blue),
            onPressed: _showFilterOptions,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.blue),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _loadData();
                  break;
                case 'toggle_empty':
                  _toggleShowEmptyEntries();
                  break;
                case 'clear_all':
                  _clearAllWaterEntries();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Làm mới dữ liệu'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_empty',
                child: Row(
                  children: [
                    Icon(
                      _showEmptyEntries ? Icons.visibility_off : Icons.visibility,
                      color: Colors.blue,
                      size: 20
                    ),
                    SizedBox(width: 8),
                    Text(_showEmptyEntries ? 'Ẩn ngày trống' : 'Hiện ngày trống'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Xóa tất cả', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildHistoryList(),
    );
  }

  Widget _buildHistoryList() {
    return Consumer2<WaterProvider, ExerciseProvider>(
      builder: (context, waterProvider, exerciseProvider, child) {
        final waterEntries = waterProvider.getEntriesByDay();
        final exerciseEntries = exerciseProvider.getExercisesByDay();
        
        // Kết hợp các mục và sắp xếp theo ngày
        Map<String, List<dynamic>> combinedEntries = {};
        
        // Thêm mục nước nếu được chọn
        if (_showWaterItems) {
          waterEntries.forEach((day, entries) {
            if (!combinedEntries.containsKey(day)) {
              combinedEntries[day] = [];
            }
            combinedEntries[day]!.addAll(entries.map((e) => {'type': 'water', 'data': e}));
          });
        }
        
        // Thêm mục tập thể dục nếu được chọn
        if (_showExerciseItems) {
          exerciseEntries.forEach((day, entries) {
            if (!combinedEntries.containsKey(day)) {
              combinedEntries[day] = [];
            }
            combinedEntries[day]!.addAll(entries.map((e) => {'type': 'exercise', 'data': e}));
          });
        }
        
        // Sắp xếp lại các mục theo thời gian
        combinedEntries.forEach((day, entries) {
          entries.sort((a, b) {
            DateTime aTime = a['type'] == 'water' 
                ? (a['data'] as WaterEntry).timestamp
                : DateTime.parse((a['data'] as Exercise).date);
                
            DateTime bTime = b['type'] == 'water'
                ? (b['data'] as WaterEntry).timestamp
                : DateTime.parse((b['data'] as Exercise).date);
                
            return bTime.compareTo(aTime);
          });
        });
        
        // Kiểm tra có dữ liệu nước hay không để hiển thị thông báo phù hợp
        bool hasWaterData = waterEntries.isNotEmpty;
        
        if (combinedEntries.isEmpty) {
          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showWaterItems ? Icons.water_drop : Icons.history,
                          size: 64,
                          color: Colors.blue.withOpacity(0.3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          _showWaterItems && !hasWaterData
                            ? 'Chưa có dữ liệu nước uống'
                            : 'Chưa có dữ liệu hoạt động',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        if (_showWaterItems && !hasWaterData)
                          Text(
                            'Hãy thêm bản ghi nước uống để theo dõi',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_showWaterItems) {
                              // Hiển thị hộp thoại thêm nước
                              Provider.of<WaterProvider>(context, listen: false)
                                  .showWaterInputDialog(context);
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          icon: Icon(_showWaterItems ? Icons.water_drop : Icons.add, size: 18),
                          label: Text(_showWaterItems ? 'Thêm nước uống' : 'Thêm hoạt động ngay'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: combinedEntries.length,
            itemBuilder: (context, index) {
              final dayKey = combinedEntries.keys.elementAt(index);
              final entriesForDay = combinedEntries[dayKey]!;
              
              // Tính tổng lượng nước và bài tập trong ngày
              int totalWaterForDay = 0;
              int totalExerciseForDay = 0;
              int waterCount = 0;
              int exerciseCount = 0;
              
              for (var entry in entriesForDay) {
                if (entry['type'] == 'water') {
                  totalWaterForDay += (entry['data'] as WaterEntry).amount;
                  waterCount++;
                } else if (entry['type'] == 'exercise') {
                  totalExerciseForDay += (entry['data'] as Exercise).calories;
                  exerciseCount++;
                }
              }
              
              // Chỉ hiển thị nếu có dữ liệu hoặc người dùng chọn hiển thị ngày trống
              bool hasData = totalWaterForDay > 0 || totalExerciseForDay > 0;
              if (!hasData && !_showEmptyEntries) return SizedBox.shrink();
              
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
                            dayKey,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _getFullDateFormatted(dayKey),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              if (totalWaterForDay > 0)
                                Chip(
                                  label: Text(
                                    '${totalWaterForDay} ml',
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
                          if (waterCount > 0 || exerciseCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
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
                                  // Nút thêm nước cho mỗi ngày
                                  if (_showWaterItems)
                                    InkWell(
                                      onTap: () {
                                        // Đặt ngày được chọn về ngày trong card
                                        final dateParts = dayKey.split(' ');
                                        DateTime selectedDate;
                                        if (dayKey == 'Hôm nay') {
                                          selectedDate = DateTime.now();
                                        } else if (dayKey == 'Hôm qua') {
                                          selectedDate = DateTime.now().subtract(Duration(days: 1));
                                        } else if (dateParts.length >= 4) {
                                          // "Ngày X tháng Y"
                                          int day = int.tryParse(dateParts[1]) ?? 1;
                                          int month = int.tryParse(dateParts[3]) ?? 1;
                                          int year = DateTime.now().year;
                                          selectedDate = DateTime(year, month, day);
                                        } else {
                                          selectedDate = DateTime.now();
                                        }
                                        
                                        // Cập nhật ngày và hiển thị dialog thêm nước
                                        final waterProv = Provider.of<WaterProvider>(context, listen: false);
                                        waterProv.setSelectedDate(DateFormat('yyyy-MM-dd').format(selectedDate));
                                        waterProv.showWaterInputDialog(context);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add,
                                              size: 12,
                                              color: Colors.blue,
                                            ),
                                            SizedBox(width: 2),
                                            Text(
                                              'Thêm nước',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Danh sách các bản ghi trong ngày
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.all(0),
                      itemCount: entriesForDay.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = entriesForDay[index];
                        if (entry['type'] == 'water') {
                          return _buildWaterEntryItem(entry['data'] as WaterEntry, dayKey);
                        } else {
                          return _buildExerciseEntryItem(entry['data'] as Exercise, dayKey);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWaterEntryItem(WaterEntry entry, String dayKey) {
    // Định dạng thời gian hiển thị
    String timeDisplay = DateFormat('HH:mm').format(entry.timestamp);
    
    // Định dạng lượng nước với dấu phẩy hàng nghìn
    String formattedAmount = NumberFormat('#,###').format(entry.amount);
    
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
        timeDisplay,
        style: TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'delete') {
            _showDeleteConfirmation(entry);
          }
        },
        itemBuilder: (context) => [
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
  
  Widget _buildExerciseEntryItem(Exercise exercise, String dayKey) {
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
        icon: Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'delete') {
            _showDeleteExerciseConfirmation(exercise);
          }
        },
        itemBuilder: (context) => [
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

  void _showDeleteConfirmation(WaterEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa bản ghi'),
        content: Text('Bạn có chắc muốn xóa bản ghi này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<WaterProvider>(context, listen: false)
                  .deleteWaterEntry(entry.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã xóa bản ghi nước')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteExerciseConfirmation(Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa bản ghi'),
        content: Text('Bạn có chắc muốn xóa bản ghi bài tập này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Tạo ID duy nhất từ các thuộc tính của exercise
              String exerciseId = '${exercise.name}_${exercise.date}_${exercise.minutes}';
              await Provider.of<ExerciseProvider>(context, listen: false)
                  .deleteExercise(exerciseId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã xóa bản ghi bài tập')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa'),
          ),
        ],
      ),
    );
  }

  String _getTitleFromFilters() {
    // Nếu có nhiều bộ lọc được chọn, hiển thị "Nhật ký kết hợp"
    if (_selectedFilters.length > 1) {
      return 'Nhật ký kết hợp';
    }
    
    // Nếu chỉ một bộ lọc được chọn
    if (_selectedFilters.contains('Bài tập')) {
      return 'Lịch sử bài tập';
    } else if (_selectedFilters.contains('Nước')) {
      return 'Lịch sử nước uống';
    } else if (_selectedFilters.contains('Thực phẩm')) {
      return 'Lịch sử thực phẩm';
    } else if (_selectedFilters.contains('Thực phẩm yêu thích')) {
      return 'Thực phẩm yêu thích';
    } else {
      return 'Nhật ký hoạt động';
    }
  }

  IconData _getIconFromFilters() {
    // Nếu có nhiều bộ lọc được chọn, hiển thị biểu tượng history
    if (_selectedFilters.length > 1) {
      return Icons.history;
    }
    
    // Nếu chỉ một bộ lọc được chọn
    if (_selectedFilters.contains('Bài tập')) {
      return Icons.fitness_center;
    } else if (_selectedFilters.contains('Nước')) {
      return Icons.water_drop;
    } else if (_selectedFilters.contains('Thực phẩm') || _selectedFilters.contains('Thực phẩm yêu thích')) {
      return Icons.restaurant;
    } else {
      return Icons.history;
    }
  }

  String _getFullDateFormatted(String dayKey) {
    if (dayKey == 'Hôm nay') {
      return DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(DateTime.now());
    } else if (dayKey == 'Hôm qua') {
      return DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(DateTime.now().subtract(Duration(days: 1)));
    } else {
      // Phân tích ngày từ dayKey (dạng "Ngày X tháng Y")
      try {
        // Cố gắng phân tích từ định dạng Việt Nam
        List<String> parts = dayKey.split(' ');
        if (parts.length >= 4) {
          int day = int.parse(parts[1]);
          int month = int.parse(parts[3]);
          int year = DateTime.now().year;
          
          return DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(DateTime(year, month, day));
        }
      } catch (e) {
        // Nếu không thể phân tích, trả về dayKey như mặc định
      }
      return dayKey;
    }
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