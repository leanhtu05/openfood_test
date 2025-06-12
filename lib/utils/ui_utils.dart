import 'package:flutter/material.dart';

class UiUtils {
  // Hiển thị SnackBar thông báo
  static void showSnackBar({
    required BuildContext context,
    required String message,
    bool isSuccess = true,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: duration,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Đóng',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  // Format giá trị dinh dưỡng hiển thị
  static String formatNutrition(dynamic value) {
    if (value == null) return '0';
    
    try {
      double doubleValue = value is double ? value : double.parse(value.toString());
      
      // Làm tròn theo logic:
      // - Giá trị < 1: giữ 2 số thập phân
      // - Giá trị 1-10: giữ 1 số thập phân
      // - Giá trị > 10: làm tròn thành số nguyên
      if (doubleValue < 1) {
        return doubleValue.toStringAsFixed(2);
      } else if (doubleValue < 10) {
        return doubleValue.toStringAsFixed(1);
      } else {
        return doubleValue.round().toString();
      }
    } catch (e) {
      // Nếu không thể chuyển đổi, trả về giá trị gốc
      return value.toString();
    }
  }
} 