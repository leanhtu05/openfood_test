import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/food_entry.dart';
import 'food_item_card.dart';

class FoodItemsList extends StatelessWidget {
  final List<FoodItem> items;
  final Function(List<FoodItem>) onItemsChanged;
  final FoodEntry foodEntry;

  const FoodItemsList({
    Key? key,
    required this.items,
    required this.onItemsChanged,
    required this.foodEntry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thực phẩm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.add, size: 18),
                label: Text('Thêm'),
                onPressed: () {
                  // Tính năng thêm thực phẩm mới sẽ được triển khai sau
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chức năng thêm thực phẩm sẽ được bổ sung trong bản cập nhật tiếp theo'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Chưa có thực phẩm nào được thêm vào',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          // Wrap ListView in a Container with a fixed height if there are many items
          items.length <= 3 
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildFoodItemCards(),
            )
          : Container(
              height: 350, // Fixed height for many items
              child: ListView.builder(
                shrinkWrap: true,
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return FoodItemCard(
                    item: items[index],
                    index: index,
                    foodEntry: foodEntry,
                    onFoodEntryChanged: (updatedFoodEntry) {
                      // Cập nhật danh sách item từ updatedFoodEntry
                      onItemsChanged(updatedFoodEntry.items);
                    },
                    onDeletePressed: () {
                      // Xóa item khỏi danh sách
                      final updatedItems = List<FoodItem>.from(items);
                      updatedItems.removeAt(index);
                      onItemsChanged(updatedItems);
                    },
                  );
                },
              ),
            ),
      ],
    );
  }

  // Helper method to build food item cards without ListView when there are few items
  List<Widget> _buildFoodItemCards() {
    return List.generate(
      items.length,
      (index) => FoodItemCard(
        item: items[index],
        index: index,
        foodEntry: foodEntry,
        onFoodEntryChanged: (updatedFoodEntry) {
          onItemsChanged(updatedFoodEntry.items);
        },
        onDeletePressed: () {
          final updatedItems = List<FoodItem>.from(items);
          updatedItems.removeAt(index);
          onItemsChanged(updatedItems);
        },
      ),
    );
  }
} 