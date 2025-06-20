import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../meal_components.dart' as components;
import '../home/meal_cards.dart';
import '../../providers/food_provider.dart';
import '../../models/food_entry.dart';
import '../../utils/constants.dart';

class MealsSection extends StatelessWidget {
  final VoidCallback onMealTap;
  final Function(FoodEntry)? onFoodItemTap;
  final Function(String)? onMealTypeTap;

  const MealsSection({
    Key? key,
    required this.onMealTap,
    this.onFoodItemTap,
    this.onMealTypeTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lấy provider để truy cập dữ liệu bữa ăn
    final foodProvider = Provider.of<FoodProvider>(context);
    final selectedDate = foodProvider.selectedDate;
    
    // In log để debug
    print('MealsSection.build: Ngày đang chọn: $selectedDate');
    
    // Lấy dữ liệu từ todayEntries để đảm bảo phù hợp với mục đích ban đầu
    List<FoodEntry> entries = foodProvider.todayEntries;
    
    // In log số lượng entries
    print('MealsSection.build: Số lượng entries: ${entries.length}');
    
    // In thông tin chi tiết về các entries để debug
    for (var entry in entries) {
      final entryDate = entry.dateTime.toIso8601String().split('T')[0];
      print('MealsSection.build: Entry: ${entry.description} (${entry.mealType}) - ngày: $entryDate');
    }
    
    // Hiển thị loading indicator nếu đang tải dữ liệu
    if (foodProvider.isLoadingMeals && entries.isEmpty) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Center(
              child: CircularProgressIndicator(),
            ),
            SizedBox(height: 16),
            Text(
              'Đang tải dữ liệu bữa ăn...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Sắp xếp theo thời gian gần nhất
    entries.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    
    // Nhóm bữa ăn theo loại
    Map<String, List<FoodEntry>> mealsByType = {};
    for (var entry in entries) {
      String normalizedType = _normalizeMealType(entry.mealType);
      if (!mealsByType.containsKey(normalizedType)) {
        mealsByType[normalizedType] = [];
      }
      mealsByType[normalizedType]!.add(entry);
    }
    
    // In log các loại bữa ăn đã tìm thấy để debug
    print('MealsSection.build: Các loại bữa ăn đã tìm thấy: ${mealsByType.keys.join(', ')}');
    
    // Hiển thị bữa ăn theo thứ tự: sáng-trưa-tối-phụ
    return Column(
      children: [
        // Bữa sáng
        _buildMealSection(
          context: context,
          mealType: 'Bữa sáng',
          mealExists: mealsByType.containsKey('Bữa sáng'),
          entries: mealsByType['Bữa sáng'],
          icon: Icons.wb_sunny_outlined,
          color: Colors.orange,
          suggestion: 'Bánh mì ngũ cốc, trứng, sữa',
          calories: '506',
        ),
        
        // Bữa trưa
        _buildMealSection(
          context: context,
          mealType: 'Bữa trưa',
          mealExists: mealsByType.containsKey('Bữa trưa'),
          entries: mealsByType['Bữa trưa'],
          icon: Icons.wb_cloudy_outlined,
          color: Colors.lightBlue,
          suggestion: 'Cơm, rau xào, thịt gà',
          calories: '811',
        ),
        
        // Bữa tối
        _buildMealSection(
          context: context,
          mealType: 'Bữa tối',
          mealExists: mealsByType.containsKey('Bữa tối'),
          entries: mealsByType['Bữa tối'],
          icon: Icons.nights_stay_outlined,
          color: Colors.indigo,
          suggestion: 'Soup, cá hồi, salad',
          calories: '811',
        ),
      ],
    );
  }
  
  Widget _buildMealSection({
    required BuildContext context,
    required String mealType,
    required bool mealExists,
    List<FoodEntry>? entries,
    required IconData icon,
    required Color color,
    required String suggestion,
    required String calories,
  }) {
    if (mealExists && entries != null) {
      return MealFoodDetailCard(
        mealType: mealType,
        entries: entries,
        onAddPressed: onMealTypeTap != null ? () => onMealTypeTap!(mealType) : onMealTap,
        onFoodItemTap: onFoodItemTap,
      );
    } else {
      // Using MealItemCard from meal_cards.dart, not the one from meal_components.dart
      return MealItemCard(
        title: mealType,
        subtitle: 'Gợi ý: $suggestion',
        icon: icon,
        color: color,
        calories: '${calories}kcal',
        onAddPressed: onMealTypeTap != null ? () => onMealTypeTap!(mealType) : onMealTap,
      );
    }
  }
  
  // Chuẩn hóa tên loại bữa ăn
  String _normalizeMealType(String type) {
    // Kiểm tra các giá trị chính xác trước
    if (type == 'Bữa sáng') return 'Bữa sáng';
    if (type == 'Bữa trưa') return 'Bữa trưa';
    if (type == 'Bữa tối') return 'Bữa tối';
    if (type == 'Bữa phụ') return 'Bữa phụ';
    
    // Kiểm tra dựa trên từ khóa
    if (type.toLowerCase().contains('sáng')) return 'Bữa sáng';
    if (type.toLowerCase().contains('trưa')) return 'Bữa trưa';
    if (type.toLowerCase().contains('tối')) return 'Bữa tối';
    if (type.toLowerCase().contains('phụ') || 
        type.toLowerCase().contains('nhẹ') || 
        type.toLowerCase().contains('vặt')) return 'Bữa phụ';
    
    // Tự động phân loại theo thời gian nếu không có loại bữa ăn
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return 'Bữa sáng';
    if (hour >= 11 && hour < 14) return 'Bữa trưa';
    if (hour >= 17 && hour < 22) return 'Bữa tối';
    return 'Bữa phụ';
  }
} 