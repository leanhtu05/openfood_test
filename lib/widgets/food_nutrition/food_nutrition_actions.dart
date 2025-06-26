import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_entry.dart';
import '../../providers/food_provider.dart';
import 'food_nutrition_dialogs.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Lớp chứa các hành động với thực phẩm
class FoodNutritionActions {
  /// Thêm thực phẩm mới
  static void addMoreFood(BuildContext context) {
    // Thông báo tính năng đang phát triển
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tính năng thêm thực phẩm đang được phát triển'),
        duration: Duration(seconds: 2),
      ),
    );
    
    /* Đoạn code này cần được triển khai khi có màn hình FoodItemsListScreen
    // Mở màn hình chọn thực phẩm
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodItemsListScreen(
          onFoodItemSelected: (FoodItem selectedItem) {
            // Xử lý khi người dùng chọn item mới
          },
        ),
      ),
    );
    */
  }

  /// Xóa thực phẩm
  static Future<bool> deleteFood(BuildContext context, FoodEntry foodEntry) async {
    final isConfirmed = await FoodNutritionDialogs.showDeleteConfirmation(context);
    if (isConfirmed == true) {
      try {
        // Xóa ảnh từ Firebase Storage nếu có
        if (foodEntry.imageUrl != null && foodEntry.imageUrl!.isNotEmpty) {
          if (foodEntry.imageUrl!.startsWith('https://firebasestorage.googleapis.com')) {
            try {
              // Tạo reference từ URL
              final storage = FirebaseStorage.instance;
              final ref = storage.refFromURL(foodEntry.imageUrl!);
              
              // Xóa file
              await ref.delete();
              print('Đã xóa ảnh từ Firebase Storage: ${foodEntry.imageUrl}');
            } catch (e) {
              print('Lỗi khi xóa ảnh từ Firebase Storage: $e');
            }
          }
        }
        
        // Kiểm tra nếu có gs:// URL trong imagePath
        if (foodEntry.imagePath != null && foodEntry.imagePath!.isNotEmpty) {
          if (foodEntry.imagePath!.startsWith('gs://')) {
            try {
              // Tạo reference từ gs:// URL
              final storage = FirebaseStorage.instance;
              final ref = storage.refFromURL(foodEntry.imagePath!);
              
              // Xóa file
              await ref.delete();
              print('Đã xóa ảnh từ Firebase Storage (gs:// URL): ${foodEntry.imagePath}');
            } catch (e) {
              print('Lỗi khi xóa ảnh từ Firebase Storage (gs:// URL): $e');
            }
          }
        }
        
        // Xóa entry trong provider
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        foodProvider.deleteFoodEntry(foodEntry.id);
        
        // Đồng bộ dữ liệu với Firestore
        await foodProvider.synchronizeWithFirebase();
        
        // Hiển thị thông báo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa món ăn'),
            duration: Duration(seconds: 2),
          ),
        );
        return true;
      } catch (e) {
        print('Lỗi khi xóa món ăn: $e');
        // Hiển thị thông báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa món ăn: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return false;
      }
    }
    return false;
  }

  /// ✏️ CHỈNH SỬA THÔNG TIN MÓN ĂN (giữ nguyên ngày hiện tại)
  static Future<FoodEntry?> editFoodDetails(BuildContext context, FoodEntry foodEntry) async {
    final newDescription = await FoodNutritionDialogs.showEditFoodDetailsDialog(
      context,
      foodEntry.description,
    );

    if (newDescription != null) {
      print('✏️ EditFoodDetails: Cập nhật tên món ăn từ "${foodEntry.description}" → "$newDescription"');

      // ✏️ GIỮ NGUYÊN NGÀY: Khi edit thông tin, không thay đổi ngày của món ăn
      // Chỉ cập nhật description, giữ nguyên tất cả thông tin khác bao gồm dateTime
      final updatedEntry = foodEntry.copyWith(
        description: newDescription,
        // Không cập nhật dateTime - giữ nguyên ngày hiện tại của món ăn
      );

      // Cập nhật trong provider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      foodProvider.updateFoodEntry(updatedEntry);

      print('✏️ EditFoodDetails: Đã cập nhật thông tin, ngày giữ nguyên: ${updatedEntry.dateTime}');

      return updatedEntry;
    }

    return null;
  }

  /// Thay thế thực phẩm
  static void replaceFood(BuildContext context) {
    // Thông báo tính năng đang phát triển
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tính năng thay thế thực phẩm đang được phát triển'),
        duration: Duration(seconds: 2),
      ),
    );
    
    /* Đoạn code này cần được triển khai khi có màn hình FoodItemsListScreen
    // Mở màn hình chọn thực phẩm để thay thế
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodItemsListScreen(
          onFoodItemSelected: (FoodItem selectedItem) {
            // Xử lý khi người dùng chọn item mới
          },
        ),
      ),
    );
    */
  }

  /// Xử lý khi thay đổi loại bữa ăn
  static FoodEntry updateMealType(FoodEntry foodEntry, String newMealType) {
    // Tạo một FoodEntry mới với loại bữa ăn đã cập nhật
    return FoodEntry(
      id: foodEntry.id,
      description: foodEntry.description,
      imagePath: foodEntry.imagePath,
      audioPath: foodEntry.audioPath,
      dateTime: foodEntry.dateTime,
      isFavorite: foodEntry.isFavorite,
      barcode: foodEntry.barcode,
      calories: foodEntry.calories,
      nutritionInfo: foodEntry.nutritionInfo,
      mealType: newMealType,
      items: foodEntry.items,
    );
  }

  /// Xử lý khi thay đổi ngày
  static Future<FoodEntry?> updateDate(BuildContext context, FoodEntry foodEntry) async {
    try {
      // Hiển thị date picker
      final pickedDate = await FoodNutritionDialogs.showDatePickerDialog(context, foodEntry.dateTime);
      
      if (pickedDate != null) {
        // Hiển thị indicator đang cập nhật
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                ),
                SizedBox(width: 16),
                Text('Đang cập nhật ngày...'),
              ],
            ),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
        
        // Tạo DateTime mới giữ nguyên giờ, phút, giây nhưng thay đổi ngày, tháng, năm
        final updatedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          foodEntry.dateTime.hour,
          foodEntry.dateTime.minute,
          foodEntry.dateTime.second,
        );
        
        // Lấy FoodProvider
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        
        // Đặt ngày đã chọn trong provider
        final selectedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
        foodProvider.setSelectedDate(selectedDate);
        
        // Tạo entry mới với ngày đã cập nhật
        final updatedEntry = FoodEntry(
          id: foodEntry.id,
          description: foodEntry.description,
          imagePath: foodEntry.imagePath,
          audioPath: foodEntry.audioPath,
          dateTime: updatedDateTime,
          isFavorite: foodEntry.isFavorite,
          barcode: foodEntry.barcode,
          calories: foodEntry.calories,
          nutritionInfo: foodEntry.nutritionInfo,
          mealType: foodEntry.mealType,
          items: foodEntry.items,
        );
        
        // Cập nhật entry trong provider
        foodProvider.updateFoodEntry(updatedEntry);
        
        // Xóa cache để đảm bảo dữ liệu được tính toán lại
        foodProvider.clearNutritionCache();
        foodProvider.refreshNutrition();
        
        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật ngày thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        return updatedEntry;
      }
    } catch (e) {
      print('Lỗi khi cập nhật ngày: $e');
      
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật ngày: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    return null;
  }
} 