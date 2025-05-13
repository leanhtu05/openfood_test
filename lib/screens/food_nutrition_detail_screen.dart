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

  // Thêm biến để quản lý trạng thái mở rộng thông tin dinh dưỡng
  bool _isNutritionExpanded = true;

  // Biến quản lý trạng thái loading
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _foodEntry = widget.foodEntry;
    _mealName = _foodEntry.mealType;
    
    // Đảm bảo khẩu phần luôn bằng 1 mặc định
    _servingSize = 1.0;
    
    // Cập nhật thông tin dinh dưỡng dựa trên khẩu phần mặc định
    _updateDefaultServingSize();

    // Đồng bộ hóa thông tin dinh dưỡng từ các nguồn khác nhau
    _synchronizeNutritionData();

    // Sync with date from provider if applicable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncDateWithProvider();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lắng nghe sự thay đổi ngày từ FoodProvider
    final foodProvider = Provider.of<FoodProvider>(context);
    final selectedDate = foodProvider.selectedDate;

    // Nếu ngày đã chọn khác với ngày hiện tại của FoodEntry, cập nhật FoodEntry
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

  @override
  Widget build(BuildContext context) {
    // Định dạng ngày giờ
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateString = dateFormat.format(_foodEntry.dateTime);
    
    // Tính toán giá trị dinh dưỡng một lần duy nhất cho toàn bộ build
    final nutritionValues = _foodEntry.calculateNutritionFromAPI();
    final calories = nutritionValues['calories']?.toInt() ?? 0;
    final protein = nutritionValues['protein']?.toInt() ?? 0;
    final fat = nutritionValues['fat']?.toInt() ?? 0;
    final carbs = nutritionValues['carbs']?.toInt() ?? 0;
    final totalWeight = _foodEntry.nutritionInfo?['totalWeight']?.toInt() ?? 
                        _foodEntry.totalWeight.toInt() ?? 150;
    
    return Scaffold(
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
              onPressed: () => Navigator.of(context).pop(),
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
            // Biểu tượng dấu sao - Yêu thích
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: IconButton(
                icon: Icon(
                  _foodEntry.isFavorite ? Icons.star : Icons.star_border, 
                  color: _foodEntry.isFavorite ? Colors.amber : Color(0xFF42A5F5), 
                  size: 22
                ),
                onPressed: () {
                  // Toggle favorite status
                  setState(() {
                    _foodEntry = FoodEntry(
                      id: _foodEntry.id,
                      description: _foodEntry.description,
                      imagePath: _foodEntry.imagePath,
                      audioPath: _foodEntry.audioPath,
                      dateTime: _foodEntry.dateTime,
                      isFavorite: !_foodEntry.isFavorite,
                      barcode: _foodEntry.barcode,
                      calories: _foodEntry.calories,
                      nutritionInfo: _foodEntry.nutritionInfo,
                      mealType: _foodEntry.mealType,
                      items: _foodEntry.items,
                    );
                  });
                  
                  // Hiển thị thông báo
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_foodEntry.isFavorite 
                          ? 'Đã thêm vào danh sách yêu thích' 
                          : 'Đã xóa khỏi danh sách yêu thích'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            // Menu tùy chọn (ba chấm dọc)
            Padding(
              padding: EdgeInsets.only(left: 4, right: 16),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Color(0xFF212121), size: 22),
                onSelected: (String result) {
                  if (result == 'delete') {
                    _deleteFood();
                  } else if (result == 'edit') {
                    _editFoodDetails();
                  } else if (result == 'replace') {
                    _replaceFood();
                  } else if (result == 'share') {
                    _showShareOptions();
                  } else if (result == 'details') {
                    _showNutritionDetails();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined, color: Colors.blue),
                      title: Text('Sửa món ăn', style: TextStyle(color: Colors.black)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'replace',
                    child: ListTile(
                      leading: Icon(Icons.swap_horiz, color: Colors.purple),
                      title: Text('Thay thế', style: TextStyle(color: Colors.black)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'details',
                    child: ListTile(
                      leading: Icon(Icons.info_outline, color: Colors.blue),
                      title: Text('Chi tiết dinh dưỡng', style: TextStyle(color: Colors.black)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share, color: Colors.green),
                      title: Text('Chia sẻ', style: TextStyle(color: Colors.black)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Xóa', style: TextStyle(color: Colors.black)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
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
                        onEditTime: () => _showTimePicker(),
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
                        onWeightChanged: _updateFoodWeight,
                      ),
                      
                      SizedBox(height: 6),
                      
                      // Barcode information (if available)
                      if (_foodEntry.barcode != null && _foodEntry.barcode!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.qr_code, size: 14, color: Colors.grey[600]),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Dữ liệu từ mã vạch: ${_foodEntry.barcode}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
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
                      key: ValueKey('nutrition_illustration_${_foodEntry.id}_${_servingSize}_${DateTime.now().millisecondsSinceEpoch}'), // Add unique key for forced rebuild
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
                              "Tổng Cộng: ${totalWeight}g",
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
                              _buildSimpleNutrientIndicator("${calories}kcal", Colors.red),
                              SizedBox(width: 8),
                              _buildSimpleNutrientIndicator("${protein}g", Colors.blue),
                              SizedBox(width: 8),
                              _buildSimpleNutrientIndicator("${fat}g", Colors.amber),
                              SizedBox(width: 8),
                              _buildSimpleNutrientIndicator("${carbs}g", Colors.green),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: 8),
                  
                  // Right side with compact save button
                  ElevatedButton(
                    onPressed: () {
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
                        _foodEntry = _foodEntry.copyWith(nutritionInfo: updatedNutritionInfo);
                      }
                      
                      // Cập nhật entry trong provider
                      foodProvider.updateFoodEntry(_foodEntry);
                      
                      // Đồng bộ dữ liệu dinh dưỡng nếu có items
                      if (_foodEntry.items.isNotEmpty) {
                        foodProvider.synchronizeNutrition(
                          entryId: _foodEntry.id,
                          servingSize: _foodEntry.items.first.servingSize,
                        );
                      }
                      
                      // Xóa cache để đảm bảo dữ liệu được tính toán lại
                      foodProvider.refreshNutrition();
                      
                      print('Đã lưu thay đổi với dữ liệu dinh dưỡng: calories=${nutritionValues['calories']}, protein=${nutritionValues['protein']}, totalWeight=${nutritionValues['totalWeight']}');
                      
                      // Quay về màn hình trước với kết quả thành công
                      Navigator.of(context).pop({
                        'foodEntriesUpdated': true,
                        'selectedDate': _foodEntry.dateTime.toIso8601String().split('T')[0],
                      });
                    },
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
              child: Text('Xoá', style: TextStyle(color: Colors.red)),
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
      setState(() {
        // Tạo DateTime mới giữ nguyên giờ, phút, giây nhưng thay đổi ngày, tháng, năm
        final updatedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _foodEntry.dateTime.hour,
          _foodEntry.dateTime.minute,
          _foodEntry.dateTime.second,
        );
        
        // Cập nhật FoodEntry với ngày mới
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
        
        // Cập nhật provider để đồng bộ dữ liệu
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        
        // Cập nhật entry trong provider
        foodProvider.updateFoodEntry(_foodEntry);
        
        // Cập nhật ngày được chọn trong provider
        final selectedDate = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        foodProvider.setSelectedDate(selectedDate);
        
        // Xóa cache để đảm bảo dữ liệu được tính toán lại
        foodProvider.clearNutritionCache();
        
        // In log để debug
        final dateFormatter = DateFormat('dd/MM/yyyy');
        print('Đã cập nhật ngày: ${dateFormatter.format(updatedDateTime)}');
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
                _buildDetailItem('Calo', '${nutritionValues['calories']?.toInt() ?? 0} kcal', Colors.orange),
                _buildDetailItem('Protein', '${nutritionValues['protein']?.toInt() ?? 0}g', Colors.blue),
                _buildDetailItem('Chất béo', '${nutritionValues['fat']?.toInt() ?? 0}g', Colors.orange.shade700),
                _buildDetailItem('Carbs', '${nutritionValues['carbs']?.toInt() ?? 0}g', Colors.green),
                _buildDetailItem('Đường', '${nutritionValues['sugar']?.toInt() ?? 0}g', Colors.pink),
                _buildDetailItem('Chất xơ', '${nutritionValues['fiber']?.toInt() ?? 0}g', Colors.brown),
                _buildDetailItem('Cholesterol', '${_foodEntry.nutritionInfo?["cholesterol"] ?? 0}mg', Colors.orange.shade700),
                _buildDetailItem('Vitamin D', '${_foodEntry.nutritionInfo?["vitaminD"] ?? 0}mcg', Colors.amber),
                _buildDetailItem('Vitamin B12', '${_foodEntry.nutritionInfo?["vitaminB12"] ?? 0}mcg', Colors.purple),
                _buildDetailItem('Vitamin C', '${_foodEntry.nutritionInfo?["vitaminC"] ?? 0}mg', Colors.orange),
                _buildDetailItem('Sắt', '${_foodEntry.nutritionInfo?["iron"] ?? 0}mg', Colors.red),
                _buildDetailItem('Canxi', '${_foodEntry.nutritionInfo?["calcium"] ?? 0}mg', Colors.grey),
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
  void _synchronizeNutritionData() {
    // Kiểm tra nếu có thông tin từ phân tích AI hoặc mã vạch
    if (_foodEntry.nutritionInfo != null && _foodEntry.nutritionInfo!.isNotEmpty) {
      // Đảm bảo có totalWeight trong nutritionInfo
      if (!_foodEntry.nutritionInfo!.containsKey('totalWeight') && _foodEntry.items.isNotEmpty) {
        final updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
        updatedNutritionInfo['totalWeight'] = 100.0; // 1 khẩu phần = 100g
        updatedNutritionInfo['servingSize'] = 1.0;
        
        // Cập nhật FoodEntry từ dữ liệu dinh dưỡng
        setState(() {
          _foodEntry = FoodDataAdapter.updateWithNutritionInfo(
            entry: _foodEntry.copyWith(nutritionInfo: updatedNutritionInfo), 
            nutritionInfo: updatedNutritionInfo
          );
        });
      } else {
        // Đảm bảo servingSize trong nutritionInfo là 1.0
        final updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
        updatedNutritionInfo['servingSize'] = 1.0;
        
        // Cập nhật FoodEntry từ dữ liệu dinh dưỡng
        setState(() {
          _foodEntry = FoodDataAdapter.updateWithNutritionInfo(
            entry: _foodEntry.copyWith(nutritionInfo: updatedNutritionInfo), 
            nutritionInfo: updatedNutritionInfo
          );
        });
      }
      
      // Đồng bộ dữ liệu với provider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      foodProvider.updateFoodEntry(_foodEntry);
      foodProvider.clearNutritionCache();
      
    } else if (_foodEntry.items.isNotEmpty) {
      // Nếu không có dữ liệu dinh dưỡng nhưng có items, tự động tải từ API
      _fetchNutritionDataFromAPI();
    }
    
    // Đảm bảo servingSize được khởi tạo là 1.0
    setState(() {
      _servingSize = 1.0;
    });
  }
  
  // Hàm tải dữ liệu dinh dưỡng từ API
  Future<void> _fetchNutritionDataFromAPI() async {
    if (_foodEntry.items.isEmpty) return;
    
    try {
      // Hiển thị loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Lấy tên thực phẩm từ item đầu tiên
      final foodName = _foodEntry.items.first.name;
      
      // Gọi API để lấy dữ liệu dinh dưỡng
      final nutritionData = await FoodDataAdapter.fetchNutritionInfo(foodName);
      
      if (nutritionData != null) {
        // Cập nhật FoodEntry với dữ liệu từ API
        setState(() {
          _foodEntry = FoodDataAdapter.updateWithNutritionInfo(
            entry: _foodEntry,
            nutritionInfo: nutritionData,
            fromAPI: true,
          );
          _isLoading = false;
        });
        
        // Đồng bộ dữ liệu với provider
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        
        // Cập nhật entry trong provider
        foodProvider.updateFoodEntry(_foodEntry);
        
        // Đồng bộ dữ liệu dinh dưỡng nếu có items
        if (_foodEntry.items.isNotEmpty) {
          foodProvider.synchronizeNutrition(
            entryId: _foodEntry.id,
            servingSize: _foodEntry.items.first.servingSize,
          );
        }
        
        // Xóa cache để đảm bảo dữ liệu được tính toán lại
        foodProvider.refreshNutrition();
        
        // Hiển thị thông báo nhỏ ở góc dưới màn hình
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật thông tin dinh dưỡng từ cơ sở dữ liệu'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Lỗi khi tải dữ liệu dinh dưỡng từ API: $e');
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
                  _foodEntry = FoodEntry(
                    id: _foodEntry.id,
                    description: tempDescription,
                    imagePath: _foodEntry.imagePath,
                    audioPath: _foodEntry.audioPath,
                    dateTime: _foodEntry.dateTime,
                    isFavorite: _foodEntry.isFavorite,
                    barcode: _foodEntry.barcode,
                    calories: _foodEntry.calories,
                    nutritionInfo: _foodEntry.nutritionInfo,
                    mealType: _foodEntry.mealType,
                    items: _foodEntry.items,
                  );
                });
                Navigator.pop(context);
                
                // Hiển thị thông báo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã cập nhật thông tin món ăn'),
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
          return item.copyWith(servingSize: newServingSize);
        }).toList();
        
        // Cập nhật FoodEntry với items mới và thông tin dinh dưỡng mới
        Map<String, dynamic> updatedNutritionInfo = {};
        if (_foodEntry.nutritionInfo != null) {
          updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
          // Cập nhật khẩu phần
          updatedNutritionInfo['servingSize'] = newServingSize;
          
          // Cập nhật tổng khối lượng - đồng bộ với khẩu phần (100g = 1 khẩu phần)
          final oldTotalWeight = updatedNutritionInfo['totalWeight'] ?? (oldServingSize * 100);
          updatedNutritionInfo['totalWeight'] = newServingSize * 100;
          
          // Tính lại tỷ lệ dựa trên khối lượng mới
          ratio = updatedNutritionInfo['totalWeight'] / oldTotalWeight;
          
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
          final micronutrients = ['fiber', 'sugar', 'sodium', 'cholesterol', 'vitaminD', 'vitaminC', 
                                 'vitaminB12', 'calcium', 'iron', 'potassium', 'magnesium'];
          
          for (var nutrient in micronutrients) {
            if (updatedNutritionInfo.containsKey(nutrient)) {
              updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
            }
          }
        } else {
          updatedNutritionInfo = {
            'servingSize': newServingSize,
            'totalWeight': newServingSize * 100,
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
  
  // Cập nhật khối lượng thực phẩm
  void _updateFoodWeight(double newWeight) {
    // Kiểm tra giá trị newWeight, có thể cần điều chỉnh
    if (newWeight > 1000) { // Giới hạn hợp lý
      newWeight = 1000;
    }
    
    // Kiểm tra nếu khối lượng không thay đổi
    double oldWeight = 150;
    if (_foodEntry.nutritionInfo != null && _foodEntry.nutritionInfo!.containsKey('totalWeight')) {
      oldWeight = _foodEntry.nutritionInfo!['totalWeight'];
    }
    
    if (newWeight == oldWeight) {
      return; // Tránh cập nhật không cần thiết
    }
    
    // Tính khẩu phần mới dựa trên gram mới (100g = 1 khẩu phần)
    double newServingSize = newWeight / 100;
    
    setState(() {
      // Cập nhật khẩu phần
      _servingSize = newServingSize;
      
      // Tính hệ số thay đổi
      double ratio = newWeight / oldWeight;
      
      // Tính toán giá trị dinh dưỡng một lần duy nhất
      final nutritionValues = _foodEntry.calculateNutritionFromAPI();
      final calories = (nutritionValues['calories']! * ratio).toDouble();
      final protein = (nutritionValues['protein']! * ratio).toDouble();
      final fat = (nutritionValues['fat']! * ratio).toDouble();
      final carbs = (nutritionValues['carbs']! * ratio).toDouble();
      
      // Cập nhật tất cả các giá trị dinh dưỡng theo tỷ lệ
      Map<String, dynamic> updatedNutritionInfo = {};
      if (_foodEntry.nutritionInfo != null) {
        updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
        
        // Cập nhật các giá trị dinh dưỡng chính
        updatedNutritionInfo['calories'] = calories;
        updatedNutritionInfo['protein'] = protein;
        updatedNutritionInfo['fat'] = fat;
        updatedNutritionInfo['carbs'] = carbs;
        
        // Xác định nếu oldTotalWeight đã quá lớn
        if (oldWeight > 1000) {
          oldWeight = 1000;
        }
        updatedNutritionInfo['totalWeight'] = newWeight;
        
        // Cập nhật servingSize
        updatedNutritionInfo['servingSize'] = newServingSize;
        
        // Cập nhật items với servingSize mới nếu có
        if (_foodEntry.items.isNotEmpty) {
          final updatedItems = _foodEntry.items.map((item) {
            return item.copyWith(servingSize: newServingSize);
          }).toList();
          
          // Cập nhật FoodEntry với items mới
          _foodEntry = _foodEntry.copyWith(
            items: updatedItems,
            nutritionInfo: updatedNutritionInfo,
          );
        } else {
          // Cập nhật FoodEntry chỉ với nutritionInfo mới
          _foodEntry = _foodEntry.copyWith(
            nutritionInfo: updatedNutritionInfo,
          );
        }
        
        // Cập nhật các vi chất dinh dưỡng theo tỷ lệ
        final micronutrients = [
          'fiber', 'sugar', 'sodium', 'cholesterol', 'vitaminD', 'vitaminC', 
          'vitaminB12', 'calcium', 'iron', 'potassium', 'magnesium'
        ];
        
        for (var nutrient in micronutrients) {
          if (updatedNutritionInfo.containsKey(nutrient)) {
            updatedNutritionInfo[nutrient] = (updatedNutritionInfo[nutrient] * ratio).toDouble();
          }
        }
      } else {
        updatedNutritionInfo = {
          'calories': calories,
          'protein': protein,
          'fat': fat,
          'carbs': carbs,
          'totalWeight': newWeight,
          'servingSize': newServingSize,
        };
        
        // Tạo đối tượng FoodEntry mới với thông tin đã cập nhật
        _foodEntry = _foodEntry.copyWith(
          nutritionInfo: updatedNutritionInfo,
        );
      }
      
      // Cập nhật Provider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Cập nhật entry trong provider
      foodProvider.updateFoodEntry(_foodEntry);
      
      // Đồng bộ dữ liệu dinh dưỡng nếu có items
      if (_foodEntry.items.isNotEmpty) {
        foodProvider.synchronizeNutrition(
          entryId: _foodEntry.id,
          servingSize: newServingSize,
        );
      }
      
      // Xóa cache để đảm bảo dữ liệu được tính toán lại
      foodProvider.refreshNutrition();
    });
    
    // Hiển thị thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật khối lượng: ${newWeight.toInt()}g (${newServingSize.toStringAsFixed(1)} khẩu phần)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Thêm phương thức mới để cập nhật khẩu phần mặc định
  void _updateDefaultServingSize() {
    // Nếu đã có thông tin dinh dưỡng, cập nhật servingSize trong đó
    if (_foodEntry.nutritionInfo != null) {
      final updatedNutritionInfo = Map<String, dynamic>.from(_foodEntry.nutritionInfo!);
      updatedNutritionInfo['servingSize'] = 1.0;
      
      // Cập nhật totalWeight để tương ứng với khẩu phần 1.0
      if (!updatedNutritionInfo.containsKey('totalWeight') || updatedNutritionInfo['totalWeight'] <= 0) {
        updatedNutritionInfo['totalWeight'] = 100.0; // 1 khẩu phần = 100g
      }
      
      _foodEntry = _foodEntry.copyWith(nutritionInfo: updatedNutritionInfo);
    }
    
    // Nếu có các items, cập nhật servingSize cho từng item
    if (_foodEntry.items.isNotEmpty) {
      final currentServingSize = _foodEntry.items.first.servingSize;
      if (currentServingSize != 1.0) {
        final ratio = 1.0 / currentServingSize;
        
        // Cập nhật từng item với servingSize = 1.0
        final updatedItems = _foodEntry.items.map((item) {
          return item.copyWith(servingSize: 1.0);
        }).toList();
        
        _foodEntry = _foodEntry.copyWith(items: updatedItems);
      }
    }
  }

  @override
  void dispose() {
    // Đảm bảo lưu thay đổi trước khi thoát màn hình
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    // Cập nhật entry trong provider
    foodProvider.updateFoodEntry(_foodEntry);
    
    // Xóa cache để đảm bảo dữ liệu được tính toán lại khi quay lại màn hình chính
    foodProvider.refreshNutrition();
    
    print('FoodNutritionDetailScreen: Đã lưu và đồng bộ dữ liệu khi thoát màn hình');
    
    super.dispose();
  }
} 