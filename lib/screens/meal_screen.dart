import 'package:flutter/material.dart';
import '../widgets/day_selector.dart';
import '../widgets/meal_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/constants.dart';
import '../screens/food_logging_screen.dart';
import '../utils/auth_helper.dart';

class MealScreen extends StatefulWidget {
  final String? mealId;

  const MealScreen({Key? key, this.mealId}) : super(key: key);
  
  @override
  _MealScreenState createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  int _selectedDay = 8;
  int _selectedNavIndex = 3;

  @override
  void initState() {
    super.initState();
    // Nếu có mealId truyền vào, có thể thực hiện logic lấy dữ liệu tại đây
    if (widget.mealId != null) {
      _loadMealData(widget.mealId!);
    }
  }
  
  // Phương thức mẫu để load dữ liệu bữa ăn từ ID
  void _loadMealData(String mealId) {
    // TODO: Implement loading meal data from database or API
    print('Loading meal data for ID: $mealId');
    // Có thể sử dụng Provider, Firebase hoặc API khác để lấy dữ liệu
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.mealId != null ? 'Chi tiết bữa ăn' : 'DietAI'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          DaySelector(
            selectedDay: _selectedDay,
            onDaySelected: (day) {
              setState(() {
                _selectedDay = day;
              });
            },
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildMealHeader('Bữa sáng', AppIcons.breakfast),
                MealItem(
                  imageUrl: 'assets/images/breakfast.png',
                  calories: 506,
                  onAddPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FoodLoggingScreen()),
                    );
                  },
                ),
                _buildMealHeader('Bữa trưa', AppIcons.lunch),
                MealItem(
                  imageUrl: 'assets/images/lunch.png',
                  calories: 811,
                  onAddPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FoodLoggingScreen()),
                    );
                  },
                ),
                _buildMealHeader('Bữa tối', AppIcons.dinner),
                MealItem(
                  imageUrl: 'assets/images/dinner.png',
                  calories: 811,
                  onAddPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FoodLoggingScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedNavIndex,
        onItemSelected: (index) {
          setState(() {
            _selectedNavIndex = index;
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Kiểm tra đăng nhập trước khi vào food logging
          final success = await AuthHelper.requireLogin(
            context,
            onAuthenticated: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FoodLoggingScreen()),
            ),
            title: 'Ghi lại bữa ăn',
            message: 'Mời bạn đăng nhập để trải nghiệm tính năng ghi lại bữa ăn và nhận diện thức ăn bằng AI',
            feature: 'ghi lại bữa ăn',
          );

          if (!success) {
            AuthHelper.showLoginRequiredSnackBar(
              context,
              feature: 'ghi lại bữa ăn',
            );
          }
        },
        backgroundColor: Colors.green.shade100,
        child: Icon(
          Icons.camera_alt_outlined,
          color: AppColors.primary,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildMealHeader(String title, String icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Text(
            icon,
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}