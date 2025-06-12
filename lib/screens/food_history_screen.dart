import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/food_entry.dart';
import '../providers/food_provider.dart';
import '../utils/constants.dart';
import '../screens/food_nutrition_detail_screen.dart';

// Lớp định nghĩa style mặc định cho ứng dụng
class AppStyles {
  // Font styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.3,
  );
  
  static const TextStyle subtitle1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );
  
  // Colors
  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color secondaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  
  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );
  
  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 800);
}

class FoodHistoryScreen extends StatefulWidget {
  static const routeName = '/food-history';

  @override
  _FoodHistoryScreenState createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends State<FoodHistoryScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _fadeController;
  
  @override
  void initState() {
    super.initState();
    
    // Animation controller setup
    _fadeController = AnimationController(
      vsync: this,
      duration: AppStyles.mediumAnimationDuration,
    );
    
    // Tải dữ liệu khi màn hình được khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    // Sử dụng loadData() thay vì loadFoodEntries() không tồn tại
    await foodProvider.loadData();
    
    setState(() {
      _isLoading = false;
    });
    
    // Start animation after data is loaded
    _fadeController.forward();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              Icon(Icons.access_time, color: AppStyles.primaryColor, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thực phẩm đã ghi nhận', 
                  style: AppStyles.heading2.copyWith(color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list, color: AppStyles.secondaryColor, size: 20),
              onPressed: () {
                // Add haptic feedback
                HapticFeedback.lightImpact();
              },
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppStyles.primaryColor),
                ),
              )
            : FadeTransition(
                opacity: _fadeController,
                child: _buildFoodEntriesList(),
              ),
      ),
    );
  }
  
  Widget _buildFoodEntriesList() {
    final foodProvider = Provider.of<FoodProvider>(context);
    final entries = foodProvider.entries;
    
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_food,
              size: 64,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 16),
            Text(
              'Chưa có bữa ăn nào được ghi lại',
              style: AppStyles.body1.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // Nhóm các bữa ăn theo ngày
    final groupedEntries = <String, List<FoodEntry>>{};
    for (var entry in entries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(entry.dateTime);
      if (!groupedEntries.containsKey(dateStr)) {
        groupedEntries[dateStr] = [];
      }
      groupedEntries[dateStr]!.add(entry);
    }
    
    return AnimationLimiter(
      child: ListView.builder(
        physics: BouncingScrollPhysics(),
        itemCount: groupedEntries.length,
        padding: EdgeInsets.only(bottom: 24, top: 8),
        itemBuilder: (context, index) {
          final dateStr = groupedEntries.keys.elementAt(index);
          final entriesForDate = groupedEntries[dateStr]!;
          final date = DateTime.parse(dateStr);
          
          // Tính tổng dinh dưỡng cho ngày này
          double totalCalories = 0;
          double totalProtein = 0;
          double totalFat = 0; 
          double totalCarbs = 0;
          
          for (var entry in entriesForDate) {
            totalCalories += entry.calculateNutritionFromAPI()['calories'] ?? 0;
            totalProtein += entry.calculateNutritionFromAPI()['protein'] ?? 0;
            totalFat += entry.calculateNutritionFromAPI()['fat'] ?? 0;
            totalCarbs += entry.calculateNutritionFromAPI()['carbs'] ?? 0;
          }
          
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: AppStyles.mediumAnimationDuration,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 12),
                    // Tiêu đề ngày và tổng lượng dinh dưỡng
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(date),
                            style: AppStyles.heading1,
                          ),
                          SizedBox(height: 8),
                          // Tổng lượng dinh dưỡng theo ngày
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildNutrientSummary(Icons.local_fire_department, '${totalCalories.round()}kcal', Colors.orange),
                                  SizedBox(width: 16),
                                  _buildNutrientSummary(Icons.circle, '${totalProtein.round()}g', Colors.blue),
                                  SizedBox(width: 16),
                                  _buildNutrientSummary(Icons.circle, '${totalFat.round()}g', Colors.amber),
                                  SizedBox(width: 16),
                                  _buildNutrientSummary(Icons.circle, '${totalCarbs.round()}g', Colors.green),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    ...entriesForDate.asMap().map((i, entry) => MapEntry(
                      i,
                      AnimationConfiguration.staggeredList(
                        position: i,
                        duration: Duration(milliseconds: 300),
                        child: SlideAnimation(
                          horizontalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildFoodEntryItem(entry),
                          ),
                        ),
                      ),
                    )).values.toList(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNutrientSummary(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          text,
          style: AppStyles.body1.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFoodEntryItem(FoodEntry entry) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final nutritionValues = entry.calculateNutritionFromAPI();
    
    // Lấy giá trị dinh dưỡng
    final calories = nutritionValues['calories'] ?? 0;
    final protein = nutritionValues['protein'] ?? 0;
    final fat = nutritionValues['fat'] ?? 0;
    final carbs = nutritionValues['carbs'] ?? 0;
    
    // Unique tag for hero animation
    final heroTag = 'food-${entry.id}';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodNutritionDetailScreen(
                  foodEntry: entry,
                  onSave: (updatedEntry) => foodProvider.updateFoodEntry(updatedEntry),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ảnh thực phẩm
                Hero(
                  tag: heroTag,
                  child: _buildFoodImage(entry),
                ),
                SizedBox(width: 12),
                
                // Thông tin bữa ăn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên thực phẩm
                      Text(
                        entry.description,
                        style: AppStyles.subtitle1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      
                      // Loại bữa ăn và thời gian
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getMealTypeIcon(entry.mealType),
                                  size: 12,
                                  color: Colors.grey.shade700,
                                ),
                                SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    entry.mealType,
                                    style: AppStyles.caption.copyWith(
                                      color: Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      _formatDetailedDate(entry.dateTime),
                                      style: AppStyles.caption.copyWith(
                                        color: Colors.blue.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 8),
                      // Thông tin dinh dưỡng
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildNutrientInfo(Icons.local_fire_department, '${calories.round()}kcal', Colors.orange),
                              SizedBox(width: 10),
                              _buildNutrientInfo(Icons.circle, '${protein.round()}g', Colors.blue),
                              SizedBox(width: 10),
                              _buildNutrientInfo(Icons.circle, '${fat.round()}g', Colors.amber),
                              SizedBox(width: 10),
                              _buildNutrientInfo(Icons.circle, '${carbs.round()}g', Colors.green),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Menu
                Material(
                  color: Colors.transparent,
                  shape: CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: IconButton(
                    icon: Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    splashColor: Colors.grey.shade200,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _showOptionsMenu(context, entry);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFoodImage(FoodEntry entry) {
    return AnimatedContainer(
      duration: AppStyles.shortAnimationDuration,
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppStyles.primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: entry.imagePath != null && entry.imagePath!.isNotEmpty
          ? Image.file(
              File(entry.imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildDefaultFoodImage(),
            )
          : _buildDefaultFoodImage(),
      ),
    );
  }
  
  Widget _buildDefaultFoodImage() {
    return Container(
      color: Colors.green.shade50,
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: AppStyles.primaryColor,
          ),
        ),
      ),
    );
  }
  
  Widget _buildNutrientInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: 3),
        Text(
          text,
          style: AppStyles.body2.copyWith(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showOptionsMenu(BuildContext context, FoodEntry entry) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(top: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ListTile(
            leading: Icon(Icons.edit, color: AppStyles.secondaryColor, size: 20),
            title: Text('Chỉnh sửa', style: AppStyles.body1),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FoodNutritionDetailScreen(
                    foodEntry: entry,
                    onSave: (updatedEntry) => foodProvider.updateFoodEntry(updatedEntry),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.favorite,
              color: entry.isFavorite ? AppStyles.errorColor : Colors.grey,
              size: 20,
            ),
            title: Text(
              entry.isFavorite ? 'Bỏ yêu thích' : 'Yêu thích',
              style: AppStyles.body1,
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              foodProvider.toggleFavorite(entry.id, !entry.isFavorite);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: AppStyles.errorColor, size: 20),
            title: Text('Xóa', style: AppStyles.body1),
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              _confirmDelete(context, entry);
            },
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }
  
  void _confirmDelete(BuildContext context, FoodEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa bữa ăn', style: AppStyles.heading2),
        content: Text(
          'Bạn có chắc chắn muốn xóa ${entry.description}?',
          style: AppStyles.body1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            child: Text('Hủy', style: AppStyles.body1),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              'Xóa',
              style: AppStyles.body1.copyWith(color: AppStyles.errorColor),
            ),
            onPressed: () {
              Navigator.pop(context);
              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
              foodProvider.deleteFoodEntry(entry.id);
              
              // Show a more interactive snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Đã xóa bữa ăn', style: AppStyles.body2.copyWith(color: Colors.white)),
                    ],
                  ),
                  behavior: SnackBarBehavior.fixed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: AppStyles.primaryColor,
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'bữa sáng':
        return Icons.wb_sunny_outlined;
      case 'bữa trưa':
        return Icons.wb_sunny;
      case 'bữa tối':
        return Icons.nights_stay;
      case 'bữa phụ':
        return Icons.fastfood;
      default:
        return Icons.restaurant;
    }
  }
  
  String _formatDate(DateTime date) {
    String timeStr = DateFormat('HH:mm').format(date);
    
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      return 'Hôm nay ($timeStr)';
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return 'Hôm qua ($timeStr)';
    } else {
      // Format như "tháng 5 14 (20:46)"
      String month = DateFormat('M', 'vi').format(date);
      String day = DateFormat('d', 'vi').format(date);
      return 'tháng $month $day ($timeStr)';
    }
  }
  
  String _formatDetailedDate(DateTime dateTime) {
    String timeStr = DateFormat('HH:mm').format(dateTime);
    return timeStr;
  }
} 