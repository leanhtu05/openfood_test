import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/food_entry.dart';
import '../providers/food_provider.dart';
import '../providers/user_data_provider.dart';
import '../services/nutrition_sync_service.dart';
import '../widgets/food_nutrition/nutrition_illustration.dart';
import '../widgets/food_nutrition/header_food_info_card.dart';
import '../widgets/food_nutrition/food_nutrition_dialogs.dart';
import '../widgets/food_nutrition/food_nutrition_actions.dart';
import '../widgets/food_nutrition/nutrition_footer.dart';

class FoodNutritionDetailScreen extends StatefulWidget {
  final FoodEntry foodEntry;
  final Function(FoodEntry) onSave;
  final String? heroTag;

  const FoodNutritionDetailScreen({
    Key? key,
    required this.foodEntry,
    required this.onSave,
    this.heroTag,
  }) : super(key: key);

  @override
  _FoodNutritionDetailScreenState createState() => _FoodNutritionDetailScreenState();
}

class _FoodNutritionDetailScreenState extends State<FoodNutritionDetailScreen> {
  late FoodEntry _foodEntry;
  late String _mealName;
  double _servingSize = 1.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _foodEntry = widget.foodEntry;
    _mealName = _foodEntry.mealType;

    // Nếu có items thì lấy servingSize của item đầu tiên, nếu không thì mặc định là 1.0
    if (_foodEntry.items.isNotEmpty) {
      _servingSize = _foodEntry.items.first.servingSize;
    }

    // Thiết lập các hoạt động sau khi khung hình đầu tiên được dựng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Đồng bộ ngày từ provider
        _syncDateWithProvider();
        
        // Cập nhật servingSize mặc định
        _updateDefaultServingSize();
        
        // Đợi một chút trước khi đồng bộ dữ liệu dinh dưỡng
        Future.delayed(Duration(milliseconds: 50), () {
          if (mounted) {
            // Tìm kiếm thông tin dinh dưỡng từ API nếu cần
            if (_foodEntry.nutritionInfo == null || _foodEntry.nutritionInfo!.isEmpty) {
              _fetchNutritionDataFromAPI();
            } else {
              // Đồng bộ dữ liệu hiện có
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
    
    // Sử dụng Future.microtask để trì hoãn cập nhật state
    Future.microtask(() {
      // Lấy FoodEntry từ provider để đảm bảo dữ liệu luôn cập nhật
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final updatedEntry = foodProvider.getFoodEntryById(_foodEntry.id);
      
      if (updatedEntry != null && mounted) {
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
    
    // Tính toán các giá trị dinh dưỡng
    Map<String, double> nutritionValues = _calculateNutritionValues();
    
    return WillPopScope(
      onWillPop: () async {
        // Không lưu dữ liệu khi nhấn nút back
        return true;
      },
      child: Scaffold(
        appBar: _buildAppBar(),
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
                          _buildLoadingIndicator(),

                        // Data source notification
                        if (!_isLoading && _foodEntry.nutritionInfo != null && 
                            _foodEntry.nutritionInfo!.containsKey('dataSource'))
                          _buildDataSourceNotification(),

                        // Food information header
                        HeaderFoodInfoCard(
                          foodEntry: _foodEntry,
                          servingSize: _servingSize,
                          onEditTime: () {
                            setState(() {
                              // Lấy dữ liệu mới từ provider để đảm bảo đồng bộ
                              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                              _foodEntry = foodProvider.getFoodEntryById(_foodEntry.id) ?? _foodEntry;
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
                          _buildBarcodeInfo(),
                      ],
                    ),
                  ),
                  
                  // Nutrition illustration as a separate sliver
                  SliverToBoxAdapter(
                    child: _buildNutritionIllustration(
                      nutritionValues, 
                      caloriesGoal, 
                      proteinGoal, 
                      fatGoal, 
                      carbsGoal,
                      userDataProvider
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
            NutritionFooter(
              foodEntry: _foodEntry,
              nutritionValues: nutritionValues,
              onSavePressed: _handleSaveAndExit,
            ),
          ],
        ),
      ),
    );
  }

  // SECTION: UI Components
  
  // AppBar với các chức năng quản lý
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(56.0),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.shade200,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: Colors.grey.shade200,
          ),
        ),
        leadingWidth: 56,
        titleSpacing: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.arrow_back, color: Color(0xFF212121), size: 24),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        title: Padding(
          padding: EdgeInsets.only(left: 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nightlight_round, color: Color(0xFF212121), size: 20),
              SizedBox(width: 4),
              Flexible(
                child: InkWell(
                  onTap: _showMealTypeSelection,
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
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: _synchronizeAllData,
            tooltip: 'Đồng bộ dữ liệu dinh dưỡng',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editFoodDetails();
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
    );
  }

  // Widget hiển thị loading
  Widget _buildLoadingIndicator() {
    return Container(
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
    );
  }

  // Widget thông báo nguồn dữ liệu
  Widget _buildDataSourceNotification() {
    return Container(
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
    );
  }

  // Widget hiển thị thông tin mã vạch
  Widget _buildBarcodeInfo() {
    return Container(
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
    );
  }

  // Widget hiển thị minh họa dinh dưỡng
  Widget _buildNutritionIllustration(
    Map<String, double> nutritionValues,
    double caloriesGoal,
    double proteinGoal,
    double fatGoal,
    double carbsGoal,
    UserDataProvider userDataProvider
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
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
        key: ValueKey('nutrition_illustration_${_foodEntry.id}_${_servingSize}_${_foodEntry.items.length}_${DateTime.now().millisecondsSinceEpoch}'),
        totalCalories: nutritionValues['calories'] ?? _foodEntry.totalCalories,
        totalProtein: nutritionValues['protein'] ?? _foodEntry.totalProtein,
        totalFat: nutritionValues['fat'] ?? _foodEntry.totalFat,
        totalCarbs: nutritionValues['carbs'] ?? _foodEntry.totalCarbs,
        caloriesGoal: caloriesGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
        nutritionInfo: _foodEntry.nutritionInfo ?? {},
        cholesterolGoal: userDataProvider.nutritionGoals['cholesterol'] ?? 300.0,
        omega3Goal: userDataProvider.nutritionGoals['omega3'] ?? 1.6,
        fiberGoal: userDataProvider.nutritionGoals['fiber'] ?? 25.0,
        waterGoal: userDataProvider.nutritionGoals['water'] ?? 2000.0,
        sugarGoal: userDataProvider.nutritionGoals['sugar'] ?? 50.0,
        saturatedFatGoal: userDataProvider.nutritionGoals['saturatedFat'] ?? 20.0,
        caffeineGoal: userDataProvider.nutritionGoals['caffeine'] ?? 400.0,
        alcoholGoal: userDataProvider.nutritionGoals['alcohol'] ?? 14.0,
        vitaminDGoal: userDataProvider.nutritionGoals['vitaminD'] ?? 15.0,
        vitaminB12Goal: userDataProvider.nutritionGoals['vitaminB12'] ?? 2.4,
        vitaminCGoal: userDataProvider.nutritionGoals['vitaminC'] ?? 75.0,
        vitaminBGoal: userDataProvider.nutritionGoals['vitaminB'] ?? 15.0,
        ironGoal: userDataProvider.nutritionGoals['iron'] ?? 18.0,
        calciumGoal: userDataProvider.nutritionGoals['calcium'] ?? 1000.0,
        magnesiumGoal: userDataProvider.nutritionGoals['magnesium'] ?? 400.0,
        potassiumGoal: userDataProvider.nutritionGoals['potassium'] ?? 4700.0,
        // Các vi chất bổ sung từ API USDA
        vitaminAGoal: userDataProvider.nutritionGoals['vitaminA'] ?? 900.0,
        vitaminEGoal: userDataProvider.nutritionGoals['vitaminE'] ?? 15.0,
        vitaminKGoal: userDataProvider.nutritionGoals['vitaminK'] ?? 120.0,
        thiaminGoal: userDataProvider.nutritionGoals['thiamin'] ?? 1.2,
        riboflavinGoal: userDataProvider.nutritionGoals['riboflavin'] ?? 1.3,
        niacinGoal: userDataProvider.nutritionGoals['niacin'] ?? 16.0,
        phosphorusGoal: userDataProvider.nutritionGoals['phosphorus'] ?? 700.0,
        seleniumGoal: userDataProvider.nutritionGoals['selenium'] ?? 55.0,
        copperGoal: userDataProvider.nutritionGoals['copper'] ?? 0.9,
        manganeseGoal: userDataProvider.nutritionGoals['manganese'] ?? 2.3,
        transFatGoal: userDataProvider.nutritionGoals['transFat'] ?? 2.0,
        useRadialGradient: true,
        backgroundColor: Colors.grey.shade50,
        showDetailedLabels: true,
        showMacroMainSummary: true,
      ),
    );
  }

  // SECTION: Actions & Event Handlers
  
  void _showMealTypeSelection() {
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
  }
  
  Widget _buildMealTypeOption(String mealType) {
    return ListTile(
      title: Text(mealType),
      onTap: () {
        setState(() {
          _mealName = mealType;
          
          // Cập nhật FoodEntry với loại bữa ăn mới
          _foodEntry = FoodNutritionActions.updateMealType(_foodEntry, mealType);
          
          // Đồng bộ ngay lập tức với Food Provider để cập nhật trong HomeScreen
          final foodProvider = Provider.of<FoodProvider>(context, listen: false);
          foodProvider.updateFoodEntry(_foodEntry);
        });
        
        // Hiển thị thông báo xác nhận đã đổi loại bữa ăn
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuyển sang $mealType'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
      },
      trailing: _mealName == mealType ? Icon(Icons.check, color: Colors.green) : null,
    );
  }

  // Tính toán giá trị dinh dưỡng từ nhiều nguồn
  Map<String, double> _calculateNutritionValues() {
    Map<String, double> values = {};
    
    // Kiểm tra nếu có nutritionInfo
    if (_foodEntry.nutritionInfo != null) {
      // Lấy giá trị từ nutritionInfo với giá trị mặc định từ các items
      values['calories'] = 
          _foodEntry.nutritionInfo!['calories'] is num ? 
          (_foodEntry.nutritionInfo!['calories'] as num).toDouble() : 
          _foodEntry.totalCalories;
          
      values['protein'] = 
          _foodEntry.nutritionInfo!['protein'] is num ? 
          (_foodEntry.nutritionInfo!['protein'] as num).toDouble() : 
          _foodEntry.totalProtein;
          
      values['fat'] = 
          _foodEntry.nutritionInfo!['fat'] is num ? 
          (_foodEntry.nutritionInfo!['fat'] as num).toDouble() : 
          _foodEntry.totalFat;
          
      values['carbs'] = 
          _foodEntry.nutritionInfo!['carbs'] is num ? 
          (_foodEntry.nutritionInfo!['carbs'] as num).toDouble() : 
          _foodEntry.totalCarbs;
    } else {
      // Sử dụng giá trị từ items
      values['calories'] = _foodEntry.totalCalories;
      values['protein'] = _foodEntry.totalProtein;
      values['fat'] = _foodEntry.totalFat;
      values['carbs'] = _foodEntry.totalCarbs;
    }
    
    return values;
  }

  // Đồng bộ với ngày từ provider
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
      } catch (e) {
        print('Lỗi khi cập nhật ngày từ FoodProvider: $e');
      }
    }
  }

  // Cập nhật khẩu phần mặc định
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
      
      // Đồng bộ lại với provider
      Future.microtask(() {
        if (mounted) {
          final foodProvider = Provider.of<FoodProvider>(context, listen: false);
          foodProvider.updateFoodEntry(_foodEntry);
        }
      });
    }
  }

  // SECTION: Async Operations
  
  // Đồng bộ hóa dữ liệu dinh dưỡng
  Future<void> _synchronizeNutritionData() async {
    bool wasLoading = _isLoading;
    
    if (!wasLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      final updatedEntry = await NutritionSyncService.synchronizeNutritionData(
        context: context,
        foodEntry: _foodEntry,
        servingSize: _servingSize,
      );
      
      if (mounted) {
        setState(() {
          _foodEntry = updatedEntry;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Lỗi khi đồng bộ dữ liệu: $e');
      
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
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final updatedEntry = await NutritionSyncService.fetchNutritionDataFromAPI(
        context: context,
        foodEntry: _foodEntry,
        servingSize: _servingSize,
      );
      
      if (mounted) {
        setState(() {
          _foodEntry = updatedEntry;
          _isLoading = false;
        });
        
        // Đảm bảo đồng bộ hóa dữ liệu
        await _synchronizeNutritionData();
        
        // Hiển thị thông báo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật thông tin dinh dưỡng từ API'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Lỗi khi fetch dữ liệu dinh dưỡng: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Hiển thị thông báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lấy dữ liệu dinh dưỡng: $e'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Đồng bộ toàn bộ dữ liệu
  Future<void> _synchronizeAllData() async {
    // Hiển thị đang đồng bộ
    FoodNutritionDialogs.showSynchronizingDialog(context);
    
    try {
      final updatedEntry = await NutritionSyncService.synchronizeAllData(
        context: context,
        foodEntry: _foodEntry,
        servingSize: _servingSize,
      );
      
      if (mounted) {
        setState(() {
          _foodEntry = updatedEntry;
        });
      }
    } catch (e) {
      print('Lỗi khi đồng bộ tất cả dữ liệu: $e');
    } finally {
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
  }

  // Xử lý lưu và thoát
  Future<void> _handleSaveAndExit() async {
    // Hiển thị đang cập nhật
    FoodNutritionDialogs.showSavingDialog(context);
    
    try {
      final updatedEntry = await NutritionSyncService.handleSaveAndExit(
        context: context,
        foodEntry: _foodEntry,
        servingSize: _servingSize,
      );
      
      // Đóng dialog loading
      Navigator.pop(context);
      
      // Gọi callback onSave
      widget.onSave(updatedEntry);
      
      // Lấy chuỗi ngày từ DateTime để truyền về
      String dateStr = "${updatedEntry.dateTime.year}-${updatedEntry.dateTime.month.toString().padLeft(2, '0')}-${updatedEntry.dateTime.day.toString().padLeft(2, '0')}";
      
      // Quay về màn hình trước với kết quả thành công và truyền chi tiết cập nhật
      Navigator.of(context).pop({
        'foodEntriesUpdated': true,
        'selectedDate': dateStr,
        'updatedEntry': updatedEntry,
        'updatedMealType': updatedEntry.mealType, // Thêm thông tin loại bữa ăn đã cập nhật
      });
      
      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu thay đổi thành công'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Đóng dialog loading
      Navigator.pop(context);
      
      print('Lỗi khi lưu và thoát: $e');
      
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu thay đổi: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // SECTION: Action Handlers
  
  // Thêm thực phẩm mới
  void _addMoreFood() {
    FoodNutritionActions.addMoreFood(context);
  }
  
  // Xóa thực phẩm
  Future<void> _deleteFood() async {
    final result = await FoodNutritionActions.deleteFood(context, _foodEntry);
    if (result) {
      Navigator.of(context).pop();
    }
  }
  
  // Sửa thông tin thực phẩm
  Future<void> _editFoodDetails() async {
    final updatedEntry = await FoodNutritionActions.editFoodDetails(context, _foodEntry);
    if (updatedEntry != null && mounted) {
      setState(() {
        _foodEntry = updatedEntry;
      });
    }
  }
  
  // Thay thế thực phẩm
  void _replaceFood() {
    FoodNutritionActions.replaceFood(context);
  }
  
  // Cập nhật kích thước khẩu phần
  void _updateServingSize(double newServingSize) {
    if (_servingSize == newServingSize) {
      return; // Tránh cập nhật không cần thiết
    }
    
    try {
      final updatedEntry = NutritionSyncService.updateServingSize(
        context: context,
        foodEntry: _foodEntry,
        newServingSize: newServingSize,
        oldServingSize: _servingSize,
      );
      
      setState(() {
        _servingSize = newServingSize;
        _foodEntry = updatedEntry;
      });
      
      // Hiển thị thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật khẩu phần: ${newServingSize.toStringAsFixed(1)} (${(newServingSize * 100).toInt()}g)'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Lỗi khi cập nhật khẩu phần: $e');
    }
  }
  
  // Xử lý khi thay đổi khối lượng
  void _onWeightChanged(double newWeight) {
    try {
      final updatedEntry = NutritionSyncService.onWeightChanged(
        context: context,
        foodEntry: _foodEntry,
        newWeight: newWeight,
      );
      
      setState(() {
        _foodEntry = updatedEntry;
        _servingSize = newWeight / 100; // Cập nhật servingSize theo weight mới
      });
      
      // Hiển thị thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật khối lượng: ${newWeight.toInt()}g (${_servingSize.toStringAsFixed(1)} khẩu phần)'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Lỗi khi thay đổi khối lượng: $e');
    }
  }

  @override
  void dispose() {
    // Đảm bảo làm sạch cache khi thoát màn hình
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      foodProvider.refreshNutrition();
    } catch (e) {
      print('Lỗi trong phương thức dispose: $e');
    }
    
    super.dispose();
  }
} 