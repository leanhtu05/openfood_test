import 'package:flutter/material.dart';
import '../services/price_ai_analysis_service.dart';
import '../models/grocery_cost_analysis.dart';

class AIGroceryOptimizerScreen extends StatefulWidget {
  final List<GroceryItemWithCost>? initialGroceryList;
  
  const AIGroceryOptimizerScreen({Key? key, this.initialGroceryList}) : super(key: key);

  @override
  State<AIGroceryOptimizerScreen> createState() => _AIGroceryOptimizerScreenState();
}

class _AIGroceryOptimizerScreenState extends State<AIGroceryOptimizerScreen> {
  final PriceAIAnalysisService _aiService = PriceAIAnalysisService();
  
  List<GroceryItemWithCost> _groceryItems = [];
  bool _isOptimizing = false;
  Map<String, dynamic>? _optimization;
  
  final _itemNameController = TextEditingController();
  final _itemAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialGroceryList != null) {
      _groceryItems = List.from(widget.initialGroceryList!);
    } else {
      _addSampleItems();
    }
  }

  void _addSampleItems() {
    _groceryItems = [
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
    ];
  }

  Future<void> _optimizeGroceryList() async {
    if (_groceryItems.isEmpty) {
      _showErrorSnackBar('Vui lòng thêm ít nhất một mặt hàng');
      return;
    }
    
    setState(() => _isOptimizing = true);
    
    try {
      final groceryData = _groceryItems.map((item) => {
        'name': item.name,
        'amount': item.amount,
        'unit': item.unit,
        'category': item.category,
        'estimated_cost': item.estimatedCost,
        'price_per_unit': item.pricePerUnit,
      }).toList();
      
      final optimization = await _aiService.analyzeGroceryListIntelligently(groceryData);
      
      setState(() {
        _optimization = optimization;
        _isOptimizing = false;
      });
    } catch (e) {
      setState(() => _isOptimizing = false);
      _showErrorSnackBar('Lỗi tối ưu hóa: $e');
    }
  }

  void _addItem() {
    if (_itemNameController.text.trim().isEmpty || _itemAmountController.text.trim().isEmpty) {
      _showErrorSnackBar('Vui lòng nhập đầy đủ thông tin');
      return;
    }
    
    final newItem = GroceryItemWithCost(
      name: _itemNameController.text.trim(),
      amount: _itemAmountController.text.trim(),
      unit: 'kg',
      category: 'Khác',
      estimatedCost: 0,
      pricePerUnit: 0,
    );
    
    setState(() {
      _groceryItems.add(newItem);
      _itemNameController.clear();
      _itemAmountController.clear();
      _optimization = null; // Clear previous optimization
    });
  }

  void _removeItem(int index) {
    setState(() {
      _groceryItems.removeAt(index);
      _optimization = null; // Clear previous optimization
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        title: const Text('AI Tối ưu Grocery'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: _groceryItems.isNotEmpty && !_isOptimizing ? _optimizeGroceryList : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              color: Colors.teal[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.smart_toy, color: Colors.teal[700], size: 32),
                        const SizedBox(width: 12),
                        const Text(
                          'AI Tối ưu Grocery',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI sẽ phân tích danh sách và đưa ra gợi ý tối ưu hóa chi phí, dinh dưỡng và thời gian mua sắm',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Add Item Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thêm mặt hàng',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _itemNameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên thực phẩm',
                              hintText: 'VD: thịt bò, cà chua',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _itemAmountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số lượng',
                              hintText: '1',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Grocery List
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Danh sách Grocery',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${_groceryItems.length} mặt hàng',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_groceryItems.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Chưa có mặt hàng nào\nThêm mặt hàng để bắt đầu tối ưu hóa',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...(_groceryItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(item.name),
                            subtitle: Text('${item.amount} ${item.unit}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.estimatedCost > 0)
                                  Text(
                                    _formatCurrency(item.estimatedCost),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      })),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Optimize Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _groceryItems.isNotEmpty && !_isOptimizing ? _optimizeGroceryList : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isOptimizing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('AI đang tối ưu hóa...'),
                        ],
                      )
                    : const Text(
                        'Tối ưu hóa với AI',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Optimization Results
            if (_optimization != null) _buildOptimizationResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizationResults() {
    final optimization = _optimization!;
    final optimizations = optimization['optimization_suggestions'] as List? ?? [];
    final substitutions = optimization['substitution_recommendations'] as Map<String, dynamic>? ?? {};
    final timing = optimization['timing_advice'] ?? '';
    final budget = optimization['budget_optimization'] ?? '';
    final health = optimization['health_insights'] ?? '';
    final sustainability = optimization['sustainability_tips'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.psychology, color: Colors.teal[700]),
            const SizedBox(width: 8),
            const Text(
              'Kết quả Tối ưu hóa AI',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Optimization Suggestions
        if (optimizations.isNotEmpty) ...[
          _buildOptimizationCard(
            'Tối ưu Chi phí',
            optimizations,
            Icons.savings,
            Colors.green,
          ),
          const SizedBox(height: 12),
        ],
        
        // Substitutions
        if (substitutions.isNotEmpty) ...[
          _buildSubstitutionCard(substitutions),
          const SizedBox(height: 12),
        ],
        
        // Timing Advice
        if (timing.isNotEmpty) ...[
          _buildAdviceCard(
            'Thời điểm Mua sắm',
            timing,
            Icons.schedule,
            Colors.blue,
          ),
          const SizedBox(height: 12),
        ],
        
        // Budget Optimization
        if (budget.isNotEmpty) ...[
          _buildAdviceCard(
            'Tối ưu Ngân sách',
            budget,
            Icons.account_balance_wallet,
            Colors.orange,
          ),
          const SizedBox(height: 12),
        ],
        
        // Health Insights
        if (health.isNotEmpty) ...[
          _buildAdviceCard(
            'Insights Dinh dưỡng',
            health,
            Icons.health_and_safety,
            Colors.red,
          ),
          const SizedBox(height: 12),
        ],
        
        // Sustainability
        if (sustainability.isNotEmpty) ...[
          _buildAdviceCard(
            'Bền vững Môi trường',
            sustainability,
            Icons.eco,
            Colors.green,
          ),
        ],
      ],
    );
  }

  Widget _buildOptimizationCard(
    String title,
    List optimizations,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...optimizations.map((opt) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb, size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(opt.toString())),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSubstitutionCard(Map<String, dynamic> substitutions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Text(
                  'Gợi ý Thay thế',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...substitutions.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(entry.key),
                  ),
                  const Icon(Icons.arrow_forward, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAdviceCard(
    String title,
    String advice,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemAmountController.dispose();
    super.dispose();
  }
}
