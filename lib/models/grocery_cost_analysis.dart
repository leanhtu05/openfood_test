import 'dart:convert';

/// Model cho phân tích chi phí nguyên liệu
class GroceryCostAnalysis {
  final double totalCost;
  final double averageCostPerItem;
  final Map<String, CategoryCostBreakdown> categoryBreakdown;
  final List<CostSavingTip> savingTips;
  final BudgetComparison budgetComparison;
  final List<PriceAlert> priceAlerts;
  final DateTime analysisDate;

  GroceryCostAnalysis({
    required this.totalCost,
    required this.averageCostPerItem,
    required this.categoryBreakdown,
    required this.savingTips,
    required this.budgetComparison,
    required this.priceAlerts,
    required this.analysisDate,
  });

  factory GroceryCostAnalysis.fromJson(Map<String, dynamic> json) {
    return GroceryCostAnalysis(
      totalCost: (json['total_cost'] ?? 0.0).toDouble(),
      averageCostPerItem: (json['average_cost_per_item'] ?? 0.0).toDouble(),
      categoryBreakdown: (json['category_breakdown'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, CategoryCostBreakdown.fromJson(value))),
      savingTips: (json['saving_tips'] as List<dynamic>? ?? [])
          .map((tip) => CostSavingTip.fromJson(tip))
          .toList(),
      budgetComparison: BudgetComparison.fromJson(json['budget_comparison'] ?? {}),
      priceAlerts: (json['price_alerts'] as List<dynamic>? ?? [])
          .map((alert) => PriceAlert.fromJson(alert))
          .toList(),
      analysisDate: DateTime.tryParse(json['analysis_date'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_cost': totalCost,
      'average_cost_per_item': averageCostPerItem,
      'category_breakdown': categoryBreakdown.map((key, value) => MapEntry(key, value.toJson())),
      'saving_tips': savingTips.map((tip) => tip.toJson()).toList(),
      'budget_comparison': budgetComparison.toJson(),
      'price_alerts': priceAlerts.map((alert) => alert.toJson()).toList(),
      'analysis_date': analysisDate.toIso8601String(),
    };
  }
}

/// Phân tích chi phí theo danh mục
class CategoryCostBreakdown {
  final String categoryName;
  final double totalCost;
  final double percentage;
  final int itemCount;
  final double averageCostPerItem;
  final List<String> topExpensiveItems;

  CategoryCostBreakdown({
    required this.categoryName,
    required this.totalCost,
    required this.percentage,
    required this.itemCount,
    required this.averageCostPerItem,
    required this.topExpensiveItems,
  });

  factory CategoryCostBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryCostBreakdown(
      categoryName: json['category_name'] ?? '',
      totalCost: (json['total_cost'] ?? 0.0).toDouble(),
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      itemCount: json['item_count'] ?? 0,
      averageCostPerItem: (json['average_cost_per_item'] ?? 0.0).toDouble(),
      topExpensiveItems: List<String>.from(json['top_expensive_items'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_name': categoryName,
      'total_cost': totalCost,
      'percentage': percentage,
      'item_count': itemCount,
      'average_cost_per_item': averageCostPerItem,
      'top_expensive_items': topExpensiveItems,
    };
  }
}

/// Mẹo tiết kiệm chi phí
class CostSavingTip {
  final String title;
  final String description;
  final double potentialSaving;
  final String category;
  final int priority; // 1-5, 5 là ưu tiên cao nhất

  CostSavingTip({
    required this.title,
    required this.description,
    required this.potentialSaving,
    required this.category,
    required this.priority,
  });

  factory CostSavingTip.fromJson(Map<String, dynamic> json) {
    return CostSavingTip(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      potentialSaving: (json['potential_saving'] ?? 0.0).toDouble(),
      category: json['category'] ?? '',
      priority: json['priority'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'potential_saving': potentialSaving,
      'category': category,
      'priority': priority,
    };
  }
}

/// So sánh với ngân sách
class BudgetComparison {
  final double budgetLimit;
  final double actualCost;
  final double difference;
  final bool isOverBudget;
  final double percentageUsed;

  BudgetComparison({
    required this.budgetLimit,
    required this.actualCost,
    required this.difference,
    required this.isOverBudget,
    required this.percentageUsed,
  });

  factory BudgetComparison.fromJson(Map<String, dynamic> json) {
    final budgetLimit = (json['budget_limit'] ?? 0.0).toDouble();
    final actualCost = (json['actual_cost'] ?? 0.0).toDouble();
    final difference = actualCost - budgetLimit;
    
    return BudgetComparison(
      budgetLimit: budgetLimit,
      actualCost: actualCost,
      difference: difference,
      isOverBudget: difference > 0,
      percentageUsed: budgetLimit > 0 ? (actualCost / budgetLimit) * 100 : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'budget_limit': budgetLimit,
      'actual_cost': actualCost,
      'difference': difference,
      'is_over_budget': isOverBudget,
      'percentage_used': percentageUsed,
    };
  }
}

/// Cảnh báo giá cả
class PriceAlert {
  final String itemName;
  final double currentPrice;
  final double averagePrice;
  final double priceChange;
  final String alertType; // 'high', 'low', 'normal'
  final String message;

  PriceAlert({
    required this.itemName,
    required this.currentPrice,
    required this.averagePrice,
    required this.priceChange,
    required this.alertType,
    required this.message,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      itemName: json['item_name'] ?? '',
      currentPrice: (json['current_price'] ?? 0.0).toDouble(),
      averagePrice: (json['average_price'] ?? 0.0).toDouble(),
      priceChange: (json['price_change'] ?? 0.0).toDouble(),
      alertType: json['alert_type'] ?? 'normal',
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_name': itemName,
      'current_price': currentPrice,
      'average_price': averagePrice,
      'price_change': priceChange,
      'alert_type': alertType,
      'message': message,
    };
  }
}

/// Model cho item trong grocery list với thông tin giá cả
class GroceryItemWithCost {
  final String name;
  final String amount;
  final String unit;
  final String category;
  final double estimatedCost;
  final double pricePerUnit;
  final bool isChecked;

  GroceryItemWithCost({
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
    required this.estimatedCost,
    required this.pricePerUnit,
    this.isChecked = false,
  });

  factory GroceryItemWithCost.fromJson(Map<String, dynamic> json) {
    return GroceryItemWithCost(
      name: json['name'] ?? '',
      amount: json['amount'] ?? '',
      unit: json['unit'] ?? '',
      category: json['category'] ?? '',
      estimatedCost: (json['estimated_cost'] ?? 0.0).toDouble(),
      pricePerUnit: (json['price_per_unit'] ?? 0.0).toDouble(),
      isChecked: json['is_checked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'category': category,
      'estimated_cost': estimatedCost,
      'price_per_unit': pricePerUnit,
      'is_checked': isChecked,
    };
  }
}
