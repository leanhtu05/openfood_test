import 'package:flutter/material.dart';
import '../services/finance_agent_service.dart';
import '../models/grocery_cost_analysis.dart';
import '../widgets/grocery/cost_analysis_widget.dart';
import '../screens/grocery_list_screen.dart';

class FinanceAgentDemoScreen extends StatefulWidget {
  @override
  _FinanceAgentDemoScreenState createState() => _FinanceAgentDemoScreenState();
}

class _FinanceAgentDemoScreenState extends State<FinanceAgentDemoScreen> {
  GroceryCostAnalysis? _analysis;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runDemo();
  }

  Future<void> _runDemo() async {
    setState(() {
      _isLoading = true;
    });

    // Tạo dữ liệu demo
    final demoGroceryItems = <String, GroceryItem>{
      'thịt bò': GroceryItem(
        name: 'Thịt bò',
        amount: '500',
        unit: 'g',
        category: '🥩 Thịt tươi sống',
      ),
      'cà chua': GroceryItem(
        name: 'Cà chua',
        amount: '300',
        unit: 'g',
        category: '🥬 Rau củ quả',
      ),
      'hành tây': GroceryItem(
        name: 'Hành tây',
        amount: '200',
        unit: 'g',
        category: '🥬 Rau củ quả',
      ),
      'gạo': GroceryItem(
        name: 'Gạo',
        amount: '1',
        unit: 'kg',
        category: '🌾 Thực phẩm khô',
      ),
      'trứng gà': GroceryItem(
        name: 'Trứng gà',
        amount: '6',
        unit: 'quả',
        category: '🥛 Sản phẩm từ sữa',
      ),
      'dầu oliu': GroceryItem(
        name: 'Dầu oliu',
        amount: '3',
        unit: 'muỗng canh',
        category: '🧂 Gia vị & Nước chấm',
      ),
      'phô mai': GroceryItem(
        name: 'Phô mai',
        amount: '100',
        unit: 'g',
        category: '🥛 Sản phẩm từ sữa',
      ),
      'chuối': GroceryItem(
        name: 'Chuối',
        amount: '1',
        unit: 'kg',
        category: '🥬 Rau củ quả',
      ),
    };

    try {
      final analysis = await FinanceAgentService.analyzeCosts(
        demoGroceryItems,
        budgetLimit: 300000, // 300k VND
      );

      setState(() {
        _analysis = analysis;
        _isLoading = false;
      });
    } catch (e) {
      print('Lỗi demo: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '💲 AI Finance Agent Demo',
          style: TextStyle(
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.green.shade800),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _runDemo,
            tooltip: 'Chạy lại demo',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'AI đang phân tích chi phí...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : _analysis == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Không thể tải phân tích',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _runDemo,
                        child: Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.all(16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade50, Colors.green.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.green.shade600),
                                SizedBox(width: 8),
                                Text(
                                  'Demo AI Finance Agent',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Đây là demo tính năng phân tích chi phí thực phẩm bằng AI. '
                              'Hệ thống sử dụng dữ liệu giá cả thực tế tại Việt Nam để ước tính chi phí và đưa ra lời khuyên tối ưu ngân sách.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CostAnalysisWidget(
                        analysis: _analysis!,
                        onBudgetTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tính năng cập nhật ngân sách sẽ được triển khai trong phiên bản đầy đủ'),
                              backgroundColor: Colors.blue.shade600,
                            ),
                          );
                        },
                      ),
                      Container(
                        margin: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🛒 Danh sách mua sắm demo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildDemoGroceryList(),
                          ],
                        ),
                      ),
                      SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
      floatingActionButton: _analysis != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroceryListScreen(),
                  ),
                );
              },
              backgroundColor: Colors.green.shade600,
              icon: Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                'Xem danh sách thực tế',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildDemoGroceryList() {
    final demoItems = [
      {'name': 'Thịt bò', 'amount': '500g', 'cost': '175,000₫'},
      {'name': 'Cà chua', 'amount': '300g', 'cost': '7,500₫'},
      {'name': 'Hành tây', 'amount': '200g', 'cost': '4,000₫'},
      {'name': 'Gạo', 'amount': '1kg', 'cost': '25,000₫'},
      {'name': 'Trứng gà', 'amount': '6 quả', 'cost': '24,000₫'},
      {'name': 'Dầu oliu', 'amount': '3 muỗng canh', 'cost': '6,750₫'},
      {'name': 'Phô mai', 'amount': '100g', 'cost': '20,000₫'},
      {'name': 'Chuối', 'amount': '1kg', 'cost': '25,000₫'},
    ];

    return Column(
      children: demoItems.map((item) {
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      item['amount']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                item['cost']!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
