import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grocery_cost_analysis.dart';
import '../screens/grocery_list_screen.dart';

class ShoppingFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection names
  static const String groceryListsCollection = 'grocery_lists';
  static const String costAnalysesCollection = 'cost_analyses';
  static const String shoppingHistoryCollection = 'shopping_history';
  static const String priceTrackingCollection = 'price_tracking';

  // ===== GROCERY LISTS =====
  
  /// Lưu grocery list vào Firestore
  static Future<String> saveGroceryList({
    required String userId,
    required Map<String, GroceryItem> groceryItems,
    String? listName,
  }) async {
    try {
      final docRef = await _firestore.collection(groceryListsCollection).add({
        'user_id': userId,
        'list_name': listName ?? 'Danh sách ${DateTime.now().day}/${DateTime.now().month}',
        'items': groceryItems.map((key, item) => MapEntry(key, {
          'name': item.name,
          'amount': item.amount,
          'unit': item.unit,
          'category': item.category,
          'is_checked': item.isChecked,
        })),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'total_items': groceryItems.length,
        'status': 'active', // active, completed, archived
      });
      
      print('✅ Đã lưu grocery list: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Lỗi lưu grocery list: $e');
      throw Exception('Không thể lưu danh sách mua sắm: $e');
    }
  }

  /// Lấy grocery lists của user
  static Future<List<Map<String, dynamic>>> getUserGroceryLists(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(groceryListsCollection)
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Lỗi lấy grocery lists: $e');
      return [];
    }
  }

  /// Cập nhật grocery list
  static Future<bool> updateGroceryList({
    required String listId,
    required Map<String, GroceryItem> groceryItems,
  }) async {
    try {
      await _firestore.collection(groceryListsCollection).doc(listId).update({
        'items': groceryItems.map((key, item) => MapEntry(key, {
          'name': item.name,
          'amount': item.amount,
          'unit': item.unit,
          'category': item.category,
          'is_checked': item.isChecked,
        })),
        'updated_at': FieldValue.serverTimestamp(),
        'total_items': groceryItems.length,
      });
      
      print('✅ Đã cập nhật grocery list: $listId');
      return true;
    } catch (e) {
      print('❌ Lỗi cập nhật grocery list: $e');
      return false;
    }
  }

  // ===== COST ANALYSES =====
  
  /// Lưu cost analysis vào Firestore
  static Future<String> saveCostAnalysis({
    required String userId,
    required String groceryListId,
    required GroceryCostAnalysis analysis,
  }) async {
    try {
      final docRef = await _firestore.collection(costAnalysesCollection).add({
        'user_id': userId,
        'grocery_list_id': groceryListId,
        'total_cost': analysis.totalCost,
        'average_cost_per_item': analysis.averageCostPerItem,
        'category_breakdown': analysis.categoryBreakdown.map(
          (key, value) => MapEntry(key, value.toJson())
        ),
        'saving_tips': analysis.savingTips.map((tip) => tip.toJson()).toList(),
        'budget_comparison': analysis.budgetComparison.toJson(),
        'price_alerts': analysis.priceAlerts.map((alert) => alert.toJson()).toList(),
        'analysis_date': analysis.analysisDate,
        'created_at': FieldValue.serverTimestamp(),
      });
      
      print('✅ Đã lưu cost analysis: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Lỗi lưu cost analysis: $e');
      throw Exception('Không thể lưu phân tích chi phí: $e');
    }
  }

  /// Lấy cost analyses của user
  static Future<List<GroceryCostAnalysis>> getUserCostAnalyses(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(costAnalysesCollection)
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Xử lý timestamp fields trước khi parse
        final processedData = _processTimestampFields(data);
        return GroceryCostAnalysis.fromJson(processedData);
      }).toList();
    } catch (e) {
      print('❌ Lỗi lấy cost analyses: $e');
      return [];
    }
  }

  /// Xử lý các trường timestamp từ Firestore
  static Map<String, dynamic> _processTimestampFields(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Danh sách các trường có thể là timestamp
    final timestampFields = [
      'created_at',
      'updated_at',
      'analysis_date',
      'recorded_at',
      'last_updated',
    ];

    for (final field in timestampFields) {
      if (result.containsKey(field)) {
        final value = result[field];
        if (value is Timestamp) {
          // Chuyển Timestamp thành ISO string để GroceryCostAnalysis.fromJson có thể parse
          result[field] = value.toDate().toIso8601String();
        }
      }
    }

    return result;
  }

  // ===== SHOPPING HISTORY =====
  
  /// Lưu lịch sử mua sắm
  static Future<String> saveShoppingHistory({
    required String userId,
    required String groceryListId,
    required Map<String, dynamic> purchaseData,
  }) async {
    try {
      final docRef = await _firestore.collection(shoppingHistoryCollection).add({
        'user_id': userId,
        'grocery_list_id': groceryListId,
        'purchase_date': FieldValue.serverTimestamp(),
        'store_name': purchaseData['store_name'],
        'total_amount_paid': purchaseData['total_amount_paid'],
        'items_purchased': purchaseData['items_purchased'],
        'payment_method': purchaseData['payment_method'],
        'receipt_image_url': purchaseData['receipt_image_url'],
        'notes': purchaseData['notes'],
        'created_at': FieldValue.serverTimestamp(),
      });
      
      print('✅ Đã lưu shopping history: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Lỗi lưu shopping history: $e');
      throw Exception('Không thể lưu lịch sử mua sắm: $e');
    }
  }

  // ===== PRICE TRACKING =====
  
  /// Lưu giá sản phẩm để tracking
  static Future<void> trackItemPrice({
    required String itemName,
    required double price,
    required String storeName,
    required String location,
  }) async {
    try {
      await _firestore.collection(priceTrackingCollection).add({
        'item_name': itemName.toLowerCase(),
        'price': price,
        'store_name': storeName,
        'location': location,
        'recorded_at': FieldValue.serverTimestamp(),
        'source': 'user_input', // user_input, api_scraping, manual_update
      });
      
      print('✅ Đã track giá: $itemName - $price VND tại $storeName');
    } catch (e) {
      print('❌ Lỗi track giá: $e');
    }
  }

  /// Lấy lịch sử giá của sản phẩm
  static Future<List<Map<String, dynamic>>> getItemPriceHistory(String itemName) async {
    try {
      final querySnapshot = await _firestore
          .collection(priceTrackingCollection)
          .where('item_name', isEqualTo: itemName.toLowerCase())
          .orderBy('recorded_at', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Lỗi lấy price history: $e');
      return [];
    }
  }

  /// Lấy giá trung bình của sản phẩm
  static Future<double> getAveragePrice(String itemName) async {
    try {
      final priceHistory = await getItemPriceHistory(itemName);
      if (priceHistory.isEmpty) return 0.0;

      final totalPrice = priceHistory.fold<double>(
        0.0, 
        (sum, item) => sum + (item['price'] ?? 0.0)
      );
      
      return totalPrice / priceHistory.length;
    } catch (e) {
      print('❌ Lỗi tính giá trung bình: $e');
      return 0.0;
    }
  }

  // ===== UTILITY METHODS =====
  
  /// Xóa grocery list
  static Future<bool> deleteGroceryList(String listId) async {
    try {
      await _firestore.collection(groceryListsCollection).doc(listId).delete();
      print('✅ Đã xóa grocery list: $listId');
      return true;
    } catch (e) {
      print('❌ Lỗi xóa grocery list: $e');
      return false;
    }
  }

  /// Lấy thống kê mua sắm của user
  static Future<Map<String, dynamic>> getUserShoppingStats(String userId) async {
    try {
      // Lấy tổng số lists
      final listsSnapshot = await _firestore
          .collection(groceryListsCollection)
          .where('user_id', isEqualTo: userId)
          .get();

      // Lấy tổng chi phí
      final analysesSnapshot = await _firestore
          .collection(costAnalysesCollection)
          .where('user_id', isEqualTo: userId)
          .get();

      double totalSpent = 0.0;
      for (final doc in analysesSnapshot.docs) {
        totalSpent += (doc.data()['total_cost'] ?? 0.0);
      }

      return {
        'total_lists': listsSnapshot.docs.length,
        'total_analyses': analysesSnapshot.docs.length,
        'total_spent': totalSpent,
        'average_per_list': listsSnapshot.docs.isNotEmpty ? totalSpent / listsSnapshot.docs.length : 0.0,
      };
    } catch (e) {
      print('❌ Lỗi lấy shopping stats: $e');
      return {
        'total_lists': 0,
        'total_analyses': 0,
        'total_spent': 0.0,
        'average_per_list': 0.0,
      };
    }
  }
}
