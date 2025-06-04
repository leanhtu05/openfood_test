import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:math';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:intl/intl.dart';
import 'package:openfood/providers/food_provider.dart';
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
import '../widgets/food_logging/food_logging_app_bar.dart';
import '../widgets/food_logging/ai_processing_dialog.dart';

// Import services
import '../services/image_handler_service.dart';
import '../services/voice_recording_service.dart';
import '../services/barcode_scanner_service.dart';
import '../services/food_entry_service.dart';
import '../services/food_ai_service.dart';
import '../providers/user_data_provider.dart';

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
  String _selectedMealType = 'Bữa chính';
  String? _selectedDate;
  late String _mealTypeTitle;
  late FoodProvider _foodProvider;
  
  // AI recognition state
  bool _isRecognizing = false;
  RecognitionStatus _recognitionStatus = RecognitionStatus.idle;
  String _successMessage = '';
  int _currentAIStep = 0;

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
    final image = await _imageService.takeFoodPhoto();
    _handleImageCapture(image);
  }

  Future<void> _pickFoodPhoto() async {
    final image = await _imageService.pickFoodPhoto();
    _handleImageCapture(image);
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
    
    if (result != null) {
      _processNutritionAnalysisResult(result);
    }
  }
  
  void _handleFoodEntryUpdate(FoodEntry updatedEntry) {
    Provider.of<FoodProvider>(context, listen: false)
        .updateFoodEntry(updatedEntry);
  }
  
  void _processNutritionAnalysisResult(dynamic result) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    if (result is Map<String, dynamic> && 
        result.containsKey('updatedEntry') && 
        result['updatedEntry'] is FoodEntry) {
      
        final updatedEntry = result['updatedEntry'] as FoodEntry;
        foodProvider.updateHomeScreenWithNewEntry(context, updatedEntry);
        
        if (result.containsKey('selectedDate')) {
        final selectedDate = result['selectedDate'] as String;
          foodProvider.setSelectedDate(selectedDate);
        setState(() => _selectedDate = selectedDate);
        }
        
        _updateSuccessState(updatedEntry);
    } else if (result is FoodEntry) {
      foodProvider.updateHomeScreenWithNewEntry(context, result);
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
      _currentAIStep = 0;
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
      builder: (context) => AIProcessingDialog(currentStep: _currentAIStep),
    );
  }
  
  Future<void> _simulateAIProcessing() async {
    await _foodAIService.simulateAIProcessing((step) {
    if (!mounted) return;
      setState(() => _currentAIStep = step);
    });
  }
  
  void _closeProcessingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
  
  void _handleSuccessfulAIAnalysis(FoodEntry entry) {
    // Update UI with success message
    _successMessage = _foodAIService.generateSuccessMessage(entry);
    _showSnackbar(_successMessage);
    
    // Update description if empty
    if (_descriptionController.text.isEmpty) {
      setState(() => _descriptionController.text = entry.description);
    }
    
    // Show nutrition details
    _showEnhancedNutritionAnalysis(entry);
  }
  
  void _showSnackbar(String message, {int seconds = 3, SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: seconds),
        action: action,
      )
    );
  }
  
  void _showNoFoodDetectedMessage() {
    _showSnackbar(
      'Không thể nhận diện thực phẩm. Vui lòng thử lại hoặc nhập thủ công.',
      seconds: 4,
        action: SnackBarAction(
          label: 'TÌM KIẾM',
          onPressed: _openFoodDatabase,
        ),
    );
  }
  
  void _showAnalysisErrorMessage(dynamic error) {
    _showSnackbar(
      'Lỗi khi phân tích ảnh: $error',
      seconds: 5,
        action: SnackBarAction(
          label: 'NHẬP THỦ CÔNG',
          onPressed: _openFoodDatabase,
        ),
    );
  }
    
  void _showErrorMessage(String message) {
    _showSnackbar(message);
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
    _showSnackbar(
      'Không tìm thấy thông tin từ mã vạch. Thử tìm kiếm thủ công?',
            action: SnackBarAction(
              label: 'TÌM KIẾM',
              onPressed: _openFoodDatabase,
            ),
    );
  }

  // NAVIGATION AND DATABASE
  Future<void> _openFoodDatabase() async {
    final result = await Navigator.pushNamed(context, FoodSearchScreen.routeName);
    
    if (result is List<FoodItem> && result.isNotEmpty) {
      await _processMultipleFoodItems(result);
    } else if (result is FoodItem) {
      await _processSingleFoodItem(result);
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
    
    if (updateResult != null) {
      foodProvider.updateHomeScreenWithNewEntry(
        context, 
        updateResult is FoodEntry ? updateResult : entry
      );
    }
  }
  
  // UI ACTIONS
  void _showHistory() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => FoodHistoryScreen())
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
    _descriptionController.text = "Bữa ăn trống";
    _showErrorMessage('Chuyển sang chế độ thực phẩm trống');
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
    return Row(
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
} 