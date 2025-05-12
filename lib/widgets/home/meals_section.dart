import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../meal_components.dart';
import '../home/meal_cards.dart';
import '../../providers/food_provider.dart';
import '../../models/food_entry.dart';
import '../../utils/constants.dart';

class MealsSection extends StatelessWidget {
  final VoidCallback onMealTap;

  const MealsSection({
    Key? key,
    required this.onMealTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lấy provider để truy cập dữ liệu bữa ăn
    final foodProvider = Provider.of<FoodProvider>(context);
    final selectedDate = foodProvider.selectedDate;
    
    List<FoodEntry> todayEntries = foodProvider.todayEntries;
    
    // Sắp xếp theo thời gian gần nhất
    todayEntries.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    
    // Nhóm bữa ăn theo loại
    Map<String, List<FoodEntry>> mealsByType = {};
    for (var entry in todayEntries) {
      String normalizedType = _normalizeMealType(entry.mealType);
      if (!mealsByType.containsKey(normalizedType)) {
        mealsByType[normalizedType] = [];
      }
      mealsByType[normalizedType]!.add(entry);
    }
    
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
        
        // Bữa phụ
        _buildMealSection(
          context: context,
          mealType: 'Bữa phụ',
          mealExists: mealsByType.containsKey('Bữa phụ'),
          entries: mealsByType['Bữa phụ'],
          icon: Icons.access_time,
          color: Colors.purple,
          suggestion: 'Hoa quả, sữa chua, hạt',
          calories: '506',
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
        onAddPressed: onMealTap,
      );
    } else {
      return MealItemCard(
        title: mealType,
        subtitle: 'Gợi ý: $suggestion',
        icon: icon,
        color: color,
        calories: '${calories}kcal',
        onAddPressed: onMealTap,
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