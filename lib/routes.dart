import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/exercise_log_screen.dart';
import 'screens/exercise_history_screen.dart';
import 'screens/meal_screen.dart';
import 'screens/water_history_screen.dart';
import 'screens/combined_history_screen.dart';
import 'screens/food_logging_screen.dart';
import 'screens/food_history_screen.dart';
import 'screens/food_search_screen.dart';
import 'screens/food_detail_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/tdee_calculator_screen.dart';
import 'screens/onboarding/activity_level_page.dart';
import 'screens/onboarding/weight_gain_pace_page.dart';
import '../screens/meal_recording_screen.dart';
import 'screens/diet_plan_screen.dart';
import 'screens/onboarding/age_selection_page.dart';
import 'screens/onboarding/height_selection_page.dart';
import 'screens/onboarding/weight_selection_page.dart';
import 'screens/onboarding/diet_goal_page.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/grocery_list_screen.dart';
import 'screens/recipe_detail_screen.dart';
// 🗑️ Đã xóa import các demo screens theo yêu cầu
import 'models/meal_plan.dart';

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
  FoodSearchScreen.routeName: (context) => FoodSearchScreen(),
  '/onboarding': (context) => const OnboardingScreen(),
  '/age': (context) => const AgeSelectionPage(),
  '/height': (context) => const HeightSelectionPage(),
  '/weight': (context) => const WeightSelectionPage(),
  '/activity-level': (context) => const ActivityLevelPage(),
  '/goal': (context) => const DietGoalPage(),
  '/weight-gain-pace': (context) => const WeightGainPacePage(),
  '/tdee-calculator': (context) => const TDEECalculatorScreen(),
  '/meal-recording': (context) => const MealRecordingScreen(initialDate: null),
  '/diet-plan': (context) => const DietPlanScreen(),
  '/grocery-list': (context) => GroceryListScreen(),
  '/settings': (context) => SettingsScreen(),
  // 🗑️ Đã xóa các demo routes theo yêu cầu

  '/auth': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final isLoginMode = args?['isLoginMode'] ?? true;
    final onAuthSuccess = args?['onAuthSuccess'] as VoidCallback?;
    return AuthScreen(
      isLoginMode: isLoginMode,
      onAuthSuccess: onAuthSuccess,
    );
  },
};

Route<dynamic>? generateRoute(RouteSettings settings) {
  if (settings.name == '/food_detail') {
    final args = settings.arguments as Map<String, dynamic>;
    final String foodId = args['id'] as String;
    
    return MaterialPageRoute(
      builder: (context) => FoodDetailScreen(id: foodId),
    );
  }

  
  if (settings.name == '/food-search') {
    return MaterialPageRoute(
      builder: (context) => FoodSearchScreen(),
    );
  }
  
  if (settings.name == '/meal_detail') {
    final mealId = settings.arguments as String?;
    return MaterialPageRoute(
      builder: (context) => MealScreen(mealId: mealId),
    );
  }

  if (settings.name == '/recipe_detail') {
    final dish = settings.arguments as Dish;
    return MaterialPageRoute(
      builder: (context) => RecipeDetailScreen(dish: dish),
    );
  }

  return null;
}