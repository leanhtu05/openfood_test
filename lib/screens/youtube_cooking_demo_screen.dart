import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import 'recipe_detail_screen.dart';

class YouTubeCookingDemoScreen extends StatelessWidget {
  const YouTubeCookingDemoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Demo YouTube Hướng Dẫn Nấu Ăn',
          style: TextStyle(
            color: Colors.orange.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.orange.shade800),
      ),
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade800],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xem Video Hướng Dẫn Nấu Ăn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Nhấn vào món ăn để xem hướng dẫn trên YouTube',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Danh sách món ăn mẫu:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: _buildSampleDishes(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSampleDishes(BuildContext context) {
    final sampleDishes = [
      {
        'name': 'Phở Bò',
        'description': 'Món phở truyền thống Việt Nam',
        'prepTime': 120,
      },
      {
        'name': 'Bún Chả',
        'description': 'Bún chả Hà Nội thơm ngon',
        'prepTime': 45,
      },
      {
        'name': 'Cơm Tấm',
        'description': 'Cơm tấm sườn nướng',
        'prepTime': 60,
      },
      {
        'name': 'Bánh Mì',
        'description': 'Bánh mì thịt nướng',
        'prepTime': 30,
      },
      {
        'name': 'Gỏi Cuốn',
        'description': 'Gỏi cuốn tôm thịt',
        'prepTime': 25,
      },
      {
        'name': 'Canh Chua',
        'description': 'Canh chua cá bông lau',
        'prepTime': 40,
      },
    ];

    return sampleDishes.map((dishData) {
      return Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.restaurant,
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            dishData['name'] as String,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                dishData['description'] as String,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.orange.shade600),
                  SizedBox(width: 4),
                  Text(
                    '${dishData['prepTime']} phút',
                    style: TextStyle(
                      color: Colors.orange.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Icon(
            Icons.play_circle_outline,
            color: Colors.orange.shade600,
            size: 32,
          ),
          onTap: () {
            // Tạo Dish object mẫu
            final dish = Dish(
              name: dishData['name'] as String,
              description: dishData['description'] as String,
              ingredients: [
                'Nguyên liệu 1',
                'Nguyên liệu 2',
                'Nguyên liệu 3',
              ],
              instructions: [
                'Bước 1: Chuẩn bị nguyên liệu',
                'Bước 2: Chế biến món ăn',
                'Bước 3: Hoàn thiện và trình bày',
              ],
              nutrition: {
                'calories': 300.0,
                'protein': 20.0,
                'fat': 10.0,
                'carbs': 40.0,
              },
              prepTimeInMinutes: dishData['prepTime'] as int,
              detailedIngredients: [],
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(dish: dish),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}
