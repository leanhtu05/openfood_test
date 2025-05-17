import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:intl/intl.dart';
import 'package:openfood/providers/food_provider.dart';
import 'package:openfood/services/food_database_service.dart';
import 'package:openfood/utils/food_data_adapter.dart';
import '../widgets/food_logging/food_description_input.dart';
import '../widgets/food_logging/food_image_preview.dart';
import '../widgets/food_logging/action_buttons.dart';
import '../widgets/food_logging/barcode_scanner_button.dart';
import '../widgets/food_logging/empty_food_button.dart';
import '../widgets/food_analysis/food_analysis_result.dart';
import '../widgets/food_analysis/nutrient_progress_indicator.dart';
import '../screens/food_history_screen.dart';
import '../screens/food_recognition_screen.dart';
import '../screens/food_search_screen.dart';
import '../screens/food_nutrition_detail_screen.dart';
import '../widgets/food_logging/food_logging_header.dart';
import '../widgets/food_logging/image_section.dart';
import '../widgets/custom_loading_indicator.dart';
import 'package:uuid/uuid.dart';
import '../providers/exercise_provider.dart';
import '../providers/water_provider.dart';

// Enum cho trạng thái nhận diện thực phẩm
enum RecognitionStatus {
  idle,
  processing,
  success,
  failed
}

class FoodLoggingScreen extends StatefulWidget {
  static const routeName = '/food-logging';
  
  // Thêm tham số initialDate để nhận ngày được chọn từ widget khác
  final String? initialDate;
  
  const FoodLoggingScreen({Key? key, this.initialDate}) : super(key: key);

  @override
  _FoodLoggingScreenState createState() => _FoodLoggingScreenState();
}

class _FoodLoggingScreenState extends State<FoodLoggingScreen> {
  // Controllers
  final TextEditingController _descriptionController = TextEditingController();
  final _audioRecorder = Record();
  final FoodDatabaseService _databaseService = FoodDatabaseService();
  final ImagePicker _picker = ImagePicker();
  
  // State variables
  File? _foodImage;
  bool _isProcessing = false;
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _audioPath;
  String? _barcode;
  String _selectedMealType = 'Bữa chính';
  String? _selectedDate;
  late String _mealTypeTitle;
  late FoodProvider _foodProvider;
  
  // AI recognition state
  bool _isRecognizing = false;
  RecognitionStatus _recognitionStatus = RecognitionStatus.idle;
  String successMessage = '';
  int _currentAIStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeComponents();
  }

  void _initializeComponents() {
    _databaseService.initialize();
    _mealTypeTitle = _getMealTypeTitle();
    _selectedDate = widget.initialDate;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupProviders();
    });
  }
  
  void _setupProviders() {
    _foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
    if (_selectedDate == null || _selectedDate!.isEmpty) {
      _selectedDate = _foodProvider.selectedDate;
    } else {
      _foodProvider.setSelectedDate(_selectedDate!);
    }
      
    _foodProvider.addListener(_updateSelectedDate);
  }

  String _getMealTypeTitle() {
    switch (_selectedMealType) {
      case 'Bữa sáng': return 'Bữa sáng';
      case 'Bữa trưa': return 'Bữa trưa';
      case 'Bữa tối': return 'Bữa tối';
      case 'Bữa phụ': return 'Bữa phụ';
      default: return 'Bữa chính';
    }
  }
  
  void _updateSelectedDate() {
    if(!mounted) return;
    
    if (_foodProvider.selectedDate != _selectedDate) {
      setState(() {
        _selectedDate = _foodProvider.selectedDate;
      });
      print('FoodLoggingScreen: Đã cập nhật _selectedDate từ provider: $_selectedDate');
    }
  }

  @override
  void dispose() {
    _foodProvider.removeListener(_updateSelectedDate);
    _descriptionController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // SECTION: IMAGE HANDLING
  Future<void> _takeFoodPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _foodImage = File(image.path);
        });
        _analyzeImageAndShowEnhancedResults();
      }
    } catch (e) {
      _showErrorMessage('Không thể chụp ảnh: $e');
    }
  }

  Future<void> _pickFoodPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _foodImage = File(image.path);
        });
        _analyzeImageAndShowEnhancedResults();
      }
    } catch (e) {
      _showErrorMessage('Không thể chọn ảnh: $e');
    }
  }

  // SECTION: FOOD ANALYSIS
  void _showEnhancedNutritionAnalysis(FoodEntry entry) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: entry,
          onSave: _handleFoodEntryUpdate,
        ),
      ),
    );
    
    if (result != null) {
      _processNutritionAnalysisResult(result);
    }
  }
  
  void _handleFoodEntryUpdate(FoodEntry updatedEntry) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    foodProvider.updateFoodEntry(updatedEntry);
    _logEntryDebugInfo('_handleFoodEntryUpdate', updatedEntry);
  }
  
  void _processNutritionAnalysisResult(dynamic result) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    if (result is Map<String, dynamic>) {
      print('_processNutritionAnalysisResult: Kết quả dạng Map');
      
      if (result.containsKey('updatedEntry') && result['updatedEntry'] is FoodEntry) {
        final updatedEntry = result['updatedEntry'] as FoodEntry;
        foodProvider.updateHomeScreenWithNewEntry(context, updatedEntry);
        
        if (result.containsKey('selectedDate')) {
          String selectedDate = result['selectedDate'];
          foodProvider.setSelectedDate(selectedDate);
          
          setState(() {
            _selectedDate = selectedDate;
          });
        }
        
        _updateSuccessState(updatedEntry);
      }
    } else if (result is FoodEntry) {
      foodProvider.updateHomeScreenWithNewEntry(context, result);
      _updateSuccessState(result);
    }
  }
  
  void _updateSuccessState(FoodEntry entry) {
    setState(() {
      _isRecognizing = false;
      _recognitionStatus = RecognitionStatus.success;
      final itemsCount = entry.items.length;
      if (itemsCount == 1) {
        successMessage = 'Đã nhận diện: ${entry.items.first.name} (${entry.totalCalories} kcal)';
      } else {
        successMessage = 'Đã nhận diện ${itemsCount} món ăn (${entry.totalCalories} kcal)';
      }
    });
  }
  
  void _logEntryDebugInfo(String prefix, FoodEntry entry) {
    print('$prefix: Entry ID: ${entry.id}');
    print('$prefix: Ngày: ${entry.dateTime}');
    print('$prefix: Loại bữa ăn: ${entry.mealType}');
    
    if (entry.items.isNotEmpty) {
      final item = entry.items.first;
      print('$prefix: Item name: ${item.name}');
      print('$prefix: Calories: ${item.calories}, Protein: ${item.protein}, Carbs: ${item.carbs}, Fat: ${item.fat}');
      print('$prefix: ServingSize: ${item.servingSize}');
    }
  }

  Future<FoodEntry?> _analyzeImageAndShowEnhancedResults() async {
    if (_foodImage == null) return null;
    
    setState(() {
      _isProcessing = true;
    });
    
    FoodEntry? resultEntry;
    
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final targetDate = foodProvider.selectedDate;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return _buildAIProcessingDialog();
        },
      );
      
      await _simulateAIProcessing();
      
      final entry = await foodProvider.addFoodEntryWithAI(
        image: _foodImage!,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : "Bữa ăn " + _selectedMealType,
        mealType: _selectedMealType,
        date: _selectedDate ?? targetDate,
      );
      
      _closeProcessingDialog();
      
      if (entry != null) {
        _handleSuccessfulAIAnalysis(entry);
        resultEntry = entry;
      } else {
        _showNoFoodDetectedMessage();
      }
    } catch (e) {
      _closeProcessingDialog();
      _showAnalysisErrorMessage(e);
    } finally {
      setState(() {
        _isProcessing = false;
        _currentAIStep = 0;
      });
    }
    
    return resultEntry;
  }
  
  Future<void> _simulateAIProcessing() async {
    await Future.delayed(Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() { _currentAIStep = 1; }); // Tiền xử lý ảnh
    
    await Future.delayed(Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() { _currentAIStep = 2; }); // Nhận diện món ăn
    
    await Future.delayed(Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() { _currentAIStep = 3; }); // Ước tính khẩu phần
    
    await Future.delayed(Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() { _currentAIStep = 4; }); // Tính toán dinh dưỡng
  }
  
  void _closeProcessingDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
  
  void _handleSuccessfulAIAnalysis(FoodEntry entry) {
    final itemsCount = entry.items.length;
    
    setState(() {
      if (itemsCount == 0) {
        successMessage = 'Đã lưu bữa ăn nhưng không tìm thấy thông tin dinh dưỡng chính xác.';
      } else if (itemsCount == 1) {
        successMessage = 'Đã nhận diện: ${entry.items.first.name} (${entry.totalCalories} kcal)';
      } else {
        successMessage = 'Đã nhận diện ${itemsCount} món ăn (${entry.totalCalories} kcal)';
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        duration: Duration(seconds: 3),
      )
    );
    
    if (_descriptionController.text.isEmpty) {
      setState(() {
        _descriptionController.text = entry.description;
      });
    }
    
    _showEnhancedNutritionAnalysis(entry);
  }
  
  void _showNoFoodDetectedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể nhận diện thực phẩm. Vui lòng thử lại hoặc nhập thủ công.'),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'TÌM KIẾM',
          onPressed: _openFoodDatabase,
        ),
      )
    );
  }
  
  void _showAnalysisErrorMessage(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi phân tích ảnh: $error'),
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'NHẬP THỦ CÔNG',
          onPressed: _openFoodDatabase,
        ),
      )
    );
    
    print('Exception during image analysis: $error');
  }
  
  // SECTION: FOOD ENTRY MANAGEMENT
  Future<void> _saveFoodEntry() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorMessage('Vui lòng nhập mô tả bữa ăn');
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      if (_selectedDate == null || _selectedDate!.isEmpty) {
        _selectedDate = DateTime.now().toIso8601String().split('T')[0];
      }
      
      final entry = await foodProvider.addFoodEntryManual(
        dateTime: DateTime.parse(_selectedDate!),
        description: _descriptionController.text,
        mealType: _selectedMealType,
        image: _foodImage,
      );
      
      print('Đã lưu bữa ăn: ${entry.description} (${entry.mealType}) cho ngày $_selectedDate');
      print('Thời gian lưu: ${entry.dateTime}');
      
      foodProvider.updateHomeScreenWithNewEntry(context, entry);
      
      final returnData = {
        'foodEntriesUpdated': true,
        'selectedDate': _selectedDate,
      };
      
      Navigator.of(context).pop(returnData);
    } catch (e) {
      print('Error saving food entry: $e');
      _showErrorMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // SECTION: VOICE RECORDING
  void _startVoiceRecording() {
    _showErrorMessage('Tính năng ghi âm sẽ được cập nhật soon!');
  }

  Future<void> _toggleRecording() async {
    final isGranted = await _requestPermission();
    if (!isGranted) return;
    
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioPath = path;
          _hasRecording = true;
        }
      });
      
      _showErrorMessage('Đã dừng ghi âm');
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/audio_$timestamp.m4a';
      
      await _audioRecorder.start(path: path);
      
      setState(() {
        _isRecording = true;
      });
      
      _showErrorMessage('Đang ghi âm... Nhấn lại để dừng');
    }
  }
  
  Future<bool> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showErrorMessage('Cần quyền truy cập microphone để sử dụng tính năng này');
      return false;
    }
    return true;
  }

  // SECTION: BARCODE SCANNING
  Future<void> _scanBarcode() async {
    try {
      final permissionStatus = await Permission.camera.request();
      
      if (permissionStatus.isGranted) {
        String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 
          'Hủy', 
          true, 
          ScanMode.BARCODE
        );
        
        if (barcodeScanRes != '-1') {
          setState(() {
            _barcode = barcodeScanRes;
          });
          
          _showErrorMessage('Đã quét mã: $_barcode');
          await _searchProductByBarcode(barcodeScanRes);
        }
      } else {
        _showErrorMessage('Cần quyền truy cập camera để sử dụng tính năng này');
      }
    } catch (e) {
      print('Lỗi khi quét mã vạch: $e');
      _showErrorMessage('Không thể quét mã vạch: $e');
    }
  }
  
  Future<void> _searchProductByBarcode(String barcode) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final items = await _databaseService.searchFoodByBarcode(barcode);
      
      if (items.isNotEmpty) {
        final uuid = Uuid();
        final String entryId = uuid.v4();
        
        final FoodItem foodItem = items.first;
        final entry = FoodEntry(
          id: entryId,
          description: foodItem.name,
          items: [foodItem],
          dateTime: DateTime.now(),
          mealType: _selectedMealType,
          barcode: barcode,
          nutritionInfo: _createNutritionInfoFromFoodItem(foodItem, barcode),
        );
        
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        foodProvider.addFoodEntry(entry);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodNutritionDetailScreen(
              foodEntry: entry,
              onSave: (updatedEntry) {
                foodProvider.updateFoodEntry(updatedEntry);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tìm thấy thông tin từ mã vạch. Thử tìm kiếm thủ công?'),
            action: SnackBarAction(
              label: 'TÌM KIẾM',
              onPressed: _openFoodDatabase,
            ),
          )
        );
      }
    } catch (e) {
      print('Lỗi khi tìm kiếm mã vạch: $e');
      _showErrorMessage('Không thể tìm kiếm mã vạch: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  Map<String, dynamic> _createNutritionInfoFromFoodItem(FoodItem item, String barcode) {
    return {
      'calories': item.calories,
      'protein': item.protein,
      'fat': item.fat,
      'carbs': item.carbs,
      'fiber': item.fiber,
      'sugar': item.sugar,
      'sodium': item.sodium,
      'servingSize': item.servingSize,
      'totalWeight': item.servingSize * 100,
      'dataSource': 'Database',
      'barcode': barcode,
      ...item.additionalNutrients ?? {},
    };
  }

  // SECTION: NAVIGATION AND DATABASE
  void _openFoodDatabase() async {
    final result = await Navigator.of(context).pushNamed(FoodSearchScreen.routeName);
    
    if (result is List<FoodItem> && result.isNotEmpty) {
      await _processMultipleFoodItems(result);
    } else if (result is FoodItem) {
      await _processSingleFoodItem(result);
    }
  }
  
  Future<void> _processMultipleFoodItems(List<FoodItem> items) async {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    final DateTime selectedDateTime = _selectedDate != null 
        ? DateTime.parse(_selectedDate!)
        : DateTime.now();
    
    final entry = await foodProvider.addFoodEntryManual(
      description: items.map((item) => item.name).join(", "),
      mealType: _selectedMealType,
      dateTime: selectedDateTime,
      items: items,
    );
    
    print('Đã tạo entry từ tìm kiếm với ngày: ${entry.dateTime}');
    
    await _showNutritionDetailAndUpdateUI(entry, foodProvider);
  }
  
  Future<void> _processSingleFoodItem(FoodItem item) async {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    final DateTime selectedDateTime = _selectedDate != null 
        ? DateTime.parse(_selectedDate!)
        : DateTime.now();
    
    final entry = await foodProvider.addFoodEntryManual(
      description: item.name,
      mealType: _selectedMealType,
      dateTime: selectedDateTime,
      items: [item],
    );
    
    print('Đã tạo entry từ item đơn lẻ với ngày: ${entry.dateTime}');
    
    await _showNutritionDetailAndUpdateUI(entry, foodProvider);
  }
  
  Future<void> _showNutritionDetailAndUpdateUI(FoodEntry entry, FoodProvider foodProvider) async {
    final updateResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: entry,
          onSave: (updatedEntry) {
            foodProvider.updateFoodEntry(updatedEntry);
            print('Đã cập nhật entry từ FoodNutritionDetailScreen với ngày: ${updatedEntry.dateTime}');
          },
        ),
      ),
    );
    
    if (updateResult != null) {
      foodProvider.updateHomeScreenWithNewEntry(
        context, 
        updateResult is FoodEntry ? updateResult : entry
      );
    }
  }
  
  void _showHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => FoodHistoryScreen())
    );
  }
  
  void _showFavorites() {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    List<FoodItem> favoriteItems = foodProvider.favoriteItems;
    
    if (favoriteItems.isEmpty) {
      _showErrorMessage('Bạn chưa có món ăn yêu thích nào');
      return;
    }
    
    _openFoodDatabase();
  }
  
  void _addToFavorites() {
    final description = _descriptionController.text;
    
    if (description.isEmpty && _foodImage == null) {
      _showErrorMessage('Vui lòng thêm ảnh hoặc mô tả bữa ăn trước khi đánh dấu yêu thích');
      return;
    }
    
    _saveFoodEntry();
  }
  
  void _switchToEmptyFood() {
    _descriptionController.text = "Bữa ăn trống";
    _showErrorMessage('Chuyển sang chế độ thực phẩm trống');
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodProvider = Provider.of<FoodProvider>(context);
    _selectedDate = foodProvider.selectedDate;
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildDescriptionBox(),
                SizedBox(height: 16),
                _buildInstructionText(),
                SizedBox(height: 16),
                _buildImageSection(),
                SizedBox(height: 24),
                _buildMainActionButtons(),
                SizedBox(height: 24),
                _buildSecondaryActionButtons(),
                SizedBox(height: 24),
                _buildFoodDescriptionInput(),
                SizedBox(height: 16),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: true,
      title: Row(
        children: [
          Icon(Icons.qr_code_2, color: Colors.green[800]),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Ghi lại thực phẩm', 
              style: TextStyle(color: Colors.green[800], fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Spacer(),
          TextButton(
            onPressed: _switchToEmptyFood,
            child: Text('Thực phẩm trống', style: TextStyle(color: Colors.blue)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
      iconTheme: IconThemeData(color: Colors.green[800]),
    );
  }
  
  Widget _buildDescriptionBox() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mô tả bữa ăn của bạn, ví dụ: "Một đĩa gà nướng với cơm, một phần nhỏ cà rốt luộc và hai ly nước cam"',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructionText() {
    return Text(
      'Chụp ảnh toàn bộ bữa ăn của bạn và/hoặc mô tả nó ở trên',
      style: TextStyle(fontSize: 16, color: Colors.black87),
      textAlign: TextAlign.center,
    );
  }
  
  Widget _buildImageSection() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(24),
      ),
      child: _foodImage != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.file(_foodImage!, fit: BoxFit.cover),
          )
        : Icon(Icons.camera_alt, size: 60, color: Colors.grey[400]),
    );
  }
  
  Widget _buildMainActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Search
        IconButton(
          icon: Icon(Icons.search, size: 36, color: Colors.blue),
          onPressed: _openFoodDatabase,
        ),
        SizedBox(width: 24),
        // Gallery
        IconButton(
          icon: Icon(Icons.photo, size: 36, color: Colors.orange),
          onPressed: _pickFoodPhoto,
        ),
        SizedBox(width: 24),
        // Camera (nút lớn)
        GestureDetector(
          onTap: _takeFoodPhoto,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green[700]!, width: 4),
            ),
            child: Icon(Icons.camera_alt, color: Colors.white, size: 40),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSecondaryActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Barcode
        IconButton(
          icon: Icon(Icons.qr_code_scanner, color: Colors.purple),
          onPressed: _scanBarcode,
        ),
        SizedBox(width: 8),
        // Lịch sử
        ElevatedButton.icon(
          onPressed: _showHistory,
          icon: Icon(Icons.history, color: Colors.blue),
          label: Text('Lịch Sử', style: TextStyle(color: Colors.blue)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
        SizedBox(width: 8),
        // Yêu thích
        ElevatedButton.icon(
          onPressed: _showFavorites,
          icon: Icon(Icons.star, color: Colors.blue),
          label: Text('Yêu thích', style: TextStyle(color: Colors.blue)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFoodDescriptionInput() {
    return FoodDescriptionInput(
      controller: _descriptionController,
      onSubmit: _saveFoodEntry,
    );
  }
  
  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveFoodEntry,
      child: Text('Lưu bữa ăn'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // SECTION: UI COMPONENTS
  Widget _buildAIProcessingDialog() {
    return AlertDialog(
      contentPadding: EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Phân tích bữa ăn bằng AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            _buildAIProcessStep(
              icon: Icons.image,
              title: 'Tiền xử lý ảnh',
              description: 'Chuẩn hóa ảnh, tăng độ tương phản, loại bỏ nhiễu...',
              isActive: _currentAIStep >= 1,
              isProcessing: _currentAIStep == 1,
            ),
            
            _buildStepConnector(),
            
            _buildAIProcessStep(
              icon: Icons.food_bank,
              title: 'Nhận diện món ăn',
              description: 'AI phân tích và nhận diện các loại thực phẩm trong ảnh',
              isActive: _currentAIStep >= 2,
              isProcessing: _currentAIStep == 2,
            ),
            
            _buildStepConnector(),
            
            _buildAIProcessStep(
              icon: Icons.scale,
              title: 'Ước tính khẩu phần',
              description: 'Phân tích kích thước và ước tính khối lượng từng món',
              isActive: _currentAIStep >= 3,
              isProcessing: _currentAIStep == 3,
            ),
            
            _buildStepConnector(),
            
            _buildAIProcessStep(
              icon: Icons.calculate,
              title: 'Tính toán dinh dưỡng',
              description: 'Tính toán calo, protein, carbs, chất béo từ dữ liệu nhận diện',
              isActive: _currentAIStep >= 4,
              isProcessing: _currentAIStep == 4,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAIProcessStep({
    required IconData icon,
    required String title,
    required String description,
    required bool isActive,
    required bool isProcessing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: isProcessing
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                )
              : Icon(
                  isActive ? (isProcessing ? Icons.hourglass_empty : Icons.check) : icon,
                  color: isActive ? Colors.white : Colors.grey,
                ),
        ),
        SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.black : Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.grey[700] : Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStepConnector() {
    return Container(
      margin: EdgeInsets.only(left: 20),
      height: 20,
      width: 2,
      color: Colors.grey.withOpacity(0.3),
    );
  }
} 