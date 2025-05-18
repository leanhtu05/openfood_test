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
import '../services/meal_plan_api_service.dart';
import '../models/meal_plan.dart';

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
  bool _isApiConnected = false;
  bool _isLoadingMealPlan = false;
  MealPlan? _currentMealPlan;
  String? _apiErrorMessage;
  
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
      
      // Kiểm tra kết nối API
      _checkApiConnection();
      
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
      
      // Thêm nút tạo kế hoạch thực đơn
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_isApiConnected)
            FloatingActionButton(
              heroTag: 'btn_meal_plan',
              onPressed: _isLoadingMealPlan ? null : _generateWeeklyMealPlan,
              backgroundColor: Colors.orange,
              child: Icon(Icons.restaurant_menu),
              tooltip: 'Tạo kế hoạch thực đơn',
            ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'btn_add_food',
            onPressed: () {
              // Thêm thực phẩm mới
              // ... existing code ...
            },
            backgroundColor: Colors.green,
            child: Icon(Icons.add),
            tooltip: 'Thêm thực phẩm',
          ),
        ],
      ),
      
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
          
          // Tính toán tổng hợp dinh dưỡng
          final nutritionGoals = foodProvider.getNutritionGoals(context);
          // Chuyển đổi kiểu Map<String, dynamic> sang Map<String, double>
          final Map<String, double> convertedGoals = {};
          nutritionGoals.forEach((key, value) {
            if (value is num) {
              convertedGoals[key] = value.toDouble();
            }
          });
          final summaryData = _calculateNutritionSummary(recordedMeals, convertedGoals);
          
          // Nếu đang tải kế hoạch thực đơn
          if (_isLoadingMealPlan) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang tải kế hoạch thực đơn...'),
                ],
              ),
            );
          }
          
          // Nếu có lỗi API
          if (_apiErrorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(_apiErrorMessage!, textAlign: TextAlign.center),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkApiConnection,
                    child: Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          
          // Nếu có kế hoạch thực đơn
          if (_currentMealPlan != null) {
            // Lấy ngày trong tuần
            final DateTime selectedDateTime = DateTime.parse(_selectedDate);
            final String dayOfWeek = _getDayOfWeekString(selectedDateTime.weekday);
            
            // Lấy kế hoạch cho ngày đã chọn
            final dayPlan = _currentMealPlan!.weeklyPlan[dayOfWeek];
            
            if (dayPlan != null) {
              // Hiển thị kế hoạch thực đơn cho ngày đã chọn
              return Column(
                children: [
                  // Bộ chọn ngày (phần đã có)
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
                  
                  // Tiêu đề kế hoạch thực đơn
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kế hoạch thực đơn - ${_getVietnameseDayName(dayOfWeek)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.history),
                              onPressed: _getMealPlanHistory,
                              tooltip: 'Lịch sử kế hoạch',
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh),
                              onPressed: _replaceDayMealPlan,
                              tooltip: 'Tạo lại kế hoạch cho ngày này',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Hiển thị thông tin dinh dưỡng
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNutrientInfo('Calo', dayPlan.nutritionSummary['calories']?.round() ?? 0, 'kcal', Colors.red),
                        _buildNutrientInfo('Protein', dayPlan.nutritionSummary['protein']?.round() ?? 0, 'g', Colors.blue),
                        _buildNutrientInfo('Carbs', dayPlan.nutritionSummary['carbs']?.round() ?? 0, 'g', Colors.orange),
                        _buildNutrientInfo('Chất béo', dayPlan.nutritionSummary['fat']?.round() ?? 0, 'g', Colors.amber),
                      ],
                    ),
                  ),
                  
                  // Danh sách các bữa ăn
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: dayPlan.meals.keys.length,
                      itemBuilder: (context, index) {
                        final mealType = dayPlan.meals.keys.elementAt(index);
                        final meals = dayPlan.meals[mealType] ?? [];
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mealType,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...meals.map((meal) => _buildMealCard(meal)).toList(),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            }
          }
          
          // Trở về giao diện mặc định nếu không có kế hoạch
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
                                              // Lấy mục tiêu dinh dưỡng từ FoodProvider thay vì trực tiếp từ UserDataProvider
                                              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                                              final goals = foodProvider.getNutritionGoals(context);
                                              
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
                              
                              // Hiển thị nút tạo kế hoạch thực đơn nếu kết nối API thành công
                              if (_isApiConnected)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Card(
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.restaurant_menu, color: Colors.green),
                                              SizedBox(width: 8),
                                              Text(
                                                'Kế hoạch thực đơn thông minh',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'DietAI có thể tạo kế hoạch thực đơn phù hợp với mục tiêu dinh dưỡng của bạn.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: _generateWeeklyMealPlan,
                                                icon: Icon(Icons.add_circle_outline),
                                                label: Text('Tạo kế hoạch mới'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: _getMealPlanHistory,
                                                icon: Icon(Icons.history),
                                                label: Text('Xem lịch sử'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              
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
          height: 170, // Tăng chiều cao từ 150 lên 170 để phù hợp với vòng tròn lớn hơn
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
              final itemWidth = (constraints.maxWidth / 3.5).clamp(85.0, 110.0); // Tăng kích thước tối đa của item để phù hợp với vòng tròn lớn hơn
              
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
        size: 80.0, // Tăng kích thước lên 80.0
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
      size: 80.0, // Tăng kích thước lên 80.0
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

  // Kiểm tra kết nối API
  Future<void> _checkApiConnection() async {
    try {
      final isConnected = await MealPlanApiService.checkApiConnection();
      setState(() {
        _isApiConnected = isConnected;
      });
      
      if (isConnected) {
        print('MealRecordingScreen: Kết nối API thành công');
      } else {
        print('MealRecordingScreen: Không thể kết nối với API');
      }
    } catch (e) {
      print('Lỗi khi kiểm tra kết nối API: $e');
      setState(() {
        _isApiConnected = false;
      });
    }
  }
  
  // Tạo kế hoạch thực đơn hàng tuần
  Future<void> _generateWeeklyMealPlan() async {
    if (!_isApiConnected) {
      _showErrorMessage('Không thể kết nối với API. Vui lòng thử lại sau.');
      return;
    }
    
    setState(() {
      _isLoadingMealPlan = true;
      _apiErrorMessage = null;
    });
    
    try {
      // Lấy mục tiêu dinh dưỡng từ UserDataProvider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final nutritionGoals = foodProvider.getNutritionGoals(context);
      
      // Tạo kế hoạch thực đơn
      final result = await MealPlanApiService.generateWeeklyMealPlan(
        caloriesTarget: nutritionGoals['calories'] ?? 2000,
        proteinTarget: nutritionGoals['protein'] ?? 150,
        fatTarget: nutritionGoals['fat'] ?? 70,
        carbsTarget: nutritionGoals['carbs'] ?? 250,
      );
      
      setState(() {
        _currentMealPlan = MealPlan.fromJson(result);
        _isLoadingMealPlan = false;
      });
      
      _showSuccessMessage('Đã tạo kế hoạch thực đơn thành công');
    } catch (e) {
      print('Lỗi khi tạo kế hoạch thực đơn: $e');
      setState(() {
        _isLoadingMealPlan = false;
        _apiErrorMessage = 'Lỗi khi tạo kế hoạch thực đơn: $e';
      });
      _showErrorMessage('Lỗi khi tạo kế hoạch thực đơn: $e');
    }
  }
  
  // Thay thế kế hoạch thực đơn cho ngày hiện tại
  Future<void> _replaceDayMealPlan() async {
    if (!_isApiConnected) {
      _showErrorMessage('Không thể kết nối với API. Vui lòng thử lại sau.');
      return;
    }
    
    setState(() {
      _isLoadingMealPlan = true;
      _apiErrorMessage = null;
    });
    
    try {
      // Xác định ngày trong tuần (Monday, Tuesday, ...)
      final DateTime selectedDateTime = DateTime.parse(_selectedDate);
      final String dayOfWeek = _getDayOfWeekString(selectedDateTime.weekday);
      
      // Lấy mục tiêu dinh dưỡng từ UserDataProvider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final nutritionGoals = foodProvider.getNutritionGoals(context);
      
      // Thay thế kế hoạch thực đơn cho ngày đã chọn
      final result = await MealPlanApiService.replaceDayMealPlan(
        day: dayOfWeek,
        caloriesTarget: nutritionGoals['calories'] ?? 2000,
        proteinTarget: nutritionGoals['protein'] ?? 150,
        fatTarget: nutritionGoals['fat'] ?? 70,
        carbsTarget: nutritionGoals['carbs'] ?? 250,
      );
      
      // Cập nhật kế hoạch thực đơn hiện tại
      if (_currentMealPlan != null) {
        final updatedPlan = {..._currentMealPlan!.weeklyPlan};
        updatedPlan[dayOfWeek] = DayMealPlan.fromJson(result['day_plan']);
        
        setState(() {
          _currentMealPlan = MealPlan(
            id: _currentMealPlan!.id,
            userId: _currentMealPlan!.userId,
            createdAt: _currentMealPlan!.createdAt,
            weeklyPlan: updatedPlan,
            nutritionTargets: _currentMealPlan!.nutritionTargets,
          );
          _isLoadingMealPlan = false;
        });
      } else {
        // Nếu chưa có kế hoạch hiện tại, tạo mới
        await _generateWeeklyMealPlan();
      }
      
      _showSuccessMessage('Đã cập nhật kế hoạch thực đơn cho ngày ${_getVietnameseDayName(dayOfWeek)}');
    } catch (e) {
      print('Lỗi khi thay thế kế hoạch thực đơn ngày: $e');
      setState(() {
        _isLoadingMealPlan = false;
        _apiErrorMessage = 'Lỗi khi thay thế kế hoạch thực đơn ngày: $e';
      });
      _showErrorMessage('Lỗi khi thay thế kế hoạch thực đơn ngày: $e');
    }
  }
  
  // Lấy lịch sử kế hoạch thực đơn
  Future<void> _getMealPlanHistory() async {
    if (!_isApiConnected) {
      _showErrorMessage('Không thể kết nối với API. Vui lòng thử lại sau.');
      return;
    }
    
    setState(() {
      _isLoadingMealPlan = true;
      _apiErrorMessage = null;
    });
    
    try {
      final history = await MealPlanApiService.getMealPlanHistory();
      
      setState(() {
        _isLoadingMealPlan = false;
      });
      
      // Hiển thị lịch sử trong dialog
      _showMealPlanHistoryDialog(history);
    } catch (e) {
      print('Lỗi khi lấy lịch sử kế hoạch thực đơn: $e');
      setState(() {
        _isLoadingMealPlan = false;
        _apiErrorMessage = 'Lỗi khi lấy lịch sử kế hoạch thực đơn: $e';
      });
      _showErrorMessage('Lỗi khi lấy lịch sử kế hoạch thực đơn: $e');
    }
  }
  
  // Hiển thị dialog lịch sử kế hoạch thực đơn
  void _showMealPlanHistoryDialog(List<dynamic> history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lịch sử kế hoạch thực đơn'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: history.isEmpty
              ? Center(child: Text('Không có kế hoạch thực đơn nào.'))
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final DateTime createdAt = DateTime.parse(item['created_at']);
                    final String formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute}';
                    
                    return ListTile(
                      title: Text('Kế hoạch #${index + 1}'),
                      subtitle: Text('Ngày tạo: $formattedDate'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteMealPlan(item['filename']);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        // Load kế hoạch này
                        _loadMealPlanFromHistory(item);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }
  
  // Tải kế hoạch thực đơn từ lịch sử
  Future<void> _loadMealPlanFromHistory(dynamic historyItem) async {
    setState(() {
      _isLoadingMealPlan = true;
      _apiErrorMessage = null;
    });
    
    try {
      // Parse dữ liệu từ history item
      final MealPlan mealPlan = MealPlan.fromJson(historyItem);
      
      setState(() {
        _currentMealPlan = mealPlan;
        _isLoadingMealPlan = false;
      });
      
      _showSuccessMessage('Đã tải kế hoạch thực đơn thành công');
    } catch (e) {
      print('Lỗi khi tải kế hoạch thực đơn từ lịch sử: $e');
      setState(() {
        _isLoadingMealPlan = false;
        _apiErrorMessage = 'Lỗi khi tải kế hoạch thực đơn từ lịch sử: $e';
      });
      _showErrorMessage('Lỗi khi tải kế hoạch thực đơn từ lịch sử: $e');
    }
  }
  
  // Xóa kế hoạch thực đơn
  Future<void> _deleteMealPlan(String filename) async {
    setState(() {
      _isLoadingMealPlan = true;
      _apiErrorMessage = null;
    });
    
    try {
      final result = await MealPlanApiService.deleteMealPlan(filename);
      
      setState(() {
        _isLoadingMealPlan = false;
      });
      
      _showSuccessMessage('Đã xóa kế hoạch thực đơn thành công');
      
      // Tải lại lịch sử
      _getMealPlanHistory();
    } catch (e) {
      print('Lỗi khi xóa kế hoạch thực đơn: $e');
      setState(() {
        _isLoadingMealPlan = false;
        _apiErrorMessage = 'Lỗi khi xóa kế hoạch thực đơn: $e';
      });
      _showErrorMessage('Lỗi khi xóa kế hoạch thực đơn: $e');
    }
  }
  
  // Hiển thị thông báo thành công
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  // Chuyển đổi số thứ tự ngày trong tuần sang tên tiếng Anh
  String _getDayOfWeekString(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Monday';
    }
  }
  
  // Chuyển đổi tên tiếng Anh sang tên tiếng Việt
  String _getVietnameseDayName(String englishDay) {
    switch (englishDay) {
      case 'Monday': return 'Thứ 2';
      case 'Tuesday': return 'Thứ 3';
      case 'Wednesday': return 'Thứ 4';
      case 'Thursday': return 'Thứ 5';
      case 'Friday': return 'Thứ 6';
      case 'Saturday': return 'Thứ 7';
      case 'Sunday': return 'Chủ nhật';
      default: return englishDay;
    }
  }

  // Widget hiển thị thông tin dinh dưỡng
  Widget _buildNutrientInfo(String label, int value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$value$unit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  
  // Widget hiển thị thẻ món ăn
  Widget _buildMealCard(Meal meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hình ảnh món ăn (nếu có)
                if (meal.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      meal.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.restaurant, color: Colors.grey),
                  ),
                
                SizedBox(width: 12),
                
                // Thông tin món ăn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        meal.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Thông tin dinh dưỡng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMealNutrientInfo('Calo', meal.nutrition['calories']?.round() ?? 0, 'kcal', Colors.red),
                _buildMealNutrientInfo('Protein', meal.nutrition['protein']?.round() ?? 0, 'g', Colors.blue),
                _buildMealNutrientInfo('Carbs', meal.nutrition['carbs']?.round() ?? 0, 'g', Colors.orange),
                _buildMealNutrientInfo('Chất béo', meal.nutrition['fat']?.round() ?? 0, 'g', Colors.amber),
              ],
            ),
            
            // Ingredients (tuỳ chọn)
            if (meal.ingredients.isNotEmpty) ...[
              SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Nguyên liệu',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: meal.ingredients.map((ingredient) => Chip(
                        label: Text(
                          ingredient,
                          style: TextStyle(fontSize: 12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.green.shade50,
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ],
            
            // Nút hành động
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // Tạo một FoodEntry từ Meal và thêm vào nhật ký
                    _addMealToFoodEntry(meal);
                  },
                  icon: Icon(Icons.add_circle, size: 16),
                  label: Text('Thêm vào nhật ký'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget hiển thị thông tin dinh dưỡng cho món ăn
  Widget _buildMealNutrientInfo(String label, int value, String unit, Color color) {
    return Column(
      children: [
        Text(
          '$value$unit',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  // Thêm món ăn từ kế hoạch vào nhật ký
  Future<void> _addMealToFoodEntry(Meal meal) async {
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Xác định loại bữa ăn dựa trên thời gian hiện tại
      DateTime selectedDateTime = DateTime.parse(_selectedDate);
      final now = DateTime.now();
      selectedDateTime = DateTime(
        selectedDateTime.year, 
        selectedDateTime.month, 
        selectedDateTime.day,
        now.hour,
        now.minute,
      );
      
      // Tạo FoodItem từ Meal
      final foodItem = FoodItem(
        id: const Uuid().v4(),
        name: meal.name,
        brand: '',
        calories: meal.nutrition['calories'] ?? 0,
        protein: meal.nutrition['protein'] ?? 0,
        fat: meal.nutrition['fat'] ?? 0,
        carbs: meal.nutrition['carbs'] ?? 0,
        servingSize: 1.0,
        servingUnit: 'khẩu phần',
        fiber: meal.nutrition['fiber'],
        sugar: meal.nutrition['sugar'],
        sodium: meal.nutrition['sodium'],
        additionalNutrients: meal.nutrition,
      );
      
      // Tạo FoodEntry từ FoodItem
      final entry = FoodEntry(
        description: meal.name,
        mealType: _selectedMealType,
        dateTime: selectedDateTime,
        items: [foodItem],
        nutritionInfo: {...meal.nutrition, 'servingSize': 1.0, 'totalWeight': 100.0},
      );
      
      // Thêm vào foodProvider
      foodProvider.addFoodEntry(entry);
      
      // Cập nhật UI
      loadMealData();
      
      // Hiển thị thông báo
      _showSuccessMessage('Đã thêm ${meal.name} vào nhật ký');
    } catch (e) {
      print('Lỗi khi thêm món ăn vào nhật ký: $e');
      _showErrorMessage('Lỗi khi thêm món ăn vào nhật ký: $e');
    }
  }
}
