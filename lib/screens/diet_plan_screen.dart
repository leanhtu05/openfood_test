import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../services/meal_plan_api_service.dart';
import '../services/firestore_service.dart';
import '../models/meal_plan.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import 'food_nutrition_detail_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../providers/food_provider.dart';
import '../providers/user_data_provider.dart';

// Extension to make text smaller
extension TextScaling on Text {
  Text scaled() {
    final TextStyle? style = this.style;
    final scaleFactor = 0.85; // Scale all text to 85% of original size
    
    if (style != null) {
      // Scale the existing style's font size
      final double? fontSize = style.fontSize;
      final newFontSize = fontSize != null ? fontSize * scaleFactor : 12.0 * scaleFactor;
      
      return Text(
        data ?? '',
        style: style.copyWith(fontSize: newFontSize),
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        locale: locale,
      );
    } else {
      // If no style was defined, use a default size
      return Text(
        data ?? '',
        style: TextStyle(fontSize: 12.0 * scaleFactor),
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        locale: locale,
      );
    }
  }
}

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({Key? key}) : super(key: key);

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  int _selectedDayIndex = 5; // T.7 selected by default
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  MealPlan? _mealPlan;
  final FirestoreService _firestoreService = FirestoreService();
  
  final List<String> _daysOfWeek = [
    'T.2', 'T.3', 'T.4', 'T.5', 'T.6', 'T.7', 'CN'
  ];
  
  final List<String> _englishDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    
    // Tải dữ liệu người dùng từ Firestore
    _loadUserProfile();
    
    // Tải kế hoạch ăn
    _loadMealPlan();
  }
  
  // Tải dữ liệu người dùng từ Firestore
  Future<void> _loadUserProfile() async {
    try {
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      
      // Tải dữ liệu từ Firestore
      await userDataProvider.loadFromFirestore();
      
      // Đồng bộ với API nếu được bật
      if (userDataProvider.syncEnabled) {
        userDataProvider.sendToApi();
      }
    } catch (e) {
      debugPrint('Lỗi khi tải dữ liệu người dùng: $e');
    }
  }
  
  Future<void> _loadMealPlan() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      Map<String, dynamic> result;
      
      // Lấy dữ liệu từ Firestore
      try {
        result = await _firestoreService.getWeeklyMealPlan();
        print('Đã tải kế hoạch từ Firestore');
        
        // Đồng bộ kế hoạch ăn đã lấy được với API và Firestore
        _syncMealPlanData(result);
      } catch (firestoreError) {
        print('Lỗi Firestore: $firestoreError - Chuyển sang dùng mock data');
        
        // Nếu không thể lấy từ Firestore, thử lấy từ API
        try {
          final isConnected = await MealPlanApiService.checkApiConnection();
          
          if (isConnected) {
            // Get real API data
            result = await MealPlanApiService.generateWeeklyMealPlan(
              caloriesTarget: 2000,
              proteinTarget: 120,
              fatTarget: 65,
              carbsTarget: 250,
              useAI: true,
            );
            
            // Đồng bộ kế hoạch ăn mới với Firestore
            _syncMealPlanData(result);
          } else {
            // Use mock data
            result = await MealPlanApiService.getMockMealPlan();
          }
        } catch (apiError) {
          throw Exception('Không thể lấy dữ liệu từ API: $apiError');
        }
      }
      
      if (mounted) {
        setState(() {
          _mealPlan = MealPlan.fromJson(result);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading meal plan: $e');
      
      // Try to load mock data as fallback
      try {
        final mockResult = await MealPlanApiService.getMockMealPlan();
        if (mounted) {
          setState(() {
            _mealPlan = MealPlan.fromJson(mockResult);
            _isLoading = false;
          });
        }
      } catch (mockError) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Không thể tải kế hoạch thực đơn: $e';
          });
        }
      }
    }
  }
  
  // Đồng bộ dữ liệu kế hoạch ăn với Firestore
  Future<void> _syncMealPlanData(Map<String, dynamic> mealPlanData) async {
    try {
      await _firestoreService.updateMealPlan(mealPlanData);
      print('Đã đồng bộ kế hoạch ăn lên Firestore');
    } catch (e) {
      print('Lỗi khi đồng bộ kế hoạch ăn lên Firestore: $e');
    }
  }

  @override  
  Widget build(BuildContext context) {    
    // Apply a custom text scale factor to make all text smaller
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: 1.0, // Use default text size scaling
      ),
      child: Scaffold(
        body: SafeArea(
          child: _isLoading 
              ? _buildLoadingState()
              : _hasError 
                  ? _buildErrorState() 
                  : _buildContent(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _loadMealPlan,
          backgroundColor: Colors.green,
          child: Icon(Icons.refresh),
          tooltip: 'Tải lại',
        ),
      ),
    );
  }
  
  Widget _buildLoadingState() {
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
  
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(_errorMessage, textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMealPlan,
            child: Text('Thử lại'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    if (_mealPlan == null) {
      return Center(child: Text('Không có dữ liệu kế hoạch thực đơn'));
    }
    
    final selectedDayName = _englishDays[_selectedDayIndex];
    final dayPlan = _mealPlan!.weeklyPlan[selectedDayName];
    
    if (dayPlan == null) {
      return Center(child: Text('Không có dữ liệu cho ngày đã chọn'));
    }
    
    // Get total nutrition values for the day
    final totalCalories = dayPlan.nutritionSummary['calories']?.round() ?? 0;
    final totalProtein = dayPlan.nutritionSummary['protein']?.round() ?? 0;
    final totalFat = dayPlan.nutritionSummary['fat']?.round() ?? 0;
    final totalCarbs = dayPlan.nutritionSummary['carbs']?.round() ?? 0;
    
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDayTabs(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Kế hoạch dinh dưỡng cân bằng chất',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildNutritionSummary(
                  calories: totalCalories,
                  protein: totalProtein,
                  fat: totalFat,
                  carbs: totalCarbs,
                ),
                
                // Build each meal type
                ...dayPlan.meals.entries.map((entry) {
                  final mealType = entry.key;
                  final meals = entry.value;
                  
                  if (meals.isEmpty) return SizedBox.shrink();
                  
                  IconData mealIcon;
                  switch (mealType) {
                    case 'Bữa sáng':
                      mealIcon = Icons.wb_sunny_outlined;
                      break;
                    case 'Bữa trưa':
                      mealIcon = Icons.cloud_outlined;
                      break;
                    case 'Bữa tối':
                      mealIcon = Icons.nights_stay_outlined;
                      break;
                    default:
                      mealIcon = Icons.access_time;
                  }
                  
                  // Use the first meal in the list for this meal type
                  final meal = meals.first;
                  
                  return _buildMealSectionFromMeal(
                    icon: mealIcon,
                    title: mealType,
                    meal: meal,
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayTabs() {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _daysOfWeek.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDayIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDayIndex = index;
              });
            },
            child: Container(
              width: 70,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight.withOpacity(0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  _daysOfWeek[index],
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? AppColors.primary : Colors.black54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNutritionSummary({
    required int calories,
    required int protein,
    required int fat,
    required int carbs,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNutrientItem(
            icon: Icons.local_fire_department,
            color: Colors.red,
            value: calories.toString(),
            unit: 'Calo',
          ),
          _buildNutrientItem(
            icon: Icons.adjust_rounded,
            color: Colors.blue,
            value: '${protein}g',
            unit: 'Protein',
          ),
          _buildNutrientItem(
            icon: Icons.water_drop_outlined,
            color: Colors.orange,
            value: '${fat}g',
            unit: 'Chất béo',
          ),
          _buildNutrientItem(
            icon: Icons.grass,
            color: Colors.green,
            value: '${carbs}g',
            unit: 'Carbs',
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientItem({
    required IconData icon,
    required Color color,
    required String value,
    required String unit,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSectionFromMeal({
    required IconData icon,
    required String title,
    required Meal meal,
  }) {
    // Get nutrition values for the meal
    final calories = meal.nutrition['calories']?.round() ?? 0;
    final protein = meal.nutrition['protein']?.round() ?? 0;
    final fat = meal.nutrition['fat']?.round() ?? 0;
    final carbs = meal.nutrition['carbs']?.round() ?? 0;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with meal type and nutrition values
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 16),
                  _buildMealNutrient(Icons.local_fire_department, calories.toString(), 'kcal', Colors.red),
                  SizedBox(width: 6),
                  _buildMealNutrient(Icons.adjust_rounded, protein.toString(), 'g', Colors.blue),
                  SizedBox(width: 6),
                  _buildMealNutrient(Icons.water_drop_outlined, fat.toString(), 'g', Colors.orange),
                  SizedBox(width: 6),
                  _buildMealNutrient(Icons.grass, carbs.toString(), 'g', Colors.green),
                ],
              ),
            ),
          ),

          // Divider
          Divider(height: 1, thickness: 1, color: AppColors.textLight.withOpacity(0.3)),

          // Meal content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal name
                Row(
                  children: [
                    Icon(Icons.restaurant, size: 16, color: Colors.grey.shade700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meal.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 8),
                
                // Meal description
                Text(
                  meal.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),

                SizedBox(height: 16),

                // Ingredients
                Text(
                  'Nguyên liệu:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                for (var ingredient in meal.ingredients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(ingredient)),
                      ],
                    ),
                  ),

                // Replace and save buttons
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh, size: 16),
                        label: Text(
                          'Thay thế AI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          // Replace this meal with a new suggestion
                          _replaceMeal(title);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add, size: 16),
                        label: Text(
                          'Ghi lại thực đơn',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          // Add this meal to food log
                          _addMealToFoodLog(meal, title);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealNutrient(IconData icon, String value, String unit, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        SizedBox(width: 2),
        Text(
          '$value$unit',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  
  // Handle replacing a meal
  Future<void> _replaceMeal(String mealType) async {
    final snackBar = SnackBar(
      content: Text('Đang thay thế $mealType...'),
      duration: Duration(seconds: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    
    try {
      // Chuyển sang sử dụng Firestore để thay thế bữa ăn
      if (_mealPlan != null) {
        final selectedDay = _englishDays[_selectedDayIndex];
        
        // Tạo một bữa ăn mới (ở đây bạn có thể tạo hoặc lấy từ API)
        // Ví dụ đơn giản: Sử dụng API để tạo một bữa ăn mới
        final mealData = await MealPlanApiService.generateSingleMeal(
          mealType: mealType,
          caloriesTarget: 500, // Mục tiêu calo cho bữa ăn mới
        );
        
        // Thay thế bữa ăn trong Firestore
        final updatedPlan = await _firestoreService.replaceMeal(
          day: selectedDay,
          mealType: mealType,
          newMeal: mealData,
        );
        
        // Cập nhật UI với kế hoạch mới
        setState(() {
          _mealPlan = MealPlan.fromJson(updatedPlan);
        });
        
        // Thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thay thế $mealType thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Lỗi khi thay thế bữa ăn: $e');
      
      // Hiển thị lỗi và tải lại
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể thay thế bữa ăn. Đang tải lại...'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Tải lại kế hoạch
      _loadMealPlan();
    }
  }
  
  // Handle adding the meal to food log
  void _addMealToFoodLog(Meal meal, String mealType) {
    // Create a FoodItem from the meal data
    final foodItem = FoodItem(
      id: Uuid().v4(),
      name: meal.name,
      calories: meal.nutrition['calories']?.toDouble() ?? 0.0,
      protein: meal.nutrition['protein']?.toDouble() ?? 0.0,
      fat: meal.nutrition['fat']?.toDouble() ?? 0.0,
      carbs: meal.nutrition['carbs']?.toDouble() ?? 0.0,
      fiber: meal.nutrition['fiber']?.toDouble(),
      sugar: meal.nutrition['sugar']?.toDouble(),
      sodium: meal.nutrition['sodium']?.toDouble(),
      servingSize: 1.0,
      servingUnit: 'serving',
      additionalNutrients: Map<String, dynamic>.from(meal.nutrition),
    );

    // Create a FoodEntry with the FoodItem
    final foodEntry = FoodEntry(
      id: Uuid().v4(),
      description: meal.name,
      mealType: mealType,
      dateTime: DateTime.now(),
      nutritionInfo: Map<String, dynamic>.from(meal.nutrition),
      items: [foodItem],
    );

    // Navigate to the FoodNutritionDetailScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: foodEntry,
          onSave: (updatedEntry) {
            // Get the FoodProvider and add the entry
            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
            foodProvider.addFoodEntry(updatedEntry);
            
            // Show a success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã thêm "${meal.name}" vào nhật ký thực phẩm'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }
} 