
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meal_plan.dart';
import '../providers/meal_plan_provider.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/finance_agent_service.dart';
import '../models/grocery_cost_analysis.dart';
import '../widgets/grocery/cost_analysis_widget.dart';
import '../utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';

class GroceryListScreen extends StatefulWidget {
  @override
  _GroceryListScreenState createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> with TickerProviderStateMixin {
  Map<String, bool> _checkedItems = {};
  Map<String, GroceryItem> _groceryItems = {};
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _collapsedCategories = {}; // Các category bị thu gọn
  late AnimationController _animationController;

  // AI Finance Agent variables
  GroceryCostAnalysis? _costAnalysis;
  bool _isAnalyzing = false;
  bool _showCostAnalysis = false;
  double _budgetLimit = 500000; // Mặc định 500k VND

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    // Tải dữ liệu sau khi widget được build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMealPlanAndGenerateList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMealPlanAndGenerateList() async {
    final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);

    // Lấy user ID hiện tại
    final user = FirebaseAuth.instance.currentUser;
    print('👤 Current user ID: ${user?.uid}');

    // Nếu chưa có meal plan, thử tải từ Firebase
    if (mealPlanProvider.currentMealPlan == null) {
      print('🔄 Không có meal plan, đang tải từ Firebase...');

      if (user != null) {
        await mealPlanProvider.loadCurrentMealPlanFromFirebase(user.uid);
      } else {
        print('❌ Không có user đăng nhập');
      }
    } else {
      print('✅ Đã có meal plan trong provider');
    }

    // Tạo grocery list
    _generateGroceryList();

    // Phân tích chi phí với AI Finance Agent
    _analyzeCosts();
  }

  void _generateGroceryList() {
    final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);
    final currentMealPlan = mealPlanProvider.currentMealPlan;

    if (currentMealPlan != null) {
      print('✅ Đã tìm thấy meal plan với ${currentMealPlan.weeklyPlan.length} ngày');
      _groceryItems = _aggregateIngredients(currentMealPlan);
      // Khởi tạo trạng thái checked cho tất cả items
      _checkedItems = Map.fromIterable(
        _groceryItems.keys,
        key: (item) => item,
        value: (item) => false,
      );
      print('✅ Đã tạo ${_groceryItems.length} nguyên liệu trong grocery list');
    } else {
      print('❌ Không tìm thấy meal plan');
      _groceryItems = {};
      _checkedItems = {};
    }

    // Cập nhật UI
    setState(() {});

    // Phân tích chi phí sau khi tạo grocery list
    if (_groceryItems.isNotEmpty) {
      _analyzeCosts();
    }
  }

  Map<String, GroceryItem> _aggregateIngredients(MealPlan mealPlan) {
    final Map<String, GroceryItem> groceryList = {};

    print('🔍 Bắt đầu xử lý meal plan với ${mealPlan.weeklyPlan.length} ngày');

    // Chỉ lấy kế hoạch cho hôm nay và ngày mai (2 ngày)
    final today = DateTime.now();
    final tomorrow = today.add(Duration(days: 1));

    final daysToProcess = [
      _getDayOfWeekString(today.weekday),
      _getDayOfWeekString(tomorrow.weekday),
    ];

    print('📅 Chỉ xử lý 2 ngày: ${daysToProcess.join(", ")}');

    mealPlan.weeklyPlan.forEach((dayName, dayPlan) {
      // Chỉ xử lý những ngày trong danh sách (case insensitive)
      final dayNameLower = dayName.toLowerCase();
      final shouldProcess = daysToProcess.any((day) => day.toLowerCase() == dayNameLower);

      print('🔍 Debug: dayName="$dayName", dayNameLower="$dayNameLower"');
      print('🔍 Debug: daysToProcess=$daysToProcess');
      print('🔍 Debug: shouldProcess=$shouldProcess');

      if (!shouldProcess) {
        print('⏭️ Bỏ qua ngày: $dayName');
        return;
      }

      print('📅 ✅ XỬ LÝ NGÀY: $dayName');

      // Xử lý từng bữa ăn trong ngày
      dayPlan.meals.forEach((mealType, mealsList) {
        print('🍽️ Xử lý bữa: $mealType với ${mealsList.length} món');

        mealsList.forEach((meal) {
          meal.dishes.forEach((dish) {
            print('🍲 Xử lý món: ${dish.name}');

            // Kiểm tra xem có ingredients không (từ Firebase)
            if (dish.ingredients.isNotEmpty) {
              print('📝 Tìm thấy ${dish.ingredients.length} ingredients từ Firebase');

              // Xử lý ingredients từ Firebase (có thể là String hoặc Map)
              dish.ingredients.forEach((ingredient) {
                String name = '';
                String amount = '1';
                String unit = '';

                if (ingredient is Map<String, dynamic>) {
                } else if (ingredient is String) {
                  // Ingredients cũ dạng string
                  name = ingredient;
                  amount = '1';
                  print('📦 String ingredient: $name');
                } else {
                  print('⚠️ Unknown ingredient type: ${ingredient.runtimeType}');
                  return;
                }

                if (name.isNotEmpty) {
                  final key = name.toLowerCase();
                  if (groceryList.containsKey(key)) {
                    groceryList[key] = groceryList[key]!.copyWith(
                      amount: _combineAmounts(groceryList[key]!.amount, amount),
                    );
                    print('➕ Cộng dồn: $name = ${groceryList[key]!.amount}');
                  } else {
                    groceryList[key] = GroceryItem(
                      name: name,
                      amount: amount,
                      unit: unit,
                      category: _categorizeIngredient(name),
                    );
                    print('🆕 Thêm mới: $name = $amount $unit');
                  }
                }
              });
            }

            // Kiểm tra detailedIngredients nếu có
            if (dish.detailedIngredients.isNotEmpty) {
              print('📝 Tìm thấy ${dish.detailedIngredients.length} detailedIngredients');

              dish.detailedIngredients.forEach((ingredient) {
                final key = ingredient.name.toLowerCase();
                if (groceryList.containsKey(key)) {
                  groceryList[key] = groceryList[key]!.copyWith(
                    amount: _combineAmounts(groceryList[key]!.amount, ingredient.amount),
                  );
                  print('➕ Cộng dồn (detailed): ${ingredient.name} = ${groceryList[key]!.amount}');
                } else {
                  groceryList[key] = GroceryItem(
                    name: ingredient.name,
                    amount: ingredient.amount,
                    unit: ingredient.unit ?? '',
                    category: ingredient.category ?? _categorizeIngredient(ingredient.name),
                  );
                  print('🆕 Thêm mới (detailed): ${ingredient.name} = ${ingredient.amount} ${ingredient.unit}');
                }
              });
            }
          });
        });
      });
    });

    print('✅ Hoàn thành xử lý, tổng cộng ${groceryList.length} nguyên liệu cho 2 ngày (hôm nay + ngày mai)');
    return groceryList;
  }

  void _createTestMealPlan() {
    print('🧪 Tạo meal plan test với dữ liệu mẫu...');

    // Tạo dữ liệu test dựa trên cấu trúc Firebase
    final testGroceryItems = <String, GroceryItem>{
      'ớt chuông': GroceryItem(
        name: 'Ớt chuông',
        amount: '50',
        unit: 'g',
        category: 'Rau củ',
      ),
      'hành tây': GroceryItem(
        name: 'Hành tây',
        amount: '80',
        unit: 'g',
        category: 'Rau củ',
      ),
      'cà chua': GroceryItem(
        name: 'Cà chua',
        amount: '100',
        unit: 'g',
        category: 'Rau củ',
      ),
      'phô mai': GroceryItem(
        name: 'Phô mai',
        amount: '30',
        unit: 'g',
        category: 'Sữa và chế phẩm',
      ),
      'bí đỏ': GroceryItem(
        name: 'Bí đỏ',
        amount: '200',
        unit: 'g',
        category: 'Rau củ',
      ),
      'thịt bò': GroceryItem(
        name: 'Thịt bò',
        amount: '200',
        unit: 'g',
        category: 'Thịt',
      ),
      'bánh mì': GroceryItem(
        name: 'Bánh mì',
        amount: '2',
        unit: 'lát',
        category: 'Ngũ cốc',
      ),
      'trứng gà': GroceryItem(
        name: 'Trứng gà',
        amount: '4',
        unit: 'quả',
        category: 'Trứng',
      ),
      'dầu oliu': GroceryItem(
        name: 'Dầu oliu',
        amount: '2',
        unit: 'muỗng canh',
        category: 'Dầu ăn',
      ),
      'rau xà lách': GroceryItem(
        name: 'Rau xà lách',
        amount: '120',
        unit: 'g',
        category: 'Rau củ',
      ),
      'chuối': GroceryItem(
        name: 'Chuối',
        amount: '2',
        unit: 'quả',
        category: 'Trái cây',
      ),
      'sữa chua hy lạp': GroceryItem(
        name: 'Sữa chua Hy Lạp',
        amount: '100',
        unit: 'g',
        category: 'Sữa và chế phẩm',
      ),
      'yến mạch': GroceryItem(
        name: 'Yến mạch',
        amount: '50',
        unit: 'g',
        category: 'Ngũ cốc',
      ),
      'mật ong': GroceryItem(
        name: 'Mật ong',
        amount: '2',
        unit: 'muỗng canh',
        category: 'Gia vị',
      ),
    };

    setState(() {
      _groceryItems = testGroceryItems;
      _checkedItems = Map.fromIterable(
        _groceryItems.keys,
        key: (item) => item,
        value: (item) => false,
      );
    });

    print('✅ Đã tạo ${_groceryItems.length} nguyên liệu test');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã tạo danh sách mua sắm test với ${_groceryItems.length} nguyên liệu!'),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _combineAmounts(String amount1, String amount2) {
    // Thử parse số từ chuỗi
    final num1 = double.tryParse(amount1.replaceAll(RegExp(r'[^0-9.]'), ''));
    final num2 = double.tryParse(amount2.replaceAll(RegExp(r'[^0-9.]'), ''));
    
    if (num1 != null && num2 != null) {
      return '${(num1 + num2).toStringAsFixed(0)}';
    }
    
    return '$amount1 + $amount2';
  }

  String _categorizeIngredient(String ingredient) {
    final ingredientLower = ingredient.toLowerCase();

    // Thịt tươi sống
    if (ingredientLower.contains('thịt') || ingredientLower.contains('gà') ||
        ingredientLower.contains('cá') || ingredientLower.contains('tôm') ||
        ingredientLower.contains('bò') || ingredientLower.contains('heo') ||
        ingredientLower.contains('lòng') || ingredientLower.contains('gan')) {
      return '🥩 Thịt tươi sống';
    }
    // Rau củ quả
    else if (ingredientLower.contains('rau') || ingredientLower.contains('củ') ||
               ingredientLower.contains('cà chua') || ingredientLower.contains('hành') ||
               ingredientLower.contains('ớt') || ingredientLower.contains('xà lách') ||
               ingredientLower.contains('cải') || ingredientLower.contains('giá đỗ') ||
               ingredientLower.contains('dưa leo') || ingredientLower.contains('bắp cải')) {
      return '🥬 Rau củ quả';
    }
    // Thực phẩm khô
    else if (ingredientLower.contains('gạo') || ingredientLower.contains('bún') ||
               ingredientLower.contains('mì') || ingredientLower.contains('bánh') ||
               ingredientLower.contains('phở') || ingredientLower.contains('cơm')) {
      return '🌾 Thực phẩm khô';
    }
    // Gia vị & Nước chấm
    else if (ingredientLower.contains('muối') || ingredientLower.contains('đường') ||
               ingredientLower.contains('gia vị') || ingredientLower.contains('tỏi') ||
               ingredientLower.contains('gừng') || ingredientLower.contains('nước chấm') ||
               ingredientLower.contains('tương') || ingredientLower.contains('dầu')) {
      return '🧂 Gia vị & Nước chấm';
    }
    // Sản phẩm từ sữa
    else if (ingredientLower.contains('sữa') || ingredientLower.contains('trứng') ||
               ingredientLower.contains('bơ') || ingredientLower.contains('phô mai') ||
               ingredientLower.contains('yaourt')) {
      return '🥛 Sản phẩm từ sữa';
    }
    // Đồ uống
    else if (ingredientLower.contains('nước') || ingredientLower.contains('trà') ||
               ingredientLower.contains('cà phê') || ingredientLower.contains('bia')) {
      return '🥤 Đồ uống';
    }

    return '📦 Khác';
  }

  /// Chuyển đổi số ngày trong tuần thành chuỗi (khớp với Firebase format)
  String _getDayOfWeekString(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Monday';
    }
  }

  /// Phân tích chi phí với AI Finance Agent
  Future<void> _analyzeCosts() async {
    if (_groceryItems.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final analysis = await FinanceAgentService.analyzeCosts(
        _groceryItems,
        budgetLimit: _budgetLimit,
      );

      setState(() {
        _costAnalysis = analysis;
        _isAnalyzing = false;
      });

      print('✅ Đã phân tích chi phí: ${analysis.totalCost} VND');
    } catch (e) {
      print('❌ Lỗi khi phân tích chi phí: $e');
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  /// Hiển thị/ẩn phân tích chi phí
  void _toggleCostAnalysis() {
    setState(() {
      _showCostAnalysis = !_showCostAnalysis;
    });
  }

  /// Cập nhật ngân sách
  void _updateBudget() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final controller = TextEditingController(text: _budgetLimit.toString());
        return AlertDialog(
          title: Text('Cập nhật ngân sách'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Ngân sách (VND)',
              hintText: 'Nhập số tiền...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final newBudget = double.tryParse(controller.text);
                if (newBudget != null && newBudget > 0) {
                  setState(() {
                    _budgetLimit = newBudget;
                  });
                  _analyzeCosts(); // Phân tích lại với ngân sách mới
                }
                Navigator.pop(context);
              },
              child: Text('Cập nhật'),
            ),
          ],
        );
      },
    );
  }

  /// Xây dựng view khi hiển thị phân tích chi phí
  Widget _buildCostAnalysisView() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildProgressHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                CostAnalysisWidget(
                  analysis: _costAnalysis!,
                  onBudgetTap: _updateBudget,
                ),
                SizedBox(height: 16),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🛒 Danh sách mua sắm chi tiết',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildGroceryListForAnalysis(),
                    ],
                  ),
                ),
                SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
        ),
        if (_isAnalyzing) _buildAnalyzingIndicator(),
      ],
    );
  }

  /// Xây dựng view bình thường (không có phân tích)
  Widget _buildNormalView() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildProgressHeader(),
        Expanded(
          child: _buildGroceryList(),
        ),
        if (_isAnalyzing) _buildAnalyzingIndicator(),
      ],
    );
  }

  /// Indicator khi đang phân tích
  Widget _buildAnalyzingIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'AI đang phân tích chi phí...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Grocery list cho chế độ phân tích (không scrollable)
  Widget _buildGroceryListForAnalysis() {
    final groceryItemsList = _filteredItems;

    if (groceryItemsList.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoSearchResults();
    }

    return _buildExpandableGroceryListForAnalysis(groceryItemsList);
  }

  /// Grocery list expandable cho chế độ phân tích
  Widget _buildExpandableGroceryListForAnalysis(List<GroceryItem> groceryItemsList) {
    // Group items by category
    final Map<String, List<GroceryItem>> groupedItems = {};
    for (final item in groceryItemsList) {
      if (!groupedItems.containsKey(item.category)) {
        groupedItems[item.category] = [];
      }
      groupedItems[item.category]!.add(item);
    }

    // Sort categories
    final sortedCategories = groupedItems.keys.toList()..sort();

    return Column(
      children: sortedCategories.map((category) {
        final items = groupedItems[category]!;
        final isCollapsed = _collapsedCategories.contains(category);

        return Column(
          children: [
            // Category Header
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedCategories.remove(category);
                  } else {
                    _collapsedCategories.add(category);
                  }
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: isCollapsed ? 0 : 0.25,
                      duration: Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_right,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Items List (Expandable)
            if (!isCollapsed)
              ...items.map((item) => _buildGroceryItem(item)),
          ],
        );
      }).toList(),
    );
  }

  /// Widget khi không có kết quả tìm kiếm
  Widget _buildNoSearchResults() {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Không tìm thấy nguyên liệu',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Thử tìm kiếm với từ khóa khác',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  /// Lấy hiển thị giá của item
  String _getItemCostDisplay(GroceryItem item) {
    try {
      final cost = FinanceAgentService.calculateItemCost(item);
      return CurrencyFormatter.formatVNDCompact(cost);
    } catch (e) {
      return 'N/A';
    }
  }

  List<GroceryItem> get _filteredItems {
    var items = _groceryItems.values.toList();

    // Filter theo search query
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) => item.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Danh sách mua sắm',
          style: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue.shade800),
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: _toggleCostAnalysis,
            tooltip: 'Phân tích chi phí AI',
            color: _showCostAnalysis ? Colors.green.shade600 : null,
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
            tooltip: 'Quản lý hiển thị',
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareGroceryList,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              print('🔄 Đang tải lại meal plan...');
              await _loadMealPlanAndGenerateList();
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
      body: _groceryItems.isEmpty
          ? _buildEmptyState()
          : _showCostAnalysis && _costAnalysis != null
              ? _buildCostAnalysisView()
              : _buildNormalView(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm nguyên liệu...',
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade600),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.blue.shade300,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Chưa có kế hoạch bữa ăn',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Hãy tạo kế hoạch bữa ăn để có danh sách mua sắm tự động cho hôm nay và ngày mai',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.restaurant_menu),
            label: Text('Tạo kế hoạch bữa ăn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              _createTestMealPlan();
            },
            icon: Icon(Icons.science),
            label: Text('Test với dữ liệu mẫu'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade600,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    final totalItems = _filteredItems.length;
    final checkedItems = _filteredItems
        .where((item) => _checkedItems[item.name.toLowerCase()] ?? false)
        .length;
    final progress = totalItems > 0 ? checkedItems / totalItems : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tiến độ mua sắm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toInt()}% hoàn thành (2 ngày)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$checkedItems/$totalItems',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryList() {
    final groceryItemsList = _filteredItems;

    if (groceryItemsList.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'Không tìm thấy nguyên liệu',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Thử tìm kiếm với từ khóa khác',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return _buildExpandableGroceryList(groceryItemsList);

  }

  Widget _buildExpandableGroceryList(List<GroceryItem> groceryItemsList) {
    // Group items by category
    final Map<String, List<GroceryItem>> groupedItems = {};
    for (final item in groceryItemsList) {
      if (!groupedItems.containsKey(item.category)) {
        groupedItems[item.category] = [];
      }
      groupedItems[item.category]!.add(item);
    }

    // Sort categories
    final sortedCategories = groupedItems.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final items = groupedItems[category]!;
        final isCollapsed = _collapsedCategories.contains(category);

        return Column(
          children: [
            // Category Header
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedCategories.remove(category);
                  } else {
                    _collapsedCategories.add(category);
                  }
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: isCollapsed ? 0 : 0.25,
                      duration: Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_right,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Items List (Expandable)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: isCollapsed ? 0 : null,
              child: isCollapsed
                  ? SizedBox.shrink()
                  : Column(
                      children: items.map((item) => _buildGroceryItem(item)).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroceryItem(GroceryItem item) {
    final isChecked = _checkedItems[item.name.toLowerCase()] ?? false;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isChecked ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isChecked
                ? Colors.grey.withOpacity(0.1)
                : Colors.grey.withOpacity(0.15),
            blurRadius: isChecked ? 4 : 8,
            offset: Offset(0, isChecked ? 1 : 2),
          ),
        ],
        border: isChecked
            ? Border.all(color: Colors.blue.shade200, width: 1)
            : null,
      ),
      child: CheckboxListTile(
        title: Text(
          item.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? Colors.grey.shade500 : Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số lượng: ${item.amount}${item.unit.isNotEmpty ? ' ${item.unit}' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: isChecked ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            if (_showCostAnalysis && _costAnalysis != null)
              Text(
                'Ước tính: ${_getItemCostDisplay(item)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isChecked ? Colors.grey.shade400 : Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        value: isChecked,
        onChanged: (bool? value) {
          setState(() {
            _checkedItems[item.name.toLowerCase()] = value ?? false;
          });
          HapticFeedback.lightImpact();
        },
        activeColor: Colors.blue.shade600,
        checkColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final totalItems = _groceryItems.length;
    final checkedItems = _checkedItems.values.where((checked) => checked).length;

    if (totalItems == 0) return SizedBox.shrink();

    // Nếu đang hiển thị phân tích chi phí, hiển thị FAB với thông tin chi phí
    if (_showCostAnalysis && _costAnalysis != null) {
      return FloatingActionButton.extended(
        onPressed: _updateBudget,
        backgroundColor: _costAnalysis!.budgetComparison.isOverBudget
            ? Colors.red.shade600
            : Colors.green.shade600,
        icon: Icon(
          Icons.account_balance_wallet,
          color: Colors.white,
        ),
        label: Text(
          'Tổng: ${CurrencyFormatter.formatVNDCompact(_costAnalysis!.totalCost)}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () {
        if (checkedItems == totalItems) {
          _showCompletionDialog();
        } else {
          _markAllAsCompleted();
        }
      },
      backgroundColor: checkedItems == totalItems
          ? Colors.orange.shade600
          : Colors.blue.shade600,
      icon: Icon(
        checkedItems == totalItems ? Icons.refresh : Icons.done_all,
        color: Colors.white,
      ),
      label: Text(
        checkedItems == totalItems ? 'Làm mới' : 'Hoàn thành tất cả',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _markAllAsCompleted() {
    setState(() {
      for (String key in _checkedItems.keys) {
        _checkedItems[key] = true;
      }
    });
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã đánh dấu tất cả nguyên liệu là hoàn thành!'),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.celebration, color: Colors.orange.shade600),
              SizedBox(width: 8),
              Text('Chúc mừng!'),
            ],
          ),
          content: Text(
            'Bạn đã mua sắm xong tất cả nguyên liệu! Bạn có muốn làm mới danh sách không?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetAllItems();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Làm mới'),
            ),
          ],
        );
      },
    );
  }

  void _resetAllItems() {
    setState(() {
      for (String key in _checkedItems.keys) {
        _checkedItems[key] = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _shareGroceryList() {
    if (_groceryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không có danh sách mua sắm để chia sẻ'),
          backgroundColor: Colors.orange.shade600,
        ),
      );
      return;
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📝 DANH SÁCH MUA SẮM\n');

    // Group items by category
    final Map<String, List<GroceryItem>> groupedItems = {};
    for (final item in _groceryItems.values) {
      if (!groupedItems.containsKey(item.category)) {
        groupedItems[item.category] = [];
      }
      groupedItems[item.category]!.add(item);
    }

    // Write each category
    groupedItems.forEach((category, items) {
      buffer.writeln('$category:');
      for (final item in items) {
        final isChecked = _checkedItems[item.name.toLowerCase()] ?? false;
        final checkMark = isChecked ? '✅' : '⬜';
        buffer.writeln('$checkMark ${item.name} - ${item.amount}${item.unit.isNotEmpty ? ' ${item.unit}' : ''}');
      }
      buffer.writeln();
    });

    buffer.writeln('Được tạo bởi ứng dụng OpenFood 🍽️');

    // Here you would typically use a share package like share_plus
    // For now, we'll copy to clipboard
    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép danh sách mua sắm vào clipboard!'),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showFilterOptions() {
    final allCategories = _groceryItems.values.map((item) => item.category).toSet().toList();
    allCategories.sort();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quản lý hiển thị danh sách',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _collapsedCategories.clear();
                            });
                            setModalState(() {});
                          },
                          icon: Icon(Icons.visibility),
                          label: Text('Mở tất cả'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _collapsedCategories.addAll(allCategories);
                            });
                            setModalState(() {});
                          },
                          icon: Icon(Icons.visibility_off),
                          label: Text('Đóng tất cả'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nhấn vào loại để mở/đóng:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allCategories.map((category) {
                      final isCollapsed = _collapsedCategories.contains(category);
                      final itemCount = _groceryItems.values.where((item) => item.category == category).length;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isCollapsed) {
                              _collapsedCategories.remove(category);
                            } else {
                              _collapsedCategories.add(category);
                            }
                          });
                          setModalState(() {});
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCollapsed ? Colors.grey.shade100 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isCollapsed ? Colors.grey.shade300 : Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                                size: 16,
                                color: isCollapsed ? Colors.grey.shade600 : Colors.blue.shade700,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '$category ($itemCount)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isCollapsed ? Colors.grey.shade600 : Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Class để đại diện cho một item trong danh sách mua sắm
class GroceryItem {
  final String name;
  final String amount;
  final String unit;
  final String category;

  GroceryItem({
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
  });

  GroceryItem copyWith({
    String? name,
    String? amount,
    String? unit,
    String? category,
  }) {
    return GroceryItem(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      category: category ?? this.category,
    );
  }
}
