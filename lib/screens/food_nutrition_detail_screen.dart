import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../providers/food_provider.dart';
import '../providers/user_data_provider.dart';
import '../services/nutrition_sync_service.dart';
import '../utils/constants.dart';
import '../widgets/food_nutrition/nutrition_illustration.dart';
import '../widgets/food_nutrition/header_food_info_card.dart';
import '../widgets/food_nutrition/food_nutrition_dialogs.dart';
import '../widgets/food_nutrition/food_nutrition_actions.dart';
import '../widgets/food_nutrition/nutrition_footer.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _isLoadingImage = false;
  bool _isEditing = false; // 🔧 FIX: Track editing state
  String? _imageUrl;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

        // Tải hình ảnh từ Firebase Storage nếu có
        _loadImageFromFirebase();

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
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);

    // Mục tiêu dinh dưỡng từ FoodProvider thay vì trực tiếp từ UserDataProvider
    final nutritionGoals = foodProvider.getNutritionGoals(context);
    final caloriesGoal = nutritionGoals['calories'] ?? 2000.0;
    final proteinGoal = nutritionGoals['protein'] ?? 50.0;
    final fatGoal = nutritionGoals['fat'] ?? 70.0;
    final carbsGoal = nutritionGoals['carbs'] ?? 310.0;

    // Tính toán các giá trị dinh dưỡng
    Map<String, double> nutritionValues = _calculateNutritionValues();

    return WillPopScope(
      onWillPop: () async {
        // Chỉ quay về màn hình trước, không lưu dữ liệu
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
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
                        Column(
                          children: [
                            // Chỉ hiển thị HeaderFoodInfoCard, không hiển thị _buildFoodImage() để tránh trùng lặp
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
                              // Truyền thêm thông tin ảnh để HeaderFoodInfoCard có thể hiển thị camera icon
                              imageUrl: _imageUrl,
                              onSelectImage: _selectImage,
                            ),


                          ],
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

  // Widget hiển thị avatar hình tròn với chữ B scan
  Widget _buildFoodImage() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.only(left: 16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _selectImage,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: _isLoadingImage
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                  strokeWidth: 2,
                                )
                              : _buildAvatarImage(),
                        ),
                        // Thêm biểu tượng camera ở góc dưới phải
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'scan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          // Thêm khoảng trống để tạo layout cân đối
          Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  // Phương thức mới để xác định và hiển thị ảnh từ nhiều nguồn
  Widget _buildAvatarImage() {
    // Kiểm tra đường dẫn URL
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      // Kiểm tra xem có phải là URL web không
      if (_imageUrl!.startsWith('http://') || _imageUrl!.startsWith('https://')) {
        // URL web, sử dụng Image.network
        print('Hiển thị ảnh từ URL web: $_imageUrl');
        return ClipOval(
          child: Image.network(
            _imageUrl!,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Lỗi tải ảnh từ URL web: $error');
              return _buildLocalAvatar();
            },
          ),
        );
      } else if (_imageUrl!.startsWith('file://')) {
        // URL file local, cần chuyển đổi thành đường dẫn file
        print('Hiển thị ảnh từ URL file: $_imageUrl');
        String filePath = _imageUrl!.replaceFirst('file://', '');
        return ClipOval(
          child: Image.file(
            File(filePath),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Lỗi tải ảnh từ file URL: $error');
              return _buildAvatarPlaceholder();
            },
          ),
        );
      } else if (_imageUrl!.startsWith('gs://')) {
        print('DEBUG: Phát hiện URL Firebase Storage (gs://): $_imageUrl');
        // Chuyển đổi gs:// URL thành HTTP URL và hiển thị ảnh
        return FutureBuilder<String>(
          future: _getDownloadUrlFromGs(_imageUrl!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    strokeWidth: 2,
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              print('Lỗi chuyển đổi gs:// URL: ${snapshot.error}');
              return _buildAvatarPlaceholder();
            } else if (snapshot.hasData) {
              return ClipOval(
                child: Image.network(
                  snapshot.data!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Lỗi tải ảnh từ Firebase URL: $error');
                    return _buildAvatarPlaceholder();
                  },
                ),
              );
            } else {
              return _buildAvatarPlaceholder();
            }
          },
        );
      }
    }
    
    // Nếu không có URL hoặc URL không hợp lệ, thử dùng imagePath
    return _buildLocalAvatar();
  }

  // Widget để hiển thị ảnh từ đường dẫn local với dạng avatar
  Widget _buildLocalAvatar() {
    if (_foodEntry.imagePath != null && _foodEntry.imagePath!.isNotEmpty) {
      String filePath = _foodEntry.imagePath!;

      // Xử lý URL file://
      if (filePath.startsWith('file://')) {
        filePath = filePath.replaceFirst('file://', '');
      }

      final file = File(filePath);
      print('DEBUG: Kiểm tra file ảnh tại: $filePath');
      print('DEBUG: File tồn tại: ${file.existsSync()}');

      try {
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Lỗi tải ảnh local: $error');
                return _buildAvatarPlaceholder();
              },
            ),
          );
        } else {
          print('DEBUG: File không tồn tại: $filePath');
          return _buildAvatarPlaceholder();
        }
      } catch (e) {
        print('Lỗi khi hiển thị ảnh local: $e');
        return _buildAvatarPlaceholder();
      }
    } else {
      print('DEBUG: Không có imagePath');
      return _buildAvatarPlaceholder();
    }
  }

  // Widget hiển thị placeholder chữ B khi không có ảnh
  Widget _buildAvatarPlaceholder() {
    return Text(
      'B',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.green.shade700,
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
    // Sử dụng các mục tiêu dinh dưỡng từ FoodProvider thay vì UserDataProvider
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final nutritionGoals = foodProvider.getNutritionGoals(context);

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
        cholesterolGoal: nutritionGoals['cholesterol'] ?? 300.0,
        omega3Goal: nutritionGoals['omega3'] ?? 1.6,
        fiberGoal: nutritionGoals['fiber'] ?? 25.0,
        waterGoal: nutritionGoals['water'] ?? 2000.0,
        sugarGoal: nutritionGoals['sugar'] ?? 50.0,
        saturatedFatGoal: nutritionGoals['saturatedFat'] ?? 20.0,
        caffeineGoal: nutritionGoals['caffeine'] ?? 400.0,
        alcoholGoal: nutritionGoals['alcohol'] ?? 14.0,
        vitaminDGoal: nutritionGoals['vitaminD'] ?? 15.0,
        vitaminB12Goal: nutritionGoals['vitaminB12'] ?? 2.4,
        vitaminCGoal: nutritionGoals['vitaminC'] ?? 75.0,
        vitaminBGoal: nutritionGoals['vitaminB'] ?? 15.0,
        ironGoal: nutritionGoals['iron'] ?? 18.0,
        calciumGoal: nutritionGoals['calcium'] ?? 1000.0,
        magnesiumGoal: nutritionGoals['magnesium'] ?? 400.0,
        potassiumGoal: nutritionGoals['potassium'] ?? 4700.0,
        // Các vi chất bổ sung từ API USDA
        vitaminAGoal: nutritionGoals['vitaminA'] ?? 900.0,
        vitaminEGoal: nutritionGoals['vitaminE'] ?? 15.0,
        vitaminKGoal: nutritionGoals['vitaminK'] ?? 120.0,
        thiaminGoal: nutritionGoals['thiamin'] ?? 1.2,
        riboflavinGoal: nutritionGoals['riboflavin'] ?? 1.3,
        niacinGoal: nutritionGoals['niacin'] ?? 16.0,
        phosphorusGoal: nutritionGoals['phosphorus'] ?? 700.0,
        seleniumGoal: nutritionGoals['selenium'] ?? 55.0,
        copperGoal: nutritionGoals['copper'] ?? 0.9,
        manganeseGoal: nutritionGoals['manganese'] ?? 2.3,
        transFatGoal: nutritionGoals['transFat'] ?? 2.0,
        useRadialGradient: true,
        backgroundColor: Colors.grey.shade50,
        showDetailedLabels: true,
        showMacroMainSummary: true,
      ),
    );
  }

  // SECTION: Actions & Event Handlers

  // Method để chọn ảnh từ gallery hoặc camera
  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Chọn từ thư viện'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      _foodEntry = _foodEntry.copyWith(imagePath: image.path);
                      _imageUrl = 'file://${image.path}';
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Chụp ảnh'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setState(() {
                      _foodEntry = _foodEntry.copyWith(imagePath: image.path);
                      _imageUrl = 'file://${image.path}';
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

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

    // Đảm bảo servingSize đồng bộ với totalWeight
    double effectiveServingSize = _servingSize;
    double totalWeight = effectiveServingSize * 100;

    // Kiểm tra nếu có nutritionInfo
    if (_foodEntry.nutritionInfo != null) {
      // Lấy servingSize từ nutritionInfo nếu có, nếu không thì dùng _servingSize
      double nutritionServingSize = _foodEntry.nutritionInfo!['servingSize'] is num
          ? (_foodEntry.nutritionInfo!['servingSize'] as num).toDouble()
          : effectiveServingSize;

      // Tính tỷ lệ để điều chỉnh giá trị dinh dưỡng theo servingSize hiện tại
      double ratio = effectiveServingSize / nutritionServingSize;

      // Lấy giá trị từ nutritionInfo và điều chỉnh theo tỷ lệ
      values['calories'] = _foodEntry.nutritionInfo!['calories'] is num
          ? ((_foodEntry.nutritionInfo!['calories'] as num).toDouble() * ratio)
          : _foodEntry.totalCalories;

      values['protein'] = _foodEntry.nutritionInfo!['protein'] is num
          ? ((_foodEntry.nutritionInfo!['protein'] as num).toDouble() * ratio)
          : _foodEntry.totalProtein;

      values['fat'] = _foodEntry.nutritionInfo!['fat'] is num
          ? ((_foodEntry.nutritionInfo!['fat'] as num).toDouble() * ratio)
          : _foodEntry.totalFat;

      values['carbs'] = _foodEntry.nutritionInfo!['carbs'] is num
          ? ((_foodEntry.nutritionInfo!['carbs'] as num).toDouble() * ratio)
          : _foodEntry.totalCarbs;

      values['fiber'] = _foodEntry.nutritionInfo!['fiber'] is num
          ? ((_foodEntry.nutritionInfo!['fiber'] as num).toDouble() * ratio)
          : _foodEntry.totalFiber;

      values['sugar'] = _foodEntry.nutritionInfo!['sugar'] is num
          ? ((_foodEntry.nutritionInfo!['sugar'] as num).toDouble() * ratio)
          : _foodEntry.totalSugar;

      values['sodium'] = _foodEntry.nutritionInfo!['sodium'] is num
          ? ((_foodEntry.nutritionInfo!['sodium'] as num).toDouble() * ratio)
          : _foodEntry.totalSodium;

      // Đảm bảo totalWeight luôn đồng bộ với servingSize hiện tại
      values['totalWeight'] = totalWeight;
    } else {
      // Nếu không có nutritionInfo, sử dụng giá trị từ items và điều chỉnh theo servingSize
      values['calories'] = _foodEntry.totalCalories;
      values['protein'] = _foodEntry.totalProtein;
      values['fat'] = _foodEntry.totalFat;
      values['carbs'] = _foodEntry.totalCarbs;
      values['fiber'] = _foodEntry.totalFiber;
      values['sugar'] = _foodEntry.totalSugar;
      values['sodium'] = _foodEntry.totalSodium;
      values['totalWeight'] = totalWeight;
    }

    return values;
  }

  // 🍽️ CHUYỂN MÓN ĂN SANG NGÀY KHÁC
  void _syncDateWithProvider() {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final selectedDate = foodProvider.selectedDate;

    final entryDateOnly = "${_foodEntry.dateTime.year}-${_foodEntry.dateTime.month.toString().padLeft(2, '0')}-${_foodEntry.dateTime.day.toString().padLeft(2, '0')}";

    print('🍽️ MoveFood: Ngày hiện tại của món ăn: $entryDateOnly');
    print('🍽️ MoveFood: Ngày được chọn: $selectedDate');

    // 🍽️ CHUYỂN MÓN ĂN: Khi user chọn ngày khác, món ăn sẽ chuyển sang ngày đó
    if (selectedDate != entryDateOnly && !_isEditing) {
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

        print('🍽️ MoveFood: ✅ CHUYỂN món ăn từ $entryDateOnly → $selectedDate');

        // Hiển thị thông báo cho user biết món ăn đã được chuyển
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📅 Đã chuyển món ăn sang ngày $selectedDate'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
            action: SnackBarAction(
              label: 'Hoàn tác',
              textColor: Colors.white,
              onPressed: () {
                // Hoàn tác việc chuyển ngày
                _undoDateChange(entryDateOnly);
              },
            ),
          ),
        );

        // Cập nhật _foodEntry với ngày mới
        setState(() {
          _foodEntry = FoodEntry(
            id: _foodEntry.id,
            description: _foodEntry.description,
            imagePath: _foodEntry.imagePath,
            imageUrl: _foodEntry.imageUrl,
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

        // Cập nhật trong provider để đồng bộ
        foodProvider.updateFoodEntry(_foodEntry);

      } catch (e) {
        print('❌ MoveFood: Lỗi khi chuyển ngày: $e');

        // Hiển thị thông báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi khi chuyển món ăn sang ngày mới'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (selectedDate == entryDateOnly) {
      print('🍽️ MoveFood: Món ăn đã ở đúng ngày được chọn');
    } else if (_isEditing) {
      print('🍽️ MoveFood: Đang edit, không chuyển ngày tự động');
    }
  }

  // 🔄 HOÀN TÁC VIỆC CHUYỂN NGÀY
  void _undoDateChange(String originalDate) {
    try {
      final dateParts = originalDate.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // Tạo DateTime với ngày gốc
      final originalDateTime = DateTime(
        year,
        month,
        day,
        _foodEntry.dateTime.hour,
        _foodEntry.dateTime.minute,
        _foodEntry.dateTime.second,
      );

      print('🔄 UndoDateChange: Hoàn tác về ngày gốc: $originalDate');

      // Cập nhật _foodEntry với ngày gốc
      setState(() {
        _foodEntry = _foodEntry.copyWith(dateTime: originalDateTime);
      });

      // Cập nhật provider để đồng bộ
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      foodProvider.updateFoodEntry(_foodEntry);

      // Cập nhật selectedDate trong provider về ngày gốc
      foodProvider.setSelectedDate(originalDate);

      // Hiển thị thông báo hoàn tác thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔄 Đã hoàn tác về ngày $originalDate'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('❌ UndoDateChange: Lỗi khi hoàn tác: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi khi hoàn tác thay đổi ngày'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
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

      // 🍽️ SAVE: Đảm bảo món ăn được lưu vào đúng ngày đã chọn
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final selectedDate = foodProvider.selectedDate;

      // Parse selectedDate để tạo DateTime với giờ phút giây từ updatedEntry
      DateTime finalDateTime = updatedEntry.dateTime;
      try {
        final dateParts = selectedDate.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);

        finalDateTime = DateTime(
          year,
          month,
          day,
          updatedEntry.dateTime.hour,
          updatedEntry.dateTime.minute,
          updatedEntry.dateTime.second,
        );

        print('🍽️ SaveAndExit: Lưu món ăn vào ngày: $selectedDate');
        print('🍽️ SaveAndExit: DateTime cuối cùng: ${finalDateTime.toString()}');
      } catch (e) {
        print('❌ SaveAndExit: Lỗi parse ngày, giữ nguyên: $e');
      }

      // Tạo final entry với ngày đã được chọn
      final finalEntry = updatedEntry.copyWith(dateTime: finalDateTime);

      // Gọi callback onSave để chỉ cập nhật bữa ăn (không thêm mới)
      widget.onSave(finalEntry);

      // Lấy chuỗi ngày từ selectedDate (đã chọn) thay vì từ DateTime
      String dateStr = selectedDate;

      // Tạo một kết quả để truyền về
      final result = {
        'foodEntriesUpdated': true,
        'selectedDate': dateStr,
        'updatedEntry': finalEntry,
        'updatedMealType': finalEntry.mealType,
      };

      // Hiển thị thông báo thành công với thông tin ngày
      final entryDateStr = "${finalEntry.dateTime.day}/${finalEntry.dateTime.month}/${finalEntry.dateTime.year}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã lưu món ăn vào ngày $entryDateStr'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Chuyển hướng đến màn hình Home và xóa tất cả màn hình trước đó trong stack
      Future.delayed(Duration(milliseconds: 500), () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
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

  // ✏️ SỬA THÔNG TIN MÓN ĂN (không ảnh hưởng đến ngày)
  Future<void> _editFoodDetails() async {
    // ✏️ Set editing state để tránh auto-move ngày khi đang edit
    setState(() {
      _isEditing = true;
    });

    try {
      print('✏️ EditFoodDetails: Bắt đầu sửa thông tin món ăn');

      final updatedEntry = await FoodNutritionActions.editFoodDetails(context, _foodEntry);
      if (updatedEntry != null && mounted) {
        setState(() {
          _foodEntry = updatedEntry;
        });

        print('✏️ EditFoodDetails: Đã cập nhật thông tin món ăn');

        // Đồng bộ lại với provider
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        foodProvider.updateFoodEntry(updatedEntry);

        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✏️ Đã cập nhật thông tin món ăn'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } finally {
      // Reset editing state để cho phép auto-move ngày trở lại
      setState(() {
        _isEditing = false;
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

  // Helper method để chuyển đổi gs:// URL thành HTTP URL
  Future<String> _getDownloadUrlFromGs(String gsUrl) async {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.refFromURL(gsUrl);
      final downloadUrl = await ref.getDownloadURL();
      print('DEBUG: Đã chuyển đổi gs:// URL thành HTTP URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('DEBUG: Lỗi chuyển đổi gs:// URL: $e');
      throw e;
    }
  }

  // Tải ảnh từ Firebase Storage
  Future<void> _loadImageFromFirebase() async {
    print('DEBUG: Bắt đầu tải ảnh cho món: ${_foodEntry.description}');
    
    if (_foodEntry.imageUrl != null && _foodEntry.imageUrl!.isNotEmpty) {
      // Nếu đã có imageUrl, kiểm tra loại URL
      print('DEBUG: Đã có imageUrl: ${_foodEntry.imageUrl}');
      
      // Kiểm tra loại URL
      if (_foodEntry.imageUrl!.startsWith('file://')) {
        print('DEBUG: imageUrl là file:// URL, cần xử lý đặc biệt');
        // URL file://, cần chuyển đổi thành đường dẫn thông thường
        // Không cần setState vì _buildAvatarImage() sẽ xử lý URL này
      }
      
      setState(() {
        _imageUrl = _foodEntry.imageUrl;
      });
      return;
    }
    
    if (_foodEntry.imagePath == null || _foodEntry.imagePath!.isEmpty) {
      // Không có đường dẫn ảnh
      print('DEBUG: Không có imagePath hoặc imageUrl');
      return;
    }
    
    setState(() {
      _isLoadingImage = true;
    });
    
    try {
      print('DEBUG: Kiểm tra imagePath: ${_foodEntry.imagePath}');
      // Kiểm tra xem imagePath là đường dẫn local hay đường dẫn Firebase Storage
      if (_foodEntry.imagePath!.startsWith('gs://') || _foodEntry.imagePath!.startsWith('https://')) {
        // Đây là đường dẫn Firebase Storage
        print('DEBUG: imagePath là URL Firebase Storage hoặc web');
        var ref = _storage.refFromURL(_foodEntry.imagePath!);
        var downloadUrl = await ref.getDownloadURL();
        print('DEBUG: Đã lấy được URL tải xuống: $downloadUrl');
        
        if (mounted) {
          setState(() {
            _imageUrl = downloadUrl;
            _isLoadingImage = false;
          });
          
          // Cập nhật imageUrl trong foodEntry
          _foodEntry = _foodEntry.copyWith(imageUrl: downloadUrl);
          
          // Cập nhật vào provider
          final foodProvider = Provider.of<FoodProvider>(context, listen: false);
          foodProvider.updateFoodEntry(_foodEntry);
        }
      } else if (_foodEntry.imagePath!.startsWith('file://')) {
        // Đường dẫn file://
        print('DEBUG: imagePath là URL file://: ${_foodEntry.imagePath}');
        setState(() {
          _imageUrl = _foodEntry.imagePath;
          _isLoadingImage = false;
        });
      } else {
        // Đây là đường dẫn local, cần upload lên Firebase Storage và lưu URL
        print('DEBUG: imagePath là đường dẫn local: ${_foodEntry.imagePath}');
        final file = File(_foodEntry.imagePath!);
        if (await file.exists()) {
          // Tạo đường dẫn trong Firebase Storage
          final userId = Provider.of<UserDataProvider>(context, listen: false).getCurrentUserId() ?? 'anonymous';
          final fileName = 'food_images/${userId}/${_foodEntry.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // Upload file lên Firebase Storage
          print('DEBUG: Bắt đầu upload file lên Firebase Storage');
          final uploadTask = _storage.ref(fileName).putFile(file);
          
          // Chờ upload hoàn tất
          final snapshot = await uploadTask;
          
          // Lấy URL download
          final downloadUrl = await snapshot.ref.getDownloadURL();
          print('DEBUG: Đã upload thành công, URL: $downloadUrl');
          
          if (mounted) {
            setState(() {
              _imageUrl = downloadUrl;
              _isLoadingImage = false;
            });
            
            // Cập nhật imageUrl trong foodEntry
            _foodEntry = _foodEntry.copyWith(imageUrl: downloadUrl);
            
            // Cập nhật vào provider
            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
            foodProvider.updateFoodEntry(_foodEntry);
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoadingImage = false;
            });
            print('DEBUG: Không tìm thấy file ảnh tại đường dẫn: ${_foodEntry.imagePath}');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
        print('DEBUG: Lỗi khi tải ảnh từ Firebase Storage: $e');
      }
    }
  }
  // Upload ảnh lên Firebase Storage
  @override
  void dispose() {
    // Lưu trữ tham chiếu đến provider trong initState hoặc didChangeDependencies để sử dụng ở đây
    // Không sử dụng Provider.of với context trong dispose() vì widget đã bị deactivated

    // Thực hiện các thao tác cần thiết không sử dụng context
    // Nếu cần phải làm mới dữ liệu, hãy gọi trước khi pop() màn hình trong các hàm khác

    super.dispose();
  }
} 