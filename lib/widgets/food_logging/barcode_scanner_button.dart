import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/food_item.dart';
import '../../utils/constants.dart';

class BarcodeScannerButton extends StatelessWidget {
  final Function(FoodItem, String) onBarcodeScan;
  final Function(String)? onError;
  final bool showLoading;

  const BarcodeScannerButton({
    Key? key,
    required this.onBarcodeScan,
    this.onError,
    this.showLoading = true,
  }) : super(key: key);

  Future<Map<String, dynamic>?> _fetchNutritionData(String barcode) async {
    try {
      // Danh sách các API endpoint để thử
      final List<String> apiEndpoints = [
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
        'https://vn.openfoodfacts.org/api/v0/product/$barcode.json',  // Vietnam endpoint
        'https://asia.openfoodfacts.org/api/v0/product/$barcode.json', // Asia endpoint
        'https://world.openfoodfacts.org/api/v2/product/$barcode'     // API v2
      ];
      
      Map<String, dynamic>? productData;
      
      // Thử tuần tự từng API endpoint
      for (String url in apiEndpoints) {
        print('Đang thử API với URL: $url');
        
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'DietAI/1.0 (Android)',
          },
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Kiểm tra xem API trả về dữ liệu và dữ liệu có hợp lệ không
          if (data['status'] == 1 && data['product'] != null) {
            // Kiểm tra thêm xem có dữ liệu dinh dưỡng không
            final product = data['product'];
            final hasNutritionData = product.containsKey('nutriments') && 
                                    product['nutriments'] != null && 
                                    product['nutriments'] is Map && 
                                    product['nutriments'].isNotEmpty;
            
            // Nếu có dữ liệu dinh dưỡng, sử dụng sản phẩm này
            if (hasNutritionData) {
              print('Đã tìm thấy dữ liệu dinh dưỡng từ API: $url');
              productData = product;
              break;
            } else {
              print('API $url không trả về dữ liệu dinh dưỡng đầy đủ');
            }
          } else {
            print('Không tìm thấy sản phẩm với mã vạch: $barcode từ API: $url, status: ${data['status']}');
          }
        } else {
          print('Lỗi khi gọi API $url: ${response.statusCode}');
        }
      }
      
      // Nếu không tìm thấy dữ liệu hợp lệ từ bất kỳ endpoint nào
      if (productData == null) {
        // Thử một hướng tiếp cận khác: tạo dữ liệu cơ bản nếu API không trả về
        print('Không tìm thấy sản phẩm trong cơ sở dữ liệu, tạo sản phẩm cơ bản');
        return {
          'product_name': 'Sản phẩm chưa xác định',
          'brands': 'Thương hiệu chưa xác định',
          'nutriments': {
            'energy-kcal_100g': 0,
            'proteins_100g': 0,
            'fat_100g': 0,
            'carbohydrates_100g': 0,
            'fiber_100g': 0,
            'sugars_100g': 0,
            'sodium_100g': 0,
          },
          'barcode': barcode,
          'dataSource': 'Tạo tự động'
        };
      }
      
