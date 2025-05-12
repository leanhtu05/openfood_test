import 'package:flutter/material.dart';
import '../widgets/day_selector.dart';
import '../widgets/meal_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/constants.dart';
import '../screens/food_logging_screen.dart';

class MealScreen extends StatefulWidget {
  @override
  _MealScreenState createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  int _selectedDay = 8;
  int _selectedNavIndex = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('DietAI'),
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
                _buildMealHeader('Đồ ăn nhẹ', AppIcons.snack),
                MealItem(
                  imageUrl: 'assets/images/snack.png',
                  calories: 506,
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FoodLoggingScreen()),
          );
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