import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/exercise_log_screen.dart';
import 'screens/exercise_history_screen.dart';
import 'screens/meal_screen.dart';
import 'screens/water_history_screen.dart';
import 'screens/combined_history_screen.dart';
import 'screens/food_logging_screen.dart';
import 'screens/food_history_screen.dart';
import 'screens/food_recognition_screen.dart';
import 'screens/food_search_screen.dart';
import 'screens/food_detail_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/tdee_calculator_screen.dart';
import 'screens/onboarding/age_page.dart';
import 'screens/onboarding/height_page.dart';
import 'screens/onboarding/weight_page.dart';
import 'screens/onboarding/activity_level_page.dart';
import 'screens/onboarding/goal_page.dart';
import 'screens/onboarding/weight_gain_pace_page.dart';
import '../screens/meal_recording_screen.dart';


Map<String, WidgetBuilder> routes = {
  '/home': (context) => HomeScreen(),
  '/exercise_log': (context) => ExerciseLogScreen(),
  '/exercise_history': (context) => ExerciseHistoryScreen(),
  '/meal': (context) => MealScreen(),
  WaterHistoryScreen.routeName: (context) => WaterHistoryScreen(),
  ExerciseHistoryScreen.routeName: (context) => ExerciseHistoryScreen(),
  '/combined_history': (context) => CombinedHistoryScreen(),
  FoodLoggingScreen.routeName: (context) => FoodLoggingScreen(),
  FoodHistoryScreen.routeName: (context) => FoodHistoryScreen(),
  FoodRecognitionScreen.routeName: (context) => FoodRecognitionScreen(),
  FoodSearchScreen.routeName: (context) => FoodSearchScreen(),
  '/onboarding': (context) => const OnboardingScreen(),
  '/age': (context) => const AgePage(),
  '/height': (context) => const HeightPage(),
  '/weight': (context) => const WeightPage(),
  '/activity-level': (context) => const ActivityLevelPage(),
  '/goal': (context) => const GoalPage(),
  '/weight-gain-pace': (context) => const WeightGainPacePage(),
  '/tdee-calculator': (context) => const TDEECalculatorScreen(),
  '/meal-recording': (context) => const MealRecordingScreen(initialDate: null),
};

Route<dynamic>? generateRoute(RouteSettings settings) {
  if (settings.name == '/food_detail') {
    final args = settings.arguments as Map<String, dynamic>;
    final String foodId = args['id'] as String;
    
    return MaterialPageRoute(
      builder: (context) => FoodDetailScreen(id: foodId),
    );
  }
  
  if (settings.name == '/food-recognition') {
    return MaterialPageRoute(
      builder: (context) => FoodRecognitionScreen(),
    );
  }
  
  if (settings.name == '/food-search') {
    return MaterialPageRoute(
      builder: (context) => FoodSearchScreen(),
    );
  }
  
  return null;
}