import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Cơ sở dữ liệu giá cả thực phẩm Việt Nam
class VietnameseFoodPrices {
  /// Giá cả thực phẩm theo danh mục
  static final Map<String, Map<String, dynamic>> foodPrices = {
    // Thịt tươi sống
    'thịt bò': {'price_per_kg': 220000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'thịt heo': {'price_per_kg': 110000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'thịt gà': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'thịt vịt': {'price_per_kg': 130000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'thịt cừu': {'price_per_kg': 400000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'thịt dê': {'price_per_kg': 380000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'sườn heo': {'price_per_kg': 180000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'ba chỉ': {'price_per_kg': 170000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'đùi gà': {'price_per_kg': 100000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'cánh gà': {'price_per_kg': 90000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},
    'ức gà': {'price_per_kg': 110000, 'unit': 'kg', 'category': '🥩 Thịt tươi sống'},

    // Hải sản
    'cá thu': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'cá hồi': {'price_per_kg': 350000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'cá ngừ': {'price_per_kg': 250000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'cá lóc': {'price_per_kg': 180000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'cá diêu hồng': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'cá chép': {'price_per_kg': 100000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'tôm sú': {'price_per_kg': 400000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'tôm thẻ': {'price_per_kg': 250000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'mực': {'price_per_kg': 300000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'bạch tuộc': {'price_per_kg': 350000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'nghêu': {'price_per_kg': 80000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'sò': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🐟 Hải sản'},
    'hàu': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🐟 Hải sản'},

    // Rau củ quả
    'cà chua': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'cà rốt': {'price_per_kg': 30000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'bắp cải': {'price_per_kg': 20000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'súp lơ': {'price_per_kg': 35000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'bông cải xanh': {'price_per_kg': 40000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'rau muống': {'price_per_kg': 15000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'rau dền': {'price_per_kg': 18000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'rau ngót': {'price_per_kg': 20000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'xà lách': {'price_per_kg': 30000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'hành tây': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'hành lá': {'price_per_kg': 40000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'tỏi': {'price_per_kg': 100000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'gừng': {'price_per_kg': 80000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'ớt': {'price_per_kg': 50000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'khoai tây': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'khoai lang': {'price_per_kg': 30000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'bí đỏ': {'price_per_kg': 20000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'bí xanh': {'price_per_kg': 18000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'mướp': {'price_per_kg': 22000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'đậu bắp': {'price_per_kg': 35000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'đậu cove': {'price_per_kg': 40000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},
    'nấm': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🥬 Rau củ quả'},

    // Trái cây
    'chuối': {'price_per_kg': 30000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'táo': {'price_per_kg': 60000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'cam': {'price_per_kg': 50000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'quýt': {'price_per_kg': 60000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'bưởi': {'price_per_kg': 40000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'dưa hấu': {'price_per_kg': 20000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'dưa lưới': {'price_per_kg': 70000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'xoài': {'price_per_kg': 45000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'đu đủ': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'thanh long': {'price_per_kg': 35000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'nhãn': {'price_per_kg': 60000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'vải': {'price_per_kg': 70000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'chôm chôm': {'price_per_kg': 55000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'sầu riêng': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'măng cụt': {'price_per_kg': 90000, 'unit': 'kg', 'category': '🍎 Trái cây'},
    'mít': {'price_per_kg': 40000, 'unit': 'kg', 'category': '🍎 Trái cây'},

    // Ngũ cốc & Gạo
    'gạo tẻ': {'price_per_kg': 18000, 'unit': 'kg', 'category': '🌾 Ngũ cốc & Gạo'},
    'gạo nếp': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🌾 Ngũ cốc & Gạo'},
    'gạo lứt': {'price_per_kg': 30000, 'unit': 'kg', 'category': '🌾 Ngũ cốc & Gạo'},
    'bột mì': {'price_per_kg': 20000, 'unit': 'kg', 'category': '🌾 Ngũ cốc & Gạo'},
    'bột gạo': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🌾 Ngũ cốc & Gạo'},
    'ngô': {'price_per_kg': 30000, 'unit': 'kg', 'category': '🌾 Ngũ cốc & Gạo'},
    'yến mạch': {'price_per_kg': 60000, 'unit': 'kg', 'category': '🌾 Ngũ cốc & Gạo'},

    // Đậu & Hạt
    'đậu phộng': {'price_per_kg': 70000, 'unit': 'kg', 'category': '🥜 Đậu & Hạt'},
    'đậu xanh': {'price_per_kg': 60000, 'unit': 'kg', 'category': '🥜 Đậu & Hạt'},
    'đậu đen': {'price_per_kg': 55000, 'unit': 'kg', 'category': '🥜 Đậu & Hạt'},
    'đậu nành': {'price_per_kg': 50000, 'unit': 'kg', 'category': '🥜 Đậu & Hạt'},
    'hạt điều': {'price_per_kg': 250000, 'unit': 'kg', 'category': '🥜 Đậu & Hạt'},
    'hạt hướng dương': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🥜 Đậu & Hạt'},
    'hạt óc chó': {'price_per_kg': 350000, 'unit': 'kg', 'category': '🥜 Đậu & Hạt'},
    'hạt chia': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🥜 Đậu & Hạt'},

    // Sữa & Trứng
    'trứng gà': {'price_per_unit': 4000, 'unit': 'quả', 'category': '🥛 Sữa & Trứng'},
    'trứng vịt': {'price_per_unit': 5000, 'unit': 'quả', 'category': '🥛 Sữa & Trứng'},
    'trứng cút': {'price_per_unit': 1500, 'unit': 'quả', 'category': '🥛 Sữa & Trứng'},
    'sữa tươi': {'price_per_liter': 30000, 'unit': 'lít', 'category': '🥛 Sữa & Trứng'},
    'sữa chua': {'price_per_kg': 40000, 'unit': 'kg', 'category': '🥛 Sữa & Trứng'},
    'phô mai': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🥛 Sữa & Trứng'},

    // Gia vị
    'muối': {'price_per_kg': 15000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'đường': {'price_per_kg': 25000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'tiêu': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'bột ngọt': {'price_per_kg': 80000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'nước mắm': {'price_per_liter': 60000, 'unit': 'lít', 'category': '🧂 Gia vị'},
    'nước tương': {'price_per_liter': 50000, 'unit': 'lít', 'category': '🧂 Gia vị'},
    'dầu ăn': {'price_per_liter': 45000, 'unit': 'lít', 'category': '🧂 Gia vị'},
    'dầu hào': {'price_per_liter': 70000, 'unit': 'lít', 'category': '🧂 Gia vị'},
    'sa tế': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'tương ớt': {'price_per_kg': 80000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'bột nghệ': {'price_per_kg': 150000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'bột quế': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'hạt nêm': {'price_per_kg': 100000, 'unit': 'kg', 'category': '🧂 Gia vị'},
    'mật ong': {'price_per_kg': 250000, 'unit': 'kg', 'category': '🧂 Gia vị'},

    // Đồ uống
    'nước lọc': {'price_per_liter': 10000, 'unit': 'lít', 'category': '🥤 Đồ uống'},
    'nước ngọt': {'price_per_liter': 20000, 'unit': 'lít', 'category': '🥤 Đồ uống'},
    'nước trái cây': {'price_per_liter': 30000, 'unit': 'lít', 'category': '🥤 Đồ uống'},
    'trà': {'price_per_kg': 150000, 'unit': 'kg', 'category': '🥤 Đồ uống'},
    'cà phê': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🥤 Đồ uống'},
    'bia': {'price_per_liter': 40000, 'unit': 'lít', 'category': '🥤 Đồ uống'},
    'rượu': {'price_per_liter': 150000, 'unit': 'lít', 'category': '🥤 Đồ uống'},

    // Bánh kẹo
    'bánh mì': {'price_per_unit': 5000, 'unit': 'ổ', 'category': '🍪 Bánh kẹo'},
    'bánh quy': {'price_per_kg': 100000, 'unit': 'kg', 'category': '🍪 Bánh kẹo'},
    'kẹo': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🍪 Bánh kẹo'},
    'socola': {'price_per_kg': 250000, 'unit': 'kg', 'category': '🍪 Bánh kẹo'},

    // Thực phẩm chế biến sẵn
    'xúc xích': {'price_per_kg': 120000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'chả cá': {'price_per_kg': 150000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'nem chua': {'price_per_kg': 80000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'giò lụa': {'price_per_kg': 200000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'chả lụa': {'price_per_kg': 180000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'pate': {'price_per_kg': 100000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'ruốc': {'price_per_kg': 300000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'mắm tôm': {'price_per_kg': 80000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'tôm khô': {'price_per_kg': 500000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
    'mực khô': {'price_per_kg': 600000, 'unit': 'kg', 'category': '🍖 Thực phẩm chế biến'},
  };

  /// Lấy giá theo tên thực phẩm
  static Map<String, dynamic>? getPrice(String foodName) {
    return foodPrices[foodName.toLowerCase()];
  }

  /// Lấy danh sách thực phẩm theo danh mục
  static Map<String, Map<String, dynamic>> getFoodsByCategory(String category) {
    return Map.fromEntries(
      foodPrices.entries.where((entry) => entry.value['category'] == category)
    );
  }

  /// Lấy tất cả danh mục
  static List<String> getAllCategories() {
    return foodPrices.values
        .map((item) => item['category'] as String)
        .toSet()
        .toList()
        ..sort();
  }

  /// Tìm kiếm thực phẩm theo tên
  static Map<String, Map<String, dynamic>> searchFood(String query) {
    final lowerQuery = query.toLowerCase();
    return Map.fromEntries(
      foodPrices.entries.where((entry) =>
        entry.key.contains(lowerQuery)
      )
    );
  }

  /// Tính giá ước tính cho một lượng thực phẩm
  static double calculateEstimatedCost(String foodName, double amount) {
    final priceData = getPrice(foodName);
    if (priceData == null) return 0.0;

    // Xử lý các loại giá khác nhau
    if (priceData.containsKey('price_per_kg')) {
      return (priceData['price_per_kg'] as num).toDouble() * amount;
    } else if (priceData.containsKey('price_per_liter')) {
      return (priceData['price_per_liter'] as num).toDouble() * amount;
    } else if (priceData.containsKey('price_per_unit')) {
      return (priceData['price_per_unit'] as num).toDouble() * amount;
    }

    return 0.0;
  }
}

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
      analysisDate: _parseDateTime(json['analysis_date']) ?? DateTime.now(),
    );
  }

  /// Helper method để parse DateTime từ nhiều format khác nhau
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is DateTime) {
        return value;
      } else if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      } else if (value is int) {
        // Milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    } catch (e) {
      print('❌ Lỗi parse DateTime: $e');
    }

    return null;
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
