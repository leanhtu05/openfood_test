import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import '../widgets/day_selector.dart';
import '../widgets/food_nutrition/header_food_info_card.dart';
import '../widgets/food_nutrition/nutrition_circle_detail.dart';
import '../widgets/food_nutrition/nutrition_circle.dart';
import '../providers/food_provider.dart';
import '../providers/user_data_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/water_provider.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../utils/constants.dart';
import '../screens/food_nutrition_detail_screen.dart';
import '../widgets/food_logging/barcode_scanner_button.dart';
import 'package:uuid/uuid.dart';
import '../screens/food_history_screen.dart';

class MealRecordingScreen extends StatefulWidget {
  final String? initialDate;
  
  const MealRecordingScreen({Key? key, this.initialDate}) : super(key: key);

  @override
  _MealRecordingScreenState createState() => _MealRecordingScreenState();
}

class _MealRecordingScreenState extends State<MealRecordingScreen> {
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  late PageController _pageController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  String _selectedMealType = 'Bữa khác';
  
  // Danh sách các nhóm dinh dưỡng với tiêu đề và danh sách các chất dinh dưỡng
  final List<Map<String, dynamic>> _nutritionGroups = [
    {
      'title': 'Tổng quan về Dinh dưỡng',
      'icon': Icons.pie_chart_outline,
      'iconColor': Colors.amber.shade700,
      'nutrients': ['calories', 'protein', 'fat', 'carbs'],
    },
    {
      'title': 'Sức khỏe Tim mạch',
      'icon': Icons.favorite_outline,
      'iconColor': Colors.red,
      'nutrients': ['cholesterol', 'omega3', 'fiber', 'water'],
    },
    {
      'title': 'Các chất cần kiểm soát',
      'icon': Icons.warning_amber_outlined,
      'iconColor': Colors.orange,
      'nutrients': ['sugar', 'saturatedFat', 'transFat', 'sodium'],
    },
    {
      'title': 'Vitamin thiết yếu',
      'icon': Icons.wb_sunny_outlined,
      'iconColor': Colors.amber,
      'nutrients': ['vitaminA', 'vitaminD', 'vitaminE', 'vitaminK', 'vitaminC'],
    },
    {
      'title': 'Vitamin nhóm B',
      'icon': Icons.medication_liquid,
      'iconColor': Colors.purple,
      'nutrients': ['vitaminB12', 'vitaminB9', 'thiamin', 'riboflavin', 'niacin'],
    },
    {
      'title': 'Khoáng chất quan trọng',
      'icon': Icons.science_outlined,
      'iconColor': Colors.blue,
      'nutrients': ['iron', 'calcium', 'magnesium', 'zinc', 'potassium'],
    },
    {
      'title': 'Khoáng chất Bổ sung',
      'icon': Icons.brightness_7,
      'iconColor': Colors.deepPurple,
      'nutrients': ['phosphorus', 'selenium', 'copper', 'manganese'],
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Sử dụng initialDate nếu có, nếu không thì dùng selectedDate từ provider
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
        // Đồng bộ ngày đã chọn với provider
        foodProvider.setSelectedDate(_selectedDate);
        print('MealRecordingScreen: Khởi tạo với initialDate: ${widget.initialDate}');
      } else {
        // Nếu không có initialDate, sử dụng ngày từ provider
        _selectedDate = foodProvider.selectedDate;
        print('MealRecordingScreen: Khởi tạo với ngày từ provider: $_selectedDate');
      }
      
      // Cập nhật ngày trong các provider khác để đảm bảo đồng bộ hoàn toàn
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      exerciseProvider.setSelectedDate(_selectedDate);
      waterProvider.setSelectedDate(_selectedDate);
      
      // Khởi tạo PageController
      _pageController = PageController(
        initialPage: 0,
        viewportFraction: 1.0, // Thiết lập viewportFraction bằng 1.0 để sử dụng toàn bộ chiều rộng
      );
      
      // Tải dữ liệu các bữa ăn
      loadMealData();
      
      print('MealRecordingScreen: Hoàn tất khởi tạo với ngày $_selectedDate');
    });
  }
  
  @override
  void dispose() {
    // Giải phóng controller khi widget bị hủy
    _pageController.dispose();
    super.dispose();
  }

  Future<void> loadMealData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Make sure the provider's selected date matches our selected date
      if (foodProvider.selectedDate != _selectedDate) {
        foodProvider.setSelectedDate(_selectedDate);
      }
      
      await foodProvider.loadData();
      
      // Thêm debug statement
      print('DEBUG: Số lượng bữa ăn đã ghi nhận: ${foodProvider.todayEntries.length}');
      print('DEBUG: Ngày được chọn: $_selectedDate');
      
      // Đảm bảo UI được cập nhật
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Lỗi khi tải dữ liệu bữa ăn: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu bữa ăn: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getNutrientValues(String nutrient, Map<String, dynamic>? summaryData) {
    if (summaryData == null || !summaryData.containsKey(nutrient)) {
      return {'value': 0.0, 'goal': 100.0, 'remaining': 100.0};
    }
    
    final data = summaryData[nutrient];
    if (data == null || !(data is Map)) {
      return {'value': 0.0, 'goal': 100.0, 'remaining': 100.0};
    }
    
    final value = (data['value'] is num) ? (data['value'] as num).toDouble() : 0.0;
    final goal = (data['goal'] is num) ? (data['goal'] as num).toDouble() : 100.0;
    final remaining = goal - value > 0 ? goal - value : 0.0;
    
    return {
      'value': value,
      'goal': goal,
      'remaining': remaining,
    };
  }

  void _navigateToMealDetails(FoodEntry foodEntry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: foodEntry,
          onSave: (updatedEntry) {
            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
            foodProvider.updateFoodEntry(updatedEntry);
            
            // Tải lại dữ liệu sau khi cập nhật
            loadMealData();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã cập nhật thông tin dinh dưỡng'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    ).then((_) {
      // Tải lại dữ liệu khi quay về từ màn hình chi tiết
      loadMealData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      
      body: Consumer<FoodProvider>(
        builder: (context, foodProvider, child) {
          // Cập nhật _selectedDate để khớp với provider nếu cần
          if (foodProvider.selectedDate != _selectedDate) {
            _selectedDate = foodProvider.selectedDate;
          }
          
          // Lấy dữ liệu từ provider
          final recordedMeals = foodProvider.todayEntries;
          
          // Debug hiển thị số lượng bữa ăn
          print('DEBUG BUILD: Số lượng bữa ăn: ${recordedMeals.length}');
          
          // Lấy mục tiêu dinh dưỡng từ UserDataProvider
          final userProvider = Provider.of<UserDataProvider>(context, listen: false);
          final goals = userProvider.nutritionGoals;
          
          // Tính toán tổng hợp dinh dưỡng
          final summaryData = _calculateNutritionSummary(recordedMeals, goals);
          
          return Column(
            children: [
              // Bộ chọn ngày
              DaySelector.fullDate(
                selectedDate: _selectedDate,
                onDateChanged: (newDate) {
                  setState(() {
                    _selectedDate = newDate;
                  });
                  
                  // Cập nhật ngày trong provider - điều này sẽ đồng bộ với HomeScreen
                  final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                  foodProvider.setSelectedDate(newDate);
                  
                  // Cập nhật ngày trong các provider khác để đảm bảo đồng bộ hoàn toàn
                  final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
                  final waterProvider = Provider.of<WaterProvider>(context, listen: false);
                  exerciseProvider.setSelectedDate(newDate);
                  waterProvider.setSelectedDate(newDate);
                  
                  // Tải lại dữ liệu khi chọn ngày mới
                  loadMealData();
                  
                  // Khi thay đổi ngày, nếu đang ở trong stack navigate, thì pop về với kết quả
                  if (Navigator.canPop(context) && ModalRoute.of(context)?.settings.name != '/') {
                    Navigator.pop(context, {'selectedDate': newDate});
                  }
                  
                  // In thông báo debug
                  print('MealRecordingScreen: Đã thay đổi ngày thành $newDate');
                },
              ),
              
              // Nội dung chính
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.0), // Xóa padding hoàn toàn
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Phần thực phẩm đã ghi nhận
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    // Navigate to food history screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FoodHistoryScreen(),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, color: Colors.black87),
                                          SizedBox(width: 8),
                                          Text(
                                            'Thực phẩm đã ghi nhận',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.arrow_forward_ios, size: 14),
                                        onPressed: () {
                                          // Navigate to food history screen
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => FoodHistoryScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: 4), // Giảm khoảng cách
                              
                              // Danh sách thực phẩm đã ghi nhận - sử dụng toàn bộ chiều rộng
                              recordedMeals.isEmpty
                                  ? _buildEmptyRecordedMeals()
                                  : Column(
                                      children: [
                                        Container(
                                          height: 250, 
                                          width: MediaQuery.of(context).size.width, // Sử dụng toàn bộ chiều rộng
                                          child: PageView.builder(
                                            controller: _pageController,
                                            itemCount: recordedMeals.length,
                                            physics: BouncingScrollPhysics(),
                                            pageSnapping: true,
                                            itemBuilder: (context, index) {
                                              final foodEntry = recordedMeals[index];
                                              // Lấy mục tiêu dinh dưỡng
                                              final userProvider = Provider.of<UserDataProvider>(context, listen: false);
                                              final goals = userProvider.nutritionGoals;
                                              
                                              return AnimatedOpacity(
                                                duration: Duration(milliseconds: 300),
                                                opacity: _pageController.hasClients && 
                                                        _pageController.page != null && 
                                                        (_pageController.page!.round() == index) ? 1.0 : 0.7,
                                                child: AnimatedScale(
                                                  duration: Duration(milliseconds: 300),
                                                  scale: _pageController.hasClients && 
                                                         _pageController.page != null && 
                                                         (_pageController.page!.round() == index) ? 1.0 : 0.9,
                                                  child: GestureDetector(
                                                    onTap: () => _navigateToMealDetails(foodEntry),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 2.0), // Xóa padding ngang
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(12), // Giảm bo góc
                                                        child: HeaderFoodInfoCard(
                                                          foodEntry: foodEntry,
                                                          servingSize: foodEntry.items.isNotEmpty 
                                                              ? foodEntry.items.first.servingSize 
                                                              : 1.0,
                                                          onEditTime: () {
                                                            // Xử lý khi sửa thời gian
                                                          },
                                                          caloriesGoal: goals['calories'] ?? 2000,
                                                          proteinGoal: goals['protein'] ?? 50,
                                                          fatGoal: goals['fat'] ?? 70,
                                                          carbsGoal: goals['carbs'] ?? 310,
                                                          onEditFood: () => _navigateToMealDetails(foodEntry),
                                                          onServingSizeChanged: (newSize) {
                                                            _updateServingSize(foodEntry.id, newSize);
                                                          },
                                                          onAddMore: () {
                                                            // Xử lý khi thêm thực phẩm
                                                          },
                                                          onDelete: () {
                                                            _deleteFoodEntry(foodEntry.id);
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            onPageChanged: (int index) {
                                              setState(() {
                                                // Cập nhật state để cập nhật indicator
                                              });
                                            },
                                          ),
                                        ),
                                        // Chỉ báo trang (page indicator) với animation và style cải tiến
                                        SizedBox(height: 12),
                                        recordedMeals.length > 1 
                                            ? AnimatedBuilder(
                                                animation: _pageController,
                                                builder: (context, child) {
                                                  // Lấy trang hiện tại một cách an toàn
                                                  int currentPage = 0;
                                                  double? currentPageDouble;
                                                  if (_pageController.hasClients && _pageController.positions.isNotEmpty) {
                                                    currentPage = _pageController.page?.round() ?? 0;
                                                    currentPageDouble = _pageController.page;
                                                  }
                                                  
                                                  return Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: List.generate(
                                                      recordedMeals.length,
                                                      (index) => Container(
                                                        width: currentPage == index ? 20 : 8,
                                                        height: 8,
                                                        margin: EdgeInsets.symmetric(horizontal: 4),
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(4),
                                                          color: currentPage == index
                                                              ? Colors.green
                                                              : Colors.grey.shade300,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : SizedBox.shrink(),
                                      ],
                                    ),
                              
                              SizedBox(height: 16),
                              
                              // Thêm biểu đồ tổng quan calo
                             
                              
                              // Hiển thị các nhóm dinh dưỡng
                              ..._nutritionGroups.map((group) {
                                return _buildSectionContainer(
                                  title: group['title'], 
                                  icon: group['icon'],
                                  iconColor: group['iconColor'],
                                  nutrients: group['nutrients'],
                                  summaryData: summaryData,
                                );
                              }).toList(),
                              
                              SizedBox(height: 80), // Không gian ở dưới cùng cho FAB
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // Biểu đồ tổng quan về calories
 
  
  // Widget hiển thị thông tin macro
  Widget _buildMacroInfo(String name, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        SizedBox(width: 6),
        Text(
          '$name: ${value.toInt()}g',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
   Widget _buildEmptyRecordedMeals() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.no_food,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'Bạn chưa ghi lại bữa ăn hôm nay',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Nhấn nút + để thêm bữa ăn mới',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> nutrients,
    Map<String, dynamic>? summaryData,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          height: 150, // Tăng chiều cao từ 140 lên 150
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                spreadRadius: 0,
                offset: Offset(0, 2),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          // Use LayoutBuilder to make the width of items adapt to screen size
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate an optimal item width based on container width
              final itemWidth = (constraints.maxWidth / 3.5).clamp(80.0, 105.0); // Tăng kích thước tối đa của item
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: nutrients.length,
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8), // Điều chỉnh padding dọc
                itemBuilder: (context, index) {
                  final nutrient = nutrients[index];
                  final nutrientInfo = _getNutrientValues(nutrient, summaryData);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 0.0), // Giảm padding dọc
                    child: SizedBox(
                      width: itemWidth,
                      child: _buildNutritionCircleForNutrient(
                        nutrient, 
                        nutrientInfo['value'], 
                        nutrientInfo['goal'],
                        nutrientInfo['remaining'],
                      ),
                    ),
                  );
                },
              );
            }
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNutritionCircleForNutrient(
    String nutrient, 
    double value, 
    double goal,
    double remaining
  ) {
    // Map các loại dinh dưỡng với tên hiển thị và màu sắc
    final nutrientDetails = {
      'calories': {'label': 'Calo', 'color': Colors.red.shade400, 'unit': 'kcal', 'icon': Icons.local_fire_department},
      'protein': {'label': 'Protein', 'color': Colors.blue.shade400, 'unit': 'g', 'icon': Icons.fitness_center},
      'fat': {'label': 'Chất béo', 'color': Colors.orange.shade400, 'unit': 'g', 'icon': Icons.water_drop},
      'carbs': {'label': 'Carb', 'color': Colors.green.shade400, 'unit': 'g', 'icon': Icons.eco},
      'cholesterol': {'label': 'Cholesterol', 'color': Colors.orange.shade400, 'unit': 'mg', 'icon': Icons.healing},
      'omega3': {'label': 'Omega-3', 'color': Colors.cyan.shade400, 'unit': 'mg', 'icon': Icons.spa},
      'fiber': {'label': 'Chất xơ', 'color': Colors.brown.shade400, 'unit': 'g', 'icon': Icons.grass},
      'water': {'label': 'Nước', 'color': Colors.blue.shade400, 'unit': 'ml', 'icon': Icons.water},
      'sugar': {'label': 'Đường', 'color': Colors.pink.shade400, 'unit': 'g', 'icon': Icons.cake},
      'saturatedFat': {'label': 'Chất béo bão hòa', 'color': Colors.grey.shade700, 'unit': 'g', 'icon': null},
      'transFat': {'label': 'Chất béo trans', 'color': Colors.red.shade300, 'unit': 'g', 'icon': null},
      'caffeine': {'label': 'Caffeine', 'color': Colors.brown.shade400, 'unit': 'mg', 'icon': Icons.coffee},
      'alcohol': {'label': 'Rượu', 'color': Colors.amber.shade400, 'unit': 'ml', 'icon': null},
      'vitaminA': {'label': 'Vitamin A', 'color': Colors.orange.shade400, 'unit': 'mcg', 'icon': null},
      'vitaminD': {'label': 'Vitamin D', 'color': Colors.amber.shade400, 'unit': 'mcg', 'icon': Icons.wb_sunny_outlined},
      'vitaminE': {'label': 'Vitamin E', 'color': Colors.green.shade300, 'unit': 'mg', 'icon': null},
      'vitaminK': {'label': 'Vitamin K', 'color': Colors.green.shade700, 'unit': 'mcg', 'icon': null},
      'vitaminB12': {'label': 'Vitamin B12', 'color': Colors.purple.shade400, 'unit': 'mcg', 'icon': null},
      'vitaminC': {'label': 'Vitamin C', 'color': Colors.orange.shade400, 'unit': 'mg', 'icon': Icons.local_florist},
      'vitaminB9': {'label': 'Vitamin B9', 'color': Colors.green.shade400, 'unit': 'mcg', 'icon': null},
      'thiamin': {'label': 'Thiamin', 'color': Colors.amber.shade600, 'unit': 'mg', 'icon': null},
      'riboflavin': {'label': 'Riboflavin', 'color': Colors.amber.shade700, 'unit': 'mg', 'icon': null},
      'niacin': {'label': 'Niacin', 'color': Colors.amber.shade800, 'unit': 'mg', 'icon': null},
      'iron': {'label': 'Sắt', 'color': Colors.red.shade700, 'unit': 'mg', 'icon': Icons.power},
      'calcium': {'label': 'Canxi', 'color': Colors.grey.shade400, 'unit': 'mg', 'icon': Icons.fitness_center},
      'magnesium': {'label': 'Magie', 'color': Colors.grey.shade600, 'unit': 'mg', 'icon': null},
      'phosphorus': {'label': 'Phốt pho', 'color': Colors.grey.shade500, 'unit': 'mg', 'icon': null},
      'potassium': {'label': 'Kali', 'color': Colors.purple.shade200, 'unit': 'mg', 'icon': null},
      'selenium': {'label': 'Selen', 'color': Colors.orange.shade300, 'unit': 'mcg', 'icon': null},
      'zinc': {'label': 'Kẽm', 'color': Colors.blue.shade400, 'unit': 'mg', 'icon': null},
      'copper': {'label': 'Đồng', 'color': Colors.brown.shade300, 'unit': 'mg', 'icon': null},
      'manganese': {'label': 'Mangan', 'color': Colors.pink.shade300, 'unit': 'mg', 'icon': null},
      'sodium': {'label': 'Natri', 'color': Colors.grey.shade400, 'unit': 'mg', 'icon': null},
    };
    
    final details = nutrientDetails[nutrient] ?? 
        {'label': nutrient, 'color': Colors.grey, 'unit': '', 'icon': null};
    
    final color = details['color'] as Color;
    final label = details['label'] as String;
    final unit = details['unit'] as String;
    final IconData? icon = details['icon'] as IconData?;
    
    // Kiểm tra xem giá trị có vượt quá mục tiêu không
    bool exceeds = value > goal;
    String remainingText = exceeds 
        ? '${(value - goal).toStringAsFixed(1)}${unit} vượt quá' 
        : 'Còn lại ${remaining.toStringAsFixed(1)}${unit}';
    
    // Tính toán phần trăm tiến trình (giới hạn ở 100%)
    double progress = value / goal;
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;
    
    if (nutrient == 'calories') {
      // Sử dụng NutritionCircle giống các nutrient khác để thống nhất giao diện
      return NutritionCircle(
        size: 62.0,
        value: progress * 100,
        max: 100.0,
        color: color,
        label: label,
        // Giữ format đẹp cho calories
        remainingText: value > 9999
            ? "${(value/1000).toStringAsFixed(1)}/${(goal/1000).toStringAsFixed(1)}k${unit}"
            : "${value.toInt()}/${goal.toInt()}${unit}",
        backgroundColor: color.withOpacity(0.2),
        useRadialGradient: false,
        showPercentage: true,
        icon: icon,
        showTotalValue: true,
      );
    }
    
    // Sử dụng NutritionCircle cho các nutrient khác để có giao diện giống với nutrition_illustration.dart
    return NutritionCircle(
      size: 62.0, // Tăng kích thước từ 55.0 lên 62.0
      value: progress * 100,
      max: 100.0,
      color: color,
      label: label,
      // Rút gọn text hiển thị hơn nữa
      remainingText: value > 999 || goal > 999 
          ? "${(value/1000).toStringAsFixed(1)}/${(goal/1000).toStringAsFixed(1)}k"
          : "${value.toInt()}/${goal.toInt()}",
      backgroundColor: color.withOpacity(0.2),
      useRadialGradient: false,
      showPercentage: true,
      icon: icon,
    );
  }

  void _showFoodLoggingOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Nút chụp ảnh
                  InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _captureImage();
                },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.camera_alt, color: Colors.green, size: 28),
                        ),
                        SizedBox(height: 8),
                        Text('Chụp ảnh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  
                  // Nút chọn từ thư viện
                  InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.photo_library, color: Colors.blue, size: 28),
                        ),
                        SizedBox(height: 8),
                        Text('Thư viện', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  
                  // Nút nhập thủ công
                  InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _navigateToManualEntry();
                },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.edit, color: Colors.orange, size: 28),
                        ),
                        SizedBox(height: 8),
                        Text('Nhập thủ công', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  
                  // Nút quét mã vạch
                  BarcodeScannerButton(
                    onBarcodeScan: (FoodItem foodItem, String barcode) {
                      Navigator.pop(context);
                      _processBarcodeFoodItem(foodItem, barcode);
                    },
                    onError: (String error) {
                      _showErrorMessage("Không thể quét mã vạch: $error");
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        _processImageForFoodRecognition(File(image.path));
      }
    } catch (e) {
      print('Lỗi khi chụp ảnh: $e');
      _showErrorMessage('Không thể sử dụng máy ảnh: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, 
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        _processImageForFoodRecognition(File(image.path));
      }
    } catch (e) {
      print('Lỗi khi chọn ảnh: $e');
      _showErrorMessage('Không thể truy cập thư viện ảnh: $e');
    }
  }

  void _processImageForFoodRecognition(File imageFile) {
    // Chuyển hướng đến màn hình nhận diện thực phẩm
    Navigator.pushNamed(
      context, 
      '/food-recognition',
      arguments: {'imageFile': imageFile, 'date': _selectedDate},
    ).then((_) {
      // Tải lại dữ liệu khi quay về
      loadMealData();
    });
  }

  void _navigateToManualEntry() {
    // Chuyển hướng đến màn hình nhập thủ công
    Navigator.pushNamed(
      context, 
      '/food-search',
      arguments: {'date': _selectedDate},
    ).then((_) {
      // Tải lại dữ liệu khi quay về
      loadMealData();
    });
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _updateServingSize(String foodEntryId, double newSize) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    print('DEBUG: Cập nhật kích thước serving size cho entry $foodEntryId thành $newSize');
    
    // Tìm entry cần cập nhật
    final index = foodProvider.todayEntries.indexWhere((entry) => entry.id == foodEntryId);
    if (index != -1) {
      final entry = foodProvider.todayEntries[index];
      print('DEBUG: Đã tìm thấy entry: ${entry.description}');
      
      // Nếu có items, cập nhật kích thước serving size của item đầu tiên
      if (entry.items.isNotEmpty) {
        final updatedItems = List<FoodItem>.from(entry.items);
        // Cập nhật serving size của item đầu tiên
        updatedItems[0] = updatedItems[0].copyWith(servingSize: newSize);
        
        // Tạo entry mới với items đã cập nhật
        final updatedEntry = entry.copyWith(items: updatedItems);
        
        // Cập nhật vào provider
        foodProvider.updateFoodEntry(updatedEntry);
        print('DEBUG: Đã cập nhật kích thước serving size!');
        
        // Tải lại dữ liệu sau khi cập nhật
        loadMealData();
      } else {
        print('DEBUG: Entry không có items!');
      }
    } else {
      print('DEBUG: Không tìm thấy entry với ID $foodEntryId!');
    }
  }

  void _deleteFoodEntry(String foodEntryId) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    print('DEBUG: Xóa entry $foodEntryId');
    
    // Tìm vị trí của entry cần xóa
    final index = foodProvider.todayEntries.indexWhere((entry) => entry.id == foodEntryId);
    if (index != -1) {
      print('DEBUG: Đã tìm thấy entry cần xóa ở vị trí $index');
      
      // Gọi phương thức xóa entry từ provider
      foodProvider.removeFoodEntry(foodEntryId);
      print('DEBUG: Đã gọi removeFoodEntry');
      
      // Tải lại dữ liệu sau khi xóa
      loadMealData();
      
      // Thông báo đã xóa
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa mục đã chọn'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      print('DEBUG: Không tìm thấy entry cần xóa!');
    }
  }

  Map<String, dynamic> _calculateNutritionSummary(List<FoodEntry> foodEntries, Map<String, double> goals) {
    // Khởi tạo map summaryData
    Map<String, dynamic> summaryData = {};
    
    // Danh sách các chất dinh dưỡng có sẵn trong FoodItem
    List<String> basicNutrients = ['calories', 'protein', 'fat', 'carbs', 'fiber', 'sugar', 'sodium'];
    
    // Danh sách bổ sung các chất dinh dưỡng cần theo dõi
    List<String> additionalNutrients = [
      'cholesterol', 'omega3', 'water',
      'saturatedFat', 'transFat', 'caffeine', 'alcohol',
      'vitaminA', 'vitaminD', 'vitaminE', 'vitaminK',
      'vitaminB12', 'vitaminC', 'vitaminB9',
      'thiamin', 'riboflavin', 'niacin',
      'iron', 'calcium', 'magnesium', 'phosphorus',
      'potassium', 'selenium', 'zinc', 'copper', 'manganese',
    ];
    
    // Tạo danh sách đầy đủ các chất dinh dưỡng
    List<String> allNutrients = [...basicNutrients, ...additionalNutrients];
    
    // Khởi tạo giá trị cho mỗi chất dinh dưỡng
    for (String nutrient in allNutrients) {
      double goalValue = goals[nutrient] ?? 100.0;
      summaryData[nutrient] = {
        'value': 0.0,
        'goal': goalValue,
        'remaining': goalValue
      };
    }
    
    // Tính tổng dinh dưỡng từ tất cả các bữa ăn
    for (FoodEntry entry in foodEntries) {
      for (FoodItem item in entry.items) {
        double multiplier = item.servingSize;
        
        // Cập nhật giá trị cho các chất dinh dưỡng chính
        if (summaryData.containsKey('calories')) {
          summaryData['calories']['value'] += item.calories * multiplier;
        }
        
        if (summaryData.containsKey('protein')) {
          summaryData['protein']['value'] += item.protein * multiplier;
        }
        
        if (summaryData.containsKey('fat')) {
          summaryData['fat']['value'] += item.fat * multiplier;
        }
        
        if (summaryData.containsKey('carbs')) {
          summaryData['carbs']['value'] += item.carbs * multiplier;
        }
        
        // Cập nhật giá trị cho các chất dinh dưỡng phụ nếu có
        if (item.fiber != null && summaryData.containsKey('fiber')) {
          summaryData['fiber']['value'] += item.fiber! * multiplier;
        }
        
        if (item.sugar != null && summaryData.containsKey('sugar')) {
          summaryData['sugar']['value'] += item.sugar! * multiplier;
        }
        
        if (item.sodium != null && summaryData.containsKey('sodium')) {
          summaryData['sodium']['value'] += item.sodium! * multiplier;
        }
        
        // Kiểm tra và cập nhật các chất dinh dưỡng bổ sung (nếu có)
        if (item.additionalNutrients != null) {
          item.additionalNutrients!.forEach((nutrient, value) {
            if (summaryData.containsKey(nutrient) && value is num) {
              summaryData[nutrient]['value'] += value.toDouble() * multiplier;
            }
          });
        }
      }
    }
    
    // Tính toán lại số lượng còn lại cho mỗi chất dinh dưỡng
    for (String nutrient in allNutrients) {
      if (summaryData.containsKey(nutrient)) {
        var nutrientData = summaryData[nutrient];
        if (nutrientData != null && nutrientData is Map) {
          double value = nutrientData['value'] ?? 0.0;
          double goal = nutrientData['goal'] ?? 100.0;
          double remaining = goal - value > 0 ? goal - value : 0.0;
          nutrientData['remaining'] = remaining;
        }
      }
    }
    
    return summaryData;
  }

  // Xử lý FoodItem được trả về từ quét mã vạch
  void _processBarcodeFoodItem(FoodItem foodItem, String barcode) {
    try {
      // Lấy thời gian hiện tại cho bữa ăn
      DateTime now = DateTime.now();
      
      // Xác định mealType dựa vào thời gian trong ngày
      String mealType = 'Bữa khác';
      final hour = now.hour;
      
      if (hour >= 5 && hour < 10) {
        mealType = 'Bữa sáng';
      } else if (hour >= 10 && hour < 14) {
        mealType = 'Bữa trưa';
      } else if (hour >= 14 && hour < 17) {
        mealType = 'Bữa phụ';
      } else if (hour >= 17 && hour < 22) {
        mealType = 'Bữa tối';
      }
      
      // Tạo UUID mới
      final uuid = Uuid();
      final String entryId = uuid.v4();
      
      // Tạo entry từ FoodItem
      final entry = FoodEntry(
        id: entryId,
        description: foodItem.name,
        items: [foodItem],
        dateTime: now,
        mealType: mealType, // Sử dụng mealType xác định từ giờ trong ngày
        barcode: barcode,
        nutritionInfo: {
          'calories': foodItem.calories,
          'protein': foodItem.protein,
          'fat': foodItem.fat,
          'carbs': foodItem.carbs,
          'fiber': foodItem.fiber,
          'sugar': foodItem.sugar,
          'sodium': foodItem.sodium,
          'servingSize': foodItem.servingSize,
          'totalWeight': foodItem.servingSize * 100,
          'dataSource': 'Open Food Facts',
          'barcode': barcode,
          ...foodItem.additionalNutrients ?? {},
        },
      );
      
      // Thêm entry vào provider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      foodProvider.addFoodEntry(entry);
      
      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tìm thấy: ${foodItem.name}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
      
      // Cập nhật lại dữ liệu trên màn hình
      loadMealData();
      
      // Ngay lập tức chuyển hướng đến màn hình chi tiết dinh dưỡng
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodNutritionDetailScreen(
            foodEntry: entry,
            onSave: (updatedEntry) {
              foodProvider.updateFoodEntry(updatedEntry);
              // Đảm bảo dữ liệu được cập nhật sau khi lưu
              loadMealData();
            },
          ),
        ),
      ).then((_) {
        // Đảm bảo tải lại dữ liệu khi quay lại
        loadMealData();
      });
    } catch (e) {
      print('Lỗi khi xử lý thông tin mã vạch: $e');
      _showErrorMessage('Không thể xử lý thông tin mã vạch: $e');
    }
  }
}
