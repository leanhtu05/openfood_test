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
import '../widgets/home/nutrition_card.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../screens/food_logging_screen.dart';
import '../widgets/draggable_floating_action_button.dart';
import '../services/onboarding_service.dart';
import 'tdee_info_screen.dart';
import '../screens/food_nutrition_detail_screen.dart';
import '../models/food_entry.dart';
import '../screens/meal_recording_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedDay = 10;
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
  
  final int _consumedCalories = 1240;
  final int _caloriesGoal = 2636;

  // Add this offset variable to the _HomeScreenState class
  Offset _fabPosition = Offset(0, 0);
  bool _isDragging = false;
  bool _showMealSuggestion = true;
  
  // Thêm biến này để kiểm soát việc refresh
  DateTime _lastRefresh = DateTime.now();

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
            behavior: SnackBarBehavior.floating,
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
    try {
      // Lấy tất cả provider
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Đồng bộ ngày
      print('Đang đồng bộ ngày đã chọn: $_selectedDate cho tất cả provider');
      exerciseProvider.setSelectedDate(_selectedDate);
      waterProvider.setSelectedDate(_selectedDate);
      
      // Xóa cache dinh dưỡng
      foodProvider.clearNutritionCache();
      
      // Đặt ngày cho food provider - điều này sẽ tự động gọi fetchDaily...
      foodProvider.setSelectedDate(_selectedDate);
      
      // Tải lại dữ liệu
      await _loadExercisesForSelectedDate();
      await waterProvider.loadData();
      await foodProvider.loadData();
      
      // Làm mới dữ liệu dinh dưỡng
      await foodProvider.refreshNutrition();
      
      // Cập nhật UI
      if (mounted) {
        setState(() {
          // Cập nhật biến để hiển thị trạng thái gợi ý bữa ăn
          _updateMealSuggestionState();
        });
      }
      
      // In ra log để debug
      print('Đã tải xong dữ liệu cho ngày: $_selectedDate');
    } catch (e) {
      print('Lỗi khi tải dữ liệu cho ngày $_selectedDate: $e');
    }
  }

  // Phương thức để cập nhật trạng thái hiển thị gợi ý bữa ăn
  void _updateMealSuggestionState() {
    final now = DateTime.now();
    final selectedDateTime = DateTime.parse(_selectedDate);
    
    // Chỉ hiển thị gợi ý bữa ăn cho ngày hiện tại
    final isSameDay = selectedDateTime.year == now.year && 
                      selectedDateTime.month == now.month && 
                      selectedDateTime.day == now.day;
                      
    _showMealSuggestion = isSameDay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Tránh gọi setState trong lúc build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Kiểm tra xem đã quá 2 giây kể từ lần refresh cuối chưa
      final now = DateTime.now();
      final difference = now.difference(_lastRefresh).inSeconds;
      
      // Nếu đã quá 2 giây, refresh dữ liệu
      if (difference > 2) {
        _lastRefresh = now;
        _loadExercisesForSelectedDate();
        _loadDataForSelectedDate();
        print('HomeScreen (didChangeDependencies): Tự động làm mới dữ liệu sau $difference giây');
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
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
        // Thêm nút Refresh
        IconButton(
          icon: Icon(Icons.refresh, color: AppColors.primary),
          onPressed: () {
            // Hiển thị thông báo
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Đang làm mới dữ liệu...'),
                  ],
                ),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.green,
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
            onTap: () {
              _navigateToFoodLogging();
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
      body: _buildBody(),
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
            setState(() {
              _selectedNavIndex = index;
            });
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
                    onTap: () {
                    Navigator.pop(context);
                    _navigateToFoodLogging();
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
                      ).then((_) => _loadDataForSelectedDate());
                    },
                  ),
                  _buildQuickActionButton(
                    icon: Icons.camera_alt,
                    label: 'Chụp ảnh',
                    color: AppColors.secondary,
                    onTap: () {
                    Navigator.pop(context);
                    _navigateToFoodLogging();
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
                await OnboardingService.resetOnboardingStatus();
                
                if (!context.mounted) return;
                Navigator.of(context).pop();
                
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

  void _navigateToFoodLogging() async {
    // Lưu thời gian hiện tại trước khi chuyển màn hình
    _lastRefresh = DateTime.now();
    
    // Mở màn hình ghi nhận thức ăn và truyền ngày đã chọn
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodLoggingScreen(initialDate: _selectedDate),
      ),
    );
    
    // Sau khi quay lại, xử lý kết quả và làm mới dữ liệu
    if (mounted) {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Xử lý kết quả trả về nếu có
      if (result != null && result is Map<String, dynamic>) {
        if (result.containsKey('selectedDate')) {
          // Lấy ngày từ kết quả trả về
          final selectedDate = result['selectedDate'];
          
          print('_navigateToFoodLogging: Nhận được ngày từ kết quả trả về: $selectedDate');
          
          // Cập nhật UI và FoodProvider
          setState(() {
            _selectedDate = selectedDate;
            // Cập nhật _selectedDay từ _selectedDate
            final selectedDateTime = DateTime.parse(_selectedDate);
            _selectedDay = selectedDateTime.day;
          });
          
          // Cập nhật ngày trong provider
          foodProvider.setSelectedDate(_selectedDate);
          
          // Cập nhật dữ liệu Food Provider cho ngày này
          await _updateFoodDataForDate(_selectedDate);
          
          // Load lại các loại dữ liệu khác cho ngày này
          await _loadDataForSelectedDate();
          
          print('_navigateToFoodLogging: Đã cập nhật UI và dữ liệu cho ngày: $_selectedDate');
        }
      }
      
      // Load lại dữ liệu (trong mọi trường hợp)
      await foodProvider.loadData();
      
      // Load lại các loại dữ liệu khác
      await _loadDataForSelectedDate();
      
      print('Quay lại từ FoodLoggingScreen: Tự động làm mới dữ liệu');
    }
  }

  Widget _buildBody() {
    switch (_selectedNavIndex) {
      case 0:
        // Tab 0
        return Center(child: Text('Tab 0'));
      case 1:
        // Tab Nutrition
        return Center(child: Text('Tính năng dinh dưỡng sẽ sớm có!'));
      case 2:
        // Icon ghi lại hiển thị MealRecordingScreen
        return MealRecordingScreen();
      case 3:

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
                children: [
                  // const UserProfileCircularSummary(),
                  DaySelector.fullDate(
                    selectedDate: _selectedDate,
                    onDateChanged: (newDate) {
                      setState(() {
                        _selectedDate = newDate;
                        // Cập nhật _selectedDay để duy trì tương thích với mã hiện tại
                        final selectedDateTime = DateTime.parse(newDate);
                        _selectedDay = selectedDateTime.day;
                        print('Đã chọn ngày mới: $_selectedDate từ DaySelector.fullDate');
                      });
                      // Cập nhật dữ liệu Food Provider trước
                      _updateFoodDataForDate(_selectedDate);
                      // Sau đó mới load dữ liệu các provider khác
                      _loadDataForSelectedDate();
                    },
                  ),
                  _buildMealTimeSuggestion(),
                  const NutritionCard(),
                  Padding(
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
                          onMealTap: () {
                            _navigateToFoodLogging();
                          },
                          onFoodItemTap: (FoodEntry foodEntry) {
                            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                            foodProvider.clearNutritionCache();
                            foodProvider.refreshNutrition();
                            final updatedFoodEntry = foodProvider.getFoodEntryById(foodEntry.id) ?? foodEntry;
                            foodProvider.clearNutritionCache();
                            ScaffoldMessenger.of(context).clearSnackBars();
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
                                    Text('Đang tải thông tin dinh dưỡng...'),
                                  ],
                                ),
                                duration: Duration(seconds: 1),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FoodNutritionDetailScreen(
                                  foodEntry: updatedFoodEntry,
                                  onSave: (updatedEntry) {
                                    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                                    foodProvider.updateFoodEntry(updatedEntry);
                                    if (updatedEntry.items.isNotEmpty) {
                                      for (var item in updatedEntry.items) {
                                        foodProvider.synchronizeNutritionData(
                                          item.id, 
                                          item.servingSize
                                        );
                                      }
                                    }
                                    if (updatedEntry.items.isNotEmpty) {
                                      foodProvider.synchronizeNutrition(
                                        entryId: updatedEntry.id,
                                        servingSize: updatedEntry.items.first.servingSize,
                                        notifyChange: true,
                                      );
                                    }
                                    foodProvider.clearNutritionCache();
                                    foodProvider.refreshNutrition();
                                    String dateStr = updatedEntry.dateTime.toIso8601String().split('T')[0];
                                    foodProvider.setSelectedDate(dateStr);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Đã cập nhật thông tin dinh dưỡng: ${updatedEntry.description}'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadDataForSelectedDate();
                                  },
                                ),
                              ),
                            ).then((result) {
                              if (result != null && result is Map<String, dynamic>) {
                                if (result.containsKey('selectedDate')) {
                                  setState(() {
                                    _selectedDate = result['selectedDate'];
                                    // Cập nhật _selectedDay từ _selectedDate
                                    final selectedDateTime = DateTime.parse(_selectedDate);
                                    _selectedDay = selectedDateTime.day;
                                  });
                                  
                                  // Cập nhật dữ liệu Food Provider
                                  _updateFoodDataForDate(_selectedDate);
                                  // Load lại dữ liệu
                                  _loadDataForSelectedDate();
                                  
                                  // In log để debug
                                  print('Đã nhận selectedDate từ FoodNutritionDetailScreen: $_selectedDate');
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: WaterSection(),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExerciseSection(
                      exercises: _selectedExercises,
                      onAddExercise: () {
                        Navigator.pushNamed(
                          context,
                          '/exercise_log',
                          arguments: _selectedDate,
                        ).then((_) => _loadExercisesForSelectedDate());
                      },
                      onViewHistory: () {
                        Navigator.pushNamed(
                          context, 
                          '/combined_history',
                          arguments: {'filter': 'exercise'}
                        ).then((_) => _loadExercisesForSelectedDate());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        // Tab 3     
      case 4:
      return Center(child: Text('Tab 4'));
        // Icon hiển thị Home Screen  
      default:
        // Tab mặc định là Home
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
                children: [
                  // const UserProfileCircularSummary(),
                  DaySelector.fullDate(
                    selectedDate: _selectedDate,
                    onDateChanged: (newDate) {
                      setState(() {
                        _selectedDate = newDate;
                        // Cập nhật _selectedDay để duy trì tương thích với mã hiện tại
                        final selectedDateTime = DateTime.parse(newDate);
                        _selectedDay = selectedDateTime.day;
                        print('Đã chọn ngày mới: $_selectedDate từ DaySelector.fullDate');
                      });
                      // Cập nhật dữ liệu Food Provider trước
                      _updateFoodDataForDate(_selectedDate);
                      // Sau đó mới load dữ liệu các provider khác
                      _loadDataForSelectedDate();
                    },
                  ),
                  _buildMealTimeSuggestion(),
                  const NutritionCard(),
                  Padding(
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
                          onMealTap: () {
                            _navigateToFoodLogging();
                          },
                          onFoodItemTap: (FoodEntry foodEntry) {
                            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                            foodProvider.clearNutritionCache();
                            foodProvider.refreshNutrition();
                            final updatedFoodEntry = foodProvider.getFoodEntryById(foodEntry.id) ?? foodEntry;
                            foodProvider.clearNutritionCache();
                            ScaffoldMessenger.of(context).clearSnackBars();
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
                                    Text('Đang tải thông tin dinh dưỡng...'),
                                  ],
                                ),
                                duration: Duration(seconds: 1),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FoodNutritionDetailScreen(
                                  foodEntry: updatedFoodEntry,
                                  onSave: (updatedEntry) {
                                    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                                    foodProvider.updateFoodEntry(updatedEntry);
                                    if (updatedEntry.items.isNotEmpty) {
                                      for (var item in updatedEntry.items) {
                                        foodProvider.synchronizeNutritionData(
                                          item.id, 
                                          item.servingSize
                                        );
                                      }
                                    }
                                    if (updatedEntry.items.isNotEmpty) {
                                      foodProvider.synchronizeNutrition(
                                        entryId: updatedEntry.id,
                                        servingSize: updatedEntry.items.first.servingSize,
                                        notifyChange: true,
                                      );
                                    }
                                    foodProvider.clearNutritionCache();
                                    foodProvider.refreshNutrition();
                                    String dateStr = updatedEntry.dateTime.toIso8601String().split('T')[0];
                                    foodProvider.setSelectedDate(dateStr);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Đã cập nhật thông tin dinh dưỡng: ${updatedEntry.description}'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadDataForSelectedDate();
                                  },
                                ),
                              ),
                            ).then((result) {
                              if (result != null && result is Map<String, dynamic>) {
                                if (result.containsKey('selectedDate')) {
                                  setState(() {
                                    _selectedDate = result['selectedDate'];
                                    // Cập nhật _selectedDay từ _selectedDate
                                    final selectedDateTime = DateTime.parse(_selectedDate);
                                    _selectedDay = selectedDateTime.day;
                                  });
                                  
                                  // Cập nhật dữ liệu Food Provider
                                  _updateFoodDataForDate(_selectedDate);
                                  // Load lại dữ liệu
                                  _loadDataForSelectedDate();
                                  
                                  // In log để debug
                                  print('Đã nhận selectedDate từ FoodNutritionDetailScreen: $_selectedDate');
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: WaterSection(),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExerciseSection(
                      exercises: _selectedExercises,
                      onAddExercise: () {
                        Navigator.pushNamed(
                          context,
                          '/exercise_log',
                          arguments: _selectedDate,
                        ).then((_) => _loadExercisesForSelectedDate());
                      },
                      onViewHistory: () {
                        Navigator.pushNamed(
                          context, 
                          '/combined_history',
                          arguments: {'filter': 'exercise'}
                        ).then((_) => _loadExercisesForSelectedDate());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        // Tab 3 
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
}

