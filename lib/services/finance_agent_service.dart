import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/grocery_cost_analysis.dart';
import '../screens/grocery_list_screen.dart';
import 'shopping_firestore_service.dart';
import 'price_ai_analysis_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service tích hợp AI Finance Agent để phân tích chi phí thực phẩm
class FinanceAgentService {
  static const String _baseUrl = 'https://backend-openfood.onrender.com';
  static final PriceAIAnalysisService _aiService = PriceAIAnalysisService();

  // Database giá cả thực phẩm Việt Nam (mẫu)
  static final Map<String, Map<String, dynamic>> _vietnamFoodPrices = {
    // Thịt tươi sống
    'thịt bò': {'price_per_kg': 350000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'thịt heo': {'price_per_kg': 180000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'thịt gà': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'cá': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'tôm': {'price_per_kg': 400000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},

    // Rau củ quả
    'cà chua': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'hành tây': {'price_per_kg': 20000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'ớt chuông': {'price_per_kg': 35000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'rau xà lách': {'price_per_kg': 30000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'bí đỏ': {'price_per_kg': 15000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'chuối': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},

    // Thực phẩm khô
    'gạo': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🌾 Thực phẩm khô'},
    'bánh mì': {'price_per_piece': 8000, 'unit': 'lát', 'category': '🌾 Thực phẩm khô'},
    'yến mạch': {'price_per_kg': 80000, 'unit': 'kg', 'category': '🌾 Thực phẩm khô'},

    // Sản phẩm từ sữa
    'trứng gà': {'price_per_piece': 4000, 'unit': 'quả', 'category': '🥛 Sản phẩm từ sữa'},
    'sữa chua hy lạp': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🥛 Sản phẩm từ sữa'},
    'phô mai': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🥛 Sản phẩm từ sữa'},

    // Gia vị & Nước chấm
    'dầu oliu': {'price_per_liter': 150000, 'unit': 'muỗng canh', 'category': '🧂 Gia vị & Nước chấm'},
    'mật ong': {'price_per_kg': 300000, 'unit': 'muỗng canh', 'category': '🧂 Gia vị & Nước chấm'},
  };

  /// Phân tích chi phí danh sách mua sắm với AI và lưu vào Firebase
  static Future<GroceryCostAnalysis> analyzeCosts(
    Map<String, GroceryItem> groceryItems,
    {double? budgetLimit, bool saveToFirebase = true, bool useAI = true}
  ) async {
    try {
      // Thử sử dụng AI trước
      if (useAI) {
        try {
          return await _analyzeWithAI(groceryItems, budgetLimit: budgetLimit, saveToFirebase: saveToFirebase);
        } catch (e) {
          print('⚠️ AI analysis failed, falling back to local analysis: $e');
        }
      }

      // Fallback: Tính toán local
      return await _analyzeLocally(groceryItems, budgetLimit: budgetLimit, saveToFirebase: saveToFirebase);

    } catch (e) {
      print('❌ Lỗi khi phân tích chi phí: $e');
      // Trả về phân tích mặc định nếu có lỗi
      return _getDefaultAnalysis(budgetLimit);
    }
  }

  /// Phân tích với AI backend
  static Future<GroceryCostAnalysis> _analyzeWithAI(
    Map<String, GroceryItem> groceryItems,
    {double? budgetLimit, bool saveToFirebase = true}
  ) async {
    print('🤖 Bắt đầu phân tích AI cho ${groceryItems.length} items...');

    // Chuyển đổi groceryItems thành format cho AI
    final groceryItemsList = groceryItems.values.map((item) => {
      'name': item.name,
      'amount': item.amount,
      'unit': item.unit,
      'category': item.category,
    }).toList();

    print('📤 Gửi dữ liệu tới AI service...');

    // Gọi AI service
    final aiAnalysis = await _aiService.analyzeGroceryListIntelligently(
      groceryItemsList,
      budgetLimit: budgetLimit,
    );

    print('📥 Nhận được phân tích từ AI: ${aiAnalysis.keys.join(", ")}');

    // Convert AI response thành GroceryCostAnalysis
    final result = _convertAIResponseToAnalysis(aiAnalysis, groceryItems, budgetLimit);

    // Lưu vào Firebase nếu cần
    if (saveToFirebase) {
      await _saveAnalysisToFirebase(groceryItems, result);
    }

    return result;
  }

  /// Phân tích local (fallback)
  static Future<GroceryCostAnalysis> _analyzeLocally(
    Map<String, GroceryItem> groceryItems,
    {double? budgetLimit, bool saveToFirebase = true}
  ) async {
    try {
      // Tính toán chi phí cho từng item
      final itemsWithCost = <GroceryItemWithCost>[];
      double totalCost = 0.0;
      final categoryTotals = <String, double>{};
      final categoryItemCounts = <String, int>{};

      for (final item in groceryItems.values) {
        final cost = calculateItemCost(item);
        final itemWithCost = GroceryItemWithCost(
          name: item.name,
          amount: item.amount,
          unit: item.unit,
          category: item.category,
          estimatedCost: cost,
          pricePerUnit: _getPricePerUnit(item),
        );

        itemsWithCost.add(itemWithCost);
        totalCost += cost;

        categoryTotals[item.category] = (categoryTotals[item.category] ?? 0) + cost;
        categoryItemCounts[item.category] = (categoryItemCounts[item.category] ?? 0) + 1;
      }

      // Tạo phân tích theo danh mục
      final categoryBreakdown = <String, CategoryCostBreakdown>{};
      for (final category in categoryTotals.keys) {
        final categoryTotal = categoryTotals[category]!;
        final itemCount = categoryItemCounts[category]!;

        categoryBreakdown[category] = CategoryCostBreakdown(
          categoryName: category,
          totalCost: categoryTotal,
          percentage: totalCost > 0 ? (categoryTotal / totalCost) * 100 : 0,
          itemCount: itemCount,
          averageCostPerItem: categoryTotal / itemCount,
          topExpensiveItems: _getTopExpensiveItemsInCategoryWithCost(itemsWithCost, category),
        );
      }

      // Tạo mẹo tiết kiệm
      final savingTips = _generateSavingTips(itemsWithCost, categoryBreakdown);

      // So sánh ngân sách
      final budgetComparison = BudgetComparison(
        budgetLimit: budgetLimit ?? 500000, // Mặc định 500k VND
        actualCost: totalCost,
        difference: totalCost - (budgetLimit ?? 500000),
        isOverBudget: totalCost > (budgetLimit ?? 500000),
        percentageUsed: (budgetLimit ?? 500000) > 0 ? (totalCost / (budgetLimit ?? 500000)) * 100 : 0,
      );

      // Tạo cảnh báo giá cả
      final priceAlerts = _generatePriceAlerts(itemsWithCost);

      final analysis = GroceryCostAnalysis(
        totalCost: totalCost,
        averageCostPerItem: groceryItems.isNotEmpty ? totalCost / groceryItems.length : 0,
        categoryBreakdown: categoryBreakdown,
        savingTips: savingTips,
        budgetComparison: budgetComparison,
        priceAlerts: priceAlerts,
        analysisDate: DateTime.now(),
      );

      // Lưu vào Firebase nếu user đã đăng nhập
      if (saveToFirebase) {
        await _saveAnalysisToFirebase(groceryItems, analysis);
      }

      return analysis;

    } catch (e) {
      print('❌ Lỗi local analysis: $e');
      return _getDefaultAnalysis(budgetLimit);
    }
  }

  /// Tính toán chi phí cho một item
  static double calculateItemCost(GroceryItem item) {
    final itemName = item.name.toLowerCase();
    final amount = _parseAmount(item.amount);
    
    // Tìm giá trong database
    for (final foodName in _vietnamFoodPrices.keys) {
      if (itemName.contains(foodName)) {
        final priceInfo = _vietnamFoodPrices[foodName]!;
        
        // Tính toán dựa trên đơn vị
        if (item.unit.toLowerCase().contains('kg') || item.unit.toLowerCase().contains('g')) {
          final amountInKg = item.unit.toLowerCase().contains('g') ? amount / 1000 : amount;
          return (priceInfo['price_per_kg'] ?? 0) * amountInKg;
        } else if (item.unit.toLowerCase().contains('quả') || item.unit.toLowerCase().contains('lát')) {
          return (priceInfo['price_per_piece'] ?? 0) * amount;
        } else if (item.unit.toLowerCase().contains('muỗng')) {
          // Ước tính 1 muỗng canh = 15ml, 1 lít = 1000ml
          final amountInLiter = amount * 0.015;
          return (priceInfo['price_per_liter'] ?? 0) * amountInLiter;
        }
      }
    }
    
    // Giá ước tính mặc định nếu không tìm thấy
    return _getDefaultPrice(item.category) * amount;
  }

  /// Parse số lượng từ chuỗi
  static double _parseAmount(String amountStr) {
    final regex = RegExp(r'(\d+(?:\.\d+)?)');
    final match = regex.firstMatch(amountStr);
    return match != null ? double.tryParse(match.group(1)!) ?? 1.0 : 1.0;
  }

  /// Lấy giá mặc định theo danh mục
  static double _getDefaultPrice(String category) {
    switch (category) {
      case '🥩 Thịt tươi sống': return 200000; // 200k/kg
      case '🥬 Rau củ quả': return 25000; // 25k/kg
      case '🌾 Thực phẩm khô': return 30000; // 30k/kg
      case '🥛 Sản phẩm từ sữa': return 50000; // 50k/kg
      case '🧂 Gia vị & Nước chấm': return 100000; // 100k/kg
      default: return 20000; // 20k/kg
    }
  }

  /// Lấy giá per unit
  static double _getPricePerUnit(GroceryItem item) {
    final totalCost = calculateItemCost(item);
    final amount = _parseAmount(item.amount);
    return amount > 0 ? totalCost / amount : 0;
  }

  /// Lấy top items đắt nhất trong danh mục (overload cho GroceryItem)
  static List<String> _getTopExpensiveItemsInCategory(
    List<GroceryItem> items,
    String category
  ) {
    final categoryItems = items.where((item) => item.category == category).toList();
    categoryItems.sort((a, b) => calculateItemCost(b).compareTo(calculateItemCost(a)));
    return categoryItems.take(3).map((item) => item.name).toList();
  }

  /// Lấy top items đắt nhất trong danh mục (original method)
  static List<String> _getTopExpensiveItemsInCategoryWithCost(
    List<GroceryItemWithCost> items,
    String category
  ) {
    final categoryItems = items.where((item) => item.category == category).toList();
    categoryItems.sort((a, b) => b.estimatedCost.compareTo(a.estimatedCost));
    return categoryItems.take(3).map((item) => item.name).toList();
  }

  /// Tạo mẹo tiết kiệm
  static List<CostSavingTip> _generateSavingTips(
    List<GroceryItemWithCost> items,
    Map<String, CategoryCostBreakdown> categoryBreakdown
  ) {
    final tips = <CostSavingTip>[];

    // Mẹo dựa trên danh mục đắt nhất
    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.totalCost.compareTo(a.value.totalCost));

    if (sortedCategories.isNotEmpty) {
      final mostExpensiveCategory = sortedCategories.first;
      tips.add(CostSavingTip(
        title: 'Tối ưu danh mục ${mostExpensiveCategory.key}',
        description: 'Danh mục này chiếm ${mostExpensiveCategory.value.percentage.toStringAsFixed(1)}% tổng chi phí. Hãy xem xét mua ở chợ truyền thống hoặc tìm khuyến mãi.',
        potentialSaving: mostExpensiveCategory.value.totalCost * 0.15, // Tiết kiệm 15%
        category: mostExpensiveCategory.key,
        priority: 5,
      ));
    }

    // Mẹo chung
    tips.add(CostSavingTip(
      title: 'Mua theo mùa',
      description: 'Chọn rau củ quả theo mùa để có giá tốt nhất và chất lượng cao nhất.',
      potentialSaving: 50000,
      category: '🥬 Rau củ quả',
      priority: 4,
    ));

    tips.add(CostSavingTip(
      title: 'So sánh giá nhiều nơi',
      description: 'Kiểm tra giá ở siêu thị, chợ truyền thống và các ứng dụng giao hàng.',
      potentialSaving: 30000,
      category: 'Tổng quát',
      priority: 3,
    ));

    return tips;
  }

  /// Tạo cảnh báo giá cả
  static List<PriceAlert> _generatePriceAlerts(List<GroceryItemWithCost> items) {
    final alerts = <PriceAlert>[];
    
    for (final item in items) {
      if (item.estimatedCost > 100000) { // Items trên 100k
        alerts.add(PriceAlert(
          itemName: item.name,
          currentPrice: item.estimatedCost,
          averagePrice: item.estimatedCost * 0.8,
          priceChange: item.estimatedCost * 0.2,
          alertType: 'high',
          message: '${item.name} có giá cao hơn bình thường 20%',
        ));
      }
    }
    
    return alerts;
  }

  /// Phân tích mặc định khi có lỗi
  static GroceryCostAnalysis _getDefaultAnalysis(double? budgetLimit) {
    return GroceryCostAnalysis(
      totalCost: 0,
      averageCostPerItem: 0,
      categoryBreakdown: {},
      savingTips: [],
      budgetComparison: BudgetComparison(
        budgetLimit: budgetLimit ?? 500000,
        actualCost: 0,
        difference: -(budgetLimit ?? 500000),
        isOverBudget: false,
        percentageUsed: 0,
      ),
      priceAlerts: [],
      analysisDate: DateTime.now(),
    );
  }

  /// Lưu analysis vào Firebase
  static Future<void> _saveAnalysisToFirebase(
    Map<String, GroceryItem> groceryItems,
    GroceryCostAnalysis analysis,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ User chưa đăng nhập, không lưu vào Firebase');
        return;
      }

      // Lưu grocery list trước
      final groceryListId = await ShoppingFirestoreService.saveGroceryList(
        userId: user.uid,
        groceryItems: groceryItems,
        listName: 'Phân tích ${DateTime.now().day}/${DateTime.now().month}',
      );

      // Lưu cost analysis
      await ShoppingFirestoreService.saveCostAnalysis(
        userId: user.uid,
        groceryListId: groceryListId,
        analysis: analysis,
      );

      // Track giá các sản phẩm
      for (final item in groceryItems.values) {
        final cost = calculateItemCost(item);
        await ShoppingFirestoreService.trackItemPrice(
          itemName: item.name,
          price: cost,
          storeName: 'Ước tính AI',
          location: 'Việt Nam',
        );
      }

      print('✅ Đã lưu analysis vào Firebase thành công');
    } catch (e) {
      print('❌ Lỗi lưu analysis vào Firebase: $e');
      // Không throw error để không ảnh hưởng UX
    }
  }

  /// Lấy lịch sử phân tích của user
  static Future<List<GroceryCostAnalysis>> getUserAnalysisHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      return await ShoppingFirestoreService.getUserCostAnalyses(user.uid);
    } catch (e) {
      print('❌ Lỗi lấy analysis history: $e');
      return [];
    }
  }

  /// Lấy thống kê mua sắm của user
  static Future<Map<String, dynamic>> getUserShoppingStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      return await ShoppingFirestoreService.getUserShoppingStats(user.uid);
    } catch (e) {
      print('❌ Lỗi lấy shopping stats: $e');
      return {};
    }
  }

  /// Convert AI response thành GroceryCostAnalysis
  static GroceryCostAnalysis _convertAIResponseToAnalysis(
    Map<String, dynamic> aiResponse,
    Map<String, GroceryItem> groceryItems,
    double? budgetLimit,
  ) {
    try {
      print('🔄 Converting AI response to analysis...');

      // Kiểm tra xem có phải enhanced local analysis không
      final isLocalAnalysis = aiResponse['analysis_type'] == 'enhanced_local';

      // Tính toán chi phí từ local data nếu AI không trả về
      double totalCost = 0.0;
      final categoryTotals = <String, double>{};
      final categoryItemCounts = <String, int>{};

      for (final item in groceryItems.values) {
        final cost = calculateItemCost(item);
        totalCost += cost;
        categoryTotals[item.category] = (categoryTotals[item.category] ?? 0) + cost;
        categoryItemCounts[item.category] = (categoryItemCounts[item.category] ?? 0) + 1;
      }

      final averageCostPerItem = groceryItems.isNotEmpty ? totalCost / groceryItems.length : 0.0;

      print('💰 Tổng chi phí tính toán: ${totalCost.toStringAsFixed(0)} VND');

      // Parse category breakdown (ưu tiên từ AI, fallback về local calculation)
      final categoryBreakdown = <String, CategoryCostBreakdown>{};
      final aiCategoryData = aiResponse['category_breakdown'] as Map<String, dynamic>? ?? {};

      if (aiCategoryData.isNotEmpty && !isLocalAnalysis) {
        // Sử dụng dữ liệu từ AI
        print('📊 Sử dụng category breakdown từ AI');
        for (final entry in aiCategoryData.entries) {
          final data = entry.value as Map<String, dynamic>;
          categoryBreakdown[entry.key] = CategoryCostBreakdown(
            categoryName: data['category_name'] ?? entry.key,
            totalCost: (data['total_cost'] ?? 0.0).toDouble(),
            percentage: (data['percentage'] ?? 0.0).toDouble(),
            itemCount: data['item_count'] ?? 0,
            averageCostPerItem: (data['average_cost_per_item'] ?? 0.0).toDouble(),
            topExpensiveItems: List<String>.from(data['top_expensive_items'] ?? []),
          );
        }
      } else {
        // Tạo category breakdown từ local calculation
        print('📊 Tạo category breakdown từ local calculation');
        for (final category in categoryTotals.keys) {
          final categoryTotal = categoryTotals[category]!;
          final itemCount = categoryItemCounts[category]!;

          categoryBreakdown[category] = CategoryCostBreakdown(
            categoryName: category,
            totalCost: categoryTotal,
            percentage: totalCost > 0 ? (categoryTotal / totalCost) * 100 : 0,
            itemCount: itemCount,
            averageCostPerItem: categoryTotal / itemCount,
            topExpensiveItems: _getTopExpensiveItemsInCategory(
              groceryItems.values.where((item) => item.category == category).toList(),
              category
            ),
          );
        }
      }

      // Parse saving tips (ưu tiên từ AI, fallback về local generation)
      final savingTips = <CostSavingTip>[];
      final aiTipsData = aiResponse['saving_tips'] as List<dynamic>? ?? [];
      final aiOptimizationSuggestions = aiResponse['optimization_suggestions'] as List<dynamic>? ?? [];

      if (aiTipsData.isNotEmpty && !isLocalAnalysis) {
        // Sử dụng tips từ AI
        print('💡 Sử dụng saving tips từ AI');
        for (final tipData in aiTipsData) {
          final tip = tipData as Map<String, dynamic>;
          savingTips.add(CostSavingTip(
            title: tip['title'] ?? '',
            description: tip['description'] ?? '',
            potentialSaving: (tip['potential_saving'] ?? 0.0).toDouble(),
            category: tip['category'] ?? '',
            priority: tip['priority'] ?? 3,
          ));
        }
      } else if (aiOptimizationSuggestions.isNotEmpty) {
        // Chuyển đổi optimization suggestions thành saving tips
        print('💡 Chuyển đổi optimization suggestions thành saving tips');
        for (int i = 0; i < aiOptimizationSuggestions.length && i < 5; i++) {
          final suggestion = aiOptimizationSuggestions[i].toString();
          savingTips.add(CostSavingTip(
            title: 'Gợi ý AI #${i + 1}',
            description: suggestion,
            potentialSaving: totalCost * 0.1, // Ước tính tiết kiệm 10%
            category: 'AI Analysis',
            priority: 4,
          ));
        }
      } else {
        // Tạo saving tips local
        print('💡 Tạo saving tips từ local analysis');
        final itemsWithCost = groceryItems.values.map((item) => GroceryItemWithCost(
          name: item.name,
          amount: item.amount,
          unit: item.unit,
          category: item.category,
          estimatedCost: calculateItemCost(item),
          pricePerUnit: _getPricePerUnit(item),
        )).toList();

        savingTips.addAll(_generateSavingTips(itemsWithCost, categoryBreakdown));
      }

      // Parse budget comparison
      final budgetData = aiResponse['budget_comparison'] as Map<String, dynamic>? ?? {};
      final budgetComparison = BudgetComparison(
        budgetLimit: budgetLimit ?? 500000,
        actualCost: totalCost,
        difference: totalCost - (budgetLimit ?? 500000),
        isOverBudget: totalCost > (budgetLimit ?? 500000),
        percentageUsed: (budgetLimit ?? 500000) > 0 ? (totalCost / (budgetLimit ?? 500000)) * 100 : 0,
      );

      // Parse price alerts
      final priceAlerts = <PriceAlert>[];
      final alertsData = aiResponse['price_alerts'] as List<dynamic>? ?? [];
      for (final alertData in alertsData) {
        final alert = alertData as Map<String, dynamic>;
        priceAlerts.add(PriceAlert(
          itemName: alert['item_name'] ?? '',
          currentPrice: (alert['current_price'] ?? 0.0).toDouble(),
          averagePrice: (alert['average_price'] ?? 0.0).toDouble(),
          priceChange: (alert['price_change'] ?? 0.0).toDouble(),
          alertType: alert['alert_type'] ?? 'info',
          message: alert['message'] ?? '',
        ));
      }

      return GroceryCostAnalysis(
        totalCost: totalCost,
        averageCostPerItem: averageCostPerItem,
        categoryBreakdown: categoryBreakdown,
        savingTips: savingTips,
        budgetComparison: budgetComparison,
        priceAlerts: priceAlerts,
        analysisDate: DateTime.now(),
      );

    } catch (e) {
      print('❌ Lỗi convert AI response: $e');
      // Fallback to local analysis
      throw Exception('Failed to convert AI response');
    }
  }
}
