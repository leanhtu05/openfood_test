import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/food_entry.dart';
import '../models/water_entry.dart';
import '../models/exercise.dart';
import '../providers/food_provider.dart';
import '../providers/water_provider.dart';
import '../providers/exercise_provider.dart';
import '../utils/constants.dart';
import '../screens/food_nutrition_detail_screen.dart';

// Lớp định nghĩa style mặc định cho ứng dụng
class AppStyles {
  // Font styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.3,
  );
  
  static const TextStyle subtitle1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );
  
  // Colors
  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color secondaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  
  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );
  
  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 800);
}

class FoodHistoryScreen extends StatefulWidget {
  static const routeName = '/food-history';

  @override
  _FoodHistoryScreenState createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends State<FoodHistoryScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _fadeController;

  // Filter options - đồng bộ với combined_history_screen
  DateTime _startDate = DateTime(2020, 1, 1);
  DateTime _endDate = DateTime.now();
  bool _isFilteringByDate = false;
  Set<String> _selectedFilters = {'Nước', 'Bài tập', 'Thực phẩm'};
  bool _showWaterItems = true;
  bool _showExerciseItems = true;
  bool _showFoodItems = true;
  Map<String, List<dynamic>> _combinedEntriesByDate = {};
  
  @override
  void initState() {
    super.initState();
    
    // Animation controller setup
    _fadeController = AnimationController(
      vsync: this,
      duration: AppStyles.mediumAnimationDuration,
    );
    
    // Tải dữ liệu khi màn hình được khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    await _loadAllData();
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

      // Load food data
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      await foodProvider.loadData();

      // Combine data
      _combineData(waterProvider, exerciseProvider, foodProvider);

      setState(() {
        _isLoading = false;
      });

      // Start animation after data is loaded
      _fadeController.forward();
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

  void _combineData(WaterProvider waterProvider, ExerciseProvider exerciseProvider, FoodProvider foodProvider) {
    Map<String, List<dynamic>> combined = {};

    final startDateFormatted = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateFormatted = DateFormat('yyyy-MM-dd').format(_endDate.add(Duration(days: 1)));

    // Process water entries
    if (_showWaterItems) {
      for (var entry in waterProvider.entries) {
        final date = DateFormat('yyyy-MM-dd').format(entry.timestamp);
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

    // Process food entries
    if (_showFoodItems) {
      for (var entry in foodProvider.allFoodEntries) {
        final date = DateFormat('yyyy-MM-dd').format(entry.dateTime);
        if (!_isFilteringByDate || (date.compareTo(startDateFormatted) >= 0 && date.compareTo(endDateFormatted) < 0)) {
          if (!combined.containsKey(date)) {
            combined[date] = [];
          }
          combined[date]!.add({
            'type': 'food',
            'data': entry,
            'timestamp': entry.dateTime,
          });
        }
      }
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
  
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: AppStyles.primaryColor, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getAppBarTitle(),
                      style: AppStyles.heading2.copyWith(color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                _getDateRangeText(),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.normal
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list, color: AppStyles.secondaryColor, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                _showFilterOptions();
              },
            ),
            IconButton(
              icon: Icon(Icons.date_range, color: AppStyles.secondaryColor, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                _showDateRangePicker();
              },
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppStyles.primaryColor),
                ),
              )
            : FadeTransition(
                opacity: _fadeController,
                child: _buildFoodEntriesList(),
              ),
      ),
    );
  }
  
  // Filter options methods - đồng bộ với combined_history_screen
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
      activeColor: AppStyles.primaryColor,
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
              primary: AppStyles.primaryColor,
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
        _isFilteringByDate = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hiển thị dữ liệu từ ${DateFormat('dd/MM/yyyy').format(picked.start)} đến ${DateFormat('dd/MM/yyyy').format(picked.end)}'
          ),
          duration: Duration(seconds: 2),
          backgroundColor: AppStyles.primaryColor,
        ),
      );
    }
  }

  String _getAppBarTitle() {
    if (_selectedFilters.length == 3) {
      return 'Lịch sử hoạt động';
    } else if (_selectedFilters.length == 1) {
      if (_selectedFilters.contains('Nước')) return 'Lịch sử uống nước';
      if (_selectedFilters.contains('Bài tập')) return 'Lịch sử bài tập';
      if (_selectedFilters.contains('Thực phẩm')) return 'Lịch sử thực phẩm';
    }
    return 'Lịch sử đã chọn';
  }

  String _getDateRangeText() {
    return _isFilteringByDate
        ? DateFormat('dd/MM').format(_startDate) + ' - ' + DateFormat('dd/MM').format(_endDate)
        : 'Tất cả';
  }

  Widget _buildFoodEntriesList() {
    return _buildCombinedList();
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

        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 8),
                    Text(
                      _formatDateHeader(date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              // Entries for this date
              ...entries.map((entry) => _buildEntryItem(entry)).toList(),
            ],
          ),
        );
      },
    );
    

  }

  Widget _buildNutrientSummary(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          text,
          style: AppStyles.body1.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFoodEntryItem(FoodEntry entry) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final nutritionValues = entry.calculateNutritionFromAPI();
    
    // Lấy giá trị dinh dưỡng
    final calories = nutritionValues['calories'] ?? 0;
    final protein = nutritionValues['protein'] ?? 0;
    final fat = nutritionValues['fat'] ?? 0;
    final carbs = nutritionValues['carbs'] ?? 0;
    
    // Unique tag for hero animation
    final heroTag = 'food-${entry.id}';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodNutritionDetailScreen(
                  foodEntry: entry,
                  onSave: (updatedEntry) => foodProvider.updateFoodEntry(updatedEntry),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ảnh thực phẩm
                Hero(
                  tag: heroTag,
                  child: _buildFoodImage(entry),
                ),
                SizedBox(width: 12),
                
                // Thông tin bữa ăn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên thực phẩm
                      Text(
                        entry.description,
                        style: AppStyles.subtitle1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      
                      // Loại bữa ăn và thời gian
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getMealTypeIcon(entry.mealType),
                                  size: 12,
                                  color: Colors.grey.shade700,
                                ),
                                SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    entry.mealType,
                                    style: AppStyles.caption.copyWith(
                                      color: Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      _formatDetailedDate(entry.dateTime),
                                      style: AppStyles.caption.copyWith(
                                        color: Colors.blue.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 8),
                      // Thông tin dinh dưỡng
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildNutrientInfo(Icons.local_fire_department, '${calories.round()}kcal', Colors.orange),
                              SizedBox(width: 10),
                              _buildNutrientInfo(Icons.circle, '${protein.round()}g', Colors.blue),
                              SizedBox(width: 10),
                              _buildNutrientInfo(Icons.circle, '${fat.round()}g', Colors.amber),
                              SizedBox(width: 10),
                              _buildNutrientInfo(Icons.circle, '${carbs.round()}g', Colors.green),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Menu
                Material(
                  color: Colors.transparent,
                  shape: CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: IconButton(
                    icon: Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    splashColor: Colors.grey.shade200,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _showOptionsMenu(context, entry);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFoodImage(FoodEntry entry) {
    return AnimatedContainer(
      duration: AppStyles.shortAnimationDuration,
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppStyles.primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: entry.imagePath != null && entry.imagePath!.isNotEmpty
          ? Image.file(
              File(entry.imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildDefaultFoodImage(),
            )
          : _buildDefaultFoodImage(),
      ),
    );
  }
  
  Widget _buildDefaultFoodImage() {
    return Container(
      color: Colors.green.shade50,
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: AppStyles.primaryColor,
          ),
        ),
      ),
    );
  }
  
  Widget _buildNutrientInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: 3),
        Text(
          text,
          style: AppStyles.body2.copyWith(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showOptionsMenu(BuildContext context, FoodEntry entry) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(top: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ListTile(
            leading: Icon(Icons.edit, color: AppStyles.secondaryColor, size: 20),
            title: Text('Chỉnh sửa', style: AppStyles.body1),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FoodNutritionDetailScreen(
                    foodEntry: entry,
                    onSave: (updatedEntry) => foodProvider.updateFoodEntry(updatedEntry),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.favorite,
              color: entry.isFavorite ? AppStyles.errorColor : Colors.grey,
              size: 20,
            ),
            title: Text(
              entry.isFavorite ? 'Bỏ yêu thích' : 'Yêu thích',
              style: AppStyles.body1,
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              foodProvider.toggleFavorite(entry.id, !entry.isFavorite);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: AppStyles.errorColor, size: 20),
            title: Text('Xóa', style: AppStyles.body1),
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              _confirmDelete(context, entry);
            },
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }
  
  void _confirmDelete(BuildContext context, FoodEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa bữa ăn', style: AppStyles.heading2),
        content: Text(
          'Bạn có chắc chắn muốn xóa ${entry.description}?',
          style: AppStyles.body1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            child: Text('Hủy', style: AppStyles.body1),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              'Xóa',
              style: AppStyles.body1.copyWith(color: AppStyles.errorColor),
            ),
            onPressed: () {
              Navigator.pop(context);
              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
              foodProvider.deleteFoodEntry(entry.id);
              
              // Show a more interactive snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Đã xóa bữa ăn', style: AppStyles.body2.copyWith(color: Colors.white)),
                    ],
                  ),
                  behavior: SnackBarBehavior.fixed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: AppStyles.primaryColor,
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'bữa sáng':
        return Icons.wb_sunny_outlined;
      case 'bữa trưa':
        return Icons.wb_sunny;
      case 'bữa tối':
        return Icons.nights_stay;
      case 'bữa phụ':
        return Icons.fastfood;
      default:
        return Icons.restaurant;
    }
  }
  
  String _formatDate(DateTime date) {
    String timeStr = DateFormat('HH:mm').format(date);
    
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      return 'Hôm nay ($timeStr)';
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return 'Hôm qua ($timeStr)';
    } else {
      // Format như "tháng 5 14 (20:46)"
      String month = DateFormat('M', 'vi').format(date);
      String day = DateFormat('d', 'vi').format(date);
      return 'tháng $month $day ($timeStr)';
    }
  }
  
  String _formatDetailedDate(DateTime dateTime) {
    String timeStr = DateFormat('HH:mm').format(dateTime);
    return timeStr;
  }

  // Combined history methods
  Widget _buildEntryItem(Map<String, dynamic> entry) {
    final type = entry['type'] as String;
    final data = entry['data'];

    switch (type) {
      case 'water':
        return _buildWaterItem(data as WaterEntry);
      case 'exercise':
        return _buildExerciseItem(data as Exercise);
      case 'food':
        return _buildFoodItem(data as FoodEntry);
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildWaterItem(WaterEntry entry) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Icon(Icons.water_drop, color: Colors.blue.shade700),
      ),
      title: Text('Uống nước'),
      subtitle: Text('${entry.amount} ml • ${DateFormat('HH:mm').format(entry.timestamp)}'),
      trailing: Icon(Icons.chevron_right),
    );
  }

  Widget _buildExerciseItem(Exercise exercise) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade100,
        child: Icon(Icons.fitness_center, color: Colors.orange.shade700),
      ),
      title: Text(exercise.name),
      subtitle: Text('${exercise.minutes} phút • ${exercise.calories} kcal • ${DateFormat('HH:mm').format(DateTime.parse(exercise.date))}'),
      trailing: Icon(Icons.chevron_right),
    );
  }

  Widget _buildFoodItem(FoodEntry entry) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.shade100,
        child: Icon(Icons.restaurant, color: Colors.green.shade700),
      ),
      title: Text(entry.description),
      subtitle: Text('${entry.mealType} • ${DateFormat('HH:mm').format(entry.dateTime)}'),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
        onSelected: (value) {
          if (value == 'edit') {
            _editFoodEntryFromCombined(entry);
          } else if (value == 'delete') {
            _deleteFoodEntryFromCombined(entry);
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

  String _formatDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));

    if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now)) {
      return 'Hôm nay';
    } else if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(yesterday)) {
      return 'Hôm qua';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  // Edit and delete methods for combined view
  Future<void> _editFoodEntryFromCombined(FoodEntry foodEntry) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodNutritionDetailScreen(
            foodEntry: foodEntry,
            onSave: (updatedEntry) {
              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
              foodProvider.updateFoodEntry(updatedEntry);
            },
          ),
        ),
      );

      if (result != null) {
        _loadAllData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở màn hình chỉnh sửa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFoodEntryFromCombined(FoodEntry foodEntry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa bữa ăn'),
        content: Text('Bạn có chắc chắn muốn xóa ${foodEntry.description}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        await foodProvider.deleteFoodEntry(foodEntry.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa bữa ăn')),
        );
        _loadAllData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa bữa ăn: $e')),
        );
      }
    }
  }
}