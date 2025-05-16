import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../providers/food_provider.dart';
import '../widgets/home/meal_cards.dart';
import 'package:intl/intl.dart';
import '../widgets/day_selector.dart';
import '../widgets/food_nutrition/food_items_list.dart';
import '../widgets/food_nutrition/nutrition_illustration.dart';
import '../widgets/food_nutrition/total_nutrition_card.dart';
import '../providers/user_data_provider.dart';
import '../utils/food_data_adapter.dart';
import '../widgets/food_nutrition/nutrition_details.dart';
import '../widgets/food_nutrition/header_food_info_card.dart';
import '../widgets/food_nutrition/serving_size_editor.dart';

class FoodNutritionDetailScreen extends StatefulWidget {
  final FoodEntry foodEntry;
  final Function(FoodEntry) onSave;

  const FoodNutritionDetailScreen({
    Key? key,
    required this.foodEntry,
    required this.onSave,
  }) : super(key: key);

  @override
  _FoodNutritionDetailScreenState createState() => _FoodNutritionDetailScreenState();
}

class _FoodNutritionDetailScreenState extends State<FoodNutritionDetailScreen> {
  late FoodEntry _foodEntry;
  late String _mealName;
  String _selectedTime = "17:00";
  double _servingSize = 1.0;
  String _foodDescription = "Bữa ăn với thịt";

  // Mục tiêu dinh dưỡng
  final double caloriesGoal = 2000.0;
  final double proteinGoal = 100.0;
  final double fatGoal = 70.0;
  final double carbsGoal = 250.0;

  // Mục tiêu vi chất
  final double cholesterolGoal = 300.0;
  final double omega3Goal = 1000.0;
  final double fiberGoal = 30.0;
  final double waterGoal = 2000.0;

  final double sugarGoal = 50.0;
  final double saturatedFatGoal = 20.0;
  final double caffeineGoal = 400.0;
  final double alcoholGoal = 100.0;

  final double vitaminDGoal = 15.0;
  final double vitaminB12Goal = 2.4;
  final double vitaminCGoal = 75.0;
  final double vitaminBGoal = 15.0;

  final double ironGoal = 18.0;
  final double calciumGoal = 1000.0;
  final double magnesiumGoal = 400.0;
  final double potassiumGoal = 4700.0;
  
  // Thêm mục tiêu cho các vi chất bổ sung từ API USDA
  final double vitaminAGoal = 900.0; // mcg
  final double vitaminEGoal = 15.0; // mg
  final double vitaminKGoal = 120.0; // mcg
  final double thiaminGoal = 1.2; // mg
  final double riboflavinGoal = 1.3; // mg
  final double niacinGoal = 16.0; // mg
  final double phosphorusGoal = 700.0; // mg
  final double seleniumGoal = 55.0; // mcg
  final double copperGoal = 0.9; // mg
  final double manganeseGoal = 2.3; // mg
  final double transFatGoal = 2.0; // g

  // Thêm biến để quản lý trạng thái mở rộng thông tin dinh dưỡng
  bool _isNutritionExpanded = true;

  // Biến quản lý trạng thái loading
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _foodEntry = widget.foodEntry;
    _mealName = _foodEntry.mealType;

    // Nếu có items thì lấy servingSize của item đầu tiên, nếu không thì mặc định là 1.0
    if (_foodEntry.items.isNotEmpty) {
      _servingSize = _foodEntry.items.first.servingSize;
    } else {
      _servingSize = 1.0;
    }

    // Quan trọng: Tách các thao tác cập nhật UI và các hoạt động tương tác với Provider
    // ra khỏi quá trình khởi tạo bằng cách sử dụng microtask và addPostFrameCallback
    
    // Sử dụng WidgetsBinding.addPostFrameCallback để đảm bảo các thao tác được thực hiện
    // sau khi khung hình đầu tiên được xây dựng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Đồng bộ ngày từ provider trước
        _syncDateWithProvider();
        
        // Sau đó cập nhật servingSize mặc định (đã được bọc trong microtask)
        _updateDefaultServingSize();
        
        // Đợi một khoảng thời gian ngắn trước khi đồng bộ dữ liệu dinh dưỡng
        // để tránh các lệnh gọi liên tiếp đến provider
        Future.delayed(Duration(milliseconds: 50), () {
          if (mounted) {
            // Tìm kiếm thông tin dinh dưỡng từ API nếu cần
            if (_foodEntry.nutritionInfo == null || _foodEntry.nutritionInfo!.isEmpty) {
              _fetchNutritionDataFromAPI();
            } else {
              // Hoặc chỉ đồng bộ dữ liệu hiện có nếu đã có thông tin dinh dưỡng
              _synchronizeNutritionData();
            }
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Sử dụng Future.microtask để trì hoãn cập nhật state đến sau khi build hoàn tất
    Future.microtask(() {
      // Lấy FoodEntry từ provider để đảm bảo dữ liệu luôn cập nhật
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final updatedEntry = foodProvider.getFoodEntryById(_foodEntry.id);
      
      if (updatedEntry != null) {
        setState(() {
          _foodEntry = updatedEntry;
          
          // Đồng bộ _servingSize từ item đầu tiên nếu có
          if (_foodEntry.items.isNotEmpty) {
            _servingSize = _foodEntry.items.first.servingSize;
            
            // Đảm bảo nutritionInfo có totalWeight đồng bộ với servingSize
            if (_foodEntry.nutritionInfo != null) {
              final updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
              
              // Đảm bảo totalWeight = servingSize * 100
              updatedNutritionInfo['totalWeight'] = _servingSize * 100;
              updatedNutritionInfo['servingSize'] = _servingSize;
              
              _foodEntry = _foodEntry.copyWith(nutritionInfo: updatedNutritionInfo);
              
              // Cập nhật lại FoodProvider
              Future.microtask(() {
                foodProvider.updateFoodEntry(_foodEntry);
              });
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lấy dữ liệu user từ provider
    final userDataProvider = Provider.of<UserDataProvider>(context);
    
    // Mục tiêu dinh dưỡng từ userDataProvider
    final caloriesGoal = userDataProvider.nutritionGoals['calories'] ?? 2000.0;
    final proteinGoal = userDataProvider.nutritionGoals['protein'] ?? 50.0;
    final fatGoal = userDataProvider.nutritionGoals['fat'] ?? 70.0;
    final carbsGoal = userDataProvider.nutritionGoals['carbs'] ?? 310.0;
    
    // Các mục tiêu dinh dưỡng chi tiết
    final cholesterolGoal = userDataProvider.nutritionGoals['cholesterol'] ?? 300.0;
    final fiberGoal = userDataProvider.nutritionGoals['fiber'] ?? 25.0;
    final sugarGoal = userDataProvider.nutritionGoals['sugar'] ?? 50.0;
    final waterGoal = userDataProvider.nutritionGoals['water'] ?? 2000.0; // ml
    final omega3Goal = userDataProvider.nutritionGoals['omega3'] ?? 1.6; // g
    final saturatedFatGoal = userDataProvider.nutritionGoals['saturatedFat'] ?? 20.0; // g
    final vitaminDGoal = userDataProvider.nutritionGoals['vitaminD'] ?? 15.0; // mcg
    final vitaminB12Goal = userDataProvider.nutritionGoals['vitaminB12'] ?? 2.4; // mcg
    final caffeineGoal = userDataProvider.nutritionGoals['caffeine'] ?? 400.0; // mg
    final alcoholGoal = userDataProvider.nutritionGoals['alcohol'] ?? 14.0; // g
    
    // Tính toán các giá trị dinh dưỡng dựa trên nutritionInfo nếu có
    // Ưu tiên sử dụng dữ liệu từ nutritionInfo trước
    Map<String, double> nutritionValues = {};
    
    // Kiểm tra nếu có nutritionInfo
    if (_foodEntry.nutritionInfo != null) {
      // Lấy giá trị từ nutritionInfo với giá trị mặc định từ các items
      nutritionValues['calories'] = 
          _foodEntry.nutritionInfo!['calories'] is num ? 
          (_foodEntry.nutritionInfo!['calories'] as num).toDouble() : 
          _foodEntry.totalCalories;
          
      nutritionValues['protein'] = 
          _foodEntry.nutritionInfo!['protein'] is num ? 
          (_foodEntry.nutritionInfo!['protein'] as num).toDouble() : 
          _foodEntry.totalProtein;
          
      nutritionValues['fat'] = 
          _foodEntry.nutritionInfo!['fat'] is num ? 
          (_foodEntry.nutritionInfo!['fat'] as num).toDouble() : 
          _foodEntry.totalFat;
          
      nutritionValues['carbs'] = 
          _foodEntry.nutritionInfo!['carbs'] is num ? 
          (_foodEntry.nutritionInfo!['carbs'] as num).toDouble() : 
          _foodEntry.totalCarbs;
    } else {
      // Sử dụng giá trị từ items
      nutritionValues['calories'] = _foodEntry.totalCalories;
      nutritionValues['protein'] = _foodEntry.totalProtein;
      nutritionValues['fat'] = _foodEntry.totalFat;
      nutritionValues['carbs'] = _foodEntry.totalCarbs;
    }
    
    // Tính phần trăm so với mục tiêu
    final caloriesPercent = nutritionValues['calories']! / caloriesGoal * 100;
    final proteinPercent = nutritionValues['protein']! / proteinGoal * 100;
    final fatPercent = nutritionValues['fat']! / fatGoal * 100;
    final carbsPercent = nutritionValues['carbs']! / carbsGoal * 100;
    
    return WillPopScope(
      onWillPop: () async {
        // Đảm bảo dữ liệu được lưu trước khi thoát
        _saveAndSyncDataBeforeExit();
        return true;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(56.0), // Chiều cao chuẩn AppBar
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.grey.shade200,
            // Thêm border mỏng ở dưới AppBar
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1.0),
              child: Container(
                height: 1.0,
                color: Colors.grey.shade200,
              ),
            ),
            // Padding 16px hai bên
            leadingWidth: 56,
            titleSpacing: 0,
            leading: Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back, color: Color(0xFF212121), size: 24),
                onPressed: () {
                  // Đảm bảo dữ liệu được lưu trước khi thoát
                  _saveAndSyncDataBeforeExit();
                  Navigator.of(context).pop();
                },
              ),
            ),
            title: Padding(
              padding: EdgeInsets.only(left: 0), // Không cần padding trái vì đã có leadingWidth
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.nightlight_round, color: Color(0xFF212121), size: 20),
                  SizedBox(width: 4),
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        // Show meal type selection dialog
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return Container(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildMealTypeOption('Bữa sáng'),
                                  _buildMealTypeOption('Bữa trưa'),
                                  _buildMealTypeOption('Bữa tối'),
                                  _buildMealTypeOption('Bữa phụ'),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 150),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _mealName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF212121), 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: Color(0xFF212121), size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Nút đồng bộ dữ liệu
              IconButton(
                icon: Icon(Icons.sync),
                onPressed: _synchronizeAllData,
                tooltip: 'Đồng bộ dữ liệu dinh dưỡng',
              ),
              // Nút menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editFoodDescription();
                      break;
                    case 'delete':
                      _deleteFood();
                      break;
                    case 'add':
                      _addMoreFood();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Sửa tên'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Thêm thực phẩm'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Xóa'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Main content area - takes available space minus bottom sheet
            Expanded(
              child: CustomScrollView(
                physics: ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Loading indicator
                        if (_isLoading)
                          Container(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text(
                                    'Đang tải dữ liệu dinh dưỡng...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Data source notification
                        if (!_isLoading && _foodEntry.nutritionInfo != null && 
                            _foodEntry.nutritionInfo!.containsKey('dataSource'))
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dữ liệu dinh dưỡng được cập nhật từ cơ sở dữ liệu chính thức',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Food information header
                        HeaderFoodInfoCard(
                          foodEntry: _foodEntry,
                          servingSize: _servingSize,
                          onEditTime: () {
                            print('onEditTime callback được gọi trong parent');
                            setState(() {
                              // Force rebuild UI của parent widget
                              // Lấy dữ liệu mới từ provider để đảm bảo đồng bộ
                              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                              _foodEntry = foodProvider.getFoodEntryById(_foodEntry.id) ?? _foodEntry;
                              print('Parent đã cập nhật FoodEntry với ngày: ${_foodEntry.dateTime}');
                            });
                          },
                          caloriesGoal: caloriesGoal,
                          proteinGoal: proteinGoal,
                          fatGoal: fatGoal,
                          carbsGoal: carbsGoal,
                          onEditFood: _editFoodDetails,
                          onServingSizeChanged: _updateServingSize,
                          onAddMore: _addMoreFood,
                          onDelete: _deleteFood,
                          onEdit: _editFoodDetails,
                          onReplace: _replaceFood,
                          onWeightChanged: _onWeightChanged,
                        ),
                        
                        SizedBox(height: 6),
                        
                        // Barcode information (if available)
                        if (_foodEntry.barcode != null && _foodEntry.barcode!.isNotEmpty)
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.qr_code, size: 16, color: Colors.blue.shade700),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Dữ liệu từ mã vạch: ${_foodEntry.barcode}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_foodEntry.nutritionInfo != null && 
                                    _foodEntry.nutritionInfo!.containsKey('dataSource') && 
                                    _foodEntry.nutritionInfo!['dataSource'] == 'Open Food Facts')
                                  Padding(
                                    padding: EdgeInsets.only(top: 4, left: 24),
                                    child: Text(
                                      'Nguồn dữ liệu: Open Food Facts',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Nutrition illustration as a separate sliver
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        // Thêm hiệu ứng gradient nhẹ cho nền
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.grey.shade50,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        // Thêm viền và shadow nhẹ
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: NutritionIllustration(
                        key: ValueKey('nutrition_illustration_${_foodEntry.id}_${_servingSize}_${_foodEntry.items.length}_${DateTime.now().millisecondsSinceEpoch}'), // Update key for better rebuild
                        totalCalories: nutritionValues['calories'] ?? _foodEntry.totalCalories,
                        totalProtein: nutritionValues['protein'] ?? _foodEntry.totalProtein,
                        totalFat: nutritionValues['fat'] ?? _foodEntry.totalFat,
                        totalCarbs: nutritionValues['carbs'] ?? _foodEntry.totalCarbs,
                        caloriesGoal: caloriesGoal,
                        proteinGoal: proteinGoal,
                        fatGoal: fatGoal,
                        carbsGoal: carbsGoal,
                        nutritionInfo: _foodEntry.nutritionInfo ?? {},
                        cholesterolGoal: cholesterolGoal,
                        omega3Goal: omega3Goal,
                        fiberGoal: fiberGoal,
                        waterGoal: waterGoal,
                        sugarGoal: sugarGoal,
                        saturatedFatGoal: saturatedFatGoal,
                        caffeineGoal: caffeineGoal,
                        alcoholGoal: alcoholGoal,
                        vitaminDGoal: vitaminDGoal,
                        vitaminB12Goal: vitaminB12Goal,
                        vitaminCGoal: vitaminCGoal,
                        vitaminBGoal: vitaminBGoal,
                        ironGoal: ironGoal,
                        calciumGoal: calciumGoal,
                        magnesiumGoal: magnesiumGoal,
                        potassiumGoal: potassiumGoal,
                        // Thêm các vi chất bổ sung từ API USDA
                        vitaminAGoal: vitaminAGoal,
                        vitaminEGoal: vitaminEGoal,
                        vitaminKGoal: vitaminKGoal,
                        thiaminGoal: thiaminGoal,
                        riboflavinGoal: riboflavinGoal,
                        niacinGoal: niacinGoal,
                        phosphorusGoal: phosphorusGoal,
                        seleniumGoal: seleniumGoal,
                        copperGoal: copperGoal,
                        manganeseGoal: manganeseGoal,
                        transFatGoal: transFatGoal,
                        // Thêm tham số để sử dụng layout nhỏ gọn hơn
                        useRadialGradient: true, // Thêm hiệu ứng gradient cho vòng tròn dinh dưỡng
                        backgroundColor: Colors.grey.shade50, // Màu nền nhạt cho vòng tròn
                        showDetailedLabels: true, // Hiển thị nhãn chi tiết
                        showMacroMainSummary: true, // Hiển thị tóm tắt macros
                      ),
                    ),
                  ),
                  
                  // Space for bottom sheet
                  SliverToBoxAdapter(
                    child: SizedBox(height: 16),
                  ),
                ],
              ),
            ),
            
            // Bottom nutrition summary and save button
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side with nutrition summary - sử dụng Expanded và layout đơn giản
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Total weight - đơn giản, không thêm container
                          Row(
                            children: [
                              Icon(Icons.menu, size: 14, color: Colors.grey.shade800),
                              SizedBox(width: 4),
                              Text(
                                "Tổng Cộng: ${_foodEntry.totalWeight}g",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 4),
                          
                          // Row 2: Nutrition values - giảm khoảng cách và kích thước
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildSimpleNutrientIndicator("${nutritionValues['calories']?.toInt() ?? 0}kcal", Colors.red),
                                SizedBox(width: 8),
                                _buildSimpleNutrientIndicator("${nutritionValues['protein']?.toInt() ?? 0}g", Colors.blue),
                                SizedBox(width: 8),
                                _buildSimpleNutrientIndicator("${nutritionValues['fat']?.toInt() ?? 0}g", Colors.amber),
                                SizedBox(width: 8),
                                _buildSimpleNutrientIndicator("${nutritionValues['carbs']?.toInt() ?? 0}g", Colors.green),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 8),
                    
                    // Right side with compact save button
                    ElevatedButton(
                      onPressed: _handleSaveAndExit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4CD964),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size(0, 0), // Giảm kích thước tối thiểu
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 12),
                          SizedBox(width: 2),
                          Text(
                            'Đồng ý',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMealTypeOption(String mealType) {
    return ListTile(
      title: Text(mealType),
      onTap: () {
        setState(() {
          _mealName = mealType;
          
          // Create a new FoodEntry with the updated meal type but preserve the original date
          _foodEntry = FoodEntry(
            id: _foodEntry.id,
            description: _foodEntry.description,
            imagePath: _foodEntry.imagePath,
            audioPath: _foodEntry.audioPath,
            dateTime: _foodEntry.dateTime,  // Giữ nguyên ngày đã chọn
            isFavorite: _foodEntry.isFavorite,
            barcode: _foodEntry.barcode,
            calories: _foodEntry.calories,
            nutritionInfo: _foodEntry.nutritionInfo,
            mealType: mealType,  // Cập nhật mealType
            items: _foodEntry.items,
          );
          
          // In thông tin để debug
          print('Đã cập nhật bữa ăn: ${_foodEntry.mealType} vào ngày ${_foodEntry.dateTime}');
        });
        Navigator.pop(context);
      },
      trailing: _mealName == mealType ? Icon(Icons.check, color: Colors.green) : null,
    );
  }
  
  void _showTimePicker() async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _foodEntry.dateTime.hour,
        minute: _foodEntry.dateTime.minute,
      ),
    );
    
    if (selectedTime != null) {
      setState(() {
        _foodEntry = FoodEntry(
          id: _foodEntry.id,
          description: _foodEntry.description,
          imagePath: _foodEntry.imagePath,
          audioPath: _foodEntry.audioPath,
          dateTime: DateTime(
            _foodEntry.dateTime.year,
            _foodEntry.dateTime.month,
            _foodEntry.dateTime.day,
            selectedTime.hour,
            selectedTime.minute,
          ),
          isFavorite: _foodEntry.isFavorite,
          barcode: _foodEntry.barcode,
          calories: _foodEntry.calories,
          nutritionInfo: _foodEntry.nutritionInfo,
          mealType: _foodEntry.mealType,
          items: _foodEntry.items,
        );
      });
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xoá món ăn'),
          content: Text('Bạn có chắc chắn muốn xoá món ăn này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Huỷ'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Quay lại màn hình trước
              },
              child: Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Hiển thị DatePicker để chọn ngày
  void _showDatePicker() async {
    // Lấy ngày hiện tại của entry để làm initialDate
    final initialDate = _foodEntry.dateTime;
    
    // Đảm bảo lastDate đủ xa trong tương lai
    final currentYear = DateTime.now().year;
    final lastDate = DateTime(currentYear + 1, 12, 31);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      // Hiển thị indicator đang cập nhật
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
              SizedBox(width: 16),
              Text('Đang cập nhật ngày...'),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
      
      // In log để debug - trước khi cập nhật
      final oldDateStr = "${_foodEntry.dateTime.year}-${_foodEntry.dateTime.month.toString().padLeft(2, '0')}-${_foodEntry.dateTime.day.toString().padLeft(2, '0')}";
      print('_showDatePicker: Ngày trước khi cập nhật: $oldDateStr');
      
      // Tạo DateTime mới giữ nguyên giờ, phút, giây nhưng thay đổi ngày, tháng, năm
      final updatedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _foodEntry.dateTime.hour,
        _foodEntry.dateTime.minute,
        _foodEntry.dateTime.second,
      );
      
      // Lấy FoodProvider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // QUAN TRỌNG: Cập nhật selectedDate trong provider TRƯỚC khi cập nhật entry
      final selectedDate = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      
      // In log để debug - ngày mới được chọn
      print('_showDatePicker: Ngày mới được chọn: $selectedDate');
      
      // Đặt ngày đã chọn trong provider
      foodProvider.setSelectedDate(selectedDate);
      print('_showDatePicker: Đã cập nhật selectedDate trong provider thành $selectedDate');
      
      // Cập nhật FoodEntry với ngày mới
      setState(() {
        _foodEntry = FoodEntry(
          id: _foodEntry.id,
          description: _foodEntry.description,
          imagePath: _foodEntry.imagePath,
          audioPath: _foodEntry.audioPath,
          dateTime: updatedDateTime,
          isFavorite: _foodEntry.isFavorite,
          barcode: _foodEntry.barcode,
          calories: _foodEntry.calories,
          nutritionInfo: _foodEntry.nutritionInfo,
          mealType: _foodEntry.mealType,
          items: _foodEntry.items,
        );
      });
      
      // In log để debug - sau khi cập nhật FoodEntry
      print('_showDatePicker: Đã cập nhật FoodEntry.dateTime thành ${updatedDateTime.toString()}');
      
      // Cập nhật provider để đồng bộ dữ liệu - sử dụng microtask để đảm bảo không ảnh hưởng UI
      Future.microtask(() {
        // Cập nhật entry trong provider
        foodProvider.updateFoodEntry(_foodEntry);
        print('_showDatePicker: Đã cập nhật FoodEntry trong provider');
        
        // Xóa cache để đảm bảo dữ liệu được tính toán lại
        foodProvider.clearNutritionCache();
        
        // Cập nhật lại dữ liệu dinh dưỡng
        foodProvider.refreshNutrition();
        
        // In log để debug
        final dateFormatter = DateFormat('dd/MM/yyyy');
        print('FoodNutritionDetailScreen: Đã cập nhật ngày: ${dateFormatter.format(_foodEntry.dateTime)}');
        print('FoodNutritionDetailScreen: Đã cập nhật selectedDate trong provider: $selectedDate');
        
        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật ngày thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      });
    }
  }

  void _showNutritionDetails() {
    // Lấy giá trị dinh dưỡng đã được tính toán chính xác
    final nutritionValues = _foodEntry.calculateNutritionFromAPI();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Chi tiết dinh dưỡng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vĩ lượng (Macronutrients)
                _buildSectionHeader('Vĩ lượng'),
                _buildDetailItem('Calo', '${nutritionValues['calories']?.toInt() ?? 0} kcal', Colors.orange),
                _buildDetailItem('Protein', '${nutritionValues['protein']?.toInt() ?? 0}g', Colors.blue),
                _buildDetailItem('Chất béo', '${nutritionValues['fat']?.toInt() ?? 0}g', Colors.orange.shade700),
                _buildDetailItem('Carbs', '${nutritionValues['carbs']?.toInt() ?? 0}g', Colors.green),
                _buildDetailItem('Đường', '${nutritionValues['sugar']?.toInt() ?? 0}g', Colors.pink),
                _buildDetailItem('Chất xơ', '${nutritionValues['fiber']?.toInt() ?? 0}g', Colors.brown),
                _buildDetailItem('Cholesterol', '${_foodEntry.nutritionInfo?["cholesterol"] ?? 0}mg', Colors.orange.shade700),
                
                SizedBox(height: 16),
                
                // Vitamin
                _buildSectionHeader('Vitamin'),
                _buildDetailItem('Vitamin A', '${_formatValue(_foodEntry.nutritionInfo?["vitaminA"])}mcg', Colors.amber),
                _buildDetailItem('Vitamin D', '${_formatValue(_foodEntry.nutritionInfo?["vitaminD"])}mcg', Colors.amber),
                _buildDetailItem('Vitamin E', '${_formatValue(_foodEntry.nutritionInfo?["vitaminE"])}mg', Colors.green.shade300),
                _buildDetailItem('Vitamin K', '${_formatValue(_foodEntry.nutritionInfo?["vitaminK"])}mcg', Colors.green.shade700),
                _buildDetailItem('Vitamin C', '${_formatValue(_foodEntry.nutritionInfo?["vitaminC"])}mg', Colors.orange),
                _buildDetailItem('Vitamin B12', '${_formatValue(_foodEntry.nutritionInfo?["vitaminB12"])}mcg', Colors.purple),
                _buildDetailItem('Folate (B9)', '${_formatValue(_foodEntry.nutritionInfo?["vitaminB9"])}mcg', Colors.green),
                _buildDetailItem('Thiamin (B1)', '${_formatValue(_foodEntry.nutritionInfo?["thiamin"])}mg', Colors.amber.shade600),
                _buildDetailItem('Riboflavin (B2)', '${_formatValue(_foodEntry.nutritionInfo?["riboflavin"])}mg', Colors.amber.shade700),
                _buildDetailItem('Niacin (B3)', '${_formatValue(_foodEntry.nutritionInfo?["niacin"])}mg', Colors.amber.shade800),
                
                SizedBox(height: 16),
                
                // Khoáng chất
                _buildSectionHeader('Khoáng chất'),
                _buildDetailItem('Sắt', '${_formatValue(_foodEntry.nutritionInfo?["iron"])}mg', Colors.red),
                _buildDetailItem('Canxi', '${_formatValue(_foodEntry.nutritionInfo?["calcium"])}mg', Colors.grey),
                _buildDetailItem('Magie', '${_formatValue(_foodEntry.nutritionInfo?["magnesium"])}mg', Colors.grey.shade600),
                _buildDetailItem('Kẽm', '${_formatValue(_foodEntry.nutritionInfo?["zinc"])}mg', Colors.blue.shade400),
                _buildDetailItem('Kali', '${_formatValue(_foodEntry.nutritionInfo?["potassium"])}mg', Colors.purple.shade200),
                _buildDetailItem('Phốt pho', '${_formatValue(_foodEntry.nutritionInfo?["phosphorus"])}mg', Colors.grey.shade500),
                _buildDetailItem('Selen', '${_formatValue(_foodEntry.nutritionInfo?["selenium"])}mcg', Colors.orange.shade300),
                _buildDetailItem('Đồng', '${_formatValue(_foodEntry.nutritionInfo?["copper"])}mg', Colors.brown.shade300),
                _buildDetailItem('Mangan', '${_formatValue(_foodEntry.nutritionInfo?["manganese"])}mg', Colors.pink.shade300),
                
                SizedBox(height: 16),
                
                // Các chất dinh dưỡng khác
                _buildSectionHeader('Khác'),
                _buildDetailItem('Chất béo bão hòa', '${_formatValue(_foodEntry.nutritionInfo?["saturatedFat"])}g', Colors.grey.shade700),
                _buildDetailItem('Chất béo trans', '${_formatValue(_foodEntry.nutritionInfo?["transFat"])}g', Colors.red.shade300),
                _buildDetailItem('Omega-3', '${_formatValue(_foodEntry.nutritionInfo?["omega3"])}mg', Colors.cyan),
                _buildDetailItem('Caffeine', '${_formatValue(_foodEntry.nutritionInfo?["caffeine"])}mg', Colors.brown),
                _buildDetailItem('Rượu', '${_formatValue(_foodEntry.nutritionInfo?["alcohol"])}g', Colors.amber),
                _buildDetailItem('Nước', '${_formatValue(_foodEntry.nutritionInfo?["water"])}ml', Colors.blue),
                _buildDetailItem('Natri', '${_formatValue(_foodEntry.nutritionInfo?["sodium"])}mg', Colors.grey.shade400),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng'),
            ),
          ],
        );
      },
    );
  }
  
  // Hàm trợ giúp để định dạng giá trị dinh dưỡng
  String _formatValue(dynamic value) {
    if (value == null) return '0';
    if (value is num) {
      if (value < 10) {
        return value.toStringAsFixed(1);
      } else {
        return value.toInt().toString();
      }
    }
    return '0';
  }
  
  // Tạo tiêu đề phần
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
  
  Widget _buildDetailItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  String getMealDisplayName(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Bữa sáng';
      case 'lunch':
        return 'Bữa trưa';
      case 'dinner':
        return 'Bữa tối';
      case 'snack':
        return 'Bữa phụ';
      default:
        return mealType;
    }
  }

  // Đồng bộ hóa thông tin dinh dưỡng từ nhiều nguồn
  Future<void> _synchronizeNutritionData() async {
    // Sử dụng biến tạm để tránh gọi setState nhiều lần
    bool wasLoading = _isLoading;
    
    if (!wasLoading) {
      // Chỉ cập nhật state nếu chưa loading
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Nếu có ID, tìm entry từ provider để đảm bảo dữ liệu mới nhất
      final updatedEntry = foodProvider.getFoodEntryById(_foodEntry.id);
      
      FoodEntry tempEntry = _foodEntry;
      double tempServingSize = _servingSize;
      
      if (updatedEntry != null) {
        // Cập nhật entry vào biến tạm
        tempEntry = updatedEntry;
      }
      
      // Đồng bộ khẩu phần
      if (tempEntry.items.isNotEmpty) {
        tempServingSize = tempEntry.items.first.servingSize;
      }
      
      // Đồng bộ dữ liệu với provider - đảm bảo không gọi notifyListeners trong quá trình build
      if (tempEntry.items.isNotEmpty) {
        // Tách phần gọi UI vào microtask để đảm bảo chạy sau khi build hoàn tất
        await foodProvider.synchronizeNutrition(
          entryId: tempEntry.id,
          servingSize: tempServingSize,
          notifyChange: false, // Không thông báo ngay lập tức
        );
        
        // Làm mới dữ liệu
        await foodProvider.refreshNutrition();
        
        // Lấy lại entry đã cập nhật sau khi đồng bộ
        final refreshedEntry = foodProvider.getFoodEntryById(tempEntry.id);
        
        if (refreshedEntry != null) {
          tempEntry = refreshedEntry;
          
          // Đảm bảo tất cả các khóa dinh dưỡng được đồng bộ
          if (tempEntry.nutritionInfo != null) {
            final nutritionInfo = Map<String, dynamic>.from(tempEntry.nutritionInfo!);
            _syncNutrientKeys(nutritionInfo);
            
            // Thêm log để debug
            print("_synchronizeNutritionData: Khóa nutrition sau đồng bộ: ${nutritionInfo.keys.toList()}");
            
            // Cập nhật FoodEntry với nutritionInfo đã đồng bộ khóa
            tempEntry = tempEntry.copyWith(nutritionInfo: nutritionInfo);
          }
        }
      }
      
      // Xóa cache để đảm bảo dữ liệu được tính toán lại
      foodProvider.clearNutritionCache();
      
      // Cập nhật state sau khi đã hoàn tất tất cả các xử lý
      if (mounted) {
        setState(() {
          _foodEntry = tempEntry;
          _servingSize = tempServingSize;
          _isLoading = false;
        });
        
        // Cập nhật provider một cách an toàn sử dụng Future.microtask
        Future.microtask(() {
          if (mounted) {
            // Cập nhật và thông báo thay đổi (updateFoodEntry đã có notifyListeners)
            foodProvider.updateFoodEntry(_foodEntry);
          }
        });
      }
    } catch (e) {
      print('Lỗi khi đồng bộ dữ liệu: $e');
      
      // Cập nhật state để tắt loading nếu có lỗi
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fetch dữ liệu dinh dưỡng từ API
  Future<void> _fetchNutritionDataFromAPI() async {
    // Chỉ gọi API khi không có nutritionInfo hoặc nutritionInfo rỗng
    if (_foodEntry.nutritionInfo != null && _foodEntry.nutritionInfo!.isNotEmpty) {
      // Đã có dữ liệu, chỉ cần đồng bộ lại
      await _synchronizeNutritionData();
      return;
    }
    
    // Hiển thị đang tải
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Sử dụng tên món ăn làm từ khóa tìm kiếm
      String searchTerm = _foodEntry.description;
      
      // Sử dụng FoodDataAdapter để gọi API
      final nutritionInfo = await FoodDataAdapter.fetchNutritionInfo(searchTerm);
      
      if (nutritionInfo != null) {
        // Đảm bảo totalWeight và servingSize được thiết lập đúng
        nutritionInfo['servingSize'] = _servingSize;
        nutritionInfo['totalWeight'] = _servingSize * 100;
        
        // Đồng bộ hóa các khóa dinh dưỡng
        _syncNutrientKeys(nutritionInfo);
        
        print("_fetchNutritionDataFromAPI: Các khóa sau khi fetch: ${nutritionInfo.keys.toList()}");
        
        // Cập nhật foodEntry với dữ liệu mới
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        
        // Cập nhật FoodEntry với dữ liệu từ API
        final updatedEntry = FoodDataAdapter.updateWithNutritionInfo(
          entry: _foodEntry,
          nutritionInfo: nutritionInfo,
          fromAPI: true,
        );
        
        setState(() {
          _foodEntry = updatedEntry;
        });
        
        // Cập nhật entry trong provider
        foodProvider.updateFoodEntry(_foodEntry);
        
        // Đảm bảo đồng bộ hóa dữ liệu giữa các item và entry
        await _synchronizeNutritionData();
        
        // Hiển thị thông báo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật thông tin dinh dưỡng từ API'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Hiển thị thông báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể lấy thông tin dinh dưỡng từ API'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Lỗi khi fetch dữ liệu dinh dưỡng: $e');
      
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lấy dữ liệu dinh dưỡng: $e'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Ẩn loading indicator
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Sync with date from provider if applicable
  void _syncDateWithProvider() {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final selectedDate = foodProvider.selectedDate;
    
    final entryDateOnly = "${_foodEntry.dateTime.year}-${_foodEntry.dateTime.month.toString().padLeft(2, '0')}-${_foodEntry.dateTime.day.toString().padLeft(2, '0')}";
    
    if (selectedDate != entryDateOnly) {
      // Chuyển đổi ngày từ chuỗi sang DateTime
      try {
        final dateParts = selectedDate.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        
        // Tạo DateTime mới với ngày từ provider nhưng giữ nguyên giờ, phút, giây
        final updatedDateTime = DateTime(
          year,
          month,
          day,
          _foodEntry.dateTime.hour,
          _foodEntry.dateTime.minute,
          _foodEntry.dateTime.second,
        );
        
        // Cập nhật _foodEntry với ngày mới
        setState(() {
          _foodEntry = FoodEntry(
            id: _foodEntry.id,
            description: _foodEntry.description,
            imagePath: _foodEntry.imagePath,
            audioPath: _foodEntry.audioPath,
            dateTime: updatedDateTime,
            isFavorite: _foodEntry.isFavorite,
            barcode: _foodEntry.barcode,
            calories: _foodEntry.calories,
            nutritionInfo: _foodEntry.nutritionInfo,
            mealType: _foodEntry.mealType,
            items: _foodEntry.items,
          );
        });
        
        print('FoodNutritionDetailScreen: Đã cập nhật ngày từ FoodProvider: $selectedDate');
      } catch (e) {
        print('Lỗi khi cập nhật ngày từ FoodProvider: $e');
      }
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chia sẻ bữa ăn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(Icons.facebook, 'Facebook', Colors.blue),
                _buildShareOption(Icons.chat, 'Message', Colors.green),
                _buildShareOption(Icons.copy, 'Copy Link', Colors.orange),
                _buildShareOption(Icons.more_horiz, 'More', Colors.purple),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chia sẻ qua $label'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // Helper method to create consistent nutrient badges
  Widget _buildNutrientBadge(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper để tạo chỉ báo dinh dưỡng đơn giản với chấm màu
  Widget _buildSimpleNutrientIndicator(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 2),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // Xử lý sự kiện sửa thông tin thực phẩm
  void _editFoodDetails() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempDescription = _foodEntry.description;
        
        return AlertDialog(
          title: Text('Sửa thông tin món ăn'),
          content: TextField(
            decoration: InputDecoration(
              labelText: 'Tên món ăn',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: tempDescription),
            onChanged: (value) {
              tempDescription = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                // Cập nhật mô tả thực phẩm
                setState(() {
                  _foodEntry = _foodEntry.copyWith(
                    description: tempDescription,
                  );
                });
                Navigator.pop(context);
                
                // Hiển thị thông báo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã cập nhật tên món ăn'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Text('Lưu'),
            ),
          ],
        );
      },
    );
  }
  
  // Sửa thông tin mô tả thực phẩm
  void _editFoodDescription() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempDescription = _foodEntry.description;
        
        return AlertDialog(
          title: Text('Sửa tên món ăn'),
          content: TextField(
            decoration: InputDecoration(
              labelText: 'Tên món ăn',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: tempDescription),
            onChanged: (value) {
              tempDescription = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                // Cập nhật mô tả thực phẩm
                setState(() {
                  _foodEntry = _foodEntry.copyWith(
                    description: tempDescription,
                  );
                });
                Navigator.pop(context);
                
                // Hiển thị thông báo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã cập nhật tên món ăn'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Text('Lưu'),
            ),
          ],
        );
      },
    );
  }
  
  // Cập nhật kích thước khẩu phần
  void _updateServingSize(double newServingSize) {
    if (_servingSize == newServingSize) {
      return; // Tránh cập nhật không cần thiết nếu giá trị không thay đổi
    }
    
    setState(() {
      _servingSize = newServingSize;
      
      // Cập nhật thông tin dinh dưỡng dựa trên khẩu phần mới
      if (_foodEntry.items.isNotEmpty) {
        // Lấy khẩu phần cũ để tính tỷ lệ
        final oldServingSize = _foodEntry.items.first.servingSize;
        var ratio = newServingSize / oldServingSize;
        
        // Cập nhật từng item với servingSize mới
        final updatedItems = _foodEntry.items.map((item) {
          return item.copyWith(
            servingSize: newServingSize,
          );
        }).toList();
        
        // Cập nhật FoodEntry với items mới và thông tin dinh dưỡng mới
        Map<String, dynamic> updatedNutritionInfo = {};
        if (_foodEntry.nutritionInfo != null) {
          updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
          // Cập nhật khẩu phần
          updatedNutritionInfo['servingSize'] = newServingSize;
          
          // Cập nhật tổng khối lượng - đồng bộ với khẩu phần (100g = 1 khẩu phần)
          updatedNutritionInfo['totalWeight'] = newServingSize * 100;
          
          // Tính lại tỷ lệ dựa trên khối lượng mới
          ratio = newServingSize / oldServingSize;
          
          // Cập nhật các giá trị dinh dưỡng theo tỷ lệ
          if (updatedNutritionInfo.containsKey('calories')) {
            updatedNutritionInfo['calories'] = (updatedNutritionInfo['calories'] * ratio).toDouble();
          }
          if (updatedNutritionInfo.containsKey('protein')) {
            updatedNutritionInfo['protein'] = (updatedNutritionInfo['protein'] * ratio).toDouble();
          }
          if (updatedNutritionInfo.containsKey('fat')) {
            updatedNutritionInfo['fat'] = (updatedNutritionInfo['fat'] * ratio).toDouble();
          }
          if (updatedNutritionInfo.containsKey('carbs')) {
            updatedNutritionInfo['carbs'] = (updatedNutritionInfo['carbs'] * ratio).toDouble();
          }
          
          // Cập nhật các vi chất
          final micronutrients = [
            // Dinh dưỡng cơ bản khác
            'fiber', 'sugar', 'sodium', 'cholesterol', 'omega3', 'water',
            
            // Vitamin 
            'vitamin_d', 'vitaminD',
            'vitamin_c', 'vitaminC',
            'vitamin_b12', 'vitaminB12', 
            'vitamin_b9', 'vitaminB9',
            'vitamin_b', 'vitaminB',
            'vitamin_a', 'vitaminA',
            'vitamin_e', 'vitaminE',
            'vitamin_k', 'vitaminK',
            
            // Khoáng chất
            'calcium', 'iron', 'potassium', 'magnesium', 'zinc',
            'phosphorus', 'selenium', 'copper', 'manganese',
            
            // Các chất khác
            'saturated_fat', 'saturatedFat',
            'trans_fat', 'transFat',
            'thiamin', 'riboflavin', 'niacin',
            'caffeine', 'alcohol'
          ];
          
          for (var nutrient in micronutrients) {
            if (updatedNutritionInfo.containsKey(nutrient)) {
              updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
            }
          }
          
          // In log để debug
          print('_updateServingSize: Đã cập nhật các giá trị dinh dưỡng với tỷ lệ $ratio');
          print('_updateServingSize: Khóa nutrition: ${updatedNutritionInfo.keys.toList()}');
          
          // Đảm bảo đồng bộ giữa các khóa snake_case và camelCase
          _syncNutrientKeys(updatedNutritionInfo);
        } else {
          updatedNutritionInfo = {
            'servingSize': newServingSize,
            'totalWeight': newServingSize * 100,
            'calories': _foodEntry.totalCalories * ratio,
            'protein': _foodEntry.totalProtein * ratio,
            'fat': _foodEntry.totalFat * ratio,
            'carbs': _foodEntry.totalCarbs * ratio,
          };
        }
        
        _foodEntry = _foodEntry.copyWith(
          items: updatedItems,
          nutritionInfo: updatedNutritionInfo,
        );
        
        // Cập nhật FoodProvider để đồng bộ dữ liệu trên toàn ứng dụng
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        
        // Đầu tiên cập nhật entry trong provider
        foodProvider.updateFoodEntry(_foodEntry);
        
        // Sau đó đồng bộ lại thông tin dinh dưỡng
        foodProvider.synchronizeNutrition(
          entryId: _foodEntry.id,
          servingSize: newServingSize,
        );
        
        // Xóa cache để đảm bảo dữ liệu được tính toán lại
        foodProvider.refreshNutrition();
      }
      
      // Hiển thị thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật khẩu phần: ${newServingSize.toStringAsFixed(1)} (${(newServingSize * 100).toInt()}g)'),
          duration: Duration(seconds: 1),
        ),
      );
    });
  }
  
  // Thêm thực phẩm mới
  void _addMoreFood() {
    // Vì FoodItemsListScreen chưa tồn tại trong project, tạm thời thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tính năng thêm thực phẩm đang được phát triển'),
        duration: Duration(seconds: 2),
      ),
    );
    
    /* Đoạn code này cần được triển khai khi có màn hình FoodItemsListScreen
    // Mở màn hình chọn thực phẩm
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodItemsListScreen(
          onFoodItemSelected: (FoodItem selectedItem) {
            setState(() {
              // Thêm mục được chọn vào danh sách hiện tại
              _foodEntry = FoodEntry(
                id: _foodEntry.id,
                description: _foodEntry.description,
                imagePath: _foodEntry.imagePath,
                audioPath: _foodEntry.audioPath,
                dateTime: _foodEntry.dateTime,
                isFavorite: _foodEntry.isFavorite,
                barcode: _foodEntry.barcode,
                calories: _foodEntry.calories,
                nutritionInfo: _foodEntry.nutritionInfo,
                mealType: _foodEntry.mealType,
                items: [..._foodEntry.items, selectedItem],
              );
            });
            
            // Tính toán lại giá trị dinh dưỡng
            _synchronizeNutritionData();
          },
        ),
      ),
    );
    */
  }
  
  // Xóa thực phẩm
  void _deleteFood() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa món ăn này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Đóng dialog
                Navigator.pop(context); // Đóng màn hình chi tiết
                
                // Gọi hàm xóa ở lớp cha
                final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                foodProvider.deleteFoodEntry(_foodEntry.id);
                
                // Hiển thị thông báo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa món ăn'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Text('Xóa'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }
  
  // Thay thế thực phẩm
  void _replaceFood() {
    // Vì FoodItemsListScreen chưa tồn tại trong project, tạm thời thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tính năng thay thế thực phẩm đang được phát triển'),
        duration: Duration(seconds: 2),
      ),
    );
    
    /* Đoạn code này cần được triển khai khi có màn hình FoodItemsListScreen
    // Mở màn hình chọn thực phẩm để thay thế
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodItemsListScreen(
          onFoodItemSelected: (FoodItem selectedItem) {
            setState(() {
              // Thay thế mục hiện tại bằng mục mới
              _foodEntry = FoodEntry(
                id: _foodEntry.id,
                description: selectedItem.name,
                imagePath: _foodEntry.imagePath,
                audioPath: _foodEntry.audioPath,
                dateTime: _foodEntry.dateTime,
                isFavorite: _foodEntry.isFavorite,
                barcode: _foodEntry.barcode,
                calories: selectedItem.calories,
                nutritionInfo: {
                  'calories': selectedItem.calories,
                  'protein': selectedItem.protein,
                  'fat': selectedItem.fat,
                  'carbs': selectedItem.carbs,
                  'servingSize': selectedItem.servingSize,
                },
                mealType: _foodEntry.mealType,
                items: [selectedItem],
              );
              
              // Cập nhật kích thước khẩu phần
              _servingSize = selectedItem.servingSize;
            });
            
            // Tính toán lại giá trị dinh dưỡng
            _synchronizeNutritionData();
          },
        ),
      ),
    );
    */
  }
  
  // Xử lý khi thay đổi khối lượng từ HeaderFoodInfoCard
  void _onWeightChanged(double newWeight) {
    // Đảm bảo weight > 0
    if (newWeight <= 0) newWeight = 1.0;
    
    // Tính servingSize mới dựa trên weight (1 servingSize = 100g)
    final newServingSize = newWeight / 100;
    
    // Lấy provider để cập nhật dữ liệu
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    setState(() {
      // Cập nhật servingSize ở state
      _servingSize = newServingSize;
      
      // Tạo bản sao mới của danh sách items
      final updatedItems = _foodEntry.items.map((item) {
        return FoodItem(
          id: item.id,
          name: item.name,
          brand: item.brand,
          calories: item.calories,
          protein: item.protein,
          fat: item.fat,
          carbs: item.carbs,
          servingSize: newServingSize, // Cập nhật servingSize mới
          servingUnit: item.servingUnit,
          fiber: item.fiber,
          sugar: item.sugar,
          sodium: item.sodium,
          imageUrl: item.imageUrl,
          additionalNutrients: item.additionalNutrients != null 
              ? Map<String, dynamic>.from(item.additionalNutrients!) 
              : null,
        );
      }).toList();
      
      // Tạo bản sao mới của nutritionInfo nếu có
      Map<String, dynamic>? updatedNutritionInfo;
      if (_foodEntry.nutritionInfo != null) {
        updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
        
        // Cập nhật totalWeight và servingSize trong nutritionInfo
        updatedNutritionInfo['totalWeight'] = newWeight;
        updatedNutritionInfo['servingSize'] = newServingSize;
        
        // Cập nhật các giá trị dinh dưỡng theo tỷ lệ nếu cần
        if (_foodEntry.items.isNotEmpty) {
          final oldServingSize = _foodEntry.items.first.servingSize;
          if (oldServingSize > 0 && newServingSize != oldServingSize) {
            final ratio = newServingSize / oldServingSize;
            
            // Cập nhật các giá trị dinh dưỡng theo tỷ lệ
            for (var nutrient in ['calories', 'protein', 'fat', 'carbs', 'fiber', 'sugar', 'sodium']) {
              if (updatedNutritionInfo.containsKey(nutrient) && updatedNutritionInfo[nutrient] is num) {
                updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
              }
            }
          }
        }
      }
      
      // Tạo FoodEntry mới với các bản sao mới
      _foodEntry = FoodEntry(
        id: _foodEntry.id,
        description: _foodEntry.description,
        imagePath: _foodEntry.imagePath,
        audioPath: _foodEntry.audioPath,
        dateTime: _foodEntry.dateTime,
        isFavorite: _foodEntry.isFavorite,
        barcode: _foodEntry.barcode,
        calories: _foodEntry.calories,
        nutritionInfo: updatedNutritionInfo,
        mealType: _foodEntry.mealType,
        items: updatedItems,
      );
    });
    
    // Hiển thị thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật khối lượng: ${newWeight.toInt()}g (${newServingSize.toStringAsFixed(1)} khẩu phần)'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Cập nhật entry trong provider
    foodProvider.updateFoodEntry(_foodEntry);
  }

  // Thêm phương thức mới để cập nhật khẩu phần mặc định
  void _updateDefaultServingSize() {
    // Đồng bộ nutritionInfo với servingSize
    if (_foodEntry.nutritionInfo != null) {
      final updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
      
      // Cập nhật servingSize trong nutritionInfo
      updatedNutritionInfo['servingSize'] = _servingSize;
      
      // Cập nhật totalWeight dựa trên servingSize
      updatedNutritionInfo['totalWeight'] = _servingSize * 100;
      
      // Cập nhật FoodEntry với nutritionInfo mới (không gọi setState)
      _foodEntry = _foodEntry.copyWith(nutritionInfo: updatedNutritionInfo);
      
      // Đồng bộ lại với provider sử dụng Future.microtask
      // để đảm bảo không cập nhật UI trong quá trình build
      Future.microtask(() {
        if (mounted) {
          final foodProvider = Provider.of<FoodProvider>(context, listen: false);
          foodProvider.updateFoodEntry(_foodEntry);
        }
      });
    }
  }

  // Đồng bộ tất cả dữ liệu dinh dưỡng
  void _synchronizeAllData() {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    // Hiển thị đang đồng bộ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang đồng bộ dữ liệu...'),
            ],
          ),
        ),
      ),
    );
    
    // Chỉ đồng bộ nếu có items
    if (_foodEntry.items.isNotEmpty) {
      // Đồng bộ cho từng item
      for (var item in _foodEntry.items) {
        // Đồng bộ dữ liệu với khẩu phần hiện tại
        foodProvider.synchronizeNutritionData(item.id, _servingSize);
      }
      
      // Đồng bộ entry hiện tại
      foodProvider.synchronizeNutrition(
        entryId: _foodEntry.id,
        servingSize: _servingSize,
      );
      
      // Xóa cache để đảm bảo dữ liệu được tính toán lại
      foodProvider.refreshNutrition();
    }
    
    // Cập nhật entry trong provider
    foodProvider.updateFoodEntry(_foodEntry);
    
    // Đóng dialog
    Navigator.pop(context);
    
    // Thông báo thành công
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã đồng bộ dữ liệu dinh dưỡng'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Phương thức xử lý khi người dùng nhấn nút Đồng ý
  void _handleSaveAndExit() {
    // Hiển thị đang đồng bộ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              SizedBox(height: 16),
              Text(
                'Đang cập nhật dữ liệu dinh dưỡng...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );

    // Lấy FoodProvider
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    // Đảm bảo dữ liệu dinh dưỡng được cập nhật đúng cách
    final nutritionValues = _foodEntry.calculateNutritionFromAPI();
    
    // Cập nhật lại nutritionInfo nếu cần thiết
    if (_foodEntry.nutritionInfo == null || _foodEntry.nutritionInfo!.isEmpty) {
      _foodEntry = _foodEntry.copyWith(
        nutritionInfo: {
          'calories': nutritionValues['calories'],
          'protein': nutritionValues['protein'],
          'fat': nutritionValues['fat'],
          'carbs': nutritionValues['carbs'],
          'fiber': nutritionValues['fiber'],
          'sugar': nutritionValues['sugar'],
          'sodium': nutritionValues['sodium'],
          'servingSize': _servingSize,
          'totalWeight': nutritionValues['totalWeight'] ?? (_servingSize * 100),
        }
      );
    } else {
      // Đảm bảo totalWeight luôn được cập nhật trong nutritionInfo
      final updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
      updatedNutritionInfo['totalWeight'] = nutritionValues['totalWeight'] ?? (_servingSize * 100);
      updatedNutritionInfo['servingSize'] = _servingSize;
      _foodEntry = _foodEntry.copyWith(nutritionInfo: updatedNutritionInfo);
    }
    
    // QUAN TRỌNG: Đặt selectedDate trước để đảm bảo màn hình home hiển thị đúng ngày
    String dateStr = "${_foodEntry.dateTime.year}-${_foodEntry.dateTime.month.toString().padLeft(2, '0')}-${_foodEntry.dateTime.day.toString().padLeft(2, '0')}";
    foodProvider.setSelectedDate(dateStr);
    
    // Cập nhật entry trong provider
    foodProvider.updateFoodEntry(_foodEntry);
    
    // Đồng bộ dữ liệu dinh dưỡng nếu có items
    if (_foodEntry.items.isNotEmpty) {
      // Đồng bộ từng item
      for (var item in _foodEntry.items) {
        foodProvider.synchronizeNutritionData(item.id, _servingSize);
      }
      
      // Đồng bộ entry sau khi items đã được đồng bộ
      foodProvider.synchronizeNutrition(
        entryId: _foodEntry.id,
        servingSize: _servingSize,
      );
    }
    
    // Xóa cache để đảm bảo dữ liệu được tính toán lại và lưu thay đổi
    foodProvider.refreshNutrition();
    
    print('FoodNutritionDetailScreen._handleSaveAndExit: Đã lưu thay đổi với dữ liệu dinh dưỡng: calories=${nutritionValues['calories']}, protein=${nutritionValues['protein']}, totalWeight=${nutritionValues['totalWeight']}');
    print('FoodNutritionDetailScreen._handleSaveAndExit: Đã cập nhật selectedDate trong provider: $dateStr');
    
    // Đóng dialog loading
    Navigator.of(context).pop();
    
    // Gọi callback onSave
    widget.onSave(_foodEntry);
    
    // Quay về màn hình trước với kết quả thành công và truyền selectedDate
    Navigator.of(context).pop({
      'foodEntriesUpdated': true,
      'selectedDate': dateStr,
      'updatedEntry': _foodEntry,
    });
    
    // Hiển thị thông báo thành công
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã lưu thay đổi thành công'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Phương thức đồng bộ dữ liệu trước khi thoát màn hình
  void _saveAndSyncDataBeforeExit() {
    try {
      // Lấy FoodProvider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Đảm bảo dữ liệu dinh dưỡng được cập nhật đúng cách
      final nutritionValues = _foodEntry.calculateNutritionFromAPI();
      
      // Cập nhật lại nutritionInfo nếu cần thiết
      if (_foodEntry.nutritionInfo == null || _foodEntry.nutritionInfo!.isEmpty) {
        _foodEntry = _foodEntry.copyWith(
          nutritionInfo: {
            'calories': nutritionValues['calories'],
            'protein': nutritionValues['protein'],
            'fat': nutritionValues['fat'],
            'carbs': nutritionValues['carbs'],
            'fiber': nutritionValues['fiber'],
            'sugar': nutritionValues['sugar'],
            'sodium': nutritionValues['sodium'],
            'servingSize': _servingSize,
            'totalWeight': nutritionValues['totalWeight'] ?? (_servingSize * 100),
          }
        );
      } else {
        // Đảm bảo totalWeight luôn được cập nhật trong nutritionInfo
        final updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
        updatedNutritionInfo['totalWeight'] = nutritionValues['totalWeight'] ?? (_servingSize * 100);
        updatedNutritionInfo['servingSize'] = _servingSize;
        _foodEntry = _foodEntry.copyWith(nutritionInfo: updatedNutritionInfo);
      }
      
      // QUAN TRỌNG: Đặt selectedDate trước để đảm bảo màn hình home hiển thị đúng ngày
      String dateStr = "${_foodEntry.dateTime.year}-${_foodEntry.dateTime.month.toString().padLeft(2, '0')}-${_foodEntry.dateTime.day.toString().padLeft(2, '0')}";
      foodProvider.setSelectedDate(dateStr);
      
      // Cập nhật entry trong provider
      foodProvider.updateFoodEntry(_foodEntry);
      
      // Đồng bộ dữ liệu dinh dưỡng nếu có items
      if (_foodEntry.items.isNotEmpty) {
        // Đồng bộ từng item
        for (var item in _foodEntry.items) {
          foodProvider.synchronizeNutritionData(item.id, _servingSize);
        }
        
        // Đồng bộ entry sau khi items đã được đồng bộ
        foodProvider.synchronizeNutrition(
          entryId: _foodEntry.id,
          servingSize: _servingSize,
        );
      }
      
      // Xóa cache để đảm bảo dữ liệu được tính toán lại
      foodProvider.refreshNutrition();
      
      // Gọi callback onSave để đảm bảo thông tin được truyền về màn hình chính
      widget.onSave(_foodEntry);
      
      print('FoodNutritionDetailScreen._saveAndSyncDataBeforeExit: Đã lưu và đồng bộ dữ liệu trước khi thoát màn hình');
      print('FoodNutritionDetailScreen._saveAndSyncDataBeforeExit: Đã cập nhật selectedDate trong provider: $dateStr');
      
      // THÊM MỚI: Trả về kết quả khi nhấn nút back
      Navigator.of(context).pop({
        'foodEntriesUpdated': true,
        'selectedDate': dateStr,
        'updatedEntry': _foodEntry,
      });
    } catch (e) {
      print('Lỗi khi đồng bộ dữ liệu trước khi thoát: $e');
    }
  }

  @override
  void dispose() {
    // Không truy cập Provider trong dispose để tránh lỗi "Looking up a deactivated widget's ancestor is unsafe"
    // Các thao tác cần thiết đã được thực hiện trong _saveAndSyncDataBeforeExit
    print('FoodNutritionDetailScreen: Đã giải phóng tài nguyên khi thoát màn hình');
    super.dispose();
  }

  // Hàm đồng bộ khóa dinh dưỡng giữa camelCase và snake_case
  void _syncNutrientKeys(Map<String, dynamic> nutritionInfo) {
    // Danh sách các khóa cần đồng bộ: snake_case -> camelCase và ngược lại
    final keyMappings = {
      'vitamin_a': 'vitaminA',
      'vitamin_b12': 'vitaminB12',
      'vitamin_c': 'vitaminC',
      'vitamin_d': 'vitaminD',
      'vitamin_e': 'vitaminE',
      'vitamin_k': 'vitaminK',
      'vitamin_b9': 'vitaminB9',
      'vitamin_b': 'vitaminB',
      'saturated_fat': 'saturatedFat',
      'trans_fat': 'transFat',
      // Thêm các khóa còn thiếu
      'cholesterol': 'cholesterol',
      'omega3': 'omega3',
      'fiber': 'fiber',
      'water': 'water',
      'sugar': 'sugar',
      'caffeine': 'caffeine',
      'alcohol': 'alcohol',
      'iron': 'iron',
      'calcium': 'calcium',
      'magnesium': 'magnesium',
      'potassium': 'potassium',
      'zinc': 'zinc',
      'phosphorus': 'phosphorus',
      'selenium': 'selenium',
      'copper': 'copper',
      'manganese': 'manganese',
      'thiamin': 'thiamin',
      'riboflavin': 'riboflavin',
      'niacin': 'niacin',
    };
    
    // Đồng bộ từ snake_case sang camelCase và ngược lại
    keyMappings.forEach((snakeKey, camelKey) {
      // Từ snake_case sang camelCase
      if (nutritionInfo.containsKey(snakeKey) && nutritionInfo[snakeKey] != null) {
        nutritionInfo[camelKey] = nutritionInfo[snakeKey];
      }
      // Từ camelCase sang snake_case
      else if (nutritionInfo.containsKey(camelKey) && nutritionInfo[camelKey] != null) {
        nutritionInfo[snakeKey] = nutritionInfo[camelKey];
      }
      // Nếu cả hai đều null, đặt giá trị mặc định là 0.0
      else if (!nutritionInfo.containsKey(snakeKey) && !nutritionInfo.containsKey(camelKey)) {
        nutritionInfo[snakeKey] = 0.0;
        nutritionInfo[camelKey] = 0.0;
      }
      // Nếu một trong hai là null, sử dụng giá trị không null
      else if (nutritionInfo.containsKey(snakeKey) && nutritionInfo[snakeKey] == null) {
        nutritionInfo[snakeKey] = nutritionInfo.containsKey(camelKey) && nutritionInfo[camelKey] != null ? 
          nutritionInfo[camelKey] : 0.0;
      }
      else if (nutritionInfo.containsKey(camelKey) && nutritionInfo[camelKey] == null) {
        nutritionInfo[camelKey] = nutritionInfo.containsKey(snakeKey) && nutritionInfo[snakeKey] != null ? 
          nutritionInfo[snakeKey] : 0.0;
      }
    });
    
    // In thông tin để debug
    print("FoodNutritionDetailScreen._syncNutrientKeys: VitaminD = ${nutritionInfo['vitaminD']}, vitamin_d = ${nutritionInfo['vitamin_d']}");
  }
} 