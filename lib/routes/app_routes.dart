import 'package:flutter/material.dart';
import '../screens/admin/settings_screen.dart';
import '../screens/food_price_management_screen.dart';
import '../screens/food_price_export_screen.dart';
import '../screens/grocery_cost_demo_screen.dart';
import '../screens/price_contribution_screen.dart';
import '../screens/community_contributions_screen.dart';
import '../screens/price_report_screen.dart';
import '../screens/ai_price_insights_screen.dart';
import '../screens/ai_price_prediction_screen.dart';
import '../screens/ai_grocery_optimizer_screen.dart';
// Import các màn hình khác ở đây

class AppRoutes {
  static const String settings = '/settings';
  static const String foodPriceManagement = '/food-price-management';
  static const String foodPriceExport = '/food-price-export';
  static const String groceryCostDemo = '/grocery-cost-demo';
  static const String priceContribution = '/price-contribution';
  static const String communityContributions = '/community-contributions';
  static const String priceReport = '/price-report';
  static const String aiPriceInsights = '/ai-price-insights';
  static const String aiPricePrediction = '/ai-price-prediction';
  static const String aiGroceryOptimizer = '/ai-grocery-optimizer';
  // Các route khác ở đây

  static Map<String, WidgetBuilder> routes = {
    settings: (context) => SettingsScreen(),
    foodPriceManagement: (context) => const FoodPriceManagementScreen(),
    foodPriceExport: (context) => const FoodPriceExportScreen(),
    groceryCostDemo: (context) => const GroceryCostDemoScreen(),
    priceContribution: (context) => const PriceContributionScreen(),
    communityContributions: (context) => const CommunityContributionsScreen(),
    aiPriceInsights: (context) => const AIPriceInsightsScreen(),
    aiPricePrediction: (context) => const AIPricePredictionScreen(),
    aiGroceryOptimizer: (context) => const AIGroceryOptimizerScreen(),
    // priceReport requires parameters, so it's handled via Navigator.push
    // Các route khác ở đây
  };
}