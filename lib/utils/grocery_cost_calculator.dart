import '../models/grocery_cost_analysis.dart';
import '../services/vietnamese_food_price_service.dart';

/// Utility class để tính toán chi phí grocery dựa trên dữ liệu Firebase
class GroceryCostCalculator {
  final VietnameseFoodPriceService _priceService = VietnameseFoodPriceService();

  /// Tính toán phân tích chi phí cho danh sách grocery
  Future<GroceryCostAnalysis> calculateCostAnalysis({
    required List<GroceryItemWithCost> groceryItems,
    double? budgetLimit,
  }) async {
    try {
      // Cập nhật giá cho các items từ Firebase
      final updatedItems = await _updateItemPrices(groceryItems);
      
      // Tính toán tổng chi phí
      final totalCost = updatedItems.fold<double>(
        0.0, 
        (sum, item) => sum + item.estimatedCost,
      );
      
      // Tính toán chi phí trung bình mỗi item
      final averageCostPerItem = updatedItems.isNotEmpty 
          ? totalCost / updatedItems.length 
          : 0.0;
      
      // Phân tích theo danh mục
      final categoryBreakdown = _calculateCategoryBreakdown(updatedItems, totalCost);
      
      // Tạo mẹo tiết kiệm
      final savingTips = await _generateSavingTips(updatedItems, categoryBreakdown);
      
      // So sánh ngân sách
      final budgetComparison = _calculateBudgetComparison(
        totalCost, 
        budgetLimit ?? 0.0,
      );
      
      // Tạo cảnh báo giá
      final priceAlerts = await _generatePriceAlerts(updatedItems);
      
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
      print('❌ Lỗi tính toán phân tích chi phí: $e');
      rethrow;
    }
  }

  /// Cập nhật giá cho các items từ Firebase
  Future<List<GroceryItemWithCost>> _updateItemPrices(
    List<GroceryItemWithCost> items,
  ) async {
    final List<GroceryItemWithCost> updatedItems = [];
    
    for (final item in items) {
      try {
        final priceData = await _priceService.getFoodPrice(item.name);
        
        if (priceData != null) {
          // Tính giá mới dựa trên dữ liệu Firebase
          double pricePerUnit = 0.0;
          if (priceData.containsKey('price_per_kg')) {
            pricePerUnit = (priceData['price_per_kg'] as num).toDouble();
          } else if (priceData.containsKey('price_per_liter')) {
            pricePerUnit = (priceData['price_per_liter'] as num).toDouble();
          } else if (priceData.containsKey('price_per_unit')) {
            pricePerUnit = (priceData['price_per_unit'] as num).toDouble();
          }
          
          final amount = double.tryParse(item.amount) ?? 1.0;
          final estimatedCost = pricePerUnit * amount;
          
          updatedItems.add(GroceryItemWithCost(
            name: item.name,
            amount: item.amount,
            unit: priceData['unit'] ?? item.unit,
            category: priceData['category'] ?? item.category,
            estimatedCost: estimatedCost,
            pricePerUnit: pricePerUnit,
            isChecked: item.isChecked,
          ));
        } else {
          // Giữ nguyên item nếu không tìm thấy giá
          updatedItems.add(item);
        }
      } catch (e) {
        print('❌ Lỗi cập nhật giá cho ${item.name}: $e');
        updatedItems.add(item);
      }
    }
    
    return updatedItems;
  }

  /// Tính toán phân tích theo danh mục
  Map<String, CategoryCostBreakdown> _calculateCategoryBreakdown(
    List<GroceryItemWithCost> items,
    double totalCost,
  ) {
    final Map<String, List<GroceryItemWithCost>> categoryItems = {};
    
    // Nhóm items theo danh mục
    for (final item in items) {
      final category = item.category.isNotEmpty ? item.category : 'Khác';
      if (!categoryItems.containsKey(category)) {
        categoryItems[category] = [];
      }
      categoryItems[category]!.add(item);
    }
    
    // Tính toán breakdown cho từng danh mục
    final Map<String, CategoryCostBreakdown> breakdown = {};
    
    categoryItems.forEach((category, categoryItemList) {
      final categoryTotalCost = categoryItemList.fold<double>(
        0.0,
        (sum, item) => sum + item.estimatedCost,
      );
      
      final percentage = totalCost > 0 ? (categoryTotalCost / totalCost) * 100 : 0.0;
      final averageCostPerItem = categoryItemList.isNotEmpty 
          ? categoryTotalCost / categoryItemList.length 
          : 0.0;
      
      // Tìm top 3 items đắt nhất trong danh mục
      final sortedItems = List<GroceryItemWithCost>.from(categoryItemList)
        ..sort((a, b) => b.estimatedCost.compareTo(a.estimatedCost));
      final topExpensiveItems = sortedItems
          .take(3)
          .map((item) => '${item.name} (${_formatCurrency(item.estimatedCost)})')
          .toList();
      
      breakdown[category] = CategoryCostBreakdown(
        categoryName: category,
        totalCost: categoryTotalCost,
        percentage: percentage,
        itemCount: categoryItemList.length,
        averageCostPerItem: averageCostPerItem,
        topExpensiveItems: topExpensiveItems,
      );
    });
    
    return breakdown;
  }

  /// Tạo mẹo tiết kiệm chi phí
  Future<List<CostSavingTip>> _generateSavingTips(
    List<GroceryItemWithCost> items,
    Map<String, CategoryCostBreakdown> categoryBreakdown,
  ) async {
    final List<CostSavingTip> tips = [];
    
    // Mẹo dựa trên danh mục đắt nhất
    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.totalCost.compareTo(a.value.totalCost));
    
    if (sortedCategories.isNotEmpty) {
      final mostExpensiveCategory = sortedCategories.first;
      tips.add(CostSavingTip(
        title: 'Giảm chi phí ${mostExpensiveCategory.key}',
        description: 'Danh mục ${mostExpensiveCategory.key} chiếm ${mostExpensiveCategory.value.percentage.toStringAsFixed(1)}% tổng chi phí. Hãy xem xét giảm bớt hoặc tìm thay thế rẻ hơn.',
        potentialSaving: mostExpensiveCategory.value.totalCost * 0.2,
        category: mostExpensiveCategory.key,
        priority: 5,
      ));
    }
    
    // Mẹo về items đắt nhất
    final sortedItems = List<GroceryItemWithCost>.from(items)
      ..sort((a, b) => b.estimatedCost.compareTo(a.estimatedCost));
    
    if (sortedItems.isNotEmpty) {
      final mostExpensiveItem = sortedItems.first;
      tips.add(CostSavingTip(
        title: 'Xem xét thay thế ${mostExpensiveItem.name}',
        description: '${mostExpensiveItem.name} là mặt hàng đắt nhất trong danh sách (${_formatCurrency(mostExpensiveItem.estimatedCost)}). Hãy tìm kiếm các lựa chọn thay thế.',
        potentialSaving: mostExpensiveItem.estimatedCost * 0.3,
        category: mostExpensiveItem.category,
        priority: 4,
      ));
    }
    
    // Mẹo chung
    tips.addAll([
      CostSavingTip(
        title: 'Mua theo mùa',
        description: 'Mua rau củ quả theo mùa để có giá tốt nhất và chất lượng tươi ngon.',
        potentialSaving: items.where((item) => item.category.contains('Rau củ quả')).fold<double>(0.0, (sum, item) => sum + item.estimatedCost) * 0.15,
        category: '🥬 Rau củ quả',
        priority: 3,
      ),
      CostSavingTip(
        title: 'So sánh giá nhiều nơi',
        description: 'So sánh giá ở các chợ, siêu thị khác nhau để tìm được giá tốt nhất.',
        potentialSaving: items.fold<double>(0.0, (sum, item) => sum + item.estimatedCost) * 0.1,
        category: 'Tổng quát',
        priority: 2,
      ),
      CostSavingTip(
        title: 'Mua số lượng lớn',
        description: 'Với các mặt hàng không dễ hỏng, mua số lượng lớn thường có giá tốt hơn.',
        potentialSaving: items.fold<double>(0.0, (sum, item) => sum + item.estimatedCost) * 0.05,
        category: 'Tổng quát',
        priority: 1,
      ),
    ]);
    
    return tips;
  }

  /// Tính toán so sánh ngân sách
  BudgetComparison _calculateBudgetComparison(double actualCost, double budgetLimit) {
    final difference = actualCost - budgetLimit;
    final isOverBudget = difference > 0;
    final percentageUsed = budgetLimit > 0 ? (actualCost / budgetLimit) * 100 : 0;
    
    return BudgetComparison(
      budgetLimit: budgetLimit,
      actualCost: actualCost,
      difference: difference,
      isOverBudget: isOverBudget,
      percentageUsed: percentageUsed,
    );
  }

  /// Tạo cảnh báo giá cả
  Future<List<PriceAlert>> _generatePriceAlerts(
    List<GroceryItemWithCost> items,
  ) async {
    final List<PriceAlert> alerts = [];
    
    try {
      final stats = await _priceService.getPriceStatistics();
      final categoryStats = stats['category_stats'] as Map<String, dynamic>? ?? {};
      
      for (final item in items) {
        final categoryData = categoryStats[item.category] as Map<String, dynamic>?;
        if (categoryData != null) {
          final averagePrice = categoryData['average'] as double? ?? 0.0;
          final currentPrice = item.pricePerUnit;
          final priceChange = ((currentPrice - averagePrice) / averagePrice) * 100;
          
          String alertType = 'normal';
          String message = '';
          
          if (priceChange > 20) {
            alertType = 'high';
            message = '${item.name} có giá cao hơn trung bình ${priceChange.toStringAsFixed(1)}%';
          } else if (priceChange < -20) {
            alertType = 'low';
            message = '${item.name} có giá thấp hơn trung bình ${priceChange.abs().toStringAsFixed(1)}% - cơ hội tốt!';
          }
          
          if (alertType != 'normal') {
            alerts.add(PriceAlert(
              itemName: item.name,
              currentPrice: currentPrice,
              averagePrice: averagePrice,
              priceChange: priceChange,
              alertType: alertType,
              message: message,
            ));
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi tạo cảnh báo giá: $e');
    }
    
    return alerts;
  }

  /// Format currency
  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}₫';
  }

  /// Tạo grocery list với cost từ meal plan
  Future<List<GroceryItemWithCost>> createGroceryListFromMealPlan(
    Map<String, List<String>> mealPlan,
  ) async {
    final Map<String, double> ingredientAmounts = {};
    final Map<String, String> ingredientUnits = {};
    final Map<String, String> ingredientCategories = {};
    
    // Tổng hợp ingredients từ meal plan
    for (final meals in mealPlan.values) {
      for (final meal in meals) {
        // TODO: Parse meal để lấy ingredients
        // Đây là placeholder logic
        final ingredients = _parseMealIngredients(meal);
        for (final ingredient in ingredients.entries) {
          final name = ingredient.key;
          final amount = ingredient.value['amount'] as double;
          final unit = ingredient.value['unit'] as String;
          
          ingredientAmounts[name] = (ingredientAmounts[name] ?? 0.0) + amount;
          ingredientUnits[name] = unit;
          
          // Lấy category từ Firebase
          final priceData = await _priceService.getFoodPrice(name);
          if (priceData != null) {
            ingredientCategories[name] = priceData['category'] ?? 'Khác';
          }
        }
      }
    }
    
    // Tạo grocery items với cost
    final List<GroceryItemWithCost> groceryItems = [];
    for (final ingredient in ingredientAmounts.entries) {
      final name = ingredient.key;
      final amount = ingredient.value;
      final unit = ingredientUnits[name] ?? 'kg';
      final category = ingredientCategories[name] ?? 'Khác';
      
      final estimatedCost = await _priceService.calculateEstimatedCost(name, amount);
      final priceData = await _priceService.getFoodPrice(name);
      
      double pricePerUnit = 0.0;
      if (priceData != null) {
        if (priceData.containsKey('price_per_kg')) {
          pricePerUnit = (priceData['price_per_kg'] as num).toDouble();
        } else if (priceData.containsKey('price_per_liter')) {
          pricePerUnit = (priceData['price_per_liter'] as num).toDouble();
        } else if (priceData.containsKey('price_per_unit')) {
          pricePerUnit = (priceData['price_per_unit'] as num).toDouble();
        }
      }
      
      groceryItems.add(GroceryItemWithCost(
        name: name,
        amount: amount.toString(),
        unit: unit,
        category: category,
        estimatedCost: estimatedCost,
        pricePerUnit: pricePerUnit,
      ));
    }
    
    return groceryItems;
  }

  /// Parse meal để lấy ingredients (placeholder)
  Map<String, Map<String, dynamic>> _parseMealIngredients(String meal) {
    // TODO: Implement proper meal parsing logic
    // Đây là placeholder trả về một số ingredients mẫu
    return {
      'thịt bò': {'amount': 0.5, 'unit': 'kg'},
      'cà chua': {'amount': 0.3, 'unit': 'kg'},
      'hành tây': {'amount': 0.2, 'unit': 'kg'},
    };
  }
}
