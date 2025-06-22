import 'dart:convert';
import '../services/price_ai_analysis_service.dart';
import '../services/finance_agent_service.dart';
import '../screens/grocery_list_screen.dart';

/// Utility class để test AI analysis functionality
class AIAnalysisTester {
  static final PriceAIAnalysisService _aiService = PriceAIAnalysisService();
  
  /// Test kết nối backend
  static Future<void> testBackendConnection() async {
    print('🔍 Testing backend connection...');
    
    final isConnected = await _aiService.testConnection();
    
    if (isConnected) {
      print('✅ Backend connection successful!');
    } else {
      print('❌ Backend connection failed - will use fallback analysis');
    }
  }
  
  /// Test AI analysis với dữ liệu mẫu
  static Future<void> testAIAnalysis() async {
    print('🧪 Testing AI analysis with sample data...');
    
    // Tạo dữ liệu test
    final testGroceryItems = {
      'thịt bò': GroceryItem(
        name: 'Thịt bò',
        amount: '500',
        unit: 'g',
        category: '🥩 Thịt tươi sống',
      ),
      'cà chua': GroceryItem(
        name: 'Cà chua',
        amount: '300',
        unit: 'g',
        category: '🥬 Rau củ quả',
      ),
      'gạo tẻ': GroceryItem(
        name: 'Gạo tẻ',
        amount: '1',
        unit: 'kg',
        category: '🌾 Ngũ cốc & Gạo',
      ),
      'trứng gà': GroceryItem(
        name: 'Trứng gà',
        amount: '6',
        unit: 'quả',
        category: '🥛 Sữa & Trứng',
      ),
      'dầu ăn': GroceryItem(
        name: 'Dầu ăn',
        amount: '1',
        unit: 'lít',
        category: '🧂 Gia vị',
      ),
    };
    
    try {
      // Test phân tích với AI
      final analysis = await FinanceAgentService.analyzeCosts(
        testGroceryItems,
        budgetLimit: 300000, // 300k VND
        useAI: true,
      );
      
      print('✅ AI Analysis completed successfully!');
      print('📊 Results:');
      print('   - Total cost: ${analysis.totalCost.toStringAsFixed(0)} VND');
      print('   - Average per item: ${analysis.averageCostPerItem.toStringAsFixed(0)} VND');
      print('   - Categories: ${analysis.categoryBreakdown.length}');
      print('   - Saving tips: ${analysis.savingTips.length}');
      print('   - Price alerts: ${analysis.priceAlerts.length}');
      print('   - Over budget: ${analysis.budgetComparison.isOverBudget}');
      
      // In chi tiết saving tips
      if (analysis.savingTips.isNotEmpty) {
        print('💡 Saving Tips:');
        for (final tip in analysis.savingTips.take(3)) {
          print('   - ${tip.title}: ${tip.description}');
        }
      }
      
      // In chi tiết category breakdown
      if (analysis.categoryBreakdown.isNotEmpty) {
        print('📈 Category Breakdown:');
        for (final entry in analysis.categoryBreakdown.entries) {
          final category = entry.value;
          print('   - ${category.categoryName}: ${category.totalCost.toStringAsFixed(0)} VND (${category.percentage.toStringAsFixed(1)}%)');
        }
      }
      
    } catch (e) {
      print('❌ AI Analysis failed: $e');
    }
  }
  
  /// Test các endpoint AI riêng lẻ
  static Future<void> testIndividualAIEndpoints() async {
    print('🔬 Testing individual AI endpoints...');
    
    // Test price trends
    try {
      print('📈 Testing price trends analysis...');
      final trends = await _aiService.analyzePriceTrends(
        category: '🥬 Rau củ quả',
        daysBack: 30,
      );
      print('✅ Price trends: ${trends.keys.join(", ")}');
    } catch (e) {
      print('❌ Price trends failed: $e');
    }
    
    // Test price prediction
    try {
      print('🔮 Testing price prediction...');
      final prediction = await _aiService.predictFuturePrices(
        foodName: 'thịt bò',
        daysAhead: 7,
      );
      print('✅ Price prediction: ${prediction.keys.join(", ")}');
    } catch (e) {
      print('❌ Price prediction failed: $e');
    }
    
    // Test grocery optimization
    try {
      print('🛒 Testing grocery optimization...');
      final optimization = await _aiService.analyzeGroceryListIntelligently([
        {'name': 'Thịt bò', 'amount': '500', 'unit': 'g', 'category': '🥩 Thịt tươi sống'},
        {'name': 'Cà chua', 'amount': '300', 'unit': 'g', 'category': '🥬 Rau củ quả'},
      ], budgetLimit: 200000);
      print('✅ Grocery optimization: ${optimization.keys.join(", ")}');
    } catch (e) {
      print('❌ Grocery optimization failed: $e');
    }
  }
  
  /// Chạy tất cả tests
  static Future<void> runAllTests() async {
    print('🚀 Starting comprehensive AI analysis tests...\n');
    
    await testBackendConnection();
    print('');
    
    await testIndividualAIEndpoints();
    print('');
    
    await testAIAnalysis();
    print('');
    
    print('🏁 All tests completed!');
  }
  
  /// Test với dữ liệu thực từ grocery list
  static Future<void> testWithRealData(Map<String, GroceryItem> groceryItems) async {
    if (groceryItems.isEmpty) {
      print('⚠️ No grocery items to test with');
      return;
    }
    
    print('🧪 Testing AI analysis with real grocery data (${groceryItems.length} items)...');
    
    try {
      final analysis = await FinanceAgentService.analyzeCosts(
        groceryItems,
        budgetLimit: 500000, // 500k VND
        useAI: true,
      );
      
      print('✅ Real data analysis completed!');
      print('📊 Total cost: ${analysis.totalCost.toStringAsFixed(0)} VND');
      print('💡 Saving tips: ${analysis.savingTips.length}');
      print('📈 Categories: ${analysis.categoryBreakdown.length}');
      
    } catch (e) {
      print('❌ Real data analysis failed: $e');
    }
  }
}
