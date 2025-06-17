import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service để lấy giá cả thực tế từ các nguồn API
class RealPriceService {
  static const String _baseUrl = 'https://backend-openfood.onrender.com';
  
  /// Lấy giá thực tế từ API backend của bạn
  static Future<Map<String, dynamic>?> getRealPrice(String itemName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/food-prices/${Uri.encodeComponent(itemName)}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ Lỗi khi lấy giá thực tế: $e');
    }
    return null;
  }
  
  /// Lấy giá từ nhiều nguồn (siêu thị, chợ, online)
  static Future<List<Map<String, dynamic>>> getMultiSourcePrices(String itemName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/food-prices/multi-source/${Uri.encodeComponent(itemName)}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sources'] ?? []);
      }
    } catch (e) {
      print('❌ Lỗi khi lấy giá từ nhiều nguồn: $e');
    }
    return [];
  }
  
  /// Cập nhật giá cả từ người dùng
  static Future<bool> updateUserPrice({
    required String itemName,
    required double price,
    required String unit,
    required String location,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/food-prices/user-update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item_name': itemName,
          'price': price,
          'unit': unit,
          'location': location,
          'user_id': userId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Lỗi khi cập nhật giá từ người dùng: $e');
      return false;
    }
  }
  
  /// Lấy giá trung bình theo khu vực
  static Future<Map<String, dynamic>?> getRegionalPrice(
    String itemName, 
    String region
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/food-prices/regional/$region/${Uri.encodeComponent(itemName)}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ Lỗi khi lấy giá theo khu vực: $e');
    }
    return null;
  }
  
  /// Lấy lịch sử giá cả
  static Future<List<Map<String, dynamic>>> getPriceHistory(
    String itemName,
    {int days = 30}
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/food-prices/history/${Uri.encodeComponent(itemName)}?days=$days'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['history'] ?? []);
      }
    } catch (e) {
      print('❌ Lỗi khi lấy lịch sử giá: $e');
    }
    return [];
  }
  
  /// Dự đoán giá cả trong tương lai
  static Future<Map<String, dynamic>?> getPricePrediction(String itemName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/food-prices/prediction/${Uri.encodeComponent(itemName)}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ Lỗi khi dự đoán giá: $e');
    }
    return null;
  }
  
  /// Tìm kiếm sản phẩm tương tự với giá tốt hơn
  static Future<List<Map<String, dynamic>>> findAlternatives(
    String itemName,
    double currentPrice
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/food-prices/alternatives'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item_name': itemName,
          'current_price': currentPrice,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['alternatives'] ?? []);
      }
    } catch (e) {
      print('❌ Lỗi khi tìm sản phẩm thay thế: $e');
    }
    return [];
  }
  
  /// Lấy khuyến mãi hiện tại
  static Future<List<Map<String, dynamic>>> getCurrentPromotions(String itemName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/food-prices/promotions/${Uri.encodeComponent(itemName)}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['promotions'] ?? []);
      }
    } catch (e) {
      print('❌ Lỗi khi lấy khuyến mãi: $e');
    }
    return [];
  }
}
