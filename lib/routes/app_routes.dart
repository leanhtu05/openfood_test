import 'package:flutter/material.dart';
import '../screens/admin/settings_screen.dart';
// Import các màn hình khác ở đây

class AppRoutes {
  static const String settings = '/settings';
  // Các route khác ở đây
  
  static Map<String, WidgetBuilder> routes = {
    settings: (context) => SettingsScreen(),
    // Các route khác ở đây
  };
} 