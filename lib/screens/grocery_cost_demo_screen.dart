import 'package:flutter/material.dart';
import '../models/grocery_cost_analysis.dart';
import '../utils/grocery_cost_calculator.dart';
import '../services/vietnamese_food_price_service.dart';

class GroceryCostDemoScreen extends StatefulWidget {
  const GroceryCostDemoScreen({Key? key}) : super(key: key);

  @override
  State<GroceryCostDemoScreen> createState() => _GroceryCostDemoScreenState();
}

class _GroceryCostDemoScreenState extends State<GroceryCostDemoScreen> {
  final GroceryCostCalculator _calculator = GroceryCostCalculator();
  final VietnameseFoodPriceService _priceService = VietnameseFoodPriceService();
  
  GroceryCostAnalysis? _analysis;
  bool _isLoading = false;
  bool _isInitializing = false;
  
  // Sample grocery list
  final List<GroceryItemWithCost> _sampleGroceryList = [
    GroceryItemWithCost(
      name: 'thịt bò',
      amount: '1',
      unit: 'kg',
      category: '🥩 Thịt tươi sống',
      estimatedCost: 350000,
      pricePerUnit: 350000,
    ),
    GroceryItemWithCost(
      name: 'cà chua',
      amount: '2',
      unit: 'kg',
      category: '🥬 Rau củ quả',
      estimatedCost: 50000,
      pricePerUnit: 25000,
    ),
    GroceryItemWithCost(
      name: 'gạo tẻ',
      amount: '5',
      unit: 'kg',
      category: '🌾 Ngũ cốc & Gạo',
      estimatedCost: 90000,
      pricePerUnit: 18000,
    ),
    GroceryItemWithCost(
      name: 'tôm sú',
      amount: '0.5',
      unit: 'kg',
      category: '🐟 Hải sản',
      estimatedCost: 200000,
      pricePerUnit: 400000,
    ),
    GroceryItemWithCost(
      name: 'trứng gà',
      amount: '10',
      unit: 'quả',
      category: '🥛 Sữa & Trứng',
      estimatedCost: 40000,
      pricePerUnit: 4000,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _calculateAnalysis();
  }

  Future<void> _initializeFirebaseData() async {
    setState(() => _isInitializing = true);
    
    try {
      await _priceService.initializePriceData();
      _showSuccessSnackBar('✅ Đã khởi tạo dữ liệu giá cả lên Firebase thành công!');
      await _calculateAnalysis(); // Recalculate with Firebase data
    } catch (e) {
      _showErrorSnackBar('❌ Lỗi khởi tạo dữ liệu: $e');
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _calculateAnalysis() async {
    setState(() => _isLoading = true);
    
    try {
      final analysis = await _calculator.calculateCostAnalysis(
        groceryItems: _sampleGroceryList,
        budgetLimit: 500000, // 500k VND budget
      );
      
      setState(() {
        _analysis = analysis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('❌ Lỗi tính toán phân tích: $e');
    }
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

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Phân tích Chi phí Grocery'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _calculateAnalysis,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _isInitializing ? null : _initializeFirebaseData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analysis == null
              ? const Center(child: Text('Không có dữ liệu phân tích'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Initialize Firebase Button
                      if (_isInitializing)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 16),
                                Text('Đang khởi tạo dữ liệu lên Firebase...'),
                              ],
                            ),
                          ),
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Khởi tạo dữ liệu Firebase',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Nhấn nút bên dưới để tải dữ liệu giá cả thực phẩm Việt Nam lên Firebase',
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _initializeFirebaseData,
                                  icon: const Icon(Icons.cloud_upload),
                                  label: const Text('Khởi tạo dữ liệu Firebase'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Grocery List
                      _buildGroceryListCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Cost Summary
                      _buildCostSummaryCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Budget Comparison
                      _buildBudgetComparisonCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Category Breakdown
                      _buildCategoryBreakdownCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Saving Tips
                      _buildSavingTipsCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Price Alerts
                      _buildPriceAlertsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGroceryListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Danh sách Grocery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...(_sampleGroceryList.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${item.name} (${item.amount} ${item.unit})'),
                  ),
                  Text(
                    _formatCurrency(item.estimatedCost),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng quan Chi phí',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng chi phí:'),
                Text(
                  _formatCurrency(_analysis!.totalCost),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chi phí trung bình/mặt hàng:'),
                Text(_formatCurrency(_analysis!.averageCostPerItem)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetComparisonCard() {
    final budget = _analysis!.budgetComparison;
    final isOverBudget = budget.isOverBudget;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'So sánh Ngân sách',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ngân sách:'),
                Text(_formatCurrency(budget.budgetLimit)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chi tiêu thực tế:'),
                Text(
                  _formatCurrency(budget.actualCost),
                  style: TextStyle(
                    color: isOverBudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isOverBudget ? 'Vượt ngân sách:' : 'Còn lại:'),
                Text(
                  _formatCurrency(budget.difference.abs()),
                  style: TextStyle(
                    color: isOverBudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: budget.percentageUsed / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverBudget ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${budget.percentageUsed.toStringAsFixed(1)}% ngân sách đã sử dụng',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phân tích theo Danh mục',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...(_analysis!.categoryBreakdown.entries.map((entry) {
              final category = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(category.categoryName)),
                        Text(
                          _formatCurrency(category.totalCost),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: category.percentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${category.percentage.toStringAsFixed(1)}% - ${category.itemCount} mặt hàng',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingTipsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mẹo Tiết kiệm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...(_analysis!.savingTips.map((tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Tiết kiệm: ${_formatCurrency(tip.potentialSaving)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(tip.description),
                  ],
                ),
              ),
            )).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAlertsCard() {
    if (_analysis!.priceAlerts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cảnh báo Giá cả',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('Không có cảnh báo giá cả nào.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cảnh báo Giá cả',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...(_analysis!.priceAlerts.map((alert) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: alert.alertType == 'high' 
                      ? Colors.red[50] 
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: alert.alertType == 'high' 
                        ? Colors.red[200]! 
                        : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      alert.alertType == 'high' 
                          ? Icons.warning 
                          : Icons.info,
                      color: alert.alertType == 'high' 
                          ? Colors.red[700] 
                          : Colors.orange[700],
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(alert.message)),
                  ],
                ),
              ),
            )).toList()),
          ],
        ),
      ),
    );
  }
}
