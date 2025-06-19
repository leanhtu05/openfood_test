import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grocery_cost_analysis.dart';

/// Service để quản lý dữ liệu giá cả thực phẩm Việt Nam trên Firebase
class VietnameseFoodPriceService {
  static const String _collectionName = 'vietnamese_food_prices';
  static const String _priceHistoryCollection = 'price_history';
  static const String _categoriesCollection = 'food_categories';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Khởi tạo dữ liệu giá cả lên Firebase (chỉ chạy một lần)
  Future<void> initializePriceData() async {
    try {
      final batch = _firestore.batch();
      final collection = _firestore.collection(_collectionName);

      // Xóa dữ liệu cũ nếu có
      final existingDocs = await collection.get();
      for (var doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }

      // Thêm dữ liệu mới
      VietnameseFoodPrices.foodPrices.forEach((foodName, priceData) {
        final docRef = collection.doc(foodName);
        batch.set(docRef, {
          'name': foodName,
          'price_data': priceData,
          'last_updated': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();
      print('✅ Đã khởi tạo ${VietnameseFoodPrices.foodPrices.length} mặt hàng lên Firebase');
    } catch (e) {
      print('❌ Lỗi khởi tạo dữ liệu: $e');
      rethrow;
    }
  }

  /// Lấy tất cả dữ liệu giá cả từ Firebase
  Future<Map<String, Map<String, dynamic>>> getAllPrices() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      final Map<String, Map<String, dynamic>> prices = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        prices[doc.id] = data['price_data'] as Map<String, dynamic>;
      }
      
      return prices;
    } catch (e) {
      print('❌ Lỗi lấy dữ liệu giá cả: $e');
      return {};
    }
  }

  /// Lấy giá của một thực phẩm cụ thể
  Future<Map<String, dynamic>?> getFoodPrice(String foodName) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(foodName.toLowerCase())
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        return data['price_data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Lỗi lấy giá thực phẩm $foodName: $e');
      return null;
    }
  }

  /// Cập nhật giá của một thực phẩm
  Future<void> updateFoodPrice(String foodName, Map<String, dynamic> newPriceData) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(foodName.toLowerCase());
      
      // Lưu lịch sử giá cũ
      final oldDoc = await docRef.get();
      if (oldDoc.exists) {
        await _savePriceHistory(foodName, oldDoc.data()!['price_data']);
      }

      // Cập nhật giá mới
      await docRef.update({
        'price_data': newPriceData,
        'last_updated': FieldValue.serverTimestamp(),
      });

      print('✅ Đã cập nhật giá cho $foodName');
    } catch (e) {
      print('❌ Lỗi cập nhật giá $foodName: $e');
      rethrow;
    }
  }

  /// Lưu lịch sử thay đổi giá
  Future<void> _savePriceHistory(String foodName, Map<String, dynamic> oldPriceData) async {
    try {
      await _firestore
          .collection(_priceHistoryCollection)
          .add({
        'food_name': foodName,
        'price_data': oldPriceData,
        'changed_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Lỗi lưu lịch sử giá: $e');
    }
  }

  /// Lấy thực phẩm theo danh mục
  Future<Map<String, Map<String, dynamic>>> getFoodsByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('price_data.category', isEqualTo: category)
          .get();
      
      final Map<String, Map<String, dynamic>> foods = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        foods[doc.id] = data['price_data'] as Map<String, dynamic>;
      }
      
      return foods;
    } catch (e) {
      print('❌ Lỗi lấy thực phẩm theo danh mục: $e');
      return {};
    }
  }

  /// Tìm kiếm thực phẩm
  Future<Map<String, Map<String, dynamic>>> searchFoods(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      final snapshot = await _firestore.collection(_collectionName).get();
      
      final Map<String, Map<String, dynamic>> results = {};
      for (var doc in snapshot.docs) {
        if (doc.id.contains(lowerQuery)) {
          final data = doc.data();
          results[doc.id] = data['price_data'] as Map<String, dynamic>;
        }
      }
      
      return results;
    } catch (e) {
      print('❌ Lỗi tìm kiếm thực phẩm: $e');
      return {};
    }
  }

  /// Lấy tất cả danh mục
  Future<List<String>> getAllCategories() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      final Set<String> categories = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final priceData = data['price_data'] as Map<String, dynamic>;
        if (priceData.containsKey('category')) {
          categories.add(priceData['category'] as String);
        }
      }
      
      final sortedCategories = categories.toList()..sort();
      return sortedCategories;
    } catch (e) {
      print('❌ Lỗi lấy danh mục: $e');
      return [];
    }
  }

  /// Tính toán chi phí ước tính
  Future<double> calculateEstimatedCost(String foodName, double amount) async {
    try {
      final priceData = await getFoodPrice(foodName);
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
    } catch (e) {
      print('❌ Lỗi tính toán chi phí: $e');
      return 0.0;
    }
  }

  /// Lấy thống kê giá cả
  Future<Map<String, dynamic>> getPriceStatistics() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      
      final Map<String, List<double>> categoryPrices = {};
      double totalItems = 0;
      double totalValue = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final priceData = data['price_data'] as Map<String, dynamic>;
        final category = priceData['category'] as String;
        
        double price = 0;
        if (priceData.containsKey('price_per_kg')) {
          price = (priceData['price_per_kg'] as num).toDouble();
        } else if (priceData.containsKey('price_per_liter')) {
          price = (priceData['price_per_liter'] as num).toDouble();
        } else if (priceData.containsKey('price_per_unit')) {
          price = (priceData['price_per_unit'] as num).toDouble();
        }
        
        if (!categoryPrices.containsKey(category)) {
          categoryPrices[category] = [];
        }
        categoryPrices[category]!.add(price);
        totalItems++;
        totalValue += price;
      }
      
      // Tính toán thống kê cho từng danh mục
      final Map<String, Map<String, double>> categoryStats = {};
      categoryPrices.forEach((category, prices) {
        prices.sort();
        final avg = prices.reduce((a, b) => a + b) / prices.length;
        final min = prices.first;
        final max = prices.last;
        final median = prices.length % 2 == 0
            ? (prices[prices.length ~/ 2 - 1] + prices[prices.length ~/ 2]) / 2
            : prices[prices.length ~/ 2];
            
        categoryStats[category] = {
          'average': avg,
          'min': min,
          'max': max,
          'median': median,
          'count': prices.length.toDouble(),
        };
      });
      
      return {
        'total_items': totalItems,
        'total_value': totalValue,
        'average_price': totalItems > 0 ? totalValue / totalItems : 0,
        'category_stats': categoryStats,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Lỗi lấy thống kê: $e');
      return {};
    }
  }

  /// Stream để theo dõi thay đổi giá cả real-time
  Stream<Map<String, Map<String, dynamic>>> watchPriceChanges() {
    return _firestore
        .collection(_collectionName)
        .snapshots()
        .map((snapshot) {
      final Map<String, Map<String, dynamic>> prices = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        prices[doc.id] = data['price_data'] as Map<String, dynamic>;
      }
      return prices;
    });
  }

  /// Thêm thực phẩm mới
  Future<void> addNewFood(String foodName, Map<String, dynamic> priceData) async {
    try {
      await _firestore.collection(_collectionName).doc(foodName.toLowerCase()).set({
        'name': foodName,
        'price_data': priceData,
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp(),
      });
      
      print('✅ Đã thêm thực phẩm mới: $foodName');
    } catch (e) {
      print('❌ Lỗi thêm thực phẩm mới: $e');
      rethrow;
    }
  }

  /// Xóa thực phẩm
  Future<void> deleteFood(String foodName) async {
    try {
      await _firestore.collection(_collectionName).doc(foodName.toLowerCase()).delete();
      print('✅ Đã xóa thực phẩm: $foodName');
    } catch (e) {
      print('❌ Lỗi xóa thực phẩm: $e');
      rethrow;
    }
  }

  /// Đóng góp giá cả từ người dùng
  Future<void> submitUserPriceContribution({
    required String foodName,
    required double price,
    required String priceType, // 'price_per_kg', 'price_per_liter', 'price_per_unit'
    required String location,
    required String storeName,
    String? userId,
    String? userName,
    String? photoUrl,
  }) async {
    try {
      await _firestore.collection('user_price_contributions').add({
        'food_name': foodName.toLowerCase(),
        'price': price,
        'price_type': priceType,
        'location': location,
        'store_name': storeName,
        'user_id': userId,
        'user_name': userName,
        'photo_url': photoUrl,
        'submitted_at': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, approved, rejected
        'votes': 0,
        'verified': false,
      });

      print('✅ Đã gửi đóng góp giá cả cho $foodName');
    } catch (e) {
      print('❌ Lỗi gửi đóng góp: $e');
      rethrow;
    }
  }

  /// Lấy đóng góp giá cả từ người dùng
  Future<List<Map<String, dynamic>>> getUserPriceContributions({
    String? foodName,
    String? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('user_price_contributions');

      if (foodName != null) {
        query = query.where('food_name', isEqualTo: foodName.toLowerCase());
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('submitted_at', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      print('❌ Lỗi lấy đóng góp người dùng: $e');
      return [];
    }
  }

  /// Vote cho đóng góp giá cả
  Future<void> voteForPriceContribution(String contributionId, bool isUpvote) async {
    try {
      final docRef = _firestore.collection('user_price_contributions').doc(contributionId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          final currentVotes = doc.data()!['votes'] as int? ?? 0;
          transaction.update(docRef, {
            'votes': currentVotes + (isUpvote ? 1 : -1),
          });
        }
      });

      print('✅ Đã vote cho đóng góp');
    } catch (e) {
      print('❌ Lỗi vote: $e');
      rethrow;
    }
  }

  /// Phê duyệt đóng góp và cập nhật giá chính thức
  Future<void> approveContribution(String contributionId) async {
    try {
      final contributionDoc = await _firestore
          .collection('user_price_contributions')
          .doc(contributionId)
          .get();

      if (!contributionDoc.exists) {
        throw Exception('Không tìm thấy đóng góp');
      }

      final data = contributionDoc.data()!;
      final foodName = data['food_name'] as String;
      final price = data['price'] as double;
      final priceType = data['price_type'] as String;

      // Cập nhật giá chính thức
      final currentPriceData = await getFoodPrice(foodName);
      if (currentPriceData != null) {
        final updatedPriceData = Map<String, dynamic>.from(currentPriceData);
        updatedPriceData[priceType] = price;
        await updateFoodPrice(foodName, updatedPriceData);
      }

      // Cập nhật status đóng góp
      await _firestore
          .collection('user_price_contributions')
          .doc(contributionId)
          .update({
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
      });

      print('✅ Đã phê duyệt đóng góp và cập nhật giá');
    } catch (e) {
      print('❌ Lỗi phê duyệt đóng góp: $e');
      rethrow;
    }
  }

  /// Lấy lịch sử giá cả
  Future<List<Map<String, dynamic>>> getPriceHistory(String foodName) async {
    try {
      final snapshot = await _firestore
          .collection(_priceHistoryCollection)
          .where('food_name', isEqualTo: foodName.toLowerCase())
          .orderBy('changed_at', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('❌ Lỗi lấy lịch sử giá: $e');
      return [];
    }
  }

  /// Báo cáo giá sai
  Future<void> reportIncorrectPrice({
    required String foodName,
    required String reason,
    required double suggestedPrice,
    String? userId,
    String? userName,
  }) async {
    try {
      await _firestore.collection('price_reports').add({
        'food_name': foodName.toLowerCase(),
        'reason': reason,
        'suggested_price': suggestedPrice,
        'user_id': userId,
        'user_name': userName,
        'reported_at': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('✅ Đã báo cáo giá sai cho $foodName');
    } catch (e) {
      print('❌ Lỗi báo cáo: $e');
      rethrow;
    }
  }
}
