import 'package:flutter/material.dart';
import '../../models/food_entry.dart';
import '../../models/food_item.dart';
import '../../utils/constants.dart';
import 'meal_nutrition_summary.dart';
import 'food_item_row.dart';

/// Widget hiển thị thẻ thông tin bữa ăn nhỏ gọn
class MealDetailCard extends StatelessWidget {
  final String mealType;
  final List<FoodItem> items;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final VoidCallback? onTap;

  const MealDetailCard({
    Key? key,
    required this.mealType,
    required this.items,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.onTap,
  }) : super(key: key);

  // Constructor tạo từ FoodEntry
  factory MealDetailCard.fromFoodEntry({
    required FoodEntry entry,
    VoidCallback? onTap,
  }) {
    // Sử dụng calculateNutritionFromAPI để lấy dữ liệu dinh dưỡng chính xác từ API hoặc từ items
    final nutritionValues = entry.calculateNutritionFromAPI();
    
    return MealDetailCard(
      mealType: entry.mealType,
      items: entry.items,
      totalCalories: nutritionValues['calories'] ?? 0,
      totalProtein: nutritionValues['protein'] ?? 0,
      totalCarbs: nutritionValues['carbs'] ?? 0,
      totalFat: nutritionValues['fat'] ?? 0,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với tên bữa ăn và thông tin calories
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: getMealColor(mealType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                getMealIcon(mealType),
                color: getMealColor(mealType),
              ),
            ),
            title: Row(
              children: [
                Text(
                  getMealDisplayName(mealType),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.fiber_manual_record, size: 8, color: Colors.grey),
                SizedBox(width: 8),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 16, color: Colors.redAccent),
                    SizedBox(width: 4),
                    Text(
                      '${totalCalories.toInt()}kcal',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.more_horiz, color: Colors.grey),
              onPressed: onTap,
            ),
          ),
          
          // Danh sách món ăn
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildFoodItems(items),
            ),
          ),
          
          // Tổng hợp chỉ số dinh dưỡng
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNutrientInfo(
                  icon: Icons.local_fire_department, 
                  value: '${totalCalories.toInt()}kcal', 
                  color: Colors.redAccent
                ),
                _buildNutrientInfo(
                  icon: Icons.water_drop, 
                  value: '${totalProtein.toInt()}g', 
                  color: Colors.blue
                ),
                _buildNutrientInfo(
                  icon: Icons.grain, 
                  value: '${totalCarbs.toInt()}g', 
                  color: Colors.orange
                ),
                _buildNutrientInfo(
                  icon: Icons.circle, 
                  value: '${totalFat.toInt()}g', 
                  color: Colors.green
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị trong MealDetailCard
  List<Widget> _buildFoodItems(List<FoodItem> items, {FoodEntry? foodEntry}) {
    return items.map((item) {
      return _buildFoodItem(item, foodEntry: foodEntry);
    }).toList();
  }

  // Kiểm tra xem description có trùng với tên các items không
  bool _isDescriptionSameAsItems(FoodEntry entry) {
    if (entry.items.isEmpty) return false;

    // Nếu chỉ có 1 item và tên giống description
    if (entry.items.length == 1) {
      return entry.description.toLowerCase().trim() == entry.items.first.name.toLowerCase().trim();
    }

    // Nếu có nhiều items, kiểm tra xem description có chứa tất cả tên items không
    final descriptionLower = entry.description.toLowerCase();
    return entry.items.every((item) => descriptionLower.contains(item.name.toLowerCase()));
  }

  // Widget hiển thị thông tin từng món ăn
  Widget _buildFoodItem(FoodItem item, {FoodEntry? foodEntry}) {
    // Đảm bảo servingSize không nhỏ hơn hoặc bằng 0
    final effectiveServingSize = item.servingSize <= 0 ? 1.0 : item.servingSize;
    
    // Xác định nên sử dụng dữ liệu từ đâu (nutritionInfo hay từ FoodItem)
    Map<String, dynamic> nutritionValues = {};
    
    if (foodEntry != null && foodEntry.nutritionInfo != null) {
      // Nếu có FoodEntry với nutritionInfo, sử dụng dữ liệu từ API
      final nutritionInfo = foodEntry.nutritionInfo!;
      final servingRatio = effectiveServingSize / (nutritionInfo['servingSize'] ?? 1.0);
      
      nutritionValues = {
        'calories': ((nutritionInfo['calories'] as num?)?.toDouble() ?? item.calories) * servingRatio,
        'protein': ((nutritionInfo['protein'] as num?)?.toDouble() ?? item.protein) * servingRatio,
        'fat': ((nutritionInfo['fat'] as num?)?.toDouble() ?? item.fat) * servingRatio,
        'carbs': ((nutritionInfo['carbs'] as num?)?.toDouble() ?? item.carbs) * servingRatio,
        'totalWeight': (nutritionInfo['totalWeight'] as num?)?.toDouble() ?? (effectiveServingSize * 100),
      };
    } else {
      // Nếu không có nutritionInfo, tính từ FoodItem
      nutritionValues = {
        'calories': item.calories * effectiveServingSize,
        'protein': item.protein * effectiveServingSize,
        'fat': item.fat * effectiveServingSize,
        'carbs': item.carbs * effectiveServingSize,
        'totalWeight': effectiveServingSize * 100, // Hiển thị gram
      };
    }
    
    // Lấy khối lượng và calo đã tính toán
    final totalWeight = nutritionValues['totalWeight']?.toInt() ?? 100;
    final actualCalories = nutritionValues['calories']?.toInt() ?? 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            item.name,
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(width: 4),
          Text(
            '${totalWeight}${item.servingUnit}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Spacer(),
          Text(
            '${actualCalories}kcal',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget hiển thị thông tin dinh dưỡng
  Widget _buildNutrientInfo({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

/// Widget hiển thị chi tiết bữa ăn với danh sách món ăn và nút thêm
class MealFoodDetailCard extends StatelessWidget {
  final String mealType;
  final List<FoodEntry> entries;
  final VoidCallback onAddPressed;
  // Thêm callback để xử lý khi một món ăn cụ thể được nhấn
  final Function(FoodEntry)? onFoodItemTap;

  const MealFoodDetailCard({
    Key? key,
    required this.mealType,
    required this.entries,
    required this.onAddPressed,
    this.onFoodItemTap, // Optional
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tính tổng dinh dưỡng của tất cả các entries sử dụng calculateNutritionFromAPI
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    
    // Danh sách tất cả các món ăn
    final allItems = <FoodItem>[];
    
    for (var entry in entries) {
      // Sử dụng calculateNutritionFromAPI để lấy dữ liệu dinh dưỡng chính xác
      final nutritionValues = entry.calculateNutritionFromAPI();
      totalCalories += nutritionValues['calories'] ?? 0;
      totalProtein += nutritionValues['protein'] ?? 0;
      totalCarbs += nutritionValues['carbs'] ?? 0;
      totalFat += nutritionValues['fat'] ?? 0;
      
      allItems.addAll(entry.items);
    }
    
    final mealColor = getMealColor(mealType);
    final mealIcon = getMealIcon(mealType);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
          // Header với tóm tắt dinh dưỡng
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mealColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(mealIcon, color: mealColor, size: 20),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealType,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${allItems.length} món · ${totalCalories.toInt()} kcal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 80),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded, 
                            size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          '${totalCalories.toInt()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            ' kcal',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Nutrition summary
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientBadge(
                  totalProtein.toInt(), 
                  'g',
                  'Protein',
                  Colors.blue,
                ),
                _buildNutrientBadge(
                  totalCarbs.toInt(), 
                  'g',
                  'Carbs',
                  Colors.orange,
                ),
                _buildNutrientBadge(
                  totalFat.toInt(), 
                  'g',
                  'Chất béo',
                  Colors.yellow.shade700,
                ),
              ],
            ),
          ),
          
          // Divider chính
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          
          // Danh sách các món ăn
          if (allItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 36,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Chưa có món ăn',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                physics: BouncingScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: entries.length, // Thay đổi từ allItems.length thành entries.length để tạo dòng theo mỗi entry
                separatorBuilder: (context, index) => Divider(
                  height: 1, 
                  thickness: 1, 
                  color: Colors.grey.shade100,
                  indent: 8,
                  endIndent: 8,
                ),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  
                  // Tính toán dinh dưỡng từ entry
                  final nutritionValues = entry.calculateNutritionFromAPI();
                  final calculatedCalories = nutritionValues['calories']?.toInt() ?? 0;
                  
                  return InkWell(
                    onTap: onFoodItemTap != null ? () => onFoodItemTap!(entry) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          // Food icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                entry.description.isNotEmpty ? entry.description[0].toUpperCase() : "F",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Food name and details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Chỉ hiển thị description nếu không có items hoặc description khác với tên items

                                  Text(
                                    entry.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  SizedBox(height: 4),
                                // Hiển thị các món ăn dưới dạng chips
                                if (entry.items.isNotEmpty)
                                  _buildFoodItemChips(entry.items)
                                else
                                  Text(
                                    'Món đơn lẻ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          // Calories
                          Text(
                            '$calculatedCalories',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                          Text(
                            'kcal',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
          // Nút ghi lại thực phẩm
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: TextButton.icon(
              onPressed: onAddPressed,
              icon: Icon(Icons.add_circle, color: mealColor, size: 18),
              label: Text(
                'Ghi lại thực phẩm',
                style: TextStyle(
                  color: mealColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: mealColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget hiển thị các món ăn dưới dạng chips
  Widget _buildFoodItemChips(List<FoodItem> items) {
    // Lấy tối đa 4 món đầu tiên để tránh quá dài
    final displayItems = items.take(4).toList();
    final hasMore = items.length > 4;

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...displayItems.map((item) => Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Text(
            item.name,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        )),
        if (hasMore)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 0.5),
            ),
            child: Text(
              '+${items.length - 4}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNutrientBadge(int value, String unit, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$value',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget hiển thị thẻ bữa ăn khi không có món ăn nào
class MealItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String calories;
  final VoidCallback onAddPressed;

  const MealItemCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.calories,
    required this.onAddPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onAddPressed, // Sử dụng onAddPressed để tạo bữa ăn đúng
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Container biểu tượng bữa ăn
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                SizedBox(width: 16),
                
                // Thông tin bữa ăn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Khoảng $calories',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Nút thêm món ăn
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: onAddPressed,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.add,
                      color: color,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Hàm tiện ích dùng chung cho cả hai widget

// Lấy biểu tượng tương ứng với loại bữa ăn
IconData getMealIcon(String mealType) {
  switch (mealType.toLowerCase()) {
    case 'sáng':
    case 'bữa sáng':
      return Icons.wb_sunny_outlined;
    case 'trưa':
    case 'bữa trưa':
      return Icons.wb_cloudy_outlined;
    case 'tối':
    case 'bữa tối':
      return Icons.nights_stay_outlined;
    case 'phụ':
    case 'bữa phụ':
      return Icons.access_time;
    default:
      return Icons.restaurant;
  }
}

// Lấy màu sắc tương ứng với loại bữa ăn
Color getMealColor(String mealType) {
  switch (mealType.toLowerCase()) {
    case 'sáng':
    case 'bữa sáng':
      return Colors.orange;
    case 'trưa':
    case 'bữa trưa':
      return Colors.lightBlue;
    case 'tối':
    case 'bữa tối':
      return Colors.indigo;
    default:
      return Colors.green;
  }
}

// Hiển thị tên bữa ăn phù hợp
String getMealDisplayName(String mealType) {
  if (mealType.toLowerCase().contains('sáng')) return 'Bữa sáng';
  if (mealType.toLowerCase().contains('trưa')) return 'Bữa trưa';
  if (mealType.toLowerCase().contains('tối')) return 'Bữa tối';
  return mealType;
}