import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_entry.dart';
import '../../adapters/food_data_adapter.dart';
import '../../providers/food_provider.dart';

/// Lớp chứa các dialog sử dụng trong màn hình FoodNutritionDetailScreen
class FoodNutritionDialogs {
    /// Hiển thị dialog chọn loại bữa ăn
    static Widget buildMealTypeOption(BuildContext context, String mealType, String currentMealName, Function(String) onMealTypeSelected) {
        return ListTile(
            title: Text(mealType),
            onTap: () {
                onMealTypeSelected(mealType);
                Navigator.pop(context, mealType);
            },
            trailing: currentMealName == mealType ? Icon(Icons.check, color: Colors.green) : null,
        );
    }

  /// Hiển thị dialog xác nhận xóa
  static Future<bool?> showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xóa món ăn'),
          content: Text('Bạn có chắc chắn muốn xóa món ăn này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// Hiển thị dialog chọn ngày
  static Future<DateTime?> showDatePickerDialog(BuildContext context, DateTime initialDate) {
    // Đảm bảo lastDate đủ xa trong tương lai
    final currentYear = DateTime.now().year;
    final lastDate = DateTime(currentYear + 1, 12, 31);
    
    return showDatePicker(
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
  }

  /// Hiển thị dialog chi tiết dinh dưỡng
  static Future<void> showNutritionDetails(BuildContext context, FoodEntry foodEntry) async {
    // Hiển thị loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Center(
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
              Text('Đang cập nhật thông tin dinh dưỡng...'),
            ],
          ),
        ),
      ),
    );
    
    // Lấy dữ liệu dinh dưỡng từ API nếu chưa đầy đủ
    FoodEntry updatedEntry = foodEntry;
    
    try {
      // Kiểm tra nếu thông tin dinh dưỡng chưa đầy đủ hoặc đã quá cũ
      if (foodEntry.nutritionInfo == null || 
          !_hasCompleteNutritionData(foodEntry.nutritionInfo!)) {
        
        // Lấy FoodProvider
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        
        // Cập nhật thông tin dinh dưỡng từ API và lưu vào database
        updatedEntry = await foodProvider.updateNutritionFromAPI(foodEntry);
      }
      
      // Đóng dialog loading
      Navigator.of(context).pop();
      
      // Lấy giá trị dinh dưỡng đã được tính toán chính xác
      final nutritionValues = updatedEntry.calculateNutritionFromAPI();
      final nutritionInfo = updatedEntry.nutritionInfo ?? {};
      
      // Hiển thị dialog với dữ liệu cập nhật
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
                  // Data source info if available
                  if (nutritionInfo['dataSource'] != null) 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'Nguồn: ${nutritionInfo['dataSource']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  
                  // Vĩ lượng (Macronutrients)
                  _buildSectionHeader('Vĩ lượng'),
                  _buildDetailItem('Calo', '${nutritionValues['calories']?.toInt() ?? 0} kcal', Colors.orange),
                  _buildDetailItem('Protein', '${nutritionValues['protein']?.toInt() ?? 0}g', Colors.blue),
                  _buildDetailItem('Chất béo', '${nutritionValues['fat']?.toInt() ?? 0}g', Colors.orange.shade700),
                  _buildDetailItem('Carbs', '${nutritionValues['carbs']?.toInt() ?? 0}g', Colors.green),
                  _buildDetailItem('Đường', '${nutritionValues['sugar']?.toInt() ?? 0}g', Colors.pink),
                  _buildDetailItem('Chất xơ', '${nutritionValues['fiber']?.toInt() ?? 0}g', Colors.brown),
                  _buildDetailItem('Cholesterol', '${_formatValue(nutritionInfo["cholesterol"])}mg', Colors.orange.shade700),
                  
                  SizedBox(height: 16),
                  
                  // Vitamin
                  _buildSectionHeader('Vitamin'),
                  _buildDetailItem('Vitamin A', '${_formatValue(nutritionInfo["vitaminA"])}mcg', Colors.amber),
                  _buildDetailItem('Vitamin D', '${_formatValue(nutritionInfo["vitaminD"])}mcg', Colors.amber),
                  _buildDetailItem('Vitamin E', '${_formatValue(nutritionInfo["vitaminE"])}mg', Colors.green.shade300),
                  _buildDetailItem('Vitamin K', '${_formatValue(nutritionInfo["vitaminK"])}mcg', Colors.green.shade700),
                  _buildDetailItem('Vitamin C', '${_formatValue(nutritionInfo["vitaminC"])}mg', Colors.orange),
                  _buildDetailItem('Vitamin B12', '${_formatValue(nutritionInfo["vitaminB12"])}mcg', Colors.purple),
                  _buildDetailItem('Folate (B9)', '${_formatValue(nutritionInfo["vitaminB9"])}mcg', Colors.green),
                  _buildDetailItem('Thiamin (B1)', '${_formatValue(nutritionInfo["thiamin"])}mg', Colors.amber.shade600),
                  _buildDetailItem('Riboflavin (B2)', '${_formatValue(nutritionInfo["riboflavin"])}mg', Colors.amber.shade700),
                  _buildDetailItem('Niacin (B3)', '${_formatValue(nutritionInfo["niacin"])}mg', Colors.amber.shade800),
                  
                  SizedBox(height: 16),
                  
                  // Khoáng chất
                  _buildSectionHeader('Khoáng chất'),
                  _buildDetailItem('Sắt', '${_formatValue(nutritionInfo["iron"])}mg', Colors.red),
                  _buildDetailItem('Canxi', '${_formatValue(nutritionInfo["calcium"])}mg', Colors.grey),
                  _buildDetailItem('Magie', '${_formatValue(nutritionInfo["magnesium"])}mg', Colors.grey.shade600),
                  _buildDetailItem('Kẽm', '${_formatValue(nutritionInfo["zinc"])}mg', Colors.blue.shade400),
                  _buildDetailItem('Kali', '${_formatValue(nutritionInfo["potassium"])}mg', Colors.purple.shade200),
                  _buildDetailItem('Phốt pho', '${_formatValue(nutritionInfo["phosphorus"])}mg', Colors.grey.shade500),
                  _buildDetailItem('Selen', '${_formatValue(nutritionInfo["selenium"])}mcg', Colors.orange.shade300),
                  _buildDetailItem('Đồng', '${_formatValue(nutritionInfo["copper"])}mg', Colors.brown.shade300),
                  _buildDetailItem('Mangan', '${_formatValue(nutritionInfo["manganese"])}mg', Colors.pink.shade300),
                  
                  SizedBox(height: 16),
                  
                  // Các chất dinh dưỡng khác
                  _buildSectionHeader('Khác'),
                  _buildDetailItem('Chất béo bão hòa', '${_formatValue(nutritionInfo["saturatedFat"])}g', Colors.grey.shade700),
                  _buildDetailItem('Chất béo trans', '${_formatValue(nutritionInfo["transFat"])}g', Colors.red.shade300),
                  _buildDetailItem('Omega-3', '${_formatValue(nutritionInfo["omega3"])}mg', Colors.cyan),
                  _buildDetailItem('Caffeine', '${_formatValue(nutritionInfo["caffeine"])}mg', Colors.brown),
                  _buildDetailItem('Rượu', '${_formatValue(nutritionInfo["alcohol"])}g', Colors.amber),
                  _buildDetailItem('Nước', '${_formatValue(nutritionInfo["water"])}ml', Colors.blue),
                  _buildDetailItem('Natri', '${_formatValue(nutritionInfo["sodium"])}mg', Colors.grey.shade400),
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
    } catch (e) {
      // Đóng dialog loading nếu có lỗi
      Navigator.of(context).pop();
      
      // Hiển thị dialog lỗi
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Lỗi cập nhật'),
          content: Text('Không thể cập nhật thông tin dinh dưỡng: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  // Kiểm tra xem thông tin dinh dưỡng có đầy đủ không
  static bool _hasCompleteNutritionData(Map<String, dynamic> nutritionInfo) {
    // Kiểm tra các giá trị dinh dưỡng quan trọng
    final requiredKeys = [
      'calories', 'protein', 'fat', 'carbs',
      'vitaminA', 'vitaminC', 'calcium', 'iron'
    ];
    
    return requiredKeys.every((key) => nutritionInfo.containsKey(key));
  }

  /// Hiển thị dialog chia sẻ
  static void showShareOptions(BuildContext context) {
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
                _buildShareOption(context, Icons.facebook, 'Facebook', Colors.blue),
                _buildShareOption(context, Icons.chat, 'Message', Colors.green),
                _buildShareOption(context, Icons.copy, 'Copy Link', Colors.orange),
                _buildShareOption(context, Icons.more_horiz, 'More', Colors.purple),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Hiển thị dialog sửa thông tin thực phẩm
  static Future<String?> showEditFoodDetailsDialog(BuildContext context, String currentDescription) {
    String tempDescription = currentDescription;
    
    return showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
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
                Navigator.pop(context, tempDescription);
              },
              child: Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  /// Hiển thị dialog loading khi đồng bộ
  static showSynchronizingDialog(BuildContext context) {
    return showDialog(
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
  }

  /// Hiển thị dialog đang cập nhật
  static showSavingDialog(BuildContext context) {
    return showDialog(
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
  }

  // Private helper methods
  static Widget _buildSectionHeader(String title) {
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
  
  static Widget _buildDetailItem(String label, String value, Color color) {
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
  
  static Widget _buildShareOption(BuildContext context, IconData icon, String label, Color color) {
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
  
  static String _formatValue(dynamic value) {
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
} 