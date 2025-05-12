import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:intl/intl.dart';
import 'package:openfood/providers/food_provider.dart';
import 'package:openfood/services/food_database_service.dart';
import 'package:openfood/utils/food_data_adapter.dart';
import '../models/food_item.dart';

// Import các widget con đã tách
import '../widgets/food_logging/food_description_input.dart';
import '../widgets/food_logging/food_image_preview.dart';
import '../widgets/food_logging/action_buttons.dart';
import '../widgets/food_logging/barcode_scanner_button.dart';
import '../widgets/food_logging/empty_food_button.dart';
import '../widgets/food_analysis/food_analysis_result.dart';
import '../widgets/food_analysis/nutrient_progress_indicator.dart';

// Import provider và models
import '../providers/food_provider.dart';
import '../models/food_entry.dart';
import '../screens/food_history_screen.dart';
import '../screens/food_recognition_screen.dart';
import '../screens/food_search_screen.dart';
import '../screens/food_nutrition_detail_screen.dart';
import '../widgets/food_logging/food_logging_header.dart';
import '../widgets/food_logging/image_section.dart';
import '../widgets/custom_loading_indicator.dart';

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
  final TextEditingController _descriptionController = TextEditingController();
  final FoodDatabaseService _databaseService = FoodDatabaseService();
  File? _foodImage;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _audioPath;
  String? _barcode;
  String _selectedMealType = 'Bữa sáng'; // Added class level variable for meal type
  String? _selectedDate; // Add this variable to store the selected date
  
  // Biến cho nhận diện thực phẩm
  bool _isRecognizing = false;
  RecognitionStatus _recognitionStatus = RecognitionStatus.idle;
  String successMessage = '';
  
  // Record instance để ghi âm
  final _audioRecorder = Record();
  
  // Biến theo dõi bước đang xử lý của AI
  int _currentAIStep = 0;
  
  @override
  void initState() {
    super.initState();
    _databaseService.initialize();
    
    // Get the current selected date from FoodProvider when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      // Sử dụng initialDate nếu có, nếu không thì dùng selectedDate từ provider
      _selectedDate = widget.initialDate ?? foodProvider.selectedDate;
      
      // Đồng bộ ngày đã chọn với provider
      if (widget.initialDate != null && widget.initialDate != foodProvider.selectedDate) {
        foodProvider.setSelectedDate(widget.initialDate!);
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // Chụp ảnh từ camera
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
        
        // Phân tích ảnh nếu cần
        _analyzeImageAndShowEnhancedResults();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chụp ảnh: $e')),
      );
    }
  }

  // Chọn ảnh từ thư viện
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
        
        // Phân tích ảnh nếu cần
        _analyzeImageAndShowEnhancedResults();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
  }

  // Hiển thị kết quả phân tích dinh dưỡng theo định dạng của food nutrition detail screen
  void _showEnhancedNutritionAnalysis(FoodEntry entry) async {
    // Hiển thị màn hình chi tiết dinh dưỡng và chờ kết quả
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: entry,
          onSave: (updatedEntry) {
            // Lưu kết quả đã chỉnh sửa
            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
            
            // Lưu vào cơ sở dữ liệu
            foodProvider.updateFoodEntry(updatedEntry);
            
            // In log thông tin để debug
            print('_showEnhancedNutritionAnalysis: Đã cập nhật entry: ${updatedEntry.id}');
            print('_showEnhancedNutritionAnalysis: Ngày: ${updatedEntry.dateTime}');
            print('_showEnhancedNutritionAnalysis: Loại bữa ăn: ${updatedEntry.mealType}');
            
            // Kiểm tra dữ liệu dinh dưỡng
            if (updatedEntry.items.isNotEmpty) {
              final item = updatedEntry.items.first;
              print('_showEnhancedNutritionAnalysis: Item name: ${item.name}');
              print('_showEnhancedNutritionAnalysis: Calories: ${item.calories}, Protein: ${item.protein}, Carbs: ${item.carbs}, Fat: ${item.fat}');
              print('_showEnhancedNutritionAnalysis: ServingSize: ${item.servingSize}');
            }
          },
        ),
      ),
    );
    
    // Cập nhật UI và hiển thị thông báo nếu có dữ liệu trả về
    if (result != null) {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // In log để debug kết quả trả về
      print('_showEnhancedNutritionAnalysis: Nhận kết quả từ màn hình chi tiết:');
      if (result is Map<String, dynamic>) {
        print('_showEnhancedNutritionAnalysis: Kết quả dạng Map');
        print('_showEnhancedNutritionAnalysis: Các key: ${result.keys.join(', ')}');
        
        if (result.containsKey('updatedEntry') && result['updatedEntry'] is FoodEntry) {
          final updatedEntry = result['updatedEntry'] as FoodEntry;
          print('_showEnhancedNutritionAnalysis: updatedEntry.dateTime: ${updatedEntry.dateTime}');
          
          // Đảm bảo cập nhật UI
          foodProvider.updateHomeScreenWithNewEntry(context, updatedEntry);
          
          // Đảm bảo ngày được cập nhật đúng nếu có
          if (result.containsKey('selectedDate')) {
            String selectedDate = result['selectedDate'];
            print('_showEnhancedNutritionAnalysis: Cập nhật ngày được chọn: $selectedDate');
            
            // Cập nhật ngày được chọn trong provider
            foodProvider.setSelectedDate(selectedDate);
            
            // Cập nhật biến local
            setState(() {
              _selectedDate = selectedDate;
            });
          }
          
          // Hiển thị thông báo thành công
          setState(() {
            _isRecognizing = false;
            _recognitionStatus = RecognitionStatus.success;
            final itemsCount = updatedEntry.items.length;
            if (itemsCount == 1) {
              successMessage = 'Đã nhận diện: ${updatedEntry.items.first.name} (${updatedEntry.totalCalories} kcal)';
            } else {
              successMessage = 'Đã nhận diện ${itemsCount} món ăn (${updatedEntry.totalCalories} kcal)';
            }
          });
        }
      } else if (result is FoodEntry) {
        print('_showEnhancedNutritionAnalysis: Kết quả dạng FoodEntry');
        foodProvider.updateHomeScreenWithNewEntry(context, result);
        
        // Hiển thị thông báo thành công
        setState(() {
          _isRecognizing = false;
          _recognitionStatus = RecognitionStatus.success;
          final itemsCount = result.items.length;
          if (itemsCount == 1) {
            successMessage = 'Đã nhận diện: ${result.items.first.name} (${result.totalCalories} kcal)';
          } else {
            successMessage = 'Đã nhận diện ${itemsCount} món ăn (${result.totalCalories} kcal)';
          }
        });
      }
    }
  }

  // Phân tích ảnh thực phẩm với AI và hiển thị kết quả theo format mới
  Future<FoodEntry?> _analyzeImageAndShowEnhancedResults() async {
    if (_foodImage == null) return null;
    
    setState(() {
      _isProcessing = true;
    });
    
    FoodEntry? resultEntry;
    
    try {
      // Sử dụng FoodProvider để phân tích ảnh bằng AI
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final targetDate = foodProvider.selectedDate;
      
      // Hiển thị dialog tiến trình phân tích theo các bước của AI
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return _buildAIProcessingDialog();
        },
      );
      
      // Mô phỏng các bước xử lý AI
      await Future.delayed(Duration(milliseconds: 800));
      if (!mounted) return null;
      setState(() {
        _currentAIStep = 1; // Tiền xử lý ảnh
      });
      
      await Future.delayed(Duration(milliseconds: 1500));
      if (!mounted) return null;
      setState(() {
        _currentAIStep = 2; // Nhận diện món ăn
      });
      
      await Future.delayed(Duration(milliseconds: 800));
      if (!mounted) return null;
      setState(() {
        _currentAIStep = 3; // Ước tính khẩu phần
      });
      
      await Future.delayed(Duration(milliseconds: 800));
      if (!mounted) return null;
      setState(() {
        _currentAIStep = 4; // Tính toán dinh dưỡng
      });
      
      // Thực hiện nhận diện thực phẩm với AI và sử dụng ngày đã chọn
      final entry = await foodProvider.addFoodEntryWithAI(
        image: _foodImage!,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : "Bữa ăn " + _selectedMealType,
        mealType: _selectedMealType,
        date: _selectedDate ?? targetDate, // Sử dụng ngày đã chọn (ưu tiên _selectedDate nếu có)
      );
      
      // Đóng dialog tiến trình
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (entry != null) {
        final itemsCount = entry.items.length;
        
        if (itemsCount == 0) {
          setState(() {
            successMessage = 'Đã lưu bữa ăn nhưng không tìm thấy thông tin dinh dưỡng chính xác.';
          });
        } else if (itemsCount == 1) {
          setState(() {
            successMessage = 'Đã nhận diện: ${entry.items.first.name} (${entry.totalCalories} kcal)';
          });
        } else {
          setState(() {
            successMessage = 'Đã nhận diện ${itemsCount} món ăn (${entry.totalCalories} kcal)';
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            duration: Duration(seconds: 3),
          )
        );
        
        // Cập nhật trường mô tả nếu trống
        if (_descriptionController.text.isEmpty) {
          setState(() {
            _descriptionController.text = entry.description;
          });
        }
        
        // Hiển thị màn hình kết quả phân tích chi tiết
        _showEnhancedNutritionAnalysis(entry);
        
        // Lưu kết quả
        resultEntry = entry;
        
        // In log để debug
        print('_analyzeImageAndShowEnhancedResults: Đã tạo entry với AI vào ngày: ${entry.dateTime}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể nhận diện thực phẩm. Vui lòng thử lại hoặc nhập thủ công.'),
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'TÌM KIẾM',
              onPressed: () {
                _openFoodDatabase();
              },
            ),
          )
        );
      }
    } catch (e) {
      // Đóng dialog tiến trình nếu có lỗi
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi phân tích ảnh: $e'),
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'NHẬP THỦ CÔNG',
            onPressed: () {
              _openFoodDatabase();
            },
          ),
        )
      );
      
      print('Exception during image analysis: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _currentAIStep = 0;
      });
    }
    
    return resultEntry;
  }
  
  // Dialog hiển thị tiến trình phân tích AI
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
            
            // Bước 1: Tiền xử lý ảnh
            _buildAIProcessStep(
              icon: Icons.image,
              title: 'Tiền xử lý ảnh',
              description: 'Chuẩn hóa ảnh, tăng độ tương phản, loại bỏ nhiễu...',
              isActive: _currentAIStep >= 1,
              isProcessing: _currentAIStep == 1,
            ),
            
            _buildStepConnector(),
            
            // Bước 2: Nhận diện món ăn
            _buildAIProcessStep(
              icon: Icons.food_bank,
              title: 'Nhận diện món ăn',
              description: 'AI phân tích và nhận diện các loại thực phẩm trong ảnh',
              isActive: _currentAIStep >= 2,
              isProcessing: _currentAIStep == 2,
            ),
            
            _buildStepConnector(),
            
            // Bước 3: Ước tính khẩu phần
            _buildAIProcessStep(
              icon: Icons.scale,
              title: 'Ước tính khẩu phần',
              description: 'Phân tích kích thước và ước tính khối lượng từng món',
              isActive: _currentAIStep >= 3,
              isProcessing: _currentAIStep == 3,
            ),
            
            _buildStepConnector(),
            
            // Bước 4: Tính toán dinh dưỡng
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
  
  // Widget hiển thị từng bước xử lý của AI
  Widget _buildAIProcessStep({
    required IconData icon,
    required String title,
    required String description,
    required bool isActive,
    required bool isProcessing,
  }) {
    return Row(
      children: [
        // Icon trạng thái
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
        
        // Thông tin bước
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
  
  // Đường kết nối giữa các bước
  Widget _buildStepConnector() {
    return Container(
      margin: EdgeInsets.only(left: 20),
      height: 20,
      width: 2,
      color: Colors.grey.withOpacity(0.3),
    );
  }
  
  // Phương thức để lưu bữa ăn mới
  Future<void> _saveFoodEntry() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập mô tả bữa ăn')),
      );
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Thay vì sử dụng ngày hiện tại, sử dụng ngày đã chọn (_selectedDate)
      // This is important to ensure we save entries to the selected date
      final entry = await foodProvider.addFoodEntryForDate(
        date: _selectedDate!, // Sử dụng ngày đã chọn
        description: _descriptionController.text,
        mealType: _selectedMealType,
        image: _foodImage,
      );
      
      // In ra log để debug
      print('Đã lưu bữa ăn: ${entry.description} (${entry.mealType}) cho ngày $_selectedDate');
      print('Thời gian lưu: ${entry.dateTime}');
      
      // Cập nhật giao diện Home
      foodProvider.updateHomeScreenWithNewEntry(context, entry);
      
      // Tạo data để trả về màn hình trước đó
      final returnData = {
        'foodEntriesUpdated': true,
        'selectedDate': _selectedDate,
      };
      
      // Quay về màn hình trước với data
      Navigator.of(context).pop(returnData);
    } catch (e) {
      print('Error saving food entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Ghi âm mô tả (sẽ tích hợp speech-to-text sau)
  void _startVoiceRecording() {
    // Sẽ tích hợp sau
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tính năng ghi âm sẽ được cập nhật soon!')),
    );
  }

  // Phương thức ghi âm
  Future<void> _toggleRecording() async {
    // Kiểm tra quyền ghi âm
    final isGranted = await _requestPermission();
    if (!isGranted) return;
    
    if (_isRecording) {
      // Dừng ghi âm
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioPath = path;
          _hasRecording = true;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã dừng ghi âm'))
      );
    } else {
      // Chuẩn bị đường dẫn lưu file âm thanh
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/audio_$timestamp.m4a';
      
      // Bắt đầu ghi âm
      await _audioRecorder.start(path: path);
      
      setState(() {
        _isRecording = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đang ghi âm... Nhấn lại để dừng'))
      );
    }
  }
  
  // Yêu cầu quyền ghi âm
  Future<bool> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cần quyền truy cập microphone để sử dụng tính năng này'))
      );
      return false;
    }
    return true;
  }

  // Phương thức quét mã vạch
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
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã quét mã: $_barcode'))
          );
          
          // Tìm kiếm thông tin sản phẩm từ mã vạch
          await _searchProductByBarcode(barcodeScanRes);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cần quyền truy cập camera để sử dụng tính năng này'))
        );
      }
    } catch (e) {
      print('Lỗi khi quét mã vạch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể quét mã vạch: $e'))
      );
    }
  }
  
  // Tìm kiếm sản phẩm từ mã vạch và hiển thị màn hình chi tiết dinh dưỡng
  Future<void> _searchProductByBarcode(String barcode) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Tìm kiếm sản phẩm từ mã vạch trong cơ sở dữ liệu
      final items = await _databaseService.searchFoodByBarcode(barcode);
      
      if (items.isNotEmpty) {
        // Sử dụng ngày đã chọn thay vì ngày hiện tại
        final DateTime selectedDateTime = _selectedDate != null 
            ? DateTime.parse(_selectedDate!)
            : DateTime.now();
        
        // Sử dụng FoodDataAdapter để tạo FoodEntry từ kết quả barcode
        final entry = FoodDataAdapter.createFromBarcode(
          foodItem: items.first,
          dateTime: selectedDateTime,
          mealType: _selectedMealType,
          imagePath: null // Không có hình ảnh cho sản phẩm quét từ mã vạch
        );
        
        // Thêm thông tin barcode vào entry
        final updatedEntry = entry.copyWith(barcode: barcode);
        
        // In log thông tin để debug
        print('_searchProductByBarcode: Đã tạo entry với ngày: ${updatedEntry.dateTime}');
        
        // Hiển thị màn hình chi tiết dinh dưỡng
        _showEnhancedNutritionAnalysis(updatedEntry);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tìm thấy thông tin từ mã vạch. Thử tìm kiếm thủ công?'),
            action: SnackBarAction(
              label: 'TÌM KIẾM',
              onPressed: () {
                _openFoodDatabase();
              },
            ),
          )
        );
      }
    } catch (e) {
      print('Lỗi khi tìm kiếm mã vạch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tìm kiếm mã vạch: $e'))
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  // Mở màn hình tìm kiếm cơ sở dữ liệu thực phẩm
  void _openFoodDatabase() async {
    final result = await Navigator.of(context).pushNamed(FoodSearchScreen.routeName);
    
    if (result is List<FoodItem> && result.isNotEmpty) {
      // Tạo một FoodEntry từ các FoodItem được chọn
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Sử dụng ngày đã chọn thay vì ngày hiện tại
      final DateTime selectedDateTime = _selectedDate != null 
          ? DateTime.parse(_selectedDate!)
          : DateTime.now();
      
      // Tạo food entry với ngày được chọn
      final entry = await foodProvider.addFoodEntry(
        description: result.map((item) => item.name).join(", "),
        mealType: _selectedMealType,
        dateTime: selectedDateTime, // Sử dụng ngày đã chọn
        items: result,
      );
      
      // In log thông tin để debug
      print('Đã tạo entry từ tìm kiếm với ngày: ${entry.dateTime}');
      
      // Hiển thị màn hình chi tiết dinh dưỡng
      final updateResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodNutritionDetailScreen(
            foodEntry: entry,
            onSave: (updatedEntry) {
              // Cập nhật thông tin món ăn
              foodProvider.updateFoodEntry(updatedEntry);
              
              // In log thông tin để debug
              print('Đã cập nhật entry từ FoodNutritionDetailScreen với ngày: ${updatedEntry.dateTime}');
            },
          ),
        ),
      );
      
      // Nếu có dữ liệu từ màn hình chi tiết trả về, cập nhật UI
      if (updateResult != null) {
        foodProvider.updateHomeScreenWithNewEntry(context, 
            updateResult is FoodEntry ? updateResult : entry);
      }
    } else if (result is FoodItem) {
      // Tạo một FoodEntry từ một FoodItem được chọn
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      
      // Sử dụng ngày đã chọn thay vì ngày hiện tại
      final DateTime selectedDateTime = _selectedDate != null 
          ? DateTime.parse(_selectedDate!)
          : DateTime.now();
      
      final entry = await foodProvider.addFoodEntry(
        description: result.name,
        mealType: _selectedMealType,
        dateTime: selectedDateTime, // Sử dụng ngày đã chọn
        items: [result],
      );
      
      // In log thông tin để debug
      print('Đã tạo entry từ item đơn lẻ với ngày: ${entry.dateTime}');
      
      // Hiển thị màn hình chi tiết dinh dưỡng
      final updateResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodNutritionDetailScreen(
            foodEntry: entry,
            onSave: (updatedEntry) {
              // Cập nhật thông tin món ăn
              foodProvider.updateFoodEntry(updatedEntry);
              
              // In log thông tin để debug
              print('Đã cập nhật entry từ FoodNutritionDetailScreen với ngày: ${updatedEntry.dateTime}');
            },
          ),
        ),
      );
      
      // Nếu có dữ liệu từ màn hình chi tiết trả về, cập nhật UI
      if (updateResult != null) {
        foodProvider.updateHomeScreenWithNewEntry(context, 
            updateResult is FoodEntry ? updateResult : entry);
      }
    }
  }
  
  // Hiển thị lịch sử
  void _showHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => FoodHistoryScreen())
    );
  }
  
  // Hiển thị yêu thích
  void _showFavorites() {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    List<FoodItem> favoriteItems = foodProvider.favoriteItems;
    
    if (favoriteItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bạn chưa có món ăn yêu thích nào'))
      );
      return;
    }
    
    // Sửa lỗi: thay vì gọi _openFoodDatabase với await, 
    // chỉ gọi như một phương thức void thông thường
    _openFoodDatabase();
  }
  
  // Thêm vào yêu thích
  void _addToFavorites() {
    final description = _descriptionController.text;
    
    if (description.isEmpty && _foodImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng thêm ảnh hoặc mô tả bữa ăn trước khi đánh dấu yêu thích'))
      );
      return;
    }
    
    _saveFoodEntry();
  }
  
  // Chuyển sang chế độ thực phẩm trống
  void _switchToEmptyFood() {
    _descriptionController.text = "Bữa ăn trống";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chuyển sang chế độ thực phẩm trống'))
    );
  }

  // Hiển thị dialog xác nhận/chỉnh sửa món ăn trước khi lưu
  Future<FoodEntry?> _showEditMealDialog(List<FoodItem> items, {String mealType = 'Meal'}) async {
    List<FoodItem> editableItems = List.from(items);
    String selectedMealType = mealType;
    
    // Danh sách các loại bữa ăn hợp lệ
    final mealTypes = ['Sáng', 'Trưa', 'Tối', 'Khác', 'Bữa chính', 'Bữa phụ', 'Bữa nhẹ', 'Meal'];

    // Đảm bảo selectedMealType nằm trong danh sách mealTypes
    if (!mealTypes.contains(selectedMealType)) {
      selectedMealType = 'Bữa chính';
    }

    FoodEntry? resultEntry;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Xác nhận & chỉnh sửa món ăn'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...editableItems.map((item) {
                      TextEditingController portionController = TextEditingController(text: item.servingSize.toString());
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.brand != null) Text(item.brand!, style: TextStyle(fontSize: 12, color: Colors.grey)),
                              // Sửa lỗi RenderFlex overflow bằng cách sử dụng Flexible
                              Row(
                                children: [
                                  Flexible(
                                    child: Text('Khẩu phần: '),
                                  ),
                                  Container(
                                    width: 60,
                                    child: TextField(
                                      controller: portionController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(suffixText: item.servingUnit),
                                      onChanged: (val) {
                                        double? newPortion = double.tryParse(val);
                                        if (newPortion != null) {
                                          setState(() {
                                            editableItems[editableItems.indexOf(item)] = FoodItem(
                                              id: item.id,
                                              name: item.name,
                                              brand: item.brand,
                                              imageUrl: item.imageUrl,
                                              calories: item.calories,
                                              protein: item.protein,
                                              fat: item.fat,
                                              carbs: item.carbs,
                                              fiber: item.fiber,
                                              sugar: item.sugar,
                                              sodium: item.sodium,
                                              servingSize: newPortion,
                                              servingUnit: item.servingUnit,
                                              additionalNutrients: item.additionalNutrients,
                                            );
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                editableItems.remove(item);
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Thêm món mới'),
                      onPressed: () async {
                        // Có thể mở màn hình tìm kiếm món ăn để thêm
                        final result = await Navigator.of(context).pushNamed('/food-search');
                        if (result is FoodItem) {
                          setState(() {
                            editableItems.add(result);
                          });
                        } else if (result is List<FoodItem> && (result as List).isNotEmpty) {
                          setState(() {
                            editableItems.addAll(result as List<FoodItem>);
                          });
                        }
                      },
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Thời gian ăn: '),
                        SizedBox(width: 8),
                        DropdownButton<String>(
                          value: selectedMealType,
                          items: mealTypes
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedMealType = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Huỷ'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ElevatedButton(
                  child: Text('Lưu vào nhật ký'),
                  onPressed: () async {
                    if (editableItems.isNotEmpty) {
                      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                      resultEntry = await foodProvider.addFoodEntry(
                        description: editableItems.map((e) => e.name).join(', '),
                        mealType: selectedMealType,
                        items: editableItems,
                      );
                      Navigator.of(ctx).pop();
                      
                      // Mở màn hình chi tiết dinh dưỡng
                      if (resultEntry != null) {
                        final updatedEntry = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FoodNutritionDetailScreen(
                              foodEntry: resultEntry!,
                              onSave: (updatedEntry) {
                                // Cập nhật thông tin
                                foodProvider.updateHomeScreenWithNewEntry(context, updatedEntry);
                              },
                            ),
                          ),
                        );
                        
                        if (updatedEntry != null) {
                          resultEntry = updatedEntry;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đã lưu bữa ăn thành công!')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
    
    return resultEntry;
  }

  // Xử lý kết quả quét mã vạch
  void _processBarcodeResult(String barcode) {
    if (barcode.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã quét mã vạch: $barcode. Đang tìm kiếm thông tin...'))
      );
      
      // Thực hiện tìm kiếm thông tin sản phẩm từ mã vạch
      // Có thể tích hợp với API tra cứu mã vạch ở đây
    }
  }

  // Thêm phương thức _showFoodSuggestionsDialog để không gặp lỗi nếu có nơi khác gọi
  Future<List<FoodItem>?> _showFoodSuggestionsDialog(List<FoodItem> items) async {
    List<FoodItem> selectedItems = [];
    
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Món ăn gợi ý'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                bool isSelected = selectedItems.contains(item);
                
                return CheckboxListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.calories} kcal'),
                  value: isSelected,
                  onChanged: (value) {
                    if (value == true) {
                      selectedItems.add(item);
                    } else {
                      selectedItems.remove(item);
                    }
                    // Cần gọi setState để cập nhật UI, nhưng trong AlertDialog với StatelessBuilder
                    // không thể gọi trực tiếp setState của _FoodLoggingScreenState
                    // Đây chỉ là code mẫu, cần thêm StatefulBuilder để cập nhật UI đúng cách
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Hủy'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              child: Text('Thêm'),
              onPressed: () {
                Navigator.of(ctx).pop(selectedItems);
              },
            ),
          ],
        );
      },
    );
    
    return selectedItems;
  }

  @override
  Widget build(BuildContext context) {
    // Get the latest selected date from the provider
    final foodProvider = Provider.of<FoodProvider>(context);
    _selectedDate = foodProvider.selectedDate;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Ghi chép bữa ăn'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (ctx) => FoodHistoryScreen(),
              ));
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green.withOpacity(0.05),
                Colors.white,
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  
                  // Chọn bữa ăn - UI mới
                  _buildMealTypeSelector(),
                  
                  SizedBox(height: 24),
                  
                  // Input mô tả thực phẩm
                  FoodDescriptionInput(
                    controller: _descriptionController,
                    onSubmit: () => _saveFoodEntry(),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Hiển thị ảnh đã chụp
                  if (_foodImage != null)
                    FoodImagePreview(
                      foodImage: _foodImage!,
                      onRemove: () {
                        setState(() {
                          _foodImage = null;
                        });
                      },
                    ),
                  
                  SizedBox(height: 20),
                  
                  // Nút chức năng
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 10.0, 
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      // Nút camera
                      ActionButton(
                        icon: Icons.camera_alt,
                        label: 'Chụp ảnh',
                        color: Colors.blue,
                        onPressed: _takeFoodPhoto,
                      ),
                      
                      // Nút thư viện
                      ActionButton(
                        icon: Icons.photo_library,
                        label: 'Thư viện',
                        color: Colors.orange,
                        onPressed: _pickFoodPhoto,
                      ),
                      
                      // Nút tìm kiếm thực phẩm
                      ActionButton(
                        icon: Icons.search,
                        label: 'Tìm kiếm',
                        color: Colors.green,
                        onPressed: _openFoodDatabase,
                      ),
                      
                      // Nút quét mã vạch
                      BarcodeScannerButton(
                        onBarcodeScan: (barcode) {
                          setState(() {
                            _barcode = barcode;
                          });
                          // Xử lý barcode
                          _searchProductByBarcode(barcode);
                        },
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Nút lớn lưu bữa ăn
                  ElevatedButton(
                    onPressed: _saveFoodEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(double.infinity, 0),
                    ),
                    child: Text(
                      'Lưu bữa ăn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
  
  // Widget mới hiển thị chọn bữa ăn
  Widget _buildMealTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn bữa ăn',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 90, // Increased height to fully accommodate the cards
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildMealTypeCard(
                icon: '🍳',
                title: 'Bữa sáng',
                timeRange: '6:00 - 9:00',
                isSelected: _selectedMealType == 'Bữa sáng',
                onTap: () {
                  setState(() {
                    _selectedMealType = 'Bữa sáng';
                  });
                },
              ),
              _buildMealTypeCard(
                icon: '🥗',
                title: 'Bữa trưa',
                timeRange: '11:00 - 13:00',
                isSelected: _selectedMealType == 'Bữa trưa',
                onTap: () {
                  setState(() {
                    _selectedMealType = 'Bữa trưa';
                  });
                },
              ),
              _buildMealTypeCard(
                icon: '🍝',
                title: 'Bữa tối',
                timeRange: '18:00 - 20:00',
                isSelected: _selectedMealType == 'Bữa tối',
                onTap: () {
                  setState(() {
                    _selectedMealType = 'Bữa tối';
                  });
                },
              ),
              _buildMealTypeCard(
                icon: '🍌',
                title: 'Bữa phụ',
                timeRange: 'Bất kỳ',
                isSelected: _selectedMealType == 'Bữa phụ',
                onTap: () {
                  setState(() {
                    _selectedMealType = 'Bữa phụ';
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Widget cho từng card bữa ăn
  Widget _buildMealTypeCard({
    required String icon,
    required String title, 
    required String timeRange,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 95,
        height: 85, // Increased height to prevent overflow
        margin: EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.max, // Fill available space
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 2,
              child: Text(
                icon,
                style: TextStyle(fontSize: 20),
              ),
            ),
            SizedBox(height: 2),
            Flexible(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.green[800] : Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 1),
            Flexible(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị nút tìm kiếm thực phẩm
  Widget _buildFoodSearchButton() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => FoodSearchScreen(),
          ),
        );
      },
      child: Container(
        width: 80,
        height: 85, // Increased height to accommodate content
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max, // Changed to max to fill available space
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Icon(Icons.search, color: Colors.green, size: 22),
            ),
            SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Tìm kiếm',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 