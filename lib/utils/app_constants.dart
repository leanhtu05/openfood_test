import 'package:flutter/material.dart';

// Các constant chung cho ứng dụng
class AppConstants {
  // Màu sắc chính
  static const Color primaryColor = Color(0xFF4CAF50); // Xanh lá đậm
  static const Color primaryColorLight = Color(0xFFE8F5E9); // Xanh lá nhạt
  static const Color accentColor = Color(0xFF4CAF50); // Xanh lá đậm
  static const Color backgroundColor = Colors.white;
  
  // Màu văn bản
  static const Color titleColor = Color(0xFF1A1A45); // Tím đậm gần như đen
  static const Color textColor = Color(0xFF1A1A45); // Tím đậm gần như đen
  static const Color textSecondaryColor = Color(0xFF757575); // Xám đậm
  
  // Màu UI
  static const Color cardColor = Color(0xFFF5F5F5); // Màu xám nhạt cho card
  static const Color selectedCardBorder = Color(0xFF4CAF50); // Viền xanh lá khi chọn
  static const Color buttonTextColor = Colors.white; // Màu chữ nút
  
  // Kích thước
  static const double iconSize = 80.0;
  static const double progressHeight = 6.0;
  static const EdgeInsets screenPadding = EdgeInsets.all(24.0);
  
  // Text styles
  static const TextStyle appTitleStyle = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static const TextStyle pageTitleStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textColor,
    letterSpacing: -0.5,
  );
  
  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 16,
    color: textColor,
    height: 1.5,
  );
  
  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: textSecondaryColor,
    height: 1.5,
  );
  
  // Button styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: buttonTextColor,
    padding: const EdgeInsets.symmetric(vertical: 16),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
  );
  
  // Selection styles
  static BoxDecoration selectedItemDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: selectedCardBorder, width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  static BoxDecoration unselectedItemDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.transparent),
  );
  
  // Theme data cho ứng dụng
  static ThemeData getAppTheme() {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        background: backgroundColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineLarge: pageTitleStyle,
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        bodyLarge: bodyTextStyle,
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primaryButtonStyle,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
} 