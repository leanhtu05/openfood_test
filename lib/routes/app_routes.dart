import 'package:flutter/material.dart';
import '../screens/admin/settings_screen.dart';
// 🗑️ Đã xóa các import demo screens theo yêu cầu
// Import các màn hình khác ở đây

class AppRoutes {
  static const String settings = '/settings';
  // 🗑️ Đã xóa các demo routes theo yêu cầu
  // Các route khác ở đây

  static Map<String, WidgetBuilder> routes = {
    settings: (context) => SettingsScreen(),
    // 🗑️ Đã xóa các demo screens khỏi routes theo yêu cầu
    // Các route khác ở đây
  };
}