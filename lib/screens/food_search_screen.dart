import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:openfood/models/food_entry.dart';
import 'package:openfood/models/nutrition_info.dart';
import 'package:openfood/providers/food_provider.dart';
import 'package:openfood/services/food_database_service.dart';
import 'package:openfood/services/edamam_food_service.dart';
import 'package:shimmer/shimmer.dart';

import '../models/food_item.dart';
import 'food_nutrition_detail_screen.dart';


class FoodSearchScreen extends StatefulWidget {
  static const routeName = '/food-search';

  @override
  _FoodSearchScreenState createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FoodDatabaseService _databaseService = FoodDatabaseService();
  final EdamamFoodService _edamamService = EdamamFoodService();
  
  bool _isSearching = false;
  bool _isLoadingNutrition = false;
  List<Map<String, dynamic>> _searchResults = [];
  NutritionInfo? _selectedNutritionInfo;
  String? _selectedFoodName;
  FoodItem? _selectedItem;
  
  // Danh sách món ăn Việt Nam phổ biến với thông tin dinh dưỡng cơ bản
  final List<Map<String, dynamic>> _vietnameseFoods = [
    {
      'fdcId': 'vn001',
      'description': 'Cơm trắng',
      'brandOwner': 'Thực phẩm Việt',
      'ingredients': 'Gạo',
      'calories': 130,
      'protein': 2.7,
      'fat': 0.3,
      'carbs': 28.2,
      'servingSize': '100g',
      'category': 'Ngũ cốc'
    },
    {
      'fdcId': 'vn002',
      'description': 'Bánh mì',
      'brandOwner': 'Thực phẩm Việt',
      'ingredients': 'Bột mì, men, muối, đường',
      'calories': 265,
      'protein': 9.0,
      'fat': 3.2,
      'carbs': 49.0,
      'servingSize': '100g',
      'category': 'Bánh mì'
    },
    {
      'fdcId': 'vn003',
      'description': 'Phở bò',
      'brandOwner': 'Thực phẩm Việt',
      'ingredients': 'Bánh phở, thịt bò, hành, gia vị',
      'calories': 215,
      'protein': 15.0,
      'fat': 5.0,
      'carbs': 25.0,
      'servingSize': '100g',
      'category': 'Món chính'
    },
    {
      'fdcId': 'vn004',
      'description': 'Thịt gà luộc',
      'brandOwner': 'Thực phẩm Việt',
      'ingredients': 'Thịt gà',
      'calories': 165,
      'protein': 31.0,
      'fat': 3.6,
      'carbs': 0.0,
      'servingSize': '100g',
      'category': 'Protein'
    },
    {
      'fdcId': 'vn005',
      'description': 'Trứng gà luộc',
      'brandOwner': 'Thực phẩm Việt',
      'ingredients': 'Trứng gà',
      'calories': 155,
      'protein': 12.6,
      'fat': 10.6,
      'carbs': 1.1,
      'servingSize': '100g',
      'category': 'Protein'
    },
    {
      'fdcId': 'vn006',
      'description': 'Chuối tiêu',
      'brandOwner': 'Trái cây Việt',
      'ingredients': 'Chuối',
      'calories': 89,
      'protein': 1.1,
      'fat': 0.3,
      'carbs': 22.8,
      'servingSize': '100g',
      'category': 'Trái cây'
    },
    {
      'fdcId': 'vn007',
      'description': 'Táo đỏ',
      'brandOwner': 'Trái cây Việt',
      'ingredients': 'Táo',
      'calories': 52,
      'protein': 0.3,
      'fat': 0.2,
      'carbs': 13.8,
      'servingSize': '100g',
      'category': 'Trái cây'
    },
    {
      'fdcId': 'vn008',
      'description': 'Rau muống xào tỏi',
      'brandOwner': 'Rau củ Việt',
      'ingredients': 'Rau muống, tỏi, dầu ăn',
      'calories': 45,
      'protein': 2.6,
      'fat': 2.0,
      'carbs': 3.4,
      'servingSize': '100g',
      'category': 'Rau củ'
    },
    {
      'fdcId': 'vn009',
      'description': 'Cà ri gà',
      'brandOwner': 'Món Việt',
      'ingredients': 'Thịt gà, khoai tây, cà rốt, gia vị cà ri',
      'calories': 195,
      'protein': 13.0,
      'fat': 10.0,
      'carbs': 12.0,
      'servingSize': '100g',
      'category': 'Món chính'
    },
    {
      'fdcId': 'vn010',
      'description': 'Cơm chiên dương châu',
      'brandOwner': 'Món Việt',
      'ingredients': 'Cơm, trứng, thịt xá xíu, đậu Hà Lan, cà rốt',
      'calories': 185,
      'protein': 7.5,
      'fat': 5.0,
      'carbs': 25.0,
      'servingSize': '100g',
      'category': 'Món chiên'
    },
    // Thêm nhiều món ăn Việt Nam phổ biến
    {
      'fdcId': 'vn011',
      'description': 'Bún chả',
      'brandOwner': 'Món Việt',
      'ingredients': 'Bún, thịt lợn nướng, nước mắm, rau sống',
      'calories': 220,
      'protein': 14.0,
      'fat': 6.0,
      'carbs': 30.0,
      'servingSize': '100g',
      'category': 'Món bún'
    },
    {
      'fdcId': 'vn012',
      'description': 'Bún riêu',
      'brandOwner': 'Món Việt',
      'ingredients': 'Bún, riêu cua, thịt, đậu phụ, mắm tôm',
      'calories': 180,
      'protein': 12.0,
      'fat': 5.0,
      'carbs': 24.0,
      'servingSize': '100g',
      'category': 'Món bún'
    },
    {
      'fdcId': 'vn013',
      'description': 'Bánh xèo',
      'brandOwner': 'Bánh Việt',
      'ingredients': 'Bột gạo, tôm, thịt, giá đỗ, hành',
      'calories': 240,
      'protein': 8.0,
      'fat': 12.0,
      'carbs': 28.0,
      'servingSize': '100g',
      'category': 'Bánh'
    },
    {
      'fdcId': 'vn014',
      'description': 'Gỏi cuốn',
      'brandOwner': 'Món Việt',
      'ingredients': 'Bánh tráng, thịt heo, tôm, bún, rau',
      'calories': 120,
      'protein': 10.0,
      'fat': 2.5,
      'carbs': 16.0,
      'servingSize': '100g',
      'category': 'Món cuốn'
    },
    {
      'fdcId': 'vn015',
      'description': 'Canh chua',
      'brandOwner': 'Món Việt',
      'ingredients': 'Đầu cá, rau ngổ, giá, me, đậu bắp',
      'calories': 85,
      'protein': 6.0,
      'fat': 2.0,
      'carbs': 10.0,
      'servingSize': '100g',
      'category': 'Món canh'
    },
    {
      'fdcId': 'vn016',
      'description': 'Chả giò',
      'brandOwner': 'Món Việt',
      'ingredients': 'Thịt heo, miến, nấm mèo, trứng, bánh đa nem',
      'calories': 270,
      'protein': 11.0,
      'fat': 16.0,
      'carbs': 20.0,
      'servingSize': '100g',
      'category': 'Món chiên'
    },
    {
      'fdcId': 'vn017',
      'description': 'Cháo gà',
      'brandOwner': 'Món Việt',
      'ingredients': 'Gạo, thịt gà, hành, gừng',
      'calories': 130,
      'protein': 8.0,
      'fat': 3.0,
      'carbs': 20.0,
      'servingSize': '100g',
      'category': 'Cháo'
    },
    {
      'fdcId': 'vn018',
      'description': 'Bò kho',
      'brandOwner': 'Món Việt',
      'ingredients': 'Thịt bò, cà rốt, củ đậu, sả, gừng',
      'calories': 180,
      'protein': 18.0,
      'fat': 8.0,
      'carbs': 10.0,
      'servingSize': '100g',
      'category': 'Món chính'
    },
    {
      'fdcId': 'vn019',
      'description': 'Cơm tấm',
      'brandOwner': 'Món Việt',
      'ingredients': 'Cơm, sườn nướng, bì, chả, trứng, mỡ hành',
      'calories': 350,
      'protein': 20.0,
      'fat': 12.0,
      'carbs': 40.0,
      'servingSize': '100g',
      'category': 'Món cơm'
    },
    {
      'fdcId': 'vn020',
      'description': 'Bún đậu mắm tôm',
      'brandOwner': 'Món Việt',
      'ingredients': 'Bún, đậu phụ, chả cốm, thịt luộc, mắm tôm',
      'calories': 260,
      'protein': 16.0,
      'fat': 10.0,
      'carbs': 28.0,
      'servingSize': '100g',
      'category': 'Món bún'
    },
  ];
  
  // Lưu lịch sử tìm kiếm
  List<String> _recentSearches = ['Cơm', 'Trứng', 'Thịt gà', 'Chuối', 'Táo'];
  
  @override
  void initState() {
    super.initState();
    _databaseService.initialize();
    _loadRecentSearches();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Tải lịch sử tìm kiếm gần đây
  Future<void> _loadRecentSearches() async {
    // Trong thực tế, bạn sẽ tải từ SharedPreferences hoặc database
    setState(() {
      _recentSearches = ['Cơm', 'Trứng', 'Thịt gà', 'Chuối', 'Táo'];
    });
  }
  
  // Lưu từ khóa tìm kiếm vào lịch sử
  Future<void> _saveSearchQuery(String query) async {
    // Tránh lưu trùng lặp
    if (_recentSearches.contains(query)) {
      _recentSearches.remove(query);
    }
    
    // Thêm từ khóa mới vào đầu danh sách
    _recentSearches.insert(0, query);
    
    // Giới hạn số lượng từ khóa gần đây
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    
    // Trong thực tế, bạn sẽ lưu vào SharedPreferences hoặc database
    setState(() {});
  }
  
  // Perform search with the user's query
  Future<void> _searchFood(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });
    
    // Lưu query vào lịch sử tìm kiếm
    _saveSearchQuery(query);
    
    try {
      print("Đang tìm kiếm thực phẩm với từ khóa: $query");
      
      // Tìm kiếm trong danh sách món ăn Việt Nam
      List<Map<String, dynamic>> localResults = _vietnameseFoods
          .where((food) => food['description'].toLowerCase().contains(query.toLowerCase()))
          .toList();
      
      if (localResults.isNotEmpty) {
        print("Tìm thấy ${localResults.length} kết quả từ dữ liệu địa phương");
        setState(() {
          _searchResults = localResults.map((food) => {
            'id': food['fdcId'],
            'name': food['description'],
            'brand': food['brandOwner'] ?? 'Thực phẩm Việt',
            'calories': food['calories'],
            'protein': food['protein'],
            'carbs': food['carbs'],
            'fat': food['fat'],
            'fiber': food['fiber'] ?? 0.0,
            'sugar': food['sugar'] ?? 0.0,
            'sodium': food['sodium'] ?? 0.0,
            'servingSize': 100.0,
            'servingUnit': 'g',
          }).toList();
          
          print("Kết quả mẫu đầu tiên: ${_searchResults.isNotEmpty ? _searchResults[0] : 'Không có'}");
          _isSearching = false;
        });
      } else {
        // Nếu không tìm thấy trong dữ liệu địa phương, tìm kiếm với API Edamam
        print("Không tìm thấy trong dữ liệu địa phương, tìm kiếm với API Edamam");
        
        // Tìm kiếm với API Edamam
        final edamamResults = await _edamamService.searchFood(query);
        
        if (edamamResults.isNotEmpty) {
          print("Tìm thấy ${edamamResults.length} kết quả từ API Edamam");
          setState(() {
            _searchResults = edamamResults.map((food) => {
              'id': food['fdcId'],
              'name': food['description'],
              'brand': food['brandOwner'] ?? food['category'] ?? 'Unknown',
              'calories': food['calories'],
              'protein': food['protein'],
              'carbs': food['carbs'],
              'fat': food['fat'],
              'fiber': 0.0, // Có thể không có thông tin chi tiết
              'sugar': 0.0,
              'sodium': 0.0,
              'servingSize': 100.0,
              'servingUnit': 'g',
              'imageUrl': food['image'],
            }).toList();
            _isSearching = false;
          });
        } else {
          // Nếu API Edamam không trả về kết quả, hiển thị kết quả mẫu dựa trên từ khóa
          print("Không tìm thấy kết quả từ API, sử dụng dữ liệu mẫu");
          setState(() {
            if (query.toLowerCase().contains('meat') || query.toLowerCase().contains('thịt')) {
              _searchResults = [
                {
                  'id': '1',
                  'name': 'Thịt bò',
                  'brand': 'Thực phẩm Việt',
                  'calories': 250,
                  'protein': 26.0,
                  'carbs': 0.0,
                  'fat': 17.0,
                  'fiber': 0.0,
                  'sugar': 0.0,
                  'sodium': 55.0,
                  'servingSize': 100.0,
                  'servingUnit': 'g',
                },
                {
                  'id': '2',
                  'name': 'Thịt heo',
                  'brand': 'Thực phẩm Việt',
                  'calories': 242,
                  'protein': 25.0,
                  'carbs': 0.0,
                  'fat': 16.0,
                  'fiber': 0.0,
                  'sugar': 0.0,
                  'sodium': 60.0,
                  'servingSize': 100.0,
                  'servingUnit': 'g',
                },
                {
                  'id': '3',
                  'name': 'Thịt gà',
                  'brand': 'Thực phẩm Việt',
                  'calories': 165,
                  'protein': 31.0,
                  'carbs': 0.0,
                  'fat': 3.6,
                  'fiber': 0.0,
                  'sugar': 0.0,
                  'sodium': 74.0,
                  'servingSize': 100.0,
                  'servingUnit': 'g',
                },
              ];
            } else if (query.toLowerCase().contains('rice') || query.toLowerCase().contains('cơm')) {
              _searchResults = [
                {
                  'id': 'r1',
                  'name': 'Cơm trắng',
                  'brand': 'Thực phẩm Việt',
                  'calories': 130,
                  'protein': 2.7,
                  'carbs': 28.2,
                  'fat': 0.3,
                  'fiber': 0.4,
                  'sugar': 0.1,
                  'sodium': 1.0,
                  'servingSize': 100.0,
                  'servingUnit': 'g',
                },
                {
                  'id': 'r2',
                  'name': 'Cơm chiên dương châu',
                  'brand': 'Món Việt',
                  'calories': 185,
                  'protein': 7.5,
                  'carbs': 25.0,
                  'fat': 5.0,
                  'fiber': 0.8,
                  'sugar': 1.2,
                  'sodium': 320.0,
                  'servingSize': 100.0,
                  'servingUnit': 'g',
                },
              ];
            } else if (query.toLowerCase().contains('fruit') || query.toLowerCase().contains('trái cây')) {
              _searchResults = [
                {
                  'id': 'f1',
                  'name': 'Chuối tiêu',
                  'brand': 'Trái cây Việt',
                  'calories': 89,
                  'protein': 1.1,
                  'carbs': 22.8,
                  'fat': 0.3,
                  'fiber': 2.6,
                  'sugar': 12.2,
                  'sodium': 1.0,
                  'servingSize': 100.0,
                  'servingUnit': 'g',
                },
                {
                  'id': 'f2',
                  'name': 'Táo đỏ',
                  'brand': 'Trái cây Việt',
                  'calories': 52,
                  'protein': 0.3,
                  'carbs': 13.8,
                  'fat': 0.2,
                  'fiber': 2.4,
                  'sugar': 10.4,
                  'sodium': 1.0,
                  'servingSize': 100.0,
                  'servingUnit': 'g',
                },
              ];
            } else {
              // Nếu không tìm thấy kết quả trùng khớp, hiển thị kết quả trống
              _searchResults = [];
            }
            
            print("Đã tạo ${_searchResults.length} kết quả mẫu");
            print("Kết quả mẫu đầu tiên: ${_searchResults.isNotEmpty ? _searchResults[0] : 'Không có'}");
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      print('Lỗi khi tìm kiếm: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }
  
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
    });
  }
  
  void _selectFood(Map<String, dynamic> food) {
    // Tạo FoodItem từ dữ liệu tìm kiếm
    final item = FoodItem(
      id: food['id'] ?? Uuid().v4(),
      name: food['name'],
      brand: food['brand'],
      calories: food['calories'] is int ? food['calories'].toDouble() : food['calories'],
      protein: food['protein'] is int ? (food['protein'] as int).toDouble() : food['protein'],
      carbs: food['carbs'] is int ? (food['carbs'] as int).toDouble() : food['carbs'],
      fat: food['fat'] is int ? (food['fat'] as int).toDouble() : food['fat'],
      fiber: food['fiber'] != null ? (food['fiber'] is int ? food['fiber'].toDouble() : food['fiber']) : 0.0,
      sugar: food['sugar'] != null ? (food['sugar'] is int ? food['sugar'].toDouble() : food['sugar']) : 0.0,
      sodium: food['sodium'] != null ? (food['sodium'] is int ? food['sodium'].toDouble() : food['sodium']) : 0.0,
      servingSize: food['servingSize'] is int ? (food['servingSize'] as int).toDouble() : food['servingSize'],
      servingUnit: food['servingUnit'] ?? 'g',
      imageUrl: food['imageUrl'],
      additionalNutrients: food['additionalNutrients'] ?? {},
    );
    
    // Cập nhật UI để hiển thị bottom sheet
    setState(() {
      _selectedItem = item;
    });
  }
  
  void _showFoodDetails(FoodItem item) {
    // Tạo FoodEntry để hiển thị trong màn hình chi tiết
    final now = DateTime.now();
    final foodEntry = FoodEntry(
      id: Uuid().v4(),
      dateTime: now,
      description: item.name,
      mealType: _getMealTypeBasedOnTime(now),
      items: [item],
    );
    
    // Mở màn hình chi tiết dinh dưỡng
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: foodEntry,
          onSave: (updatedEntry) {
            // Thêm vào nhật ký nếu người dùng lưu
            final foodProvider = Provider.of<FoodProvider>(context, listen: false);
            foodProvider.updateHomeScreenWithNewEntry(context, updatedEntry);
            
            // Quay về màn hình trước đó
            Navigator.of(context).pop(updatedEntry);
          },
        ),
      ),
    ).then((value) {
      // Sau khi trở về từ màn hình chi tiết
      if (value != null) {
        Navigator.of(context).pop(value);
      }
    });
  }
  
  // Xác định loại bữa ăn dựa trên thời gian hiện tại
  String _getMealTypeBasedOnTime(DateTime time) {
    final hour = time.hour;
    
    if (hour >= 5 && hour < 10) {
      return 'Bữa sáng';
    } else if (hour >= 10 && hour < 14) {
      return 'Bữa trưa';
    } else if (hour >= 17 && hour < 21) {
      return 'Bữa tối';
    } else {
      return 'Bữa phụ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tìm Kiếm Thực Phẩm'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Nhập tên món ăn, thịt, cơm, trái cây...',
                  prefixIcon: Icon(Icons.search, color: Colors.purple),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
                onChanged: (value) {
                  if (value.length > 2) {
                    _searchFood(value);
                  }
                },
                onSubmitted: _searchFood,
              ),
            ),
          ),
          
          // Kết quả tìm kiếm
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? _buildInitialEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final food = _searchResults[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildFoodItem(food),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomSheet: _selectedItem != null
          ? Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedItem!.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNutrientInfo('Calories', '${_selectedItem!.calories}', 'kcal'),
                      _buildNutrientInfo('Protein', '${_selectedItem!.protein}', 'g'),
                      _buildNutrientInfo('Carbs', '${_selectedItem!.carbs}', 'g'),
                      _buildNutrientInfo('Fat', '${_selectedItem!.fat}', 'g'),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showFoodDetails(_selectedItem!),
                    child: Text('Xem chi tiết'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
  
  // Widget hiển thị màn hình ban đầu khi chưa có kết quả tìm kiếm
  Widget _buildInitialEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_recentSearches.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'Tìm kiếm gần đây',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentSearches.map((term) {
                  return InkWell(
                    onTap: () {
                      _searchController.text = term;
                      _searchFood(term);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Text(
                            term,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 24),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Gợi ý danh mục thực phẩm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildFoodCategoryCard(
                  icon: '🍚',
                  title: 'Cơm & Ngũ cốc',
                  searchTerm: 'cơm',
                ),
                _buildFoodCategoryCard(
                  icon: '🥩',
                  title: 'Thịt & Cá',
                  searchTerm: 'thịt',
                ),
                _buildFoodCategoryCard(
                  icon: '🍌',
                  title: 'Trái cây',
                  searchTerm: 'trái cây',
                ),
                _buildFoodCategoryCard(
                  icon: '🥗',
                  title: 'Rau củ',
                  searchTerm: 'rau',
                ),
                _buildFoodCategoryCard(
                  icon: '🥛',
                  title: 'Sữa & Trứng',
                  searchTerm: 'sữa',
                ),
                _buildFoodCategoryCard(
                  icon: '🍜',
                  title: 'Món chính',
                  searchTerm: 'món',
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  // Widget thẻ danh mục thực phẩm
  Widget _buildFoodCategoryCard({
    required String icon,
    required String title,
    required String searchTerm,
  }) {
    return InkWell(
      onTap: () {
        _searchController.text = searchTerm;
        _searchFood(searchTerm);
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 44) / 2,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              icon,
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFoodItem(Map<String, dynamic> food) {
    return InkWell(
      onTap: () {
        _selectFood(food);
        // Sau khi chọn món ăn, mở ngay màn hình chi tiết
        if (_selectedItem != null) {
          _showFoodDetails(_selectedItem!);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Hình ảnh món ăn
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Kiểm tra xem có ảnh không, nếu không dùng icon mặc định
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.food_bank,
                        color: Colors.grey[500],
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16),
            
            // Thông tin món ăn
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food['name'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    food['brand'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Thông tin calories
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${food['calories']} kcal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${food['servingSize']}${food['servingUnit']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNutrientInfo(String label, String value, String unit) {
    Color color;
    IconData icon;
    
    switch (label) {
      case 'Calories':
        color = Colors.orange;
        icon = Icons.local_fire_department;
        break;
      case 'Protein':
        color = Colors.blue;
        icon = Icons.fitness_center;
        break;
      case 'Carbs':
        color = Colors.amber;
        icon = Icons.grain;
        break;
      case 'Fat':
        color = Colors.green;
        icon = Icons.circle;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 