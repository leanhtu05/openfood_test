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
import '../providers/user_data_provider.dart' as udp;
import '../widgets/home/calorie_progress.dart';
import '../widgets/home/exercise_section.dart';
import '../widgets/home/meals_section.dart';
import '../widgets/home/water_section.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../screens/food_logging_screen.dart';
import '../widgets/draggable_floating_action_button.dart';
import '../services/onboarding_service.dart';

import '../screens/food_nutrition_detail_screen.dart';
import '../models/food_entry.dart';
import '../screens/meal_recording_screen.dart';
import '../screens/diet_plan_screen.dart';
import '../providers/user_data_provider.dart';
import 'profile_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sync_reset_screen.dart';
import '../utils/auth_helper.dart';

import '../widgets/home/nutrition_section.dart';
import '../widgets/home/exercise_section.dart';
import '../widgets/home/water_section.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedDay = DateTime.now().day;
  int _selectedNavIndex = 3; // Đặt mặc định là tab 3 (Tập luyện)
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
    
    // Đặt trạng thái onboarding là "đã hoàn thành" để tránh quay lại màn hình onboarding
    OnboardingService.setOnboardingComplete();

    // Xóa các món ăn trùng lặp khi khởi động
    _cleanupDuplicateFoodEntries();
    
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
      final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
      
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
      
      // Tự động tính toán TDEE nếu cần
      userDataProvider.autoCalculateTDEE().then((_) {
        // Cập nhật lại UI sau khi tính toán TDEE
        _updateNutritionGoals(userDataProvider);
        
        // Đồng bộ hóa giá trị mục tiêu calo trên tất cả các màn hình
        _synchronizeCalorieGoals();
      });

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

      // Silent error handling - removed snackbar for better UX
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Thiết lập listener cho UserDataProvider để bắt các thay đổi về TDEE
    final userDataProvider = Provider.of<udp.UserDataProvider>(context);
    
    // Cập nhật ngay lập tức mục tiêu dinh dưỡng khi provider thay đổi
    // Điều này sẽ xảy ra khi người dùng điều chỉnh từ TDEE calculator hoặc các màn hình khác
    _updateNutritionGoals(userDataProvider);
    
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
      }
    });
  }

  // Phương thức để tải lại tất cả dữ liệu cho ngày đã chọn
  // Xóa các món ăn trùng lặp
  Future<void> _cleanupDuplicateFoodEntries() async {
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      await foodProvider.removeDuplicateFoodEntries();
    } catch (e) {
      // Silent error handling
    }
  }
  
  Future<void> _loadDataForSelectedDate() async {
    if (_isLoadingData) return;
    _isLoadingData = true;
    try {
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
      exerciseProvider.setSelectedDate(_selectedDate);
      waterProvider.setSelectedDate(_selectedDate);
      foodProvider.clearNutritionCache();
      foodProvider.setSelectedDate(_selectedDate);
      
      // Xóa các món ăn trùng lặp
      await foodProvider.removeDuplicateFoodEntries();
      
      await Future.wait([
        _loadExercisesForSelectedDate(),
        waterProvider.loadData(),
        foodProvider.loadData(),
      ]);
      await foodProvider.refreshNutrition();
      // Đảm bảo cập nhật lại calo và mục tiêu sau khi load dữ liệu
      _updateConsumedCalories(foodProvider);
      _updateNutritionGoals(userDataProvider);
      _updateWaterConsumption(waterProvider);
      
      // Đồng bộ hóa giá trị mục tiêu calo trên tất cả các màn hình
      await _synchronizeCalorieGoals();
      
      if (mounted) {
        setState(() {
          _updateMealSuggestionState();
        });
      }
    } catch (e) {
    } finally {
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
    }
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
              // First row of quick actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickActionButton(
                    icon: Icons.restaurant,
                    label: 'Bữa ăn',
                    color: AppColors.food,
                    onTap: () async {
                      Navigator.pop(context);

                      // Kiểm tra đăng nhập trước khi vào food logging
                      final success = await AuthHelper.requireLogin(
                        context,
                        onAuthenticated: () async {
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
                        title: 'Ghi lại bữa ăn',
                        message: 'Mời bạn đăng nhập để trải nghiệm tính năng ghi lại bữa ăn và nhận diện thức ăn bằng AI',
                        feature: 'ghi lại bữa ăn',
                      );

                      if (!success) {
                        AuthHelper.showLoginRequiredSnackBar(
                          context,
                          feature: 'ghi lại bữa ăn',
                        );
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
              SizedBox(height: 16),
              // Second row of quick actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickActionButton(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Mua sắm',
                    color: Colors.green.shade600,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/grocery-list');
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.restaurant_menu,
                    label: 'Kế hoạch',
                    color: Colors.orange.shade600,
                    onTap: () async {
                      Navigator.pop(context);

                      // Kiểm tra đăng nhập trước khi vào trang kế hoạch
                      final success = await AuthHelper.requireLogin(
                        context,
                        onAuthenticated: () => Navigator.pushNamed(context, '/diet-plan'),
                        title: 'Xem kế hoạch ăn',
                        message: 'Mời bạn đăng nhập để trải nghiệm tính năng kế hoạch ăn cá nhân hóa',
                        feature: 'kế hoạch ăn',
                      );

                      if (!success) {
                        AuthHelper.showLoginRequiredSnackBar(
                          context,
                          feature: 'kế hoạch ăn',
                        );
                      }
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'AI Chat',
                    color: Colors.purple.shade600,
                    onTap: () {
                      Navigator.pop(context);
                      // Switch to AI Chat tab
                      setState(() {
                        _selectedNavIndex = 0;
                      });
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
                final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
                await userDataProvider.resetData();

                if (!context.mounted) return;
                Navigator.of(context).pop();
                
                // Silent reset - removed snackbar for better UX
                
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
    // Kiểm tra nếu đang tải dữ liệu
    if (_isLoadingData) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    
    switch (_selectedNavIndex) {
      case 0:
        // Tab 0 - AI Chat
        return AIChatScreen();
      case 1:
        // Tab Nutrition - DietPlan
        return DietPlanScreen();
      case 2:
        // Icon ghi lại hiển thị MealRecordingScreen
        return MealRecordingScreen(initialDate: _selectedDate);
      case 3:
        // Tab Tập luyện
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildHomeContent(),
              ),
            );
          },
        );
      case 4:
        // Tab Tài khoản
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
        child: Consumer<UserDataProvider>(
          builder: (context, userDataProvider, _) {
            // Đảm bảo CalorieProgressSection sử dụng mục tiêu calo mới nhất
            final currentCaloriesGoal = userDataProvider.tdeeCalories > 0 
                ? userDataProvider.tdeeCalories 
                : (userDataProvider.dailyCalories > 0 ? userDataProvider.dailyCalories : 2000);
                
            return CalorieProgressSection(
              caloriesGoal: currentCaloriesGoal.toInt(),
            );
          },
        ),
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
              // Kiểm tra đăng nhập trước khi vào food logging
              final success = await AuthHelper.requireLogin(
                context,
                onAuthenticated: () async {
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
                title: 'Ghi lại bữa ăn',
                message: 'Mời bạn đăng nhập để trải nghiệm tính năng ghi lại bữa ăn và nhận diện thức ăn bằng AI',
                feature: 'ghi lại bữa ăn',
              );

              if (!success) {
                AuthHelper.showLoginRequiredSnackBar(
                  context,
                  feature: 'ghi lại bữa ăn',
                );
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
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Prepare data - cố gắng lấy thông tin đầy đủ nhất có thể
      foodProvider.clearNutritionCache();
      
      // Refreshing nutrition synchronously can cause issues - making it async
      Future.microtask(() async {
        try {
          await foodProvider.refreshNutrition();
          
          // Lấy phiên bản cập nhật của food entry
          final updatedFoodEntry = foodProvider.getFoodEntryById(foodEntry.id);
          if (updatedFoodEntry == null) {
          }
          
          final entryToUse = updatedFoodEntry ?? foodEntry;
          
          // Đảm bảo có dữ liệu cơ bản
          
          // Show loading snackbar
          if (context.mounted) {
            // Removed clearSnackBars for better UX
            // Removed loading snackbar for better UX
            
            // Navigate to nutrition detail screen
            _navigateToFoodNutritionDetail(entryToUse);
          }
        } catch (e) {
          // Silent error handling - removed snackbar for better UX
        }
      });
    } catch (e) {
      // Silent error handling - removed snackbar for better UX
    }
  }
  
  // Removed _showLoadingSnackBar method for better UX

  void _navigateToFoodNutritionDetail(FoodEntry entry) {
    try {
      final route = MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: entry,
          onSave: _handleFoodEntrySave,
          heroTag: "food_entry_${entry.id}", // Thêm heroTag để tránh xung đột nếu có
        ),
      );
      
      Navigator.push(context, route).then((result) {
        _handleFoodNutritionDetailResult(result);
      }).catchError((error) {
        // Silent error handling - removed snackbar for better UX
      });
      
    } catch (e) {
      // Silent error handling - removed snackbar for better UX
    }
  }
  
  void _handleFoodEntrySave(FoodEntry updatedEntry) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
    
    // Silent processing - removed snackbar for better UX
    
    Future.microtask(() async {
      // Chỉ cập nhật entry trong provider, không thêm mới
      foodProvider.updateFoodEntry(updatedEntry);
      
      // Xóa cache để đảm bảo dữ liệu được tính toán lại
      foodProvider.clearNutritionCache();
      
      // Làm mới nutrition để cập nhật UI
      await foodProvider.refreshNutrition();
      
      // Đặt ngày được chọn trong provider
      String dateStr = updatedEntry.dateTime.toIso8601String().split('T')[0];
      foodProvider.setSelectedDate(dateStr);
      
      // Tải lại dữ liệu để cập nhật UI
      await _loadDataForSelectedDate();
      
      // Đảm bảo cập nhật lại calo và mục tiêu sau khi cập nhật món ăn
      _updateConsumedCalories(foodProvider);
      _updateNutritionGoals(userDataProvider);
    });
  }
  
  void _handleFoodNutritionDetailResult(dynamic result) {
    
    if (result != null && result is Map<String, dynamic>) {
      // Nếu có kết quả trả về, cập nhật UI và dữ liệu
      if (result.containsKey('foodEntriesUpdated') && result['foodEntriesUpdated'] == true) {
        
        // Cập nhật đồng bộ dữ liệu
        Future.microtask(() async {
          try {
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
            
            // Kiểm tra xem có món ăn được cập nhật không
            if (result.containsKey('updatedEntry')) {
            }
            
            // Cập nhật tất cả dữ liệu
            await _loadDataForSelectedDate();
            
            // Silent success - removed snackbar for better UX
          } catch (e) {
            // Vẫn tải lại dữ liệu để đảm bảo UI cập nhật
            if (context.mounted) {
              _loadDataForSelectedDate();
            }
          }
        });
      } else {
      }
    } else {
    }
  }

  // Cập nhật dữ liệu món ăn khi ngày thay đổi
  Future<void> _updateFoodDataForDate(String selectedDate) async {
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Cập nhật ngày đã chọn trong FoodProvider
      foodProvider.setSelectedDate(selectedDate);
      
      // Xóa cache và tải lại dữ liệu
      foodProvider.clearNutritionCache();
      await foodProvider.loadData();
      await foodProvider.refreshNutrition();

      // In log để xác minh các món ăn cho ngày đã chọn
      final entryCount = foodProvider.todayEntries.length;
      for (var entry in foodProvider.todayEntries) {
        final entryDate = entry.dateTime.toIso8601String().split('T')[0];
      }
      
    } catch (e) {
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
    // Sử dụng phương thức mới để lấy mục tiêu calo nhất quán
    final caloriesGoal = userDataProvider.getConsistentCalorieGoal();
    
    // Cập nhật giá trị trong state
    setState(() {
      _caloriesGoal = caloriesGoal;
    });
    
    // Log để xác định nguồn của mục tiêu calo
    String source = "unknown";
    if (userDataProvider.goal == 'Giảm cân' && userDataProvider.nutritionGoals.containsKey('calories') && userDataProvider.nutritionGoals['calories']! > 0) {
      source = "adjusted_nutrition_goals";
    } else if (userDataProvider.tdeeCalories > 0) {
      source = "tdee";
    } else if (userDataProvider.nutritionGoals.containsKey('calories') && userDataProvider.nutritionGoals['calories']! > 0) {
      source = "nutrition_goals";
    } else if (userDataProvider.dailyCalories > 0) {
      source = "daily_calories";
    } else {
      source = "default_value";
    }

    // Add a debug log to check if values from TDEE calculator are received
    if (userDataProvider.tdeeCalories > 0) {
      // TDEE values are available
    } else {
      // No TDEE values received from calculator
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
    
  }

  void _checkFirebaseDataStatus() {
    // Lấy các provider cần thiết
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
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
        
        // Kiểm tra trạng thái đăng nhập
        currentUser = FirebaseAuth.instance.currentUser;
        isAuthenticated = currentUser != null;
        userId = currentUser?.uid;
        
        if (isAuthenticated) {
        }
      } catch (e) {
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

                  // Silent sync - removed snackbar for better UX
                  Navigator.of(context).pop();
                }).catchError((error) {
                  // Silent error handling - removed snackbar for better UX
                  Navigator.of(context).pop();
                });
              },
              child: Text('Đồng bộ lại'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Silent error handling - removed snackbar for better UX
    }
  }

  // Phương thức để đồng bộ hóa giá trị mục tiêu calo trên tất cả các màn hình
  Future<void> _synchronizeCalorieGoals() async {
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
    
    // Luôn tính toán lại TDEE từ đầu để đảm bảo tính nhất quán
    await userDataProvider.forceRecalculateTDEE();
    
    // Lấy giá trị mục tiêu calo nhất quán
    final consistentCalorieGoal = userDataProvider.getConsistentCalorieGoal();
    
    // Cập nhật giá trị trong state
    setState(() {
      _caloriesGoal = consistentCalorieGoal;
    });
    // Gửi dữ liệu lên API/Firestore nếu có thể
    if (userDataProvider.isFirebaseAvailable() && userDataProvider.syncEnabled) {
      await userDataProvider.sendToApi();
    }
  }
}

