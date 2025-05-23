import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:openfood/services/exercise_service.dart';
import '../widgets/day_selector.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/constants.dart';
import '../utils/water_utils.dart';
import 'package:openfood/models/exercise.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/water_provider.dart';
import '../providers/food_provider.dart';
import '../widgets/home/calorie_progress.dart';
import '../widgets/home/exercise_section.dart';
import '../widgets/home/meals_section.dart';
import '../widgets/home/water_section.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../screens/food_logging_screen.dart';
import '../widgets/draggable_floating_action_button.dart';
import '../services/onboarding_service.dart';
import 'tdee_info_screen.dart';
import '../screens/food_nutrition_detail_screen.dart';
import '../models/food_entry.dart';
import '../screens/meal_recording_screen.dart';
import '../screens/diet_plan_screen.dart';
import '../providers/user_data_provider.dart';
import 'profile_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedDay = DateTime.now().day;
  int _selectedNavIndex = 3;
  Map<String, int> _exerciseCalories = {};
  List<Exercise> _selectedExercises = [];
  DateTime? _exerciseTimestamp;
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Giá trị giả để hiển thị trong giao diện demo
  int _consumedWater = 12500; // mL đã uống
  final int _waterGoal = 3700; // mL mục tiêu
  DateTime? _lastWaterTime = DateTime.now(); // Thời gian lần cuối ghi nhận nước
  
  // Thay thế giá trị cố định bằng biến có thể thay đổi theo ngày
  int _consumedCalories = 0;
  int _caloriesGoal = 0; // Thay đổi từ final int sang int để có thể cập nhật

  // Add this offset variable to the _HomeScreenState class
  Offset _fabPosition = Offset(0, 0);
  bool _isDragging = false;
  bool _showMealSuggestion = true;
  
  // Thêm biến này để kiểm soát việc refresh
  DateTime _lastRefresh = DateTime.now();

  // Thêm biến để kiểm tra trạng thái tải
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.standard,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.standard,
      ),
    );
    
    // Lấy ngày hiện tại và cập nhật selectedDay
    final now = DateTime.now();
    _selectedDay = now.day;
    _selectedDate = now.toIso8601String().split('T')[0];
    
    // Khởi động animation khi build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      
      // Đồng bộ ngày đã chọn và tải dữ liệu - sau khi build hoàn tất
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      
      exerciseProvider.setSelectedDate(_selectedDate);
      waterProvider.setSelectedDate(_selectedDate);
      
      // Xóa cache dinh dưỡng
      foodProvider.clearNutritionCache();
      
      // Đặt ngày cho food provider - điều này sẽ tự động gọi fetchDaily...
      foodProvider.setSelectedDate(_selectedDate);
      
      // Tải dữ liệu
      _loadExercisesForSelectedDate();
      waterProvider.loadData();
      foodProvider.loadData();
      
      // Cập nhật lượng calo tiêu thụ
      _updateConsumedCalories(foodProvider);
      
      // Cập nhật mục tiêu dinh dưỡng từ UserDataProvider
      _updateNutritionGoals(userDataProvider);
      
      // Cập nhật thông tin nước
      _updateWaterConsumption(waterProvider);
      
      print('HomeScreen: Đã tải dữ liệu ban đầu cho ngày $_selectedDate');
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadExercisesForSelectedDate() async {
    try {
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      
      // Tải lại dữ liệu bài tập mà không gọi setSelectedDate
      // vì nó sẽ gọi notifyListeners() và có thể gây ra lỗi trong quá trình build
      await exerciseProvider.loadExercises();
  
      if (mounted) {
        setState(() {
          // Lấy danh sách bài tập cho ngày đã chọn từ Provider
          _selectedExercises = exerciseProvider.selectedDateExercises;
  
          // Cập nhật Map calories
          _exerciseCalories.clear();
          for (var exercise in _selectedExercises) {
            _exerciseCalories[exercise.name] = exercise.calories;
          }
  
          // Cập nhật timestamp
          _exerciseTimestamp = DateTime.now();
        });
      }
    } catch (e) {
      print('Lỗi khi tải dữ liệu bài tập: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải dữ liệu bài tập: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
  
  // Phương thức để tải lại tất cả dữ liệu cho ngày đã chọn
  Future<void> _loadDataForSelectedDate() async {
    // Thêm biến để kiểm tra trạng thái tải
    if (_isLoadingData) return;
    _isLoadingData = true;
    
    try {
      // Lấy tất cả provider
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      
      // Đồng bộ ngày - giảm bớt in debug
      exerciseProvider.setSelectedDate(_selectedDate);
      waterProvider.setSelectedDate(_selectedDate);
      
      // Xóa cache dinh dưỡng
      foodProvider.clearNutritionCache();
      
      // Đặt ngày cho food provider - điều này sẽ tự động gọi fetchDaily...
      foodProvider.setSelectedDate(_selectedDate);
      
      // Sử dụng Future.wait để tải song song các dữ liệu
      await Future.wait([
        _loadExercisesForSelectedDate(),
        waterProvider.loadData(),
        foodProvider.loadData(),
      ]);
      
      // Làm mới dữ liệu dinh dưỡng
      await foodProvider.refreshNutrition();
      
      // Cập nhật các giá trị không phụ thuộc vào setState
      _updateNutritionGoals(userDataProvider);
      _updateConsumedCalories(foodProvider);
      _updateWaterConsumption(waterProvider);
      
      // Gom tất cả setState vào một lần cập nhật
      if (mounted) {
        setState(() {
          _updateMealSuggestionState();
        });
      }
    } catch (e) {
      // Sử dụng lỗi ngắn gọn cho debug
      print('Lỗi tải dữ liệu: $e');
    } finally {
      // Luôn đặt lại trạng thái tải
      _isLoadingData = false;
    }
  }

  // Phương thức mới để tính và cập nhật lượng calo tiêu thụ
  void _updateConsumedCalories(FoodProvider foodProvider) {
    // Lấy danh sách thực phẩm trong ngày được chọn
    final todayEntries = foodProvider.todayEntries;
    
    // Reset giá trị về 0 nếu không có thực phẩm
    if (todayEntries.isEmpty) {
      setState(() {
        _consumedCalories = 0;
      });
      print('Đã reset lượng calo tiêu thụ về 0 cho ngày $_selectedDate vì không có thực phẩm');
      return;
    }
    
    // Tính tổng lượng calo từ tất cả thực phẩm trong ngày
    int totalCalories = 0;
    for (var entry in todayEntries) {
      if (entry.nutritionInfo != null && entry.nutritionInfo!['calories'] != null) {
        // Lấy giá trị từ nutritionInfo nếu có
        totalCalories += (entry.nutritionInfo!['calories'] as num).round();
      } else {
        // Nếu không có nutritionInfo, sử dụng tổng calo từ các items
        totalCalories += entry.totalCalories.round();
      }
    }
    
    // Cập nhật giá trị
    setState(() {
      _consumedCalories = totalCalories;
    });
    
    print('Đã cập nhật lượng calo tiêu thụ: $_consumedCalories cho ngày $_selectedDate');
  }

  // Phương thức để cập nhật trạng thái hiển thị gợi ý bữa ăn
  void _updateMealSuggestionState() {
    final now = DateTime.now();
    final selectedDateTime = DateTime.parse(_selectedDate);
    
    // Chỉ hiển thị gợi ý bữa ăn cho ngày hiện tại
    final isSameDay = selectedDateTime.year == now.year && 
                    selectedDateTime.month == now.month && 
                    selectedDateTime.day == now.day;
    
    // Không hiển thị gợi ý nếu đã đạt đủ lượng calorie mục tiêu
    final hasReachedCalorieGoal = _consumedCalories >= _caloriesGoal;
                    
    _showMealSuggestion = isSameDay && !hasReachedCalorieGoal;
    
    if (hasReachedCalorieGoal && isSameDay) {
      print('Đã đạt đủ mục tiêu calo cho ngày hôm nay ($_consumedCalories/$_caloriesGoal) - Ẩn gợi ý bữa ăn');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Tránh tải dữ liệu quá thường xuyên và gọi setState trong lúc build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Kiểm tra xem đã quá 5 giây kể từ lần refresh cuối chưa
      final now = DateTime.now();
      final difference = now.difference(_lastRefresh).inSeconds;
      
      // Tăng khoảng thời gian giữa các lần refresh lên 5 giây để tránh lag
      if (difference > 5 && !_isLoadingData) {
        _lastRefresh = now;
        // Chỉ tải dữ liệu bài tập - đủ để cập nhật UI mà không nặng
        _loadExercisesForSelectedDate();
        // Không gọi _loadDataForSelectedDate() ở đây để tránh làm nặng UI khi chuyển tab
      }
    });
  }

  int get totalExerciseCalories {
    return _exerciseCalories.values.fold(0, (sum, calories) => sum + calories);
  }

  // Build a modern and attractive app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'DietAI',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Thêm nút kiểm tra Firebase
        IconButton(
          icon: Icon(Icons.verified_user, color: AppColors.primary),
          tooltip: 'Kiểm tra trạng thái Firebase',
          onPressed: () {
            _checkFirebaseDataStatus();
          },
        ),
        // Thêm nút Diet Plan
        IconButton(
          icon: Icon(Icons.restaurant_menu, color: AppColors.primary),
          tooltip: 'Kế hoạch dinh dưỡng',
          onPressed: () {
            Navigator.pushNamed(context, '/diet-plan');
          },
        ),
        // Thêm nút Refresh
        IconButton(
          icon: Icon(Icons.refresh, color: AppColors.primary),
          onPressed: () {
            // Hiển thị thông báo
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text('Đang làm mới dữ liệu...'),
                    ),
                  ],
                ),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.fixed,
              ),
            );
            
            // Làm mới dữ liệu
            _loadDataForSelectedDate();
          },
        ),
        IconButton(
          icon: Icon(Icons.restart_alt, color: AppColors.primary),
          onPressed: () {
            _showResetOnboardingDialog(context);
          },
        ),
        // Notification icon with badge
        Stack(
          alignment: Alignment.center,
          children: [
        IconButton(
              icon: Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
              onPressed: () {
                // Show notification dialog
                _showNotificationDialog();
              },
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TDEEInfoScreen()),
            );
          },
        ),
      ],
    );
  }

  void _showNotificationDialog() {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                        Icons.notifications_active,
                  color: AppColors.secondary,
                  size: 30,
                ),
                      ),
              SizedBox(height: 20),
                      Text(
                        'Thông báo',
                style: AppTextStyles.heading3,
                        ),
              SizedBox(height: 10),
                      Text(
                        'Bạn đã hoàn thành mục tiêu nước uống hôm nay!',
                        textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Xác nhận'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealTimeSuggestion() {
    // Hiển thị gợi ý bữa ăn dựa vào thời gian hiện tại
    final hour = DateTime.now().hour;
    String mealType;
    String mealSuggestion;
    IconData mealIcon;
    Color bgColor;
    
    if (hour >= 5 && hour < 10) {
      mealType = 'Bữa sáng';
      mealSuggestion = 'Protein, ngũ cốc nguyên hạt và trái cây tươi';
      mealIcon = Icons.wb_sunny_outlined;
      bgColor = Colors.orange.shade100;
    } else if (hour >= 11 && hour < 14) {
      mealType = 'Bữa trưa';
      mealSuggestion = 'Protein nạc, rau xanh và carbs phức hợp';
      mealIcon = Icons.cloud_outlined;
      bgColor = Colors.blue.shade100;
    } else if (hour >= 17 && hour < 21) {
      mealType = 'Bữa tối';
      mealSuggestion = 'Protein nạc, rau xanh và ít tinh bột';
      mealIcon = Icons.nights_stay_outlined;
      bgColor = Colors.indigo.shade100;
    } else {
      mealType = 'Bữa phụ';
      mealSuggestion = 'Trái cây, hạt, sữa chua ít đường';
      mealIcon = Icons.access_time_rounded;
      bgColor = Colors.purple.shade100;
    }
    
    return Visibility(
      visible: _showMealSuggestion,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              // Get reference to provider
              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
              
              // Navigate to food logging with the current meal type
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FoodLoggingScreen(
                    initialDate: _selectedDate,
                    initialMealType: mealType, // Thêm loại bữa ăn hiện tại
                  ),
                ),
              );
              
              // Handle result and reload data
              if (result != null) {
                await _loadDataForSelectedDate();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(mealIcon, size: 24, color: AppColors.food),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đề xuất $mealType',
                          style: AppTextStyles.heading3.copyWith(fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          mealSuggestion,
                          style: AppTextStyles.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() {
                          _showMealSuggestion = false;
                        });
                      },
                      constraints: BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Consumer<FoodProvider>(
        builder: (context, foodProvider, child) {
          // Sync with provider if date changed in MealRecordingScreen tab
          if (foodProvider.selectedDate != _selectedDate) {
            // Thay vì tải dữ liệu trực tiếp trong build, dùng microtask để cập nhật sau build
            Future.microtask(() {
              setState(() {
                _selectedDate = foodProvider.selectedDate;
                // Cập nhật _selectedDay để UI hiển thị đúng
                final selectedDateTime = DateTime.parse(_selectedDate);
                _selectedDay = selectedDateTime.day;
              });
              
              // Không thực hiện tải dữ liệu nặng trong build
              // Chỉ cập nhật lại trong future để tránh lag
              _loadDataForSelectedDate();
            });
          }
          
          return _buildBody();
        }
      ),
      floatingActionButton: DraggableFloatingActionButton(
        initialOffset: Offset(MediaQuery.of(context).size.width - 80, MediaQuery.of(context).size.height / 2 - 80),
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add_outlined, color: Colors.white),
        onPressed: () => _showAddOptionsDialog(context),
      ),
      bottomNavigationBar: Container(
        height: 50,
        child: BottomNavBar(
          selectedIndex: _selectedNavIndex,
          onItemSelected: (index) {
            // Tránh thực hiện nhiều lần khi tap vào tab hiện tại
            if (_selectedNavIndex == index) return;
            
            // If the user is switching from MealRecordingScreen tab to another tab,
            // refresh the data in case date was changed in MealRecordingScreen
            final wasMealRecordingTab = _selectedNavIndex == 2;
            
            setState(() {
              _selectedNavIndex = index;
            });
            
            // If switching to MealRecordingScreen tab, ensure date is in sync
            if (index == 2) {
              // Ensure MealRecordingScreen starts with the current selected date
              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
              if (foodProvider.selectedDate != _selectedDate) {
                foodProvider.setSelectedDate(_selectedDate);
              }
            }
            
            // If coming back from MealRecordingScreen tab, refresh data
            if (wasMealRecordingTab && index != 2) {
              // Cập nhật ngày nhưng không làm nặng UI bằng cách sử dụng microtask
              Future.microtask(() {
                final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                
                // Chỉ cập nhật nếu có sự thay đổi
                if (foodProvider.selectedDate != _selectedDate) {
                  setState(() {
                    _selectedDate = foodProvider.selectedDate;
                    final selectedDateTime = DateTime.parse(_selectedDate);
                    _selectedDay = selectedDateTime.day;
                  });
                }
                
                // Tải dữ liệu ở background sau khi UI đã render
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_isLoadingData) {
                    _loadDataForSelectedDate();
                  }
                });
              });
            }
          },
        ),
      ),
    );
  }
  
  // Show options dialog when FAB is clicked
  void _showAddOptionsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Thêm mới',
                style: AppTextStyles.heading2.copyWith(fontSize: 20),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickActionButton(
                    icon: Icons.restaurant,
                    label: 'Bữa ăn',
                    color: AppColors.food,
                    onTap: () async {
                      Navigator.pop(context);
                      // Navigate to food logging
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FoodLoggingScreen(initialDate: _selectedDate),
                        ),
                      );
                      
                      // Handle result and reload data
                      if (result != null) {
                        await _loadDataForSelectedDate();
                      }
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.water_drop,
                    label: 'Nước uống',
                    color: AppColors.water,
                    onTap: () {
                      Navigator.pop(context);
                      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
                      waterProvider.showWaterInputDialog(context).then((_) {
                        // Tải lại dữ liệu sau khi thêm nước
                        _loadDataForSelectedDate();
                      });
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.fitness_center,
                    label: 'Bài tập',
                    color: AppColors.exercise,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/exercise_log',
                        arguments: _selectedDate,
                      ).then((_) => _loadExercisesForSelectedDate());
                    },
                  ),
                ],
              ),
              SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  // Quick action button for bottom sheet
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 8),
            Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Hiển thị dialog xác nhận reset onboarding
  void _showResetOnboardingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Trạng Thái Onboarding'),
          content: const Text(
            'Bạn có muốn quay lại quá trình onboarding ngay bây giờ?'
            '\n\nLựa chọn này chỉ dành cho mục đích thử nghiệm.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                // Reset onboarding status
                await OnboardingService.resetOnboardingStatus();
                
                // Reset user data to defaults
                final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
                await userDataProvider.resetData();
                
                print('Đã reset toàn bộ dữ liệu người dùng và trạng thái onboarding');
                
                if (!context.mounted) return;
                Navigator.of(context).pop();
                
                // Hiển thị thông báo xác nhận reset
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã reset dữ liệu thành công. Chuyển đến màn hình onboarding...'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
                
                // Chuyển đến màn hình onboarding ngay lập tức thay vì
                // chỉ hiển thị SnackBar và yêu cầu khởi động lại ứng dụng
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/onboarding',
                  (route) => false, // Loại bỏ tất cả các màn hình khác khỏi stack
                );
              },
              child: const Text('Reset', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedNavIndex) {
      case 0:
        // Tab 0
        return Center(child: Text('Tab 0'));
      case 1:
        // Tab Nutrition - DietPlan
        return DietPlanScreen();
      case 2:
        // Icon ghi lại hiển thị MealRecordingScreen
        return MealRecordingScreen(initialDate: _selectedDate);
      case 3:
        return _buildHomeContent();
      case 4:
        return ProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
       return SingleChildScrollView(
          child: AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: AppAnimations.medium,
                childAnimationBuilder: (widget) => SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
            children: _buildHomeContentWidgets(),
          ),
        ),
      ),
    );
  }
  
  List<Widget> _buildHomeContentWidgets() {
    return [
      _buildDaySelector(),
      _buildMealTimeSuggestion(),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CalorieProgressSection(),
      ),
      _buildMealSection(),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: WaterSection(),
      ),
      _buildExerciseSection(),
    ];
  }
  
  Widget _buildDaySelector() {
    return DaySelector.fullDate(
                    selectedDate: _selectedDate,
      onDateChanged: _handleDateChange,
    );
  }
  
  Future<void> _handleDateChange(String newDate) async {
                      setState(() {
                        _selectedDate = newDate;
                        final selectedDateTime = DateTime.parse(newDate);
                        _selectedDay = selectedDateTime.day;
    });
    
    // Synchronize date across providers
    _syncDateAcrossProviders(newDate);
    
    // Update food data first, then load other data
    await _updateFoodDataForDate(_selectedDate);
    await _loadDataForSelectedDate();
  }
  
  void _syncDateAcrossProviders(String date) {
                      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
                      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
                      
    foodProvider.setSelectedDate(date);
    exerciseProvider.setSelectedDate(date);
    waterProvider.setSelectedDate(date);
  }

  Widget _buildMealSection() {
    // Get a reference to the FoodProvider
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.list_alt, size: 20, color: AppColors.textPrimary),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Nhật ký ăn uống',
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          MealsSection(
            onMealTap: () async {
              // Push to the food logging screen with current time-based meal type
              String currentMealType = _getCurrentMealTypeByTime();
              
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FoodLoggingScreen(
                    initialDate: _selectedDate,
                    initialMealType: currentMealType,
                  ),
                ),
              );
              // Process result and reload data when returning
              if (result != null) {
                await _loadDataForSelectedDate();
              }
            },
            onFoodItemTap: _handleFoodItemTap,
            // Add meal type selection callback
            onMealTypeTap: (String mealType) async {
              // Navigate to food logging screen with the selected meal type
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FoodLoggingScreen(
                    initialDate: _selectedDate,
                    initialMealType: mealType,
                  ),
                ),
              );
              // Process result and reload data when returning
              if (result != null) {
                await _loadDataForSelectedDate();
              }
            },
          ),
        ],
      ),
    );
  }
  
  // Helper to get current meal type based on time
  String _getCurrentMealTypeByTime() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 10) {
      return 'Bữa sáng';
    } else if (hour >= 11 && hour < 14) {
      return 'Bữa trưa';
    } else if (hour >= 17 && hour < 21) {
      return 'Bữa tối';
    } else {
      return 'Bữa phụ';
    }
  }
  
  Widget _buildExerciseSection() {
    return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExerciseSection(
                      exercises: _selectedExercises,
        onAddExercise: _navigateToExerciseLog,
        onViewHistory: _navigateToExerciseHistory,
      ),
    );
  }
  
  void _navigateToExerciseLog() {
                        Navigator.pushNamed(
                          context,
                          '/exercise_log',
                          arguments: _selectedDate,
                        ).then((_) => _loadExercisesForSelectedDate());
  }
  
  void _navigateToExerciseHistory() {
                        Navigator.pushNamed(
                          context, 
                          '/combined_history',
                          arguments: {'filter': 'exercise'}
                        ).then((_) => _loadExercisesForSelectedDate());
  }

  void _handleFoodItemTap(FoodEntry foodEntry) {
                      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    // Prepare data
                            foodProvider.clearNutritionCache();
                            foodProvider.refreshNutrition();
                            final updatedFoodEntry = foodProvider.getFoodEntryById(foodEntry.id) ?? foodEntry;
                            foodProvider.clearNutritionCache();
    
    // Show loading snackbar
                            ScaffoldMessenger.of(context).clearSnackBars();
    _showLoadingSnackBar('Đang tải thông tin dinh dưỡng...');
    
    // Navigate to nutrition detail screen
    _navigateToFoodNutritionDetail(updatedFoodEntry);
  }
  
  void _showLoadingSnackBar(String message) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2, 
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      )
                                    ),
                                    SizedBox(width: 10),
            Text(message),
                                  ],
                                ),
                                duration: Duration(seconds: 1),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
  }

  void _navigateToFoodNutritionDetail(FoodEntry entry) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FoodNutritionDetailScreen(
          foodEntry: entry,
          onSave: _handleFoodEntrySave,
        ),
      ),
    ).then((result) => _handleFoodNutritionDetailResult(result));
  }
  
  void _handleFoodEntrySave(FoodEntry updatedEntry) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    // Hiển thị thông báo đang cập nhật
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16, 
              height: 16, 
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)
              )
            ),
            SizedBox(width: 8),
            Text('Đang cập nhật thông tin bữa ăn...'),
          ],
        ),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ),
    );
    
    // Thực hiện cập nhật trong background để tránh UI bị lag
    Future.microtask(() async {
      // Update food entry
      foodProvider.updateFoodEntry(updatedEntry);
      
      // Synchronize nutrition data
      if (updatedEntry.items.isNotEmpty) {
        for (var item in updatedEntry.items) {
          foodProvider.synchronizeNutritionData(
            item.id, 
            item.servingSize
          );
        }
        
        foodProvider.synchronizeNutrition(
          entryId: updatedEntry.id,
          servingSize: updatedEntry.items.first.servingSize,
          notifyChange: true,
        );
      }
      
      // Refresh nutrition data
      foodProvider.clearNutritionCache();
      await foodProvider.refreshNutrition();
      
      // Update selected date
      String dateStr = updatedEntry.dateTime.toIso8601String().split('T')[0];
      foodProvider.setSelectedDate(dateStr);
      
      // Reload data
      await _loadDataForSelectedDate();
    });
  }
  
  void _handleFoodNutritionDetailResult(dynamic result) {
    if (result != null && result is Map<String, dynamic>) {
      // Nếu có kết quả trả về, cập nhật UI và dữ liệu
      if (result.containsKey('foodEntriesUpdated') && result['foodEntriesUpdated'] == true) {
        // Cập nhật đồng bộ dữ liệu
        Future.microtask(() async {
          final foodProvider = Provider.of<FoodProvider>(context, listen: false);
          
          // Buộc làm mới dữ liệu để cập nhật loại bữa ăn mới
          await foodProvider.loadData();
          await foodProvider.refreshNutrition();
          
          // Cập nhật date nếu cần
          if (result.containsKey('selectedDate')) {
            setState(() {
              _selectedDate = result['selectedDate'];
              // Update _selectedDay from _selectedDate
              final selectedDateTime = DateTime.parse(_selectedDate);
              _selectedDay = selectedDateTime.day;
            });
          }
          
          // Cập nhật tất cả dữ liệu
          _loadDataForSelectedDate();
        });
      }
    }
  }

  // Cập nhật dữ liệu món ăn khi ngày thay đổi
  Future<void> _updateFoodDataForDate(String selectedDate) async {
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Cập nhật ngày đã chọn trong FoodProvider
      print('HomeScreen: Cập nhật ngày được chọn trong FoodProvider: $selectedDate');
      foodProvider.setSelectedDate(selectedDate);
      
      // Xóa cache và tải lại dữ liệu
      foodProvider.clearNutritionCache();
      await foodProvider.loadData();
      await foodProvider.refreshNutrition();
      
      print('HomeScreen: Đã tải lại dữ liệu món ăn cho ngày: $selectedDate');
      
      // In log để xác minh các món ăn cho ngày đã chọn
      final entryCount = foodProvider.todayEntries.length;
      print('HomeScreen: Số lượng món ăn cho ngày $selectedDate: $entryCount');
      for (var entry in foodProvider.todayEntries) {
        final entryDate = entry.dateTime.toIso8601String().split('T')[0];
        print('HomeScreen: - ${entry.description} (${entry.mealType}) - ngày: $entryDate');
      }
      
    } catch (e) {
      print('Lỗi khi cập nhật dữ liệu món ăn cho ngày: $e');
    }
  }

  // Navigate to MealRecordingScreen with date synchronization
  void _navigateToMealRecording() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealRecordingScreen(initialDate: _selectedDate),
      ),
    );
    
    // Handle result from MealRecordingScreen
    if (result != null && result is Map<String, dynamic>) {
      if (result.containsKey('selectedDate')) {
        setState(() {
          _selectedDate = result['selectedDate'];
          // Update _selectedDay for compatibility
          final selectedDateTime = DateTime.parse(_selectedDate);
          _selectedDay = selectedDateTime.day;
        });
        
        // Update data
        await _updateFoodDataForDate(_selectedDate);
        await _loadDataForSelectedDate();
      }
    }
  }

  // Phương thức để cập nhật mục tiêu dinh dưỡng từ UserDataProvider
  void _updateNutritionGoals(UserDataProvider userDataProvider) {
    // Lấy mục tiêu calo từ UserDataProvider
    final caloriesGoal = userDataProvider.nutritionGoals['calories']?.toInt() ?? 
                        userDataProvider.tdeeCalories.toInt();
    
    // Cập nhật giá trị trong state
    setState(() {
      _caloriesGoal = caloriesGoal > 0 ? caloriesGoal : 2000; // Sử dụng 2000 làm giá trị mặc định nếu không có giá trị
    });
    
    print('Đã cập nhật mục tiêu calo: $_caloriesGoal');
    
    // Add a debug log to check if values from TDEE calculator are received
    if (userDataProvider.tdeeCalories > 0) {
      print('TDEE values synchronized from calculator: ${userDataProvider.tdeeCalories} calories, ' +
            'Protein: ${userDataProvider.tdeeProtein}g, ' +
            'Carbs: ${userDataProvider.tdeeCarbs}g, ' +
            'Fat: ${userDataProvider.tdeeFat}g');
    } else {
      print('Warning: No TDEE values received from calculator. Using default or fallback values.');
    }
  }
  
  // Phương thức để cập nhật thông tin tiêu thụ nước
  void _updateWaterConsumption(WaterProvider waterProvider) {
    final consumedWater = waterProvider.totalWaterToday;
    final waterGoal = waterProvider.waterGoal;
    final lastWaterTime = waterProvider.lastWaterTime;
    
    setState(() {
      _consumedWater = consumedWater;

      _lastWaterTime = lastWaterTime;
    });
    
    print('Đã cập nhật thông tin nước: $_consumedWater / $_waterGoal ml');
  }

  void _checkFirebaseDataStatus() {
    // Lấy các provider cần thiết
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
    
    try {
      // Kiểm tra trạng thái Firebase trực tiếp
      bool isFirebaseInitialized = false;
      bool isAuthenticated = false;
      User? currentUser;
      String? userId = "Chưa đăng nhập";
      
      try {
        // Kiểm tra Firebase đã khởi tạo chưa
        final app = Firebase.app();
        isFirebaseInitialized = true;
        print('Firebase app name: ${app.name}');
        
        // Kiểm tra trạng thái đăng nhập
        currentUser = FirebaseAuth.instance.currentUser;
        isAuthenticated = currentUser != null;
        userId = currentUser?.uid;
        
        print('Firebase authenticated: $isAuthenticated');
        if (isAuthenticated) {
          print('User ID: $userId');
          print('Email: ${currentUser?.email}');
          print('Display name: ${currentUser?.displayName}');
          print('Email verified: ${currentUser?.emailVerified}');
          print('Authentication providers: ${currentUser?.providerData.map((p) => p.providerId).join(', ')}');
        }
      } catch (e) {
        print('Error checking Firebase: $e');
      }
      
      // Đồng bộ với UserDataProvider
      bool providerFirebaseAvailable = userDataProvider.isFirebaseAvailable();
      bool providerAuthenticated = userDataProvider.isUserAuthenticated();
      String providerUserId = userDataProvider.getCurrentUserId() ?? "Chưa đăng nhập";
      DateTime? lastSync = userDataProvider.lastSyncTime;
      
      // Các thông tin người dùng
      final name = userDataProvider.name;
      final gender = userDataProvider.gender;
      final age = userDataProvider.age;
      final heightCm = userDataProvider.heightCm;
      final weightKg = userDataProvider.weightKg;
      
      // Hiển thị dialog với thông tin
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isFirebaseInitialized ? Icons.cloud_done : Icons.cloud_off,
                color: isFirebaseInitialized ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8),
              Text('Trạng thái Firebase')
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Firebase đã khởi tạo: ${isFirebaseInitialized ? "✅" : "❌"}'),
                Text('Firebase đã đăng nhập: ${isAuthenticated ? "✅" : "❌"}'),
                Text('Firebase user ID: $userId'),
                if (isAuthenticated && currentUser != null) ...[
                  Container(
                    width: double.infinity,
                    child: Text(
                      'Email: ${currentUser.email ?? "Không có email"}',
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    child: Text(
                      'Họ tên: ${currentUser.displayName ?? "Chưa cập nhật họ tên"}',
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                
                Divider(),
                
                Text('Provider Firebase khả dụng: ${providerFirebaseAvailable ? "✅" : "❌"}'),
                Text('Provider đã đăng nhập: ${providerAuthenticated ? "✅" : "❌"}'),
                Text('Provider user ID: $providerUserId'),
                Text('Đồng bộ lần cuối: ${lastSync?.toString() ?? "Chưa đồng bộ"}'),
                
                Divider(),
                
                Text('Thông tin người dùng:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (name.isNotEmpty) Text('Tên: $name'),
                Text('Giới tính: $gender'),
                Text('Tuổi: $age'),
                Text('Chiều cao: $heightCm cm'),
                Text('Cân nặng: $weightKg kg'),
                
                Divider(),
                Text('Thông tin dinh dưỡng:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Mục tiêu calo: ${_caloriesGoal} kcal'),
                Text('Đã tiêu thụ: ${_consumedCalories} kcal'),
                Text('Mục tiêu nước: ${waterProvider.waterGoal} ml'),
                Text('Đã uống: ${waterProvider.totalWaterToday} ml'),
                
                Divider(),
                Text('Thông tin bài tập:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Số bài tập hôm nay: ${exerciseProvider.selectedDateExercises.length}'),
                Text('Tổng calo đốt: ${totalExerciseCalories} kcal'),
                
                Divider(),
                Text('Thông tin món ăn:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Số món ăn hôm nay: ${foodProvider.todayEntries.length}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: () {
                // Tải lại dữ liệu từ Firebase
                userDataProvider.loadFromFirestore().then((_) {
                  // Đồng bộ dữ liệu lên Firebase
                  userDataProvider.sendToApi();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã đồng bộ dữ liệu với Firebase'),
                      backgroundColor: Colors.green,
                    )
                  );
                  Navigator.of(context).pop();
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi đồng bộ: $error'),
                      backgroundColor: Colors.red,
                    )
                  );
                  Navigator.of(context).pop();
                });
              },
              child: Text('Đồng bộ lại'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Hiển thị lỗi nếu có
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi kiểm tra Firebase: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