      print('Dữ liệu trả về từ API: ${productData.keys}');
      return productData;
    } catch (e) {
      print('Lỗi khi xử lý dữ liệu: $e');
      return null;
    }
  }

  FoodItem _convertToFoodItem(Map<String, dynamic> data, String barcode) {
    // Debug log để xem dữ liệu đầy đủ
    print('Dữ liệu sản phẩm nhận được: $data');
    
    final String name = data['product_name'] ?? data['generic_name'] ?? 'Không rõ tên';
    final String brand = data['brands'] ?? '';
    
    final nutriments = data['nutriments'] ?? {};
    print('Dữ liệu dinh dưỡng: $nutriments');
    
    // Thử các khóa khác nhau cho calories
    double calories = 0;
    if (nutriments.containsKey('energy-kcal_100g')) {
      calories = double.tryParse('${nutriments['energy-kcal_100g']}') ?? 0;
    } else if (nutriments.containsKey('energy-kcal_serving')) {
      calories = double.tryParse('${nutriments['energy-kcal_serving']}') ?? 0;
    } else if (nutriments.containsKey('energy_100g')) {
      // Convert kJ to kcal if necessary
      final double energyValue = double.tryParse('${nutriments['energy_100g']}') ?? 0;
      calories = energyValue / 4.184; // Approximate conversion from kJ to kcal
    } else if (nutriments.containsKey('energy-kj_100g')) {
      final double energyKJ = double.tryParse('${nutriments['energy-kj_100g']}') ?? 0;
      calories = energyKJ / 4.184; // Convert kJ to kcal
    }
    
    double protein = double.tryParse('${nutriments['proteins_100g'] ?? 0}') ?? 0;
    double fat = double.tryParse('${nutriments['fat_100g'] ?? 0}') ?? 0;
    double carbs = double.tryParse('${nutriments['carbohydrates_100g'] ?? 0}') ?? 0;
    double fiber = double.tryParse('${nutriments['fiber_100g'] ?? 0}') ?? 0;
    double sugar = double.tryParse('${nutriments['sugars_100g'] ?? 0}') ?? 0;
    double sodium = double.tryParse('${nutriments['sodium_100g'] ?? 0}') ?? 0;
    
    // Nếu không tìm thấy sodium, thử tìm salt và chuyển đổi
    if (sodium == 0 && nutriments.containsKey('salt_100g')) {
      final double salt = double.tryParse('${nutriments['salt_100g']}') ?? 0;
      // Salt to sodium conversion: sodium = salt / 2.5
      sodium = salt / 2.5; // Sửa lỗi: cần gán giá trị chuyển đổi cho sodium
      print('Chuyển đổi từ salt ($salt g) sang sodium: $sodium g');
    }
    
    // Nếu vẫn không có giá trị dinh dưỡng, tạo giá trị mặc định
    // Đảm bảo ít nhất một giá trị khác 0 để có thể hiển thị dữ liệu
    if (calories == 0 && protein == 0 && fat == 0 && carbs == 0) {
      // Đặt giá trị ước tính nếu không tìm thấy giá trị thực
      if (data['dataSource'] == 'Tạo tự động') {
        // Giá trị ước tính dựa trên tên sản phẩm
        if (name.toLowerCase().contains("sữa") || name.toLowerCase().contains("sua")) {
          calories = 60;
          protein = 3.2;
          fat = 3.5;
          carbs = 4.8;
        } else if (name.toLowerCase().contains("thịt") || name.toLowerCase().contains("thit")) {
          calories = 250;
          protein = 25;
          fat = 15;
          carbs = 0;
        } else if (name.toLowerCase().contains("rau") || name.toLowerCase().contains("vegetable")) {
          calories = 30;
          protein = 2;
          fat = 0.5;
          carbs = 5;
        } else {
          // Giá trị mặc định chung
          calories = 100;
          protein = 5;
          fat = 3;
          carbs = 10;
        }
      }
    }
    
    Map<String, dynamic> additionalNutrients = {
      'saturatedFat': double.tryParse('${nutriments['saturated-fat_100g'] ?? 0}') ?? 0,
      'transFat': double.tryParse('${nutriments['trans-fat_100g'] ?? 0}') ?? 0,
      'cholesterol': double.tryParse('${nutriments['cholesterol_100g'] ?? 0}') ?? 0,
      'vitaminA': double.tryParse('${nutriments['vitamin-a_100g'] ?? 0}') ?? 0,
      'vitaminC': double.tryParse('${nutriments['vitamin-c_100g'] ?? 0}') ?? 0,
      'vitaminD': double.tryParse('${nutriments['vitamin-d_100g'] ?? 0}') ?? 0,
      'calcium': double.tryParse('${nutriments['calcium_100g'] ?? 0}') ?? 0,
      'iron': double.tryParse('${nutriments['iron_100g'] ?? 0}') ?? 0,
      'potassium': double.tryParse('${nutriments['potassium_100g'] ?? 0}') ?? 0,
      'dataSource': data['dataSource'] ?? 'Open Food Facts',
      'barcode': barcode,
    };
    
    // Thêm các giá trị khác dưới dạng tên chuẩn hóa và tên gốc
    if (nutriments.containsKey('salt_100g')) {
      additionalNutrients['salt'] = double.tryParse('${nutriments['salt_100g']}') ?? 0;
    }
    
    if (nutriments.containsKey('magnesium_100g')) {
      additionalNutrients['magnesium'] = double.tryParse('${nutriments['magnesium_100g']}') ?? 0;
    }
    
    if (nutriments.containsKey('zinc_100g')) {
      additionalNutrients['zinc'] = double.tryParse('${nutriments['zinc_100g']}') ?? 0;
    }
    
    // Thêm calories, protein, fat, carbs vào additionalNutrients để đảm bảo chúng được lưu vào nutritionInfo
    additionalNutrients['calories'] = calories;
    additionalNutrients['protein'] = protein;
    additionalNutrients['fat'] = fat;
    additionalNutrients['carbs'] = carbs;
    additionalNutrients['fiber'] = fiber;
    additionalNutrients['sugar'] = sugar;
    additionalNutrients['sodium'] = sodium;
    
    String imageUrl = data['image_url'] ?? data['image_front_url'] ?? '';
    
    print('Các giá trị dinh dưỡng cơ bản: calories=$calories, protein=$protein, fat=$fat, carbs=$carbs');
    
    return FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      brand: brand,
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      servingSize: 1.0,
      servingUnit: 'khẩu phần',
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      imageUrl: imageUrl,
      additionalNutrients: additionalNutrients,
    );
  }

  Future<void> _scanBarcode(BuildContext context) async {
    try {
      final permissionStatus = await Permission.camera.request();
      
      if (permissionStatus.isGranted) {
        String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 
          'Huỷ', 
          true, 
          ScanMode.BARCODE
        );
        
        if (barcodeScanRes != '-1') {
          if (showLoading) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text('Đang tìm kiếm thông tin sản phẩm...'),
                  ],
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          final productData = await _fetchNutritionData(barcodeScanRes);
          
          if (productData != null) {
            final foodItem = _convertToFoodItem(productData, barcodeScanRes);
            
            // Xử lý trường hợp khi không có dữ liệu dinh dưỡng
            final bool hasNutritionalData = foodItem.calories > 0 || 
                                           foodItem.protein > 0 || 
                                           foodItem.fat > 0 || 
                                           foodItem.carbs > 0;
            
            if (!hasNutritionalData && productData['dataSource'] == 'Tạo tự động') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Không có dữ liệu dinh dưỡng cho mã vạch: $barcodeScanRes. Dữ liệu cơ bản đã được tạo.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'Tiếp tục',
                    onPressed: () {
                      // Tiếp tục với dữ liệu trống
                    },
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã tìm thấy thông tin sản phẩm: ${foodItem.name}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            
            // Trong mọi trường hợp, vẫn gọi callback để xử lý FoodItem
            onBarcodeScan(foodItem, barcodeScanRes);
          } else {
            // Nếu không tìm thấy dữ liệu, tạo một FoodItem mặc định
            final defaultFoodItem = _createDefaultFoodItem(barcodeScanRes);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Không tìm thấy thông tin chi tiết cho mã vạch: $barcodeScanRes. Đã tạo thông tin cơ bản.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Tiếp tục',
                  onPressed: () {
                    // Người dùng xác nhận
                  },
                ),
              ),
            );
            
            // Vẫn gọi callback để xử lý FoodItem mặc định
            onBarcodeScan(defaultFoodItem, barcodeScanRes);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cần quyền truy cập camera để sử dụng tính năng này'))
        );
      }
    } catch (e) {
      print('Lỗi khi quét mã vạch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể quét mã vạch: $e'))
      );
      
      if (onError != null) {
        onError!('error');
      }
    }
  }
  
  // Tạo FoodItem mặc định khi không có dữ liệu từ API
  FoodItem _createDefaultFoodItem(String barcode) {
    return FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Sản phẩm #$barcode',
      brand: 'Chưa xác định',
      calories: 0,
      protein: 0,
      fat: 0,
      carbs: 0,
      servingSize: 1.0,
      servingUnit: 'khẩu phần',
      fiber: 0,
      sugar: 0,
      sodium: 0,
      imageUrl: '',
      additionalNutrients: {
        'dataSource': 'Tạo tự động',
        'barcode': barcode,
        'note': 'Thêm thông tin dinh dưỡng cho sản phẩm này'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _scanBarcode(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 85,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 2,
              child: Icon(Icons.qr_code_scanner, color: Colors.purple, size: 22),
            ),
            SizedBox(height: 4),
            Flexible(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Mã vạch',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 