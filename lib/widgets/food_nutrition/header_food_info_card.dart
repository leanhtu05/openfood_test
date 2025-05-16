import 'package:flutter/material.dart';
import '../../models/food_entry.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/food_provider.dart';
import '../../screens/food_nutrition_detail_screen.dart';

// Add global context variable for dialog access
BuildContext? globalContext;

class HeaderFoodInfoCard extends StatefulWidget {
  final FoodEntry foodEntry;
  final double servingSize;
  final VoidCallback onEditTime;
  final double caloriesGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbsGoal;
  final VoidCallback? onEditFood;
  final Function(double)? onServingSizeChanged;
  final VoidCallback? onAddMore;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onReplace;
  final Function(double)? onWeightChanged;

  const HeaderFoodInfoCard({
    Key? key,
    required this.foodEntry,
    required this.servingSize,
    required this.onEditTime,
    required this.caloriesGoal,
    required this.proteinGoal,
    required this.fatGoal,
    required this.carbsGoal,
    this.onEditFood,
    this.onServingSizeChanged,
    this.onAddMore,
    this.onDelete,
    this.onEdit,
    this.onReplace,
    this.onWeightChanged,
  }) : super(key: key);

  @override
  _HeaderFoodInfoCardState createState() => _HeaderFoodInfoCardState();
}

class _HeaderFoodInfoCardState extends State<HeaderFoodInfoCard> {
  // State để lưu trữ FoodEntry hiện tại
  late FoodEntry _currentFoodEntry;
  
  @override
  void initState() {
    super.initState();
    _currentFoodEntry = widget.foodEntry;
  }
  
  @override
  void didUpdateWidget(HeaderFoodInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cập nhật khi widget.foodEntry thay đổi từ bên ngoài
    if (oldWidget.foodEntry != widget.foodEntry) {
      setState(() {
        _currentFoodEntry = widget.foodEntry;
      });
    }
  }

  // Getter để trả về giá trị servingSize hiệu quả
  double get effectiveServingSize => widget.servingSize <= 0 ? 1.0 : widget.servingSize;

  @override
  Widget build(BuildContext context) {
    // Thêm dòng này vào đầu phương thức build để debug
    print('HeaderFoodInfoCard đang xây dựng với ngày: ${_formatDateTimeDisplay(_currentFoodEntry.dateTime)}');
    
    // Tính toán giá trị dinh dưỡng ưu tiên từ dữ liệu API nếu có
    final nutritionValues = _currentFoodEntry.calculateNutritionFromAPI();
    final calories = (nutritionValues['calories']!).toInt();
    final protein = (nutritionValues['protein']!).toInt();
    final fat = (nutritionValues['fat']!).toInt();
    final carbs = (nutritionValues['carbs']!).toInt();
    
    // Đảm bảo totalWeight nằm trong khoảng hợp lý
    final totalWeight = (nutritionValues['totalWeight']?.toInt() ?? 
                        _currentFoodEntry.totalWeight.toInt() ?? 150).clamp(10, 1000);
    
    // Tính số gram từ servingSize
    double gramsTotal = effectiveServingSize * 100; 
    
    // Kiểm tra xem đang ở trong màn hình meal_recording bằng cách đơn giản hơn
    final isInMealRecording = ModalRoute.of(context)?.settings.name == '/meal-recording';
    
    if (isInMealRecording) {
      // Sử dụng thiết kế gọn hơn cho màn hình meal_recording
      return Card(
        margin: EdgeInsets.zero, // Xóa margin hoàn toàn để sử dụng toàn bộ chiều rộng
        elevation: 1.5, // Giảm độ nổi
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Giảm bo góc để phù hợp với container cha
        ),
        color: Colors.white,
        child: Container(
          width: double.infinity, // Đảm bảo sử dụng toàn bộ chiều rộng
          padding: const EdgeInsets.all(10.0),
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row đầu tiên chứa loại bữa ăn và thời gian
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loại bữa ăn
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentFoodEntry.mealType,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    
                    // Thời gian
                    GestureDetector(
                      onTap: () => _showDateTimePicker(),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Text(
                            _formatTimeOnly(_currentFoodEntry.dateTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 8),
                
                // Row thứ hai chứa food icon và thông tin chính
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food icon nhỏ hơn
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _currentFoodEntry.imagePath != null && _currentFoodEntry.imagePath!.isNotEmpty
                          ? Image.file(
                              File(_currentFoodEntry.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  _currentFoodEntry.description.isNotEmpty ? _currentFoodEntry.description[0].toUpperCase() : "T",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.green.shade100,
                              child: Center(
                                child: Text(
                                  _currentFoodEntry.description.isNotEmpty ? _currentFoodEntry.description[0].toUpperCase() : "T",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                                ),
                              ),
                            ),
                      ),
                    ),
                    
                    SizedBox(width: 8),
                    
                    // Thông tin chính
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tên thực phẩm
                          Text(
                            _currentFoodEntry.description,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          SizedBox(height: 4),
                          
                          // Hiển thị chi tiết dinh dưỡng 
                          // Thông tin dinh dưỡng chi tiết hơn
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Calories với icon
                              Row(
                                children: [
                                  Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                                  SizedBox(width: 2),
                                  Text(
                                    "${calories}kcal",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 2),
                              
                              // Macros trên một hàng
                              Row(
                                children: [
                                  _buildMacroInfo("P", protein, Colors.blue, 12),
                                  SizedBox(width: 6),
                                  _buildMacroInfo("C", carbs, Colors.green, 12),
                                  SizedBox(width: 6),
                                  _buildMacroInfo("F", fat, Colors.orange.shade700, 12),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 6),
                
                // Action button row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: widget.onEditFood,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "Sửa",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 6),
                    
                    InkWell(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "Xóa",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Sử dụng thiết kế gốc cho các màn hình khác
      return Card(
        margin: EdgeInsets.zero,
        elevation: 2, // Tăng đổ bóng
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white, // Đổi màu nền thành trắng
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Tăng padding
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hiển thị loại bữa ăn
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentFoodEntry.mealType,
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Header section (food icon, name, time, serving) - thiết kế lại
                _buildCustomHeader(context),
                
                SizedBox(height: 16),
                
                // Food item with nutrition info
                _buildNutritionSummary(calories, protein, fat, carbs),

                SizedBox(height: 12),
                
                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Edit button
                    InkWell(
                      onTap: widget.onEditFood,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Sửa",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 8),
                    
                    // Delete button
                    InkWell(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Xóa",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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
  }
  
  // Helper method to create header with customized time tap handler
  Widget _buildCustomHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Food icon - circular with 56x56
        _buildFoodIcon(),
        
        SizedBox(width: 12),
        
        // Food details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food name
              Text(
                _currentFoodEntry.description,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 8),
              
              // Time with clock icon
              GestureDetector(
                onTap: () => _showDateTimePicker(),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _formatDateTimeDisplay(_currentFoodEntry.dateTime),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 8),
              
              // Serving size with slider
              Row(
                children: [
                  Icon(Icons.restaurant, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    "Khẩu phần: ",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showServingSizeDialog(),
                    child: Text(
                      "${effectiveServingSize.toStringAsFixed(1)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Phương thức để xây dựng summary nutrition
  Widget _buildNutritionSummary(int calories, int protein, int fat, int carbs) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Dinh dưỡng",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text(
                    "$calories kcal",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Macro nutrients
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroNutrient("Protein", protein, Colors.blue),
              _buildMacroNutrient("Carbs", carbs, Colors.green),
              _buildMacroNutrient("Fat", fat, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
  
  // Widget hiển thị macronutrient
  Widget _buildMacroNutrient(String name, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              "${value}g",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // Widget hiển thị mini-macro info cho meal recording screen
  Widget _buildMacroInfo(String label, int value, Color color, double fontSize) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${value}g",
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        shape: BoxShape.circle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Image if available
            if (_currentFoodEntry.imagePath != null && _currentFoodEntry.imagePath!.isNotEmpty)
              Image.file(
                File(_currentFoodEntry.imagePath!),
                fit: BoxFit.cover,
                width: 56,
                height: 56,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image loading fails
                  return Center(
                    child: Icon(Icons.image_not_supported, color: Colors.green, size: 24),
                  );
                },
              ),
            
            // First letter of food name or T if not available
            if (_currentFoodEntry.imagePath == null || _currentFoodEntry.imagePath!.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      _currentFoodEntry.description.isNotEmpty ? _currentFoodEntry.description[0].toUpperCase() : "T",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    "scan",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hiển thị dialog nhập khẩu phần
  void _showServingSizeDialog() {
    if (widget.onServingSizeChanged == null) return;
    
    final context = this.context;
    if (context == null) return;
    
    // Lấy đúng số khẩu phần từ item đầu tiên nếu có, nếu không thì lấy effectiveServingSize
    double tempServingSize = _currentFoodEntry.items.isNotEmpty ? 
        _currentFoodEntry.items.first.servingSize : effectiveServingSize;
    
    // Hiển thị số gram (không phải số khẩu phần)
    double tempGrams = tempServingSize * 100;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Điều chỉnh khẩu phần'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nhập số gram:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Số gram',
                  suffixText: 'g',
                ),
                controller: TextEditingController(text: tempGrams.toStringAsFixed(0)),
                onChanged: (value) {
                  final parsedValue = double.tryParse(value);
                  if (parsedValue != null && parsedValue > 0) {
                    tempGrams = parsedValue;
                  }
                },
              ),
              SizedBox(height: 16),
              Text(
                'Điều chỉnh số gram món ăn này',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                // Chuyển đổi từ gram sang khẩu phần (1 khẩu phần = 100g)
                final newServingSize = tempGrams / 100;
                
                if (widget.onServingSizeChanged != null) {
                  widget.onServingSizeChanged?.call(newServingSize);
                }
                Navigator.of(dialogContext).pop();
              },
              child: Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  // Hiển thị dialog nhập khối lượng (gram)
  void _showWeightInputDialog() {
    if (widget.onWeightChanged == null) return;
    
    final context = this.context;
    if (context == null) return;
    
    // Tính số gram từ servingSize
    double currentWeight = 0.0;
    
    if (_currentFoodEntry.items.isNotEmpty) {
      // Nếu có items, lấy giá trị từ servingSize của item đầu tiên
      currentWeight = _currentFoodEntry.items.first.servingSize * 100;
    } else if (_currentFoodEntry.nutritionInfo != null && _currentFoodEntry.nutritionInfo!.containsKey('totalWeight')) {
      // Nếu có totalWeight trong nutritionInfo
      currentWeight = (_currentFoodEntry.nutritionInfo!['totalWeight'] as num).toDouble();
    } else {
      // Mặc định 100g nếu không có thông tin
      currentWeight = 100.0;
    }
    
    double tempWeight = currentWeight;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Điều chỉnh khối lượng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nhập khối lượng:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Khối lượng (g)',
                  suffixText: 'g',
                ),
                controller: TextEditingController(text: tempWeight.toStringAsFixed(0)),
                onChanged: (value) {
                  final parsedValue = double.tryParse(value);
                  if (parsedValue != null && parsedValue > 0) {
                    tempWeight = parsedValue;
                  }
                },
              ),
              SizedBox(height: 16),
              Text(
                'Điều chỉnh khối lượng món ăn này',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                // Đảm bảo sử dụng .call với giá trị mới được deepcopy để tránh chia sẻ tham chiếu
                widget.onWeightChanged?.call(tempWeight);
                Navigator.of(dialogContext).pop();
              },
              child: Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }
  
  // Hiển thị dialog chọn ngày giờ
  void _showDateTimePicker() {
    // Lấy ngày giờ hiện tại từ state nội bộ
    final currentDate = _currentFoodEntry.dateTime;
    
    // Các tháng trong tiếng Việt
    final vietnameseMonths = [
      "tháng 1", "tháng 2", "tháng 3", "tháng 4", "tháng 5", "tháng 6",
      "tháng 7", "tháng 8", "tháng 9", "tháng 10", "tháng 11", "tháng 12"
    ];
    
    // Các controllers để quản lý việc scroll
    final FixedExtentScrollController dayController = FixedExtentScrollController(
      initialItem: currentDate.day - 1
    );
    final FixedExtentScrollController monthController = FixedExtentScrollController(
      initialItem: currentDate.month - 1
    );
    final FixedExtentScrollController yearController = FixedExtentScrollController(
      initialItem: currentDate.year - 2020
    );
    final FixedExtentScrollController hourController = FixedExtentScrollController(
      initialItem: currentDate.hour
    );
    final FixedExtentScrollController minuteController = FixedExtentScrollController(
      initialItem: currentDate.minute
    );
    
    // Biến lưu giá trị khi người dùng thay đổi
    int selectedDay = currentDate.day;
    int selectedMonth = currentDate.month;
    int selectedYear = currentDate.year;
    int selectedHour = currentDate.hour;
    int selectedMinute = currentDate.minute;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tiêu đề
                      Row(
                        children: [
                          const Icon(Icons.edit, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            "Chọn thời gian",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Chọn ngày
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Ngày
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: dayController,
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.5,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedDay = index + 1;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 31,
                                  builder: (context, index) {
                                    final day = index + 1;
                                    final isSelected = day == selectedDay;
                                    return Container(
                                      alignment: Alignment.center,
                                      decoration: isSelected 
                                          ? BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            )
                                          : null,
                                      child: Text(
                                        day.toString(),
                                        style: TextStyle(
                                          fontSize: isSelected ? 20 : 16,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Tháng
                            Expanded(
                              flex: 2,
                              child: ListWheelScrollView.useDelegate(
                                controller: monthController,
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.5,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedMonth = index + 1;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 12,
                                  builder: (context, index) {
                                    final month = index + 1;
                                    final isSelected = month == selectedMonth;
                                    return Container(
                                      alignment: Alignment.center,
                                      decoration: isSelected 
                                          ? BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            )
                                          : null,
                                      child: Text(
                                        vietnameseMonths[index],
                                        style: TextStyle(
                                          fontSize: isSelected ? 20 : 16,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Năm
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: yearController,
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.5,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedYear = index + 2020;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 11, // 2020-2030
                                  builder: (context, index) {
                                    final year = index + 2020;
                                    final isSelected = year == selectedYear;
                                    return Container(
                                      alignment: Alignment.center,
                                      decoration: isSelected 
                                          ? BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            )
                                          : null,
                                      child: Text(
                                        year.toString(),
                                        style: TextStyle(
                                          fontSize: isSelected ? 20 : 16,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Hiển thị thời gian đã chọn
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${selectedHour.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            Text(
                              " : ",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            Text(
                              "${selectedMinute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Chọn giờ và phút với wheel pickers
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Giờ - sử dụng ListWheelScrollView
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: hourController,
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.5,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedHour = index;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 24,
                                  builder: (context, index) {
                                    final isSelected = index == selectedHour;
                                    return Container(
                                      alignment: Alignment.center,
                                      decoration: isSelected 
                                          ? BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            )
                                          : null,
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: isSelected ? 20 : 16,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            const Text(
                              " : ",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            // Phút - sử dụng ListWheelScrollView
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: minuteController,
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.5,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedMinute = index;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 60,
                                  builder: (context, index) {
                                    final isSelected = index == selectedMinute;
                                    return Container(
                                      alignment: Alignment.center,
                                      decoration: isSelected 
                                          ? BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            )
                                          : null,
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: isSelected ? 20 : 16,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Nút đồng ý
                      ElevatedButton(
                        onPressed: () {
                          // Kiểm tra ngày hợp lệ (đặc biệt là số ngày trong tháng)
                          int maxDaysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
                          int validDay = selectedDay > maxDaysInMonth ? maxDaysInMonth : selectedDay;
                          
                          // Tạo đối tượng DateTime mới để cập nhật
                          final updatedDateTime = DateTime(
                            selectedYear,
                            selectedMonth,
                            validDay, // Sử dụng ngày đã được kiểm tra
                            selectedHour,
                            selectedMinute,
                          );
                          
                          // Đóng dialog trước tiên
                          Navigator.of(context).pop();
                          
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
                                  Text('Đang cập nhật...'),
                                ],
                              ),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.green,
                            ),
                          );
                          
                          // Sau đó thực hiện đồng bộ và cập nhật UI
                          Future.delayed(Duration.zero, () {
                            syncDateTimeWithHomeAndNutri(updatedDateTime);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Đồng ý",
                              style: TextStyle(
                                fontSize: 16,
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
            );
          }
        );
      },
    );
  }
  
  // Hàm đồng bộ hóa thời gian với màn hình home và nutri
  void syncDateTimeWithHomeAndNutri(DateTime newDateTime) {
    try {
      // Log thời gian hiện tại và thời gian mới
      print('Thời gian hiện tại: ${_formatDateTimeDisplay(_currentFoodEntry.dateTime)}');
      print('Thời gian mới: ${_formatDateTimeDisplay(newDateTime)}');
      
      // Cập nhật state nội bộ TRƯỚC - điều này quan trọng!
      setState(() {
        // Tạo một bản sao của entry hiện tại nhưng với thời gian mới (không sử dụng copyWith)
        _currentFoodEntry = FoodEntry(
          id: _currentFoodEntry.id,
          description: _currentFoodEntry.description,
          imagePath: _currentFoodEntry.imagePath,
          audioPath: _currentFoodEntry.audioPath,
          dateTime: newDateTime, // Thời gian mới
          isFavorite: _currentFoodEntry.isFavorite,
          barcode: _currentFoodEntry.barcode,
          calories: _currentFoodEntry.calories,
          nutritionInfo: _currentFoodEntry.nutritionInfo,
          mealType: _currentFoodEntry.mealType,
          items: _currentFoodEntry.items,
        );
      });
      
      print('Đã cập nhật state nội bộ, thời gian mới: ${_formatDateTimeDisplay(_currentFoodEntry.dateTime)}');
      
      // NEXT: Cập nhật trong FoodProvider
      final context = this.context;
      if (context != null) {
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        
        // Định dạng ngày mới
        final selectedDateStr = "${newDateTime.year}-${newDateTime.month.toString().padLeft(2, '0')}-${newDateTime.day.toString().padLeft(2, '0')}";
        
        // Đặt ngày được chọn trong provider
        foodProvider.setSelectedDate(selectedDateStr);
        
        // Cập nhật entry trong provider
        foodProvider.updateFoodEntry(_currentFoodEntry);
        
        // Reset các cache
        foodProvider.clearNutritionCache();
        foodProvider.refreshNutrition();
        
        // Force refresh với notifyListeners ngay lập tức không delay
        foodProvider.notifyListeners();
        
        // Thêm dòng này: Cập nhật rõ ràng màn hình home với entry mới
        foodProvider.updateHomeScreenWithNewEntry(context, _currentFoodEntry);
        
        // Thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật ngày thành: ${newDateTime.day}/${newDateTime.month}/${newDateTime.year}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Đảm bảo gọi callback để thông báo cho parent widget
      widget.onEditTime();
      
    } catch (e) {
      print('Lỗi khi đồng bộ thời gian: $e');
      widget.onEditTime();
    }
  }

  String _formatDateTimeDisplay(DateTime dateTime) {
    final vietnameseMonths = [
      "tháng 1", "tháng 2", "tháng 3", "tháng 4", "tháng 5", "tháng 6",
      "tháng 7", "tháng 8", "tháng 9", "tháng 10", "tháng 11", "tháng 12"
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final day = dateTime.day;
    final month = vietnameseMonths[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    // Luôn hiển thị ngày tháng đầy đủ để tránh nhầm lẫn
    String dateLabel = "$day $month, $year";

    return "$dateLabel $hour:$minute";
  }

  // Helper method để định dạng chỉ hiển thị giờ:phút
  String _formatTimeOnly(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }
}

enum _Direction { top, right, bottom, left }

class CornerDecorationPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final List<_Direction> directions;
  final double padding;

  CornerDecorationPainter({
    required this.color,
    required this.strokeWidth,
    required this.directions,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final direction in directions) {
      switch (direction) {
        case _Direction.top:
          canvas.drawLine(
            Offset(padding, padding),
            Offset(size.width - padding, padding),
            paint,
          );
          break;
        case _Direction.right:
          canvas.drawLine(
            Offset(size.width - padding, padding),
            Offset(size.width - padding, size.height - padding),
            paint,
          );
          break;
        case _Direction.bottom:
          canvas.drawLine(
            Offset(padding, size.height - padding),
            Offset(size.width - padding, size.height - padding),
            paint,
          );
          break;
        case _Direction.left:
          canvas.drawLine(
            Offset(padding, padding),
            Offset(padding, size.height - padding),
            paint,
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Thêm CustomPainter để vẽ nền vằn vện như trong ảnh
class StripePainter extends CustomPainter {
  final Color stripeColor;
  final double stripeWidth;
  final double stripeSpacing;
  final double angle;

  StripePainter({
    required this.stripeColor,
    required this.stripeWidth,
    required this.stripeSpacing,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stripeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stripeWidth;

    // Tạo đường chéo vằn vện
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle * 3.14159 / 180);
    canvas.translate(-size.width / 2, -size.height / 2);

    final totalWidth = size.width + size.height;
    final totalStripes = (totalWidth / (stripeWidth + stripeSpacing)).ceil();
    
    double x = -totalWidth;
    for (int i = 0; i < totalStripes * 2; i++) {
      canvas.drawLine(
        Offset(x, -size.height),
        Offset(x + totalWidth * 2, totalWidth * 2 - size.height),
        paint,
      );
      x += stripeWidth + stripeSpacing;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}