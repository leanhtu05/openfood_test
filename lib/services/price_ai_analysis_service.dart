import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service AI để phân tích giá cả thực phẩm thông minh
/// Gọi backend FastAPI endpoints thay vì xử lý local
class PriceAIAnalysisService {
  // Thử nhiều backend URLs để đảm bảo tính khả dụng
  static const List<String> _backendUrls = [
    'https://backend-openfood.onrender.com', // Primary Render backend
    'http://localhost:8000', // Local development
  ];

  // Render backend có thể sleep, cần thời gian wake-up
  static const int _renderWakeupTimeoutSeconds = 30;

  static String? _workingUrl;

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'OpenFood-Flutter-App/1.0',
  };

  /// Wake-up Render backend nếu đang sleep
  Future<bool> _wakeupRenderBackend(String url) async {
    try {
      print('🌅 Đang wake-up Render backend...');

      // Gọi endpoint đơn giản để wake-up
      final response = await http.get(
        Uri.parse('$url/'),
        headers: _headers,
      ).timeout(Duration(seconds: _renderWakeupTimeoutSeconds));

      // Chờ thêm một chút để backend khởi động hoàn toàn
      await Future.delayed(Duration(seconds: 2));

      print('✅ Render backend đã được wake-up');
      return true;
    } catch (e) {
      print('❌ Không thể wake-up Render backend: $e');
      return false;
    }
  }

  /// Tìm backend URL hoạt động với xử lý Render wake-up
  Future<String?> _findWorkingBackend() async {
    if (_workingUrl != null) {
      // Kiểm tra lại working URL để đảm bảo vẫn hoạt động
      try {
        final response = await http.get(
          Uri.parse('$_workingUrl/ai-price/health'),
          headers: _headers,
        ).timeout(Duration(seconds: 5));

        if (response.statusCode == 200) {
          return _workingUrl;
        } else {
          print('⚠️ Working URL không còn hoạt động, tìm lại...');
          _workingUrl = null;
        }
      } catch (e) {
        print('⚠️ Working URL lỗi: $e, tìm lại...');
        _workingUrl = null;
      }
    }

    for (final url in _backendUrls) {
      try {
        print('🔍 Đang kiểm tra backend: $url');

        // Xử lý đặc biệt cho Render backend (có thể đang sleep)
        final isRenderBackend = url.contains('render.com');
        final timeoutSeconds = isRenderBackend ? _renderWakeupTimeoutSeconds : 10;

        if (isRenderBackend) {
          print('⏰ Render backend có thể đang sleep, chờ wake-up (${timeoutSeconds}s)...');
        }

        final response = await http.get(
          Uri.parse('$url/ai-price/health'),
          headers: _headers,
        ).timeout(Duration(seconds: timeoutSeconds));

        if (response.statusCode == 200) {
          print('✅ Backend hoạt động: $url');
          _workingUrl = url;
          return url;
        } else {
          print('❌ Backend trả về status ${response.statusCode}: $url');
        }
      } catch (e) {
        print('❌ Backend không hoạt động: $url - $e');
        continue;
      }
    }

    print('⚠️ Không tìm thấy backend nào hoạt động, sử dụng fallback');
    return null;
  }

  /// Phân tích xu hướng giá cả
  Future<Map<String, dynamic>> analyzePriceTrends({
    String? category,
    int daysBack = 30,
  }) async {
    try {
      final baseUrl = await _findWorkingBackend();
      if (baseUrl == null) {
        return _getFallbackTrendAnalysis();
      }

      final requestBody = {
        'category': category,
        'days_back': daysBack,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/analyze-trends'),
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 10));

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
      final baseUrl = await _findWorkingBackend();
      if (baseUrl == null) {
        return _getFallbackPrediction(foodName);
      }

      final requestBody = {
        'food_name': foodName,
        'days_ahead': daysAhead,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/predict-price'),
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 10));

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
      final baseUrl = await _findWorkingBackend();
      if (baseUrl == null) {
        return _getFallbackSeasonalAnalysis();
      }

      final requestBody = {
        'category': category,
        'current_month': DateTime.now().month,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/analyze-seasonal'),
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 10));

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
      final baseUrl = await _findWorkingBackend();
      if (baseUrl == null) {
        print('⚠️ Không có backend, sử dụng phân tích local nâng cao');
        return _getEnhancedLocalAnalysis(groceryItems, budgetLimit);
      }

      final requestBody = {
        'grocery_items': groceryItems,
        'budget_limit': budgetLimit,
        'analysis_type': 'comprehensive',
        'include_ai_insights': true,
      };

      print('🤖 Gửi ${groceryItems.length} items tới AI backend: $baseUrl');

      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/optimize-grocery'),
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('✅ Nhận được phân tích AI thành công');
        return result;
      } else {
        print('❌ Backend error: ${response.statusCode}');
        throw Exception('Backend error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi phân tích grocery: $e');
      return _getEnhancedLocalAnalysis(groceryItems, budgetLimit);
    }
  }

  /// Tạo insights thông minh về thị trường
  Future<Map<String, dynamic>> generateMarketInsights({
    String? region,
    bool includeTrends = true,
  }) async {
    try {
      final baseUrl = await _findWorkingBackend();
      if (baseUrl == null) {
        return _getFallbackMarketInsights();
      }

      final requestBody = {
        'region': region,
        'include_trends': includeTrends,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/ai-price/market-insights'),
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 10));

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

  /// Test backend connection với wake-up support
  Future<bool> testConnection() async {
    try {
      final workingUrl = await _findWorkingBackend();
      return workingUrl != null;
    } catch (e) {
      print('❌ Lỗi kết nối backend: $e');
      return false;
    }
  }

  /// Test connection tới một URL cụ thể
  Future<bool> testSpecificUrl(String url) async {
    try {
      print('🔍 Testing connection to: $url');

      final response = await http.get(
        Uri.parse('$url/ai-price/health'),
        headers: _headers,
      ).timeout(Duration(seconds: 30));

      final isWorking = response.statusCode == 200;
      print(isWorking ? '✅ Connection successful' : '❌ Connection failed: ${response.statusCode}');

      return isWorking;
    } catch (e) {
      print('❌ Connection error: $e');
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

  /// Phân tích local nâng cao khi không có backend
  Map<String, dynamic> _getEnhancedLocalAnalysis(
    List<Map<String, dynamic>> groceryItems,
    double? budgetLimit
  ) {
    final totalItems = groceryItems.length;
    final categories = <String, List<Map<String, dynamic>>>{};

    // Phân loại theo danh mục
    for (final item in groceryItems) {
      final category = item['category'] ?? 'Khác';
      categories.putIfAbsent(category, () => []).add(item);
    }

    // Tạo gợi ý thông minh dựa trên dữ liệu
    final suggestions = <String>[];

    if (categories.containsKey('🥩 Thịt tươi sống') && categories['🥩 Thịt tươi sống']!.length > 3) {
      suggestions.add('Bạn có nhiều loại thịt, hãy xem xét mua ở chợ đầu mối để tiết kiệm');
    }

    if (categories.containsKey('🥬 Rau củ quả') && categories['🥬 Rau củ quả']!.length > 5) {
      suggestions.add('Mua rau củ vào buổi sáng sớm để có giá tốt và độ tươi cao');
    }

    if (totalItems > 15) {
      suggestions.add('Danh sách khá dài, hãy chia thành 2 lần mua để đảm bảo độ tươi');
    }

    // Phân tích ngân sách
    final budgetAdvice = budgetLimit != null && budgetLimit > 0
        ? 'Với ngân sách ${budgetLimit.toStringAsFixed(0)} VND, hãy ưu tiên thực phẩm thiết yếu'
        : 'Hãy đặt ngân sách cụ thể để quản lý chi tiêu hiệu quả';

    return {
      'total_items': totalItems,
      'category_count': categories.length,
      'optimization_suggestions': suggestions.isNotEmpty ? suggestions : [
        'Lập danh sách theo thứ tự ưu tiên',
        'So sánh giá ở nhiều nơi khác nhau',
        'Mua theo mùa để có giá tốt nhất'
      ],
      'substitution_recommendations': _getSmartSubstitutions(categories),
      'timing_advice': _getTimingAdvice(),
      'budget_optimization': budgetAdvice,
      'health_insights': _getHealthInsights(categories),
      'sustainability_tips': _getSustainabilityTips(categories),
      'category_analysis': _analyzeCategoriesLocally(categories),
      'generated_at': DateTime.now().toIso8601String(),
      'analysis_type': 'enhanced_local',
    };
  }

  Map<String, dynamic> _getSmartSubstitutions(Map<String, List<Map<String, dynamic>>> categories) {
    final substitutions = <String, String>{};

    // Gợi ý thay thế thông minh
    if (categories.containsKey('🥩 Thịt tươi sống')) {
      substitutions['Thịt bò'] = 'Thịt heo hoặc gà để tiết kiệm chi phí';
    }

    if (categories.containsKey('🐟 Hải sản')) {
      substitutions['Tôm sú'] = 'Tôm thẻ có giá rẻ hơn nhưng vẫn ngon';
    }

    return substitutions;
  }

  String _getTimingAdvice() {
    final hour = DateTime.now().hour;
    if (hour < 8) {
      return 'Thời điểm tuyệt vời! Chợ sáng có hàng tươi và giá tốt';
    } else if (hour < 12) {
      return 'Buổi sáng vẫn là thời điểm tốt để mua sắm';
    } else if (hour < 17) {
      return 'Buổi chiều có thể có khuyến mãi ở siêu thị';
    } else {
      return 'Buổi tối có thể có giảm giá cho thực phẩm tươi sống';
    }
  }

  String _getHealthInsights(Map<String, List<Map<String, dynamic>>> categories) {
    final insights = <String>[];

    if (!categories.containsKey('🥬 Rau củ quả')) {
      insights.add('Thiếu rau củ quả trong danh sách');
    }

    if (!categories.containsKey('🥩 Thịt tươi sống') && !categories.containsKey('🐟 Hải sản')) {
      insights.add('Cần bổ sung protein từ thịt hoặc hải sản');
    }

    return insights.isNotEmpty
        ? insights.join(', ')
        : 'Danh sách cân bằng dinh dưỡng tốt';
  }

  String _getSustainabilityTips(Map<String, List<Map<String, dynamic>>> categories) {
    return 'Ưu tiên sản phẩm địa phương, giảm túi nilon, mua đúng nhu cầu';
  }

  Map<String, dynamic> _analyzeCategoriesLocally(Map<String, List<Map<String, dynamic>>> categories) {
    final analysis = <String, dynamic>{};

    for (final entry in categories.entries) {
      analysis[entry.key] = {
        'item_count': entry.value.length,
        'priority': _getCategoryPriority(entry.key),
        'tips': _getCategoryTips(entry.key),
      };
    }

    return analysis;
  }

  int _getCategoryPriority(String category) {
    switch (category) {
      case '🥬 Rau củ quả': return 5;
      case '🥩 Thịt tươi sống': return 4;
      case '🌾 Ngũ cốc & Gạo': return 4;
      case '🥛 Sữa & Trứng': return 3;
      default: return 2;
    }
  }

  String _getCategoryTips(String category) {
    switch (category) {
      case '🥬 Rau củ quả': return 'Mua vào buổi sáng, chọn theo mùa';
      case '🥩 Thịt tươi sống': return 'Kiểm tra độ tươi, bảo quản lạnh ngay';
      case '🐟 Hải sản': return 'Mua tại chợ hải sản để đảm bảo tươi';
      case '🌾 Ngũ cốc & Gạo': return 'Mua số lượng lớn để tiết kiệm';
      default: return 'Kiểm tra hạn sử dụng';
    }
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
