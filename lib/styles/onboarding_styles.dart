import 'package:flutter/material.dart';

// Định nghĩa các hằng số cho UI
class OnboardingStyles {
  // Colors
  static const Color primaryColor = Colors.green;
  static const Color primaryColorLight = Color(0xFFE8F5E9);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color titleColor = Color(0xFF24204F);
  static const Color textColor = Colors.black87;
  static const Color textSecondaryColor = Colors.grey;
  
  // Text styles
  static const TextStyle appTitleStyle = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: titleColor,
  );
  
  static const TextStyle pageTitleStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textColor,
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
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
  );
  
  // Padding
  static const EdgeInsets screenPadding = EdgeInsets.all(24.0);
  
  // Sizes
  static const double iconSize = 150.0;
  static const double progressHeight = 6.0;
} 