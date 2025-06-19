import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service AI để phân tích giá cả thực phẩm thông minh
/// Gọi backend FastAPI endpoints thay vì xử lý local
class PriceAIAnalysisService {
  static const String baseUrl = 'http://localhost:8000'; // TODO: Update with actual backend URL
  
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Phân tích xu hướng giá cả
  Future<Map<String, dynamic>> analyzePriceTrends({
    String? category,
    int daysBack = 30,
  }) async {
    try {
      final requestBody = {
        'category': category,
        'days_back': daysBack,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/analyze-trends'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Backend error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi phân tích xu hướng: $e');
      return _getFallbackTrendAnalysis();
    }
  }

  /// Dự đoán giá cả trong tương lai
  Future<Map<String, dynamic>> predictFuturePrices({
    required String foodName,
    int daysAhead = 7,
  }) async {
    try {
      final requestBody = {
        'food_name': foodName,
        'days_ahead': daysAhead,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/predict-price'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Backend error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi dự đoán giá: $e');
      return _getFallbackPrediction(foodName);
    }
  }

  /// Phân tích mùa vụ và xu hướng theo thời gian
  Future<Map<String, dynamic>> analyzeSeasonalTrends(String? category) async {
    try {
      final requestBody = {
        'category': category,
        'current_month': DateTime.now().month,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/analyze-seasonal'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Backend error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi phân tích mùa vụ: $e');
      return _getFallbackSeasonalAnalysis();
    }
  }

  /// Phân tích thông minh cho grocery list
  Future<Map<String, dynamic>> analyzeGroceryListIntelligently(
    List<Map<String, dynamic>> groceryItems, {
    double? budgetLimit,
  }) async {
    try {
      final requestBody = {
        'grocery_items': groceryItems,
        'budget_limit': budgetLimit,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/optimize-grocery'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Backend error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi phân tích grocery: $e');
      return _getFallbackGroceryAnalysis();
    }
  }

  /// Tạo insights thông minh về thị trường
  Future<Map<String, dynamic>> generateMarketInsights({
    String? region,
    bool includeTrends = true,
  }) async {
    try {
      final requestBody = {
        'region': region,
        'include_trends': includeTrends,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/market-insights'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Backend error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi tạo market insights: $e');
      return _getFallbackMarketInsights();
    }
  }

  /// Test backend connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ai-price/health'),
        headers: _headers,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Lỗi kết nối backend: $e');
      return false;
    }
  }

  // Fallback methods khi backend không hoạt động
  Map<String, dynamic> _getFallbackTrendAnalysis() {
    return {
      'analysis_date': DateTime.now().toIso8601String(),
      'category': 'Tất cả',
      'period_days': 30,
      'trend': 'stable',
      'insights': [
        {
          'title': 'Dữ liệu đang cập nhật',
          'description': 'Hệ thống AI đang được cập nhật. Vui lòng thử lại sau.',
          'confidence': 0.5,
          'category': 'info'
        }
      ],
      'recommendations': ['Theo dõi giá thường xuyên', 'Mua theo nhu cầu thực tế'],
      'price_alerts': []
    };
  }

  Map<String, dynamic> _getFallbackPrediction(String foodName) {
    return {
      'food_name': foodName,
      'current_price': 0,
      'predicted_price': 0,
      'prediction_days': 7,
      'confidence': 0,
      'trend': 'unknown',
      'factors': ['Cần kết nối backend để dự đoán'],
      'recommendation': 'Vui lòng kiểm tra kết nối mạng và thử lại',
      'price_range': {'min': 0, 'max': 0},
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _getFallbackSeasonalAnalysis() {
    return {
      'current_season': _getCurrentSeason(DateTime.now().month),
      'seasonal_foods': ['Dữ liệu đang cập nhật'],
      'price_predictions': {},
      'buying_recommendations': ['Mua theo nhu cầu thực tế'],
      'avoid_buying': [],
      'best_deals': [],
      'analysis_date': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _getFallbackGroceryAnalysis() {
    return {
      'total_items': 0,
      'optimization_suggestions': ['Kết nối backend để nhận gợi ý tối ưu'],
      'substitution_recommendations': {},
      'timing_advice': 'Mua sáng sớm thường có giá tốt',
      'budget_optimization': 'Lập kế hoạch mua sắm chi tiết',
      'health_insights': 'Cân bằng các nhóm thực phẩm',
      'sustainability_tips': 'Ưu tiên sản phẩm địa phương',
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _getFallbackMarketInsights() {
    return {
      'market_overview': 'Đang thu thập dữ liệu thị trường từ backend',
      'trending_foods': ['Dữ liệu đang cập nhật'],
      'price_volatility': {},
      'regional_differences': 'Cần kết nối backend để phân tích',
      'consumer_behavior': 'Đang phân tích hành vi người tiêu dùng',
      'economic_factors': 'Theo dõi các yếu tố kinh tế',
      'recommendations': ['Kiểm tra kết nối mạng', 'Thử lại sau'],
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  String _getCurrentSeason(int month) {
    if (month >= 3 && month <= 5) return 'Mùa xuân';
    if (month >= 6 && month <= 8) return 'Mùa hè';
    if (month >= 9 && month <= 11) return 'Mùa thu';
    return 'Mùa đông';
  }
}
