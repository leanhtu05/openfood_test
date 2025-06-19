import 'package:flutter/material.dart';
import '../services/vietnamese_food_price_service.dart';
import '../models/grocery_cost_analysis.dart';
import 'price_contribution_screen.dart';
import 'community_contributions_screen.dart';
import 'price_report_screen.dart';

class FoodPriceManagementScreen extends StatefulWidget {
  const FoodPriceManagementScreen({Key? key}) : super(key: key);

  @override
  State<FoodPriceManagementScreen> createState() => _FoodPriceManagementScreenState();
}

class _FoodPriceManagementScreenState extends State<FoodPriceManagementScreen> {
  final VietnameseFoodPriceService _priceService = VietnameseFoodPriceService();
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, Map<String, dynamic>> _allPrices = {};
  Map<String, Map<String, dynamic>> _filteredPrices = {};
  List<String> _categories = [];
  String _selectedCategory = 'Tất cả';
  bool _isLoading = true;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final prices = await _priceService.getAllPrices();
      final categories = await _priceService.getAllCategories();
      
      setState(() {
        _allPrices = prices;
        _filteredPrices = prices;
        _categories = ['Tất cả', ...categories];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Lỗi tải dữ liệu: $e');
    }
  }

  Future<void> _initializeData() async {
    setState(() => _isInitializing = true);
    
    try {
      await _priceService.initializePriceData();
      _showSuccessSnackBar('Đã khởi tạo dữ liệu thành công!');
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Lỗi khởi tạo dữ liệu: $e');
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  void _filterPrices() {
    String query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredPrices = Map.fromEntries(
        _allPrices.entries.where((entry) {
          final matchesSearch = query.isEmpty || entry.key.contains(query);
          final matchesCategory = _selectedCategory == 'Tất cả' || 
              entry.value['category'] == _selectedCategory;
          return matchesSearch && matchesCategory;
        })
      );
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatPrice(Map<String, dynamic> priceData) {
    if (priceData.containsKey('price_per_kg')) {
      return '${_formatCurrency(priceData['price_per_kg'])}/kg';
    } else if (priceData.containsKey('price_per_liter')) {
      return '${_formatCurrency(priceData['price_per_liter'])}/lít';
    } else if (priceData.containsKey('price_per_unit')) {
      return '${_formatCurrency(priceData['price_per_unit'])}/${priceData['unit']}';
    }
    return 'N/A';
  }

  String _formatCurrency(dynamic amount) {
    final number = (amount as num).toDouble();
    return '${number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý giá cả thực phẩm'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'init') {
                _initializeData();
              } else if (value == 'stats') {
                _showStatistics();
              } else if (value == 'community') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CommunityContributionsScreen(),
                  ),
                );
              } else if (value == 'contribute') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PriceContributionScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'init',
                child: Text('Khởi tạo dữ liệu'),
              ),
              const PopupMenuItem(
                value: 'stats',
                child: Text('Xem thống kê'),
              ),
              const PopupMenuItem(
                value: 'community',
                child: Text('Đóng góp cộng đồng'),
              ),
              const PopupMenuItem(
                value: 'contribute',
                child: Text('Đóng góp giá mới'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm thực phẩm...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => _filterPrices(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                    _filterPrices();
                  },
                ),
              ],
            ),
          ),
          
          // Results Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPrices.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Không tìm thấy thực phẩm nào',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredPrices.length,
                        itemBuilder: (context, index) {
                          final entry = _filteredPrices.entries.elementAt(index);
                          final foodName = entry.key;
                          final priceData = entry.value;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green[100],
                                child: Text(
                                  foodName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                foodName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(priceData['category'] ?? ''),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatPrice(priceData),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    priceData['unit'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _showFoodDetails(foodName, priceData),
                              onLongPress: () => _showFoodActions(foodName, priceData),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _isInitializing
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: _addNewFood,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  void _showFoodDetails(String foodName, Map<String, dynamic> priceData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(foodName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Danh mục', priceData['category'] ?? 'N/A'),
            _buildDetailRow('Đơn vị', priceData['unit'] ?? 'N/A'),
            _buildDetailRow('Giá', _formatPrice(priceData)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reportPrice(foodName, priceData);
            },
            child: const Text('Báo cáo sai'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _contributePrice(foodName);
            },
            child: const Text('Đóng góp giá'),
          ),
        ],
      ),
    );
  }

  void _showFoodActions(String foodName, Map<String, dynamic> priceData) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              foodName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.blue),
              title: const Text('Xem chi tiết'),
              onTap: () {
                Navigator.pop(context);
                _showFoodDetails(foodName, priceData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.green),
              title: const Text('Đóng góp giá mới'),
              onTap: () {
                Navigator.pop(context);
                _contributePrice(foodName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Báo cáo giá sai'),
              onTap: () {
                Navigator.pop(context);
                _reportPrice(foodName, priceData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.orange),
              title: const Text('Xem lịch sử giá'),
              onTap: () {
                Navigator.pop(context);
                _showPriceHistory(foodName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _addNewFood() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PriceContributionScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  void _contributePrice(String foodName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PriceContributionScreen(initialFoodName: foodName),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  void _reportPrice(String foodName, Map<String, dynamic> priceData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PriceReportScreen(
          foodName: foodName,
          currentPriceData: priceData,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  void _showPriceHistory(String foodName) async {
    try {
      final history = await _priceService.getPriceHistory(foodName);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Lịch sử giá: $foodName'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: history.isEmpty
                ? const Center(child: Text('Chưa có lịch sử thay đổi giá'))
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];
                      final priceData = record['price_data'] as Map<String, dynamic>;
                      final changedAt = record['changed_at'];

                      return ListTile(
                        title: Text(_formatPrice(priceData)),
                        subtitle: Text(_formatDateTime(changedAt)),
                        leading: const Icon(Icons.history),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Lỗi tải lịch sử: $e');
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dateTime = timestamp.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showStatistics() async {
    try {
      final stats = await _priceService.getPriceStatistics();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thống kê giá cả'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng số mặt hàng: ${stats['total_items']?.toInt() ?? 0}'),
                Text('Giá trung bình: ${_formatCurrency(stats['average_price'] ?? 0)}'),
                const SizedBox(height: 16),
                const Text('Thống kê theo danh mục:', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...((stats['category_stats'] as Map<String, dynamic>? ?? {})
                    .entries.map((entry) {
                  final categoryStats = entry.value as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${entry.key}: ${categoryStats['count']?.toInt() ?? 0} mặt hàng',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Lỗi lấy thống kê: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
