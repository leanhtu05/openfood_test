import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import 'package:openfood/providers/food_provider.dart';
import '../widgets/food_logging/food_description_input.dart';
import '../screens/combined_history_screen.dart';
import '../screens/food_search_screen.dart';
import '../screens/food_nutrition_detail_screen.dart';
import '../widgets/food_logging/food_logging_app_bar.dart';
import '../widgets/food_logging/ai_processing_dialog.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/user_data_provider.dart';
import '../screens/food_selection_confirmation_screen.dart';
// Import services
import '../services/image_handler_service.dart';
import '../services/voice_recording_service.dart';
import '../services/barcode_scanner_service.dart';
import '../services/food_entry_service.dart';
import '../services/food_ai_service.dart';
import '../utils/auth_helper.dart';

// Enum cho trạng thái nhận diện thực phẩm
enum RecognitionStatus {
  idle,
  processing,
  success,
  failed, none
}

class FoodLoggingScreen extends StatefulWidget {
  static const routeName = '/food-logging';
  
  // Thêm tham số initialDate để nhận ngày được chọn từ widget khác
  final String? initialDate;
  // Thêm tham số initialMealType để nhận loại bữa ăn được chọn
  final String? initialMealType;
  final VoidCallback? onDataChanged;
  
  const FoodLoggingScreen({
    Key? key, 
    this.initialDate,
    this.initialMealType,
    this.onDataChanged,
  }) : super(key: key);

  @override
  _FoodLoggingScreenState createState() => _FoodLoggingScreenState();
}

class _FoodLoggingScreenState extends State<FoodLoggingScreen> {
  // Services
  late final TextEditingController _descriptionController;
  late final ImageHandlerService _imageService;
  late final VoiceRecordingService _voiceRecordingService;
  late final BarcodeScannerService _barcodeScannerService;
  late final FoodEntryService _foodEntryService;
  late final FoodAIService _foodAIService;

  // State variables
  File? _foodImage;
  bool _isProcessing = false;
  String? _barcode;
  String _selectedMealType = 'Bữa sáng';
  String? _selectedDate;
  late String _mealTypeTitle;
  late FoodProvider _foodProvider;
  
  // AI recognition state
  List<FoodItem> _recognizedFoods = [];
  List<FoodItem> _selectedFoods = [];
  String? _foodImagePath;
  bool _isRecognizing = false;
  RecognitionStatus _recognitionStatus = RecognitionStatus.none;
  String _currentAIStep = '0';
  String _successMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeComponents();
  }

  void _initializeServices() {
    _descriptionController = TextEditingController();
    _imageService = ImageHandlerService();
    _voiceRecordingService = VoiceRecordingService();
    _barcodeScannerService = BarcodeScannerService();
    _foodEntryService = FoodEntryService();
    _foodAIService = FoodAIService();

  }

  void _initializeComponents() {
    // Sử dụng initialMealType nếu có
    if (widget.initialMealType != null && widget.initialMealType!.isNotEmpty) {
      _selectedMealType = widget.initialMealType!;
    }
    
    _mealTypeTitle = _getMealTypeTitle();
    _selectedDate = widget.initialDate;
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupProviders());
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

  String _getMealTypeTitle() => _selectedMealType;
  
  void _updateSelectedDate() {
    if (!mounted) return;
    
    if (_foodProvider.selectedDate != _selectedDate) {
      setState(() => _selectedDate = _foodProvider.selectedDate);
    }
  }

  @override
  void dispose() {
    _foodProvider.removeListener(_updateSelectedDate);
    _descriptionController.dispose();
    _voiceRecordingService.dispose();
    super.dispose();
  }

  // IMAGE HANDLING
  Future<void> _takeFoodPhoto() async {
    // Kiểm tra đăng nhập trước khi chụp ảnh
    final success = await AuthHelper.requireLogin(
      context,
      onAuthenticated: () => _performTakeFoodPhoto(),
      title: 'Chụp ảnh thức ăn',
      message: 'Mời bạn đăng nhập để trải nghiệm tính năng chụp ảnh và nhận diện thức ăn bằng AI',
      feature: 'chụp ảnh thức ăn',
    );

    if (!success) {
      // Người dùng không đăng nhập, hiển thị thông báo
      AuthHelper.showLoginRequiredSnackBar(
        context,
        feature: 'chụp ảnh thức ăn',
      );
    }
  }

  Future<void> _performTakeFoodPhoto() async {
    final imagePicker = ImagePicker();
    final XFile? image = await imagePicker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final File imageFile = File(image.path);

      setState(() {
        _foodImage = imageFile;
      });

      // Xử lý ảnh với phương thức mới để nhận diện thức ăn
      await _processImage(imageFile);
    }
  }
  
  Future<void> _pickFoodPhoto() async {
    // Kiểm tra đăng nhập trước khi chọn ảnh
    final success = await AuthHelper.requireLogin(
      context,
      onAuthenticated: () => _performPickFoodPhoto(),
      title: 'Chọn ảnh thức ăn',
      message: 'Mời bạn đăng nhập để trải nghiệm tính năng chọn ảnh và nhận diện thức ăn bằng AI',
      feature: 'chọn ảnh thức ăn',
    );

    if (!success) {
      // Người dùng không đăng nhập, hiển thị thông báo
      AuthHelper.showLoginRequiredSnackBar(
        context,
        feature: 'chọn ảnh thức ăn',
      );
    }
  }

  Future<void> _performPickFoodPhoto() async {
    final imagePicker = ImagePicker();
    final XFile? image = await imagePicker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File imageFile = File(image.path);

      setState(() {
        _foodImage = imageFile;
      });

      // Xử lý ảnh với phương thức mới để nhận diện thức ăn
      await _processImage(imageFile);
    }
  }
  
  void _handleImageCapture(File? image) {
      if (image != null) {
      setState(() => _foodImage = image);
        _analyzeImageAndShowEnhancedResults();
    } else {
      _showErrorMessage('Không thể tải ảnh');
    }
  }

  // FOOD ANALYSIS
  void _showEnhancedNutritionAnalysis(FoodEntry entry) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: entry,
          onSave: _handleFoodEntryUpdate,
        ),
      ),
    );
    
    // Xử lý kết quả nếu có 
    if (result != null) {
      _processNutritionAnalysisResult(result);
      
      // Nếu cập nhật thành công và người dùng có thể đã chọn "Lưu", 
      // không cần thực hiện thêm hành động nào vì FoodNutritionDetailScreen
      // đã xử lý việc chuyển hướng về Home
    }
  }
  
  void _handleFoodEntryUpdate(FoodEntry updatedEntry) {
    // Chỉ cập nhật, không thêm mới entry vào provider
    Provider.of<FoodProvider>(context, listen: false)
        .updateFoodEntry(updatedEntry);
    
    // Xóa cache dinh dưỡng để đảm bảo dữ liệu được cập nhật đúng
    Provider.of<FoodProvider>(context, listen: false).clearNutritionCache();
    
    // Thông báo dữ liệu đã thay đổi nếu có callback
    if (widget.onDataChanged != null) {
      widget.onDataChanged!();
    }
  }
  
  void _processNutritionAnalysisResult(dynamic result) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    if (result is Map<String, dynamic> && 
        result.containsKey('updatedEntry') && 
        result['updatedEntry'] is FoodEntry) {
      
      final updatedEntry = result['updatedEntry'] as FoodEntry;
      
      // Chỉ cập nhật entry trong provider, không thêm mới
      foodProvider.updateFoodEntry(updatedEntry);
      
      // Cập nhật ngày đã chọn nếu có
      if (result.containsKey('selectedDate')) {
        final selectedDate = result['selectedDate'] as String;
        foodProvider.setSelectedDate(selectedDate);
        setState(() => _selectedDate = selectedDate);
      }
      
      _updateSuccessState(updatedEntry);
    } 
    else if (result is FoodEntry) {
      // Chỉ cập nhật entry trong provider, không thêm mới
      foodProvider.updateFoodEntry(result);
      _updateSuccessState(result);
    }
  }
  
  void _updateSuccessState(FoodEntry entry) {
    setState(() {
      _isRecognizing = false;
      _recognitionStatus = RecognitionStatus.success;
      _successMessage = _foodAIService.generateSuccessMessage(entry);
    });
  }

  Future<void> _analyzeImageAndShowEnhancedResults() async {
    if (_foodImage == null) {
      _showErrorMessage('Vui lòng chụp hoặc chọn ảnh thực phẩm trước');
      return;
    }
    
    setState(() {
      _isRecognizing = true;
      _recognitionStatus = RecognitionStatus.processing;
      _currentAIStep = '0';
    });
    
    try {
      // Hiển thị dialog xử lý AI
      _showAIProcessingDialog();
      
      // Mô phỏng các bước xử lý AI để hiển thị trên UI
      _simulateAIProcessing();
      
      // Gọi API nhận diện thực phẩm
      final result = await _foodAIService.recognizeFoodFromImage(
        _foodImage!,
        _selectedMealType,
      );
      
      // Đóng dialog hiện tại
      if (mounted) {
        _closeProcessingDialog();
      }
      
      if (!mounted) return;
      
      if (result['success']) {
        // Chuyển đổi dữ liệu API thành FoodEntry
        final entry = _foodAIService.convertRecognitionResponseToFoodEntry(
          result['data'],
          _selectedMealType,
        );
        
        if (entry != null) {
          // Thêm vào provider
          final foodProvider = Provider.of<FoodProvider>(context, listen: false);
          foodProvider.addFoodEntry(entry);
          
          // Cập nhật UI với thông báo thành công
          setState(() {
            _recognitionStatus = RecognitionStatus.success;
            _successMessage = _foodAIService.generateSuccessMessage(entry);
            _isRecognizing = false;
            
            // Cập nhật mô tả nếu trống
            if (_descriptionController.text.isEmpty) {
              _descriptionController.text = entry.description;
            }
          });
          
          // Hiển thị kết quả phân tích chi tiết
          if (mounted) {
            _showEnhancedNutritionAnalysis(entry);
          }
        } else {
          setState(() {
            _recognitionStatus = RecognitionStatus.failed;
            _isRecognizing = false;
          });
          _showNoFoodDetectedMessage();
        }
      } else {
        // Xử lý lỗi từ API
        setState(() {
          _recognitionStatus = RecognitionStatus.failed;
          _isRecognizing = false;
        });
        _showErrorMessage(result['message'] ?? 'Lỗi khi nhận diện thực phẩm');
      }
    } catch (error) {
      debugPrint('Lỗi phân tích thực phẩm: $error');
      if (mounted) {
        _closeProcessingDialog();
        setState(() {
          _recognitionStatus = RecognitionStatus.failed;
          _isRecognizing = false;
        });
        _showAnalysisErrorMessage(error);
      }
    }
  }
  
  String _getDescription() {
    return _descriptionController.text.isNotEmpty 
        ? _descriptionController.text 
        : "Bữa ăn $_selectedMealType";
  }
  
  void _showAIProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AIProcessingDialog(
        currentStep: _currentAIStep,
        onCancel: () {
          setState(() {
            _isRecognizing = false;
            _recognitionStatus = RecognitionStatus.none;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
  
  Future<void> _simulateAIProcessing() async {
    // Bước 1: Phân tích hình ảnh
    await _updateAIStep('1', 'Đang phân tích hình ảnh...');
    await Future.delayed(Duration(seconds: 1));
    
    // Bước 2: Nhận diện món ăn
    await _updateAIStep('2', 'Đang nhận diện các món ăn...');
    await Future.delayed(Duration(seconds: 2));
    
    // Bước 3: Trích xuất thông tin dinh dưỡng
    await _updateAIStep('3', 'Đang phân tích thông tin dinh dưỡng...');
    await Future.delayed(Duration(seconds: 2));
    
    // Bước 4: Hoàn thành
    await _updateAIStep('4', 'Hoàn thành!');
    await Future.delayed(Duration(milliseconds: 500));
  }
  
  // Cập nhật bước trong quá trình xử lý AI
  Future<void> _updateAIStep(String step, String message) async {
    setState(() {
      _currentAIStep = step;
    });
    
    // Cập nhật dialog nếu đang hiển thị
    if (Navigator.canPop(context)) {
      // Dialog đang mở, cập nhật trạng thái
      if (mounted) {
        setState(() {});
      }
    }
    
    // Chờ một chút để tạo hiệu ứng chuyển động
    await Future.delayed(Duration(milliseconds: 200));
  }
  
  void _closeProcessingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
  
  void _handleSuccessfulAIAnalysis(List<FoodItem> recognizedItems) {
    // Cập nhật danh sách món ăn được nhận diện
    setState(() {
      _recognizedFoods = recognizedItems;
      _isRecognizing = false;
      _recognitionStatus = RecognitionStatus.success;
    });
    
    // Đóng dialog xử lý nếu đang hiển thị
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // Hiển thị màn hình xác nhận chọn món ăn
    if (recognizedItems.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodSelectionConfirmationScreen(
            recognizedFoods: recognizedItems,
            imagePath: _foodImagePath ?? '',
            onConfirm: (selectedFoods) {
              // Xử lý khi người dùng xác nhận lựa chọn và lưu từ màn hình chi tiết
              setState(() {
                _selectedFoods = selectedFoods;
              });
              
              // Silent save - removed snackbar for better UX
              
              // Đồng bộ thông tin calo và mục tiêu
              syncCaloriesAndGoalsAfterAdd(context);
            },
          ),
        ),
      );
    } else {
      _showNoFoodDetectedMessage();
    }
  }
  
  // Removed _showSnackbar method for better UX
  
  void _showNoFoodDetectedMessage() {
    // Silent handling - removed snackbar for better UX
  }
  
  void _showAnalysisErrorMessage(dynamic error) {
    // Silent error handling - removed snackbar for better UX
  }
    
  void _showErrorMessage(String message) {
    // Silent error handling - removed snackbar for better UX
  }
  
  // FOOD ENTRY MANAGEMENT
  Future<void> _saveFoodEntry() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorMessage('Vui lòng nhập mô tả bữa ăn');
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      if (_selectedDate == null || _selectedDate!.isEmpty) {
        _selectedDate = DateTime.now().toIso8601String().split('T')[0];
      }
      
      final description = _descriptionController.text;
      final mealType = _selectedMealType;
      // Gọi phiên bản mới của addFoodEntryManual với các tham số vị trí thay vì named parameters
      final entry = await foodProvider.addFoodEntryManual(
        description,
        mealType,
        [] // Danh sách items rỗng, sẽ được cập nhật sau nếu cần
      );
      
      // Chỉ gọi updateHomeScreenWithNewEntry nếu entry không phải null
      if (entry != null && mounted) {
        foodProvider.updateHomeScreenWithNewEntry(context, entry);
      }
      
      if (mounted) {
        syncCaloriesAndGoalsAfterAdd(context);
        
        if (widget.onDataChanged != null) widget.onDataChanged!();
        
        Navigator.pop(context, {
          'foodEntriesUpdated': true,
          'selectedDate': _selectedDate,
        });
      }
    } catch (e) {
      _showErrorMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // VOICE RECORDING
  void _startVoiceRecording() {
    _showErrorMessage('Tính năng ghi âm sẽ được cập nhật soon!');
  }

  Future<void> _toggleRecording() async {
    final result = await _voiceRecordingService.toggleRecording();
    
    if (!result['success']) {
      _showErrorMessage(result['message']);
      return;
    }
    
    _showErrorMessage(result['message']);
  }

  // BARCODE SCANNING
  Future<void> _scanBarcode() async {
    try {
      final barcode = await _barcodeScannerService.scanBarcode();
      
      if (barcode != null) {
        setState(() => _barcode = barcode);
          _showErrorMessage('Đã quét mã: $_barcode');
        await _searchProductByBarcode(barcode);
      } else {
        _showErrorMessage('Cần quyền truy cập camera để sử dụng tính năng này');
      }
    } catch (e) {
      _showErrorMessage('Không thể quét mã vạch');
    }
  }
  
  Future<void> _searchProductByBarcode(String barcode) async {
    setState(() => _isProcessing = true);
    
    try {
      await _foodEntryService.searchProductByBarcode(
        barcode, 
        _selectedMealType,
        _handleBarcodeProductFound,
        _handleBarcodeProductNotFound,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  
  void _handleBarcodeProductFound(FoodEntry entry) {
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        foodProvider.addFoodEntry(entry);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodNutritionDetailScreen(
              foodEntry: entry,
          onSave: (updatedEntry) => foodProvider.updateFoodEntry(updatedEntry),
            ),
          ),
        );
  }
  
  void _handleBarcodeProductNotFound() {
    // Silent handling - removed snackbar for better UX
  }

  // NAVIGATION AND DATABASE
  Future<void> _openFoodDatabase() async {
    try {
      print('🔍 Đang mở màn hình tìm kiếm thực phẩm...');

      // Thử navigation với route name trước
      dynamic result;
      try {
        result = await Navigator.pushNamed(context, FoodSearchScreen.routeName);
      } catch (routeError) {
        print('❌ Lỗi route, thử navigation trực tiếp: $routeError');
        // Fallback: Navigation trực tiếp
        result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FoodSearchScreen()),
        );
      }

      print('🔍 Kết quả từ FoodSearchScreen: $result');

      if (result is List<FoodItem> && result.isNotEmpty) {
        print('🔍 Xử lý nhiều món ăn: ${result.length} items');
        await _processMultipleFoodItems(result);
      } else if (result is FoodItem) {
        print('🔍 Xử lý một món ăn: ${result.name}');
        await _processSingleFoodItem(result);
      } else {
        print('🔍 Không có kết quả hoặc người dùng hủy');
      }
    } catch (e) {
      print('❌ Lỗi khi mở FoodSearchScreen: $e');
      _showErrorMessage('Không thể mở màn hình tìm kiếm. Vui lòng thử lại.');
    }
  }
  
  Future<void> _processMultipleFoodItems(List<FoodItem> items) async {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final DateTime selectedDateTime = _getSelectedDateTime();
    
    final description = items.map((item) => item.name).join(", ");
    final mealType = _selectedMealType;
    // Gọi addFoodEntryManual với tham số vị trí
    final entry = await foodProvider.addFoodEntryManual(
      description,
      mealType,
      items
    );
    
    await _showNutritionDetailAndUpdateUI(entry, foodProvider);
  }
  
  Future<void> _processSingleFoodItem(FoodItem item) async {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final DateTime selectedDateTime = _getSelectedDateTime();
    
    final description = item.name;
    final mealType = _selectedMealType;
    // Gọi addFoodEntryManual với tham số vị trí
    final entry = await foodProvider.addFoodEntryManual(
      description,
      mealType,
      [item] // Danh sách chỉ chứa một item
    );
    
    await _showNutritionDetailAndUpdateUI(entry, foodProvider);
  }
  
  DateTime _getSelectedDateTime() {
    return _selectedDate != null ? DateTime.parse(_selectedDate!) : DateTime.now();
  }
  
  // Sử dụng FoodEntry? thay vì FoodEntry để cho phép giá trị null
  Future<void> _showNutritionDetailAndUpdateUI(FoodEntry? entry, FoodProvider foodProvider) async {
    // Kiểm tra nếu entry là null thì thoát khỏi hàm
    if (entry == null) {
      print('Không thể hiển thị chi tiết dinh dưỡng vì entry là null');
      return;
    }
    
    final updateResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: entry,
          onSave: (updatedEntry) => foodProvider.updateFoodEntry(updatedEntry),
        ),
      ),
    );
    
    // Chỉ cập nhật UI nếu có kết quả trả về từ màn hình chi tiết dinh dưỡng
    if (updateResult != null) {
      if (updateResult is Map<String, dynamic> && updateResult.containsKey('updatedEntry')) {
        // Nếu kết quả là Map và có key 'updatedEntry', trích xuất entry đã cập nhật
        final updatedEntry = updateResult['updatedEntry'] as FoodEntry;
        
        // Cập nhật UI với entry đã cập nhật
        foodProvider.updateHomeScreenWithNewEntry(context, updatedEntry);
        
        // Đồng bộ mục tiêu calories và các giá trị khác
        syncCaloriesAndGoalsAfterAdd(context);
        
        // Thông báo dữ liệu đã thay đổi nếu có callback
        if (widget.onDataChanged != null) {
          widget.onDataChanged!();
        }
      } else if (updateResult is FoodEntry) {
        // Nếu kết quả trực tiếp là FoodEntry, cập nhật UI
        foodProvider.updateHomeScreenWithNewEntry(context, updateResult);
        
        // Đồng bộ mục tiêu calories và các giá trị khác
        syncCaloriesAndGoalsAfterAdd(context);
        
        // Thông báo dữ liệu đã thay đổi nếu có callback
        if (widget.onDataChanged != null) {
          widget.onDataChanged!();
        }
      }
    }
  }
  
  // UI ACTIONS
  void _showHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CombinedHistoryScreen(
          initialFilters: {'Thực phẩm'}, // Chỉ hiển thị thực phẩm
          customTitle: 'Lịch sử thực phẩm',
        ),
      ),
    );
  }
  
  void _showFavorites() {
    final favoriteItems = Provider.of<FoodProvider>(context, listen: false).favoriteItems;
    
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
    // 🔧 SỬA: Mở màn hình nhập thực phẩm mới thay vì chỉ điền text
    _openManualFoodEntryDialog();
  }

  // 🔧 THÊM: Method mở dialog nhập thực phẩm thủ công
  void _openManualFoodEntryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController nameController = TextEditingController();
        final TextEditingController caloriesController = TextEditingController();
        final TextEditingController proteinController = TextEditingController();
        final TextEditingController carbsController = TextEditingController();
        final TextEditingController fatController = TextEditingController();
        final TextEditingController servingSizeController = TextEditingController(text: '100');

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text('Thêm thực phẩm mới'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên thực phẩm *',
                    hintText: 'Ví dụ: Cơm trắng, Thịt bò, Cà chua...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.restaurant, color: Colors.green),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: servingSizeController,
                        decoration: InputDecoration(
                          labelText: 'Khối lượng (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: caloriesController,
                        decoration: InputDecoration(
                          labelText: 'Calories',
                          hintText: 'Ví dụ: 150',
                          border: OutlineInputBorder(),
                          suffixText: 'kcal',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: proteinController,
                        decoration: InputDecoration(
                          labelText: 'Protein (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: carbsController,
                        decoration: InputDecoration(
                          labelText: 'Carbs (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fatController,
                        decoration: InputDecoration(
                          labelText: 'Fat (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Thông tin dinh dưỡng cho ${servingSizeController.text}g',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập tên thực phẩm')),
                  );
                  return;
                }

                _createManualFoodEntry(
                  name: nameController.text.trim(),
                  calories: double.tryParse(caloriesController.text) ?? 0,
                  protein: double.tryParse(proteinController.text) ?? 0,
                  carbs: double.tryParse(carbsController.text) ?? 0,
                  fat: double.tryParse(fatController.text) ?? 0,
                  servingSize: double.tryParse(servingSizeController.text) ?? 100,
                );

                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  // 🔧 THÊM: Method tạo thực phẩm thủ công
  Future<void> _createManualFoodEntry({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double servingSize,
  }) async {
    try {
      // Tạo FoodItem từ thông tin nhập vào
      final foodItem = FoodItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        fiber: 0.0,
        sugar: 0.0,
        sodium: 0.0,
        servingSize: servingSize / 100, // Chuyển đổi về đơn vị khẩu phần (1 khẩu phần = 100g)
        servingUnit: 'g',
        imageUrl: null,
        additionalNutrients: {},
      );

      // Xử lý như một món ăn được chọn từ database
      await _processSingleFoodItem(foodItem);

      // Cập nhật mô tả
      _descriptionController.text = name;

      // Thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm "$name" vào nhật ký'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      print('Lỗi khi tạo thực phẩm thủ công: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra khi thêm thực phẩm'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for date changes from the provider
    final foodProvider = Provider.of<FoodProvider>(context);
    _selectedDate = foodProvider.selectedDate;
    
    return Scaffold(
      appBar: FoodLoggingAppBar(onSwitchToEmptyFood: _switchToEmptyFood),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
            children: _buildScreenContent(),
          ),
        ),
      ),
    );
  }
  
  List<Widget> _buildScreenContent() {
    return [
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
    ];
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
    return Column(
      children: [
        // 🔧 THÊM: Nút "Thêm món ăn mới" rõ ràng
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _openFoodDatabase,
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Thêm món ăn mới',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        // Các nút action khác
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.search, size: 36, color: Colors.blue),
              onPressed: _openFoodDatabase,
            ),
            SizedBox(width: 24),
            IconButton(
              icon: Icon(Icons.photo, size: 36, color: Colors.orange),
              onPressed: _pickFoodPhoto,
            ),
            SizedBox(width: 24),
            _buildCameraButton(),
          ],
        ),
      ],
    );
  }
  
  Widget _buildCameraButton() {
    return GestureDetector(
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
    );
  }
  
  Widget _buildSecondaryActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.qr_code_scanner, color: Colors.purple),
          onPressed: _scanBarcode,
        ),
        SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.history,
          label: 'Lịch Sử',
          onPressed: _showHistory,
        ),
        SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.star,
          label: 'Yêu thích',
          onPressed: _showFavorites,
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required VoidCallback onPressed
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.blue),
      label: Text(label, style: TextStyle(color: Colors.blue)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
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

  // Sau khi thêm món ăn thành công, cập nhật lại calo và mục tiêu nếu HomeScreen đang mounted
  void syncCaloriesAndGoalsAfterAdd(BuildContext context) {
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      foodProvider.notifyListeners();
      userDataProvider.notifyListeners();
    } catch (e) {
      print('Lỗi khi đồng bộ calo và mục tiêu: $e');
    }
  }

  // Phương thức xử lý nhận diện ảnh
  Future<void> _processImage(File imageFile) async {
    // Lưu đường dẫn ảnh
    _foodImagePath = imageFile.path;
    
    setState(() {
      _isRecognizing = true;
      _recognitionStatus = RecognitionStatus.processing;
      _currentAIStep = '0';
    });
    
    // Hiển thị dialog xử lý
    _showAIProcessingDialog();
    
    try {
      // Cập nhật bước 1: Phân tích hình ảnh
      await _updateAIStep('1', 'Đang phân tích hình ảnh...');
      await Future.delayed(Duration(milliseconds: 500));
      
      // Cập nhật bước 2: Nhận diện món ăn
      await _updateAIStep('2', 'Đang nhận diện các món ăn...');
      
      // Sử dụng FoodAIService để gọi API nhận diện thức ăn thực tế
      final result = await _foodAIService.recognizeFoodFromImage(
        imageFile, 
        _selectedMealType
      );
      
      // Cập nhật bước 3: Trích xuất thông tin dinh dưỡng
      await _updateAIStep('3', 'Đang phân tích thông tin dinh dưỡng...');
      
      if (result['success']) {
        // Chuyển đổi kết quả từ API thành FoodEntry
        final entry = _foodAIService.convertRecognitionResponseToFoodEntry(
          result['data'],
          _selectedMealType
        );
        
        // Chuyển đổi FoodEntry thành danh sách FoodItem để hiển thị xác nhận
        List<FoodItem> recognizedItems = entry?.items ?? [];
        
        // Cập nhật bước 4: Hoàn thành
        await _updateAIStep('4', 'Hoàn thành!');
        await Future.delayed(Duration(milliseconds: 500));
        
        // Xử lý kết quả thành công
        if (recognizedItems.isNotEmpty) {
          _handleSuccessfulAIAnalysis(recognizedItems);
        } else {
          // Nếu không có kết quả, hiển thị thông báo và sử dụng fallback
          _showNoFoodDetectedMessage();
          
          // Sử dụng phương thức demo để cung cấp kết quả fallback

        }
      } else {
        // Xử lý lỗi từ API
        setState(() {
          _isRecognizing = false;
          _recognitionStatus = RecognitionStatus.failed;
        });
        _showErrorMessage(result['message'] ?? 'Lỗi khi nhận diện thực phẩm');
        
        // Sử dụng phương thức demo làm fallback

      }
    } catch (error) {
      setState(() {
        _isRecognizing = false;
        _recognitionStatus = RecognitionStatus.failed;
      });
      _showAnalysisErrorMessage(error);
      
      // Sử dụng phương thức demo làm fallback khi có lỗi

    }
  }
  
  // Sử dụng nhận diện fallback khi API thất bại

  // Chuyển đổi tên món ăn thành FoodItem với thông tin dinh dưỡng
  Future<List<FoodItem>> _convertFoodNamesToItems(List<String> foodNames) async {
    // Trong thực tế, bạn sẽ lấy thông tin dinh dưỡng từ cơ sở dữ liệu hoặc API
    // Dưới đây là ví dụ với dữ liệu mẫu
    
    final Map<String, Map<String, dynamic>> foodDatabase = {
      'Phở bò': {
        'calories': 420.0,
        'protein': 25.0,
        'fat': 10.0,
        'carbs': 60.0,
      },
      'Phở gà': {
        'calories': 380.0,
        'protein': 22.0,
        'fat': 8.0,
        'carbs': 58.0,
      },
      'Bánh mì thịt': {
        'calories': 350.0,
        'protein': 15.0,
        'fat': 12.0,
        'carbs': 48.0,
      },
      'Cơm tấm sườn': {
        'calories': 520.0,
        'protein': 28.0,
        'fat': 18.0,
        'carbs': 65.0,
      },
      'Bún chả': {
        'calories': 450.0,
        'protein': 20.0,
        'fat': 15.0,
        'carbs': 55.0,
      },
      'Bún bò Huế': {
        'calories': 480.0,
        'protein': 24.0,
        'fat': 16.0,
        'carbs': 58.0,
      },
      'Bánh xèo': {
        'calories': 400.0,
        'protein': 10.0,
        'fat': 22.0,
        'carbs': 42.0,
      },
      'Gỏi cuốn': {
        'calories': 220.0,
        'protein': 12.0,
        'fat': 5.0,
        'carbs': 35.0,
      },
      'Chả giò': {
        'calories': 300.0,
        'protein': 8.0,
        'fat': 18.0,
        'carbs': 28.0,
      },
      'Cơm rang': {
        'calories': 380.0,
        'protein': 12.0,
        'fat': 10.0,
        'carbs': 60.0,
      },
      'Bún riêu': {
        'calories': 420.0,
        'protein': 18.0,
        'fat': 12.0,
        'carbs': 55.0,
      },
    };
    
    // Dữ liệu mặc định cho món không có trong cơ sở dữ liệu
    final defaultNutrition = {
      'calories': 350.0,
      'protein': 15.0,
      'fat': 12.0,
      'carbs': 45.0,
    };
    
    List<FoodItem> foodItems = [];
    
    for (int i = 0; i < foodNames.length; i++) {
      final foodName = foodNames[i];
      final nutritionData = foodDatabase[foodName] ?? defaultNutrition;
      
      foodItems.add(FoodItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_$i',
        name: foodName,
        calories: nutritionData['calories'] as double,
        protein: nutritionData['protein'] as double,
        fat: nutritionData['fat'] as double,
        carbs: nutritionData['carbs'] as double,
      ));
    }
    
    return foodItems;
  }
} 