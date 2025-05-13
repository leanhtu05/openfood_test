import 'package:flutter/material.dart';
import '../../models/food_entry.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/food_provider.dart';

// Add global context variable for dialog access
BuildContext? globalContext;

class HeaderFoodInfoCard extends StatelessWidget {
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
  
  // Thêm getter để trả về giá trị servingSize hiệu quả
  double get effectiveServingSize => servingSize <= 0 ? 1.0 : servingSize;

  @override
  Widget build(BuildContext context) {
    // Lưu context vào biến global để sử dụng trong các dialog và cập nhật provider
    globalContext = context;
    
    // Đảm bảo servingSize không nhỏ hơn hoặc bằng 0
    // Sử dụng getter thay vì biến local
    
    // Tính toán giá trị dinh dưỡng ưu tiên từ dữ liệu API nếu có
    final nutritionValues = foodEntry.calculateNutritionFromAPI();
    final calories = (nutritionValues['calories']!).toInt();
    final protein = (nutritionValues['protein']!).toInt();
    final fat = (nutritionValues['fat']!).toInt();
    final carbs = (nutritionValues['carbs']!).toInt();
    
    // Đảm bảo totalWeight nằm trong khoảng hợp lý
    final totalWeight = (foodEntry.nutritionInfo?['totalWeight']?.toInt() ?? 
                        foodEntry.totalWeight.toInt() ?? 150).clamp(10, 1000);
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section (food icon, name, time, serving)
            _buildCustomHeader(context),
            
            SizedBox(height: 12),
            
            // Food item with nutrition info
            _buildFoodItemRow(calories, protein, fat, carbs, totalWeight),

            SizedBox(height: 8),
            
            // Add more button
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onAddMore,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFE6F0FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Color(0xFF007BFF), size: 16),
                      SizedBox(width: 4),
                      Text(
                        "Thêm nữa",
                        style: TextStyle(
                          color: Color(0xFF007BFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              // Food name with edit icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onEditFood,
                    child: Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      foodEntry.description,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 6),
              
              // Time with clock icon - with custom action to show our date time picker
              GestureDetector(
                onTap: () => _showDateTimePicker(),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 8),
                    Text(
                      _formatDateTimeDisplay(foodEntry.dateTime),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 6),
              
              // Serving size with dropdown menu icon
              Row(
                children: [
                  Icon(Icons.menu, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    "Khẩu Phần: ",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Hiển thị dialog nhập khẩu phần
                      _showServingSizeDialog();
                    },
                    child: Row(
                      children: [
                        Text(
                          "${effectiveServingSize.toStringAsFixed(1)}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF007BFF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                if (onServingSizeChanged != null) {
                                  onServingSizeChanged!(effectiveServingSize + 0.1);
                                }
                              },
                              child: Icon(Icons.arrow_drop_up, color: Color(0xFF007BFF), size: 14),
                            ),
                            InkWell(
                              onTap: () {
                                if (onServingSizeChanged != null && effectiveServingSize > 0.1) {
                                  onServingSizeChanged!(effectiveServingSize - 0.1);
                                }
                              },
                              child: Icon(Icons.arrow_drop_down, color: Color(0xFF007BFF), size: 14),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildFoodItemRow(int calories, int protein, int fat, int carbs, int totalWeight) {
    // Lấy tên món ăn từ danh sách items hoặc mô tả
    final foodName = foodEntry.items.isNotEmpty ? foodEntry.items.first.name : foodEntry.description;
    
    // Đảm bảo totalWeight có giá trị hợp lý
    final displayWeight = totalWeight <= 0 ? 100 : totalWeight;
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            spreadRadius: 0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Food type with checkmark
              Row(
                children: [
                  // Checkmark icon
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  // Food name
                  Text(
                    foodName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                  SizedBox(width: 4),
                  // Edit icon
                  GestureDetector(
                    onTap: onEditFood,
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: Color(0xFF007BFF),
                    ),
                  ),
                ],
              ),
              
              // Weight amount
              GestureDetector(
                onTap: () {
                  // Hiển thị dialog nhập khối lượng (gram)
                  _showWeightInputDialog();
                },
                child: Row(
                  children: [
                    Text(
                      "${displayWeight}g",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007BFF),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (onWeightChanged != null) {
                              onWeightChanged!(displayWeight + 10);
                            }
                          },
                          child: Icon(Icons.arrow_drop_up, color: Color(0xFF007BFF), size: 14),
                        ),
                        InkWell(
                          onTap: () {
                            if (onWeightChanged != null && displayWeight > 10) {
                              onWeightChanged!(displayWeight - 10);
                            }
                          },
                          child: Icon(Icons.arrow_drop_down, color: Color(0xFF007BFF), size: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Nutrition info in a scrollable row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Calories
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department, color: Color(0xFFFF5722), size: 16),
                      SizedBox(width: 4),
                      Text(
                        "${calories}kcal",
                        style: TextStyle(
                          color: Color(0xFFFF5722),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(width: 16),
                
                // Protein
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  child: Row(
                    children: [
                      Icon(Icons.fitness_center, color: Color(0xFF2196F3), size: 16),
                      SizedBox(width: 4),
                      Text(
                        "${protein}g",
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(width: 16),
                
                // Fat
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  child: Row(
                    children: [
                      Icon(Icons.water_drop, color: Color(0xFFFFA726), size: 16),
                      SizedBox(width: 4),
                      Text(
                        "${fat}g",
                        style: TextStyle(
                          color: Color(0xFFFFA726),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(width: 16),
                
                // Carbs
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  child: Row(
                    children: [
                      Icon(Icons.eco, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 4),
                      Text(
                        "${carbs}g",
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
            if (foodEntry.imagePath != null && foodEntry.imagePath!.isNotEmpty)
              Image.file(
                File(foodEntry.imagePath!),
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
            if (foodEntry.imagePath == null || foodEntry.imagePath!.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      foodEntry.description.isNotEmpty ? foodEntry.description[0].toUpperCase() : "T",
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
    if (onServingSizeChanged == null) return;
    
    // Không thể lấy context từ StatelessWidget nên phải truyền vào
    final context = globalContext;
    if (context == null) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        double tempServingSize = effectiveServingSize;
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text("Khẩu phần"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Slider để điều chỉnh khẩu phần
                  Slider(
                    value: tempServingSize,
                    min: 0.1,
                    max: 5.0,
                    divisions: 49,
                    label: tempServingSize.toStringAsFixed(1),
                    onChanged: (value) {
                      // Cập nhật giá trị tạm thời trong dialog
                      setState(() {
                        tempServingSize = value;
                      });
                    },
                  ),
                  
                  // Hiển thị giá trị khẩu phần
                  Text(
                    tempServingSize.toStringAsFixed(1),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  
                  // Giải thích về khẩu phần
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Điều chỉnh khẩu phần sẽ tự động tính lại giá trị dinh dưỡng",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Hủy"),
                ),
                TextButton(
                  onPressed: () {
                    // Lưu giá trị khẩu phần mới và kích hoạt cập nhật giao diện
                    onServingSizeChanged!(tempServingSize);
                    Navigator.pop(context);
                  },
                  child: Text("Đồng ý"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // Hiển thị dialog nhập khối lượng (gram)
  void _showWeightInputDialog() {
    if (onWeightChanged == null) return;
    
    // Không thể lấy context từ StatelessWidget nên phải truyền vào
    final context = globalContext;
    if (context == null) return;
    
    // Lấy khối lượng từ nutritionInfo hoặc dùng giá trị mặc định
    final currentWeight = foodEntry.nutritionInfo?['totalWeight']?.toInt() ?? 
                         foodEntry.totalWeight.toInt() ?? 100;
    
    // Đảm bảo currentWeight có giá trị hợp lý
    final displayWeight = currentWeight <= 0 ? 100 : currentWeight;
    String weightStr = displayWeight.toString();
    
    // Tính phần trăm hoàn thành dựa trên khẩu phần
    final percentComplete = (currentWeight / 2000 * 100).clamp(0, 100).toInt();
    
    // Tạo controller cho TextField
    final TextEditingController textController = TextEditingController(text: weightStr);
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Cập nhật phần trăm khi người dùng thay đổi giá trị
            int updatePercent() {
              try {
                final weight = int.tryParse(weightStr);
                if (weight == null || weight <= 0) return percentComplete;
                return (weight / 2000 * 100).clamp(0, 100).toInt();
              } catch (e) {
                return percentComplete;
              }
            }
            
            // Cập nhật giá trị hiển thị
            int getWeightValue() {
              try {
                final weight = int.tryParse(weightStr);
                return weight != null && weight > 0 ? weight : displayWeight;
              } catch (e) {
                return displayWeight;
              }
            }
            
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Vòng tròn Calo
                      Container(
                        width: 100,
                        height: 100,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Vòng tròn nền
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 8,
                                ),
                              ),
                            ),
                            
                            // Vòng tròn hiển thị phần trăm
                            CircularProgressIndicator(
                              value: updatePercent() / 100,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                            
                            // Biểu tượng lửa và phần trăm
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                Text(
                                  "${updatePercent()}%",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "Calo",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 8),
                      
                      // Text thể hiện giá trị hiện tại
                      Text(
                        "${getWeightValue()}/2000",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Trường nhập khối lượng
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Khối lượng",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  weightStr = value;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "g",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Hiển thị gợi ý trọng lượng như trong ảnh, dạng "cảnh báo"
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          border: Border.all(color: Colors.amber.shade400, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            // Tạo nền vằn vện như cảnh báo
                            Positioned.fill(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return CustomPaint(
                                    size: Size(constraints.maxWidth, constraints.maxHeight),
                                    painter: StripePainter(
                                      stripeColor: Colors.amber.shade400,
                                      stripeWidth: 12,
                                      stripeSpacing: 12,
                                      angle: -45,
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            // Hiển thị các giá trị gợi ý
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [100, 150, 200].map((weight) => 
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      weightStr = weight.toString();
                                      textController.text = weight.toString();
                                    });
                                  },
                                  child: Text(
                                    "${weight}g",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: int.tryParse(weightStr) == weight 
                                          ? FontWeight.bold 
                                          : FontWeight.normal,
                                      color: Colors.black,
                                    ),
                                  ),
                                )
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Nút điều khiển
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                foregroundColor: Colors.grey.shade600,
                              ),
                              child: Text(
                                "Hủy",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // Kiểm tra và chuyển đổi giá trị
                                try {
                                  final weight = int.tryParse(weightStr);
                                  if (weight != null && weight > 0) {
                                    onWeightChanged!(weight.toDouble());
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Vui lòng nhập một số hợp lệ")),
                                    );
                                  }
                                } catch (e) {
                                  // Hiển thị thông báo lỗi
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Vui lòng nhập một số hợp lệ")),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                "Đồng ý",
                                style: TextStyle(fontSize: 16),
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
        );
      },
    );
  }
  
  // Hiển thị dialog chọn ngày giờ
  void _showDateTimePicker() {
    if (globalContext == null) {
      // Call the original edit time callback if our context isn't available
      onEditTime();
      return;
    }
    
    // Lấy ngày giờ hiện tại hoặc từ foodEntry
    final currentDate = foodEntry.dateTime;
    
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
      context: globalContext!,
      barrierDismissible: false, // Ngăn chặn đóng dialog khi nhấn ra ngoài
      builder: (BuildContext context) {
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
                            // Ngày - sử dụng ListWheelScrollView
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
                            
                            // Tháng - sử dụng ListWheelScrollView
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
                            
                            // Năm - sử dụng ListWheelScrollView
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
                          // Tạo đối tượng DateTime mới để cập nhật
                          final updatedDateTime = DateTime(
                            selectedYear,
                            selectedMonth,
                            selectedDay,
                            selectedHour,
                            selectedMinute,
                          );
                          
                          // Đóng dialog trước tiên
                          Navigator.of(context).pop();
                          
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
    // Implement logic to sync date time between screens
    try {
      // 1. Cập nhật FoodEntry với thời gian mới
      if (foodEntry != null) {
        // Tạo bản sao của foodEntry với ngày giờ mới
        final updatedEntry = FoodEntry(
          id: foodEntry.id,
          description: foodEntry.description,
          imagePath: foodEntry.imagePath,
          audioPath: foodEntry.audioPath,
          dateTime: newDateTime,
          isFavorite: foodEntry.isFavorite,
          barcode: foodEntry.barcode,
          calories: foodEntry.calories,
          nutritionInfo: foodEntry.nutritionInfo,
          mealType: foodEntry.mealType,
          items: foodEntry.items,
        );
        
        // 2. Sử dụng Provider để cập nhật thông tin trên toàn ứng dụng
        try {
          // Lấy BuildContext từ biến global context
          final context = globalContext;
          
          // Sử dụng Provider để lấy FoodProvider instance
          if (context != null) {
            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
            
            // Cập nhật entry trong provider
            foodProvider.updateFoodEntry(updatedEntry);
            
            // Cập nhật ngày đã chọn trong provider
            final selectedDateStr = "${newDateTime.year}-${newDateTime.month.toString().padLeft(2, '0')}-${newDateTime.day.toString().padLeft(2, '0')}";
            foodProvider.setSelectedDate(selectedDateStr);
            
            // Đảm bảo dữ liệu dinh dưỡng được tính toán lại
            foodProvider.clearNutritionCache();
            
            // Cập nhật lại dữ liệu dinh dưỡng trên giao diện
            foodProvider.refreshNutrition();
            
            // In log để xác nhận việc đồng bộ hóa
            print('Đã đồng bộ thời gian: ${newDateTime.toIso8601String()} giữa các màn hình');
            print('Đã cập nhật ngày được chọn trong provider: $selectedDateStr');
          } else {
            print('Lỗi: Không thể lấy context để cập nhật provider');
          }
        } catch (e) {
          print('Lỗi khi cập nhật Provider: $e');
        }
      }
    } catch (e) {
      print('Lỗi khi đồng bộ hóa thời gian: $e');
    }
    
    // Luôn gọi callback gốc bất kể có lỗi hay không
    onEditTime();
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

    String dateLabel;
    if (dateToCheck == today) {
      dateLabel = "Hôm nay";
    } else if (dateToCheck == yesterday) {
      dateLabel = "Hôm qua";
    } else {
      dateLabel = "$day $month, $year";
    }

    return "$dateLabel $hour:$minute";
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