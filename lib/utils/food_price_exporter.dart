import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/grocery_cost_analysis.dart';
import '../services/vietnamese_food_price_service.dart';

/// Utility class để export dữ liệu giá cả ra các format khác nhau
class FoodPriceExporter {
  final VietnameseFoodPriceService _priceService = VietnameseFoodPriceService();

  /// Export dữ liệu giá cả ra JSON
  Future<String> exportToJson() async {
    try {
      final prices = await _priceService.getAllPrices();
      final stats = await _priceService.getPriceStatistics();
      
      final exportData = {
        'export_info': {
          'exported_at': DateTime.now().toIso8601String(),
          'total_items': prices.length,
          'format': 'JSON',
          'version': '1.0',
        },
        'food_prices': prices,
        'statistics': stats,
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      // Lưu file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/vietnamese_food_prices_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);
      
      return file.path;
    } catch (e) {
      throw Exception('Lỗi export JSON: $e');
    }
  }

  /// Export dữ liệu giá cả ra CSV
  Future<String> exportToCsv() async {
    try {
      final prices = await _priceService.getAllPrices();
      
      final csvLines = <String>[];
      
      // Header
      csvLines.add('Tên thực phẩm,Danh mục,Đơn vị,Giá (VND),Loại giá,Ngày cập nhật');
      
      // Data rows
      prices.forEach((foodName, priceData) {
        final category = priceData['category'] ?? '';
        final unit = priceData['unit'] ?? '';
        
        String price = '';
        String priceType = '';
        
        if (priceData.containsKey('price_per_kg')) {
          price = priceData['price_per_kg'].toString();
          priceType = 'per_kg';
        } else if (priceData.containsKey('price_per_liter')) {
          price = priceData['price_per_liter'].toString();
          priceType = 'per_liter';
        } else if (priceData.containsKey('price_per_unit')) {
          price = priceData['price_per_unit'].toString();
          priceType = 'per_unit';
        }
        
        final row = [
          _escapeCsvField(foodName),
          _escapeCsvField(category),
          _escapeCsvField(unit),
          price,
          priceType,
          DateTime.now().toIso8601String(),
        ].join(',');
        
        csvLines.add(row);
      });
      
      final csvContent = csvLines.join('\n');
      
      // Lưu file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/vietnamese_food_prices_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent, encoding: utf8);
      
      return file.path;
    } catch (e) {
      throw Exception('Lỗi export CSV: $e');
    }
  }

  /// Export báo cáo phân tích chi phí grocery
  Future<String> exportGroceryAnalysisReport(GroceryCostAnalysis analysis) async {
    try {
      final reportData = {
        'report_info': {
          'generated_at': DateTime.now().toIso8601String(),
          'analysis_date': analysis.analysisDate.toIso8601String(),
          'report_type': 'Grocery Cost Analysis',
          'version': '1.0',
        },
        'cost_summary': {
          'total_cost': analysis.totalCost,
          'average_cost_per_item': analysis.averageCostPerItem,
          'currency': 'VND',
        },
        'budget_comparison': {
          'budget_limit': analysis.budgetComparison.budgetLimit,
          'actual_cost': analysis.budgetComparison.actualCost,
          'difference': analysis.budgetComparison.difference,
          'is_over_budget': analysis.budgetComparison.isOverBudget,
          'percentage_used': analysis.budgetComparison.percentageUsed,
        },
        'category_breakdown': analysis.categoryBreakdown.map((key, value) => MapEntry(key, {
          'category_name': value.categoryName,
          'total_cost': value.totalCost,
          'percentage': value.percentage,
          'item_count': value.itemCount,
          'average_cost_per_item': value.averageCostPerItem,
          'top_expensive_items': value.topExpensiveItems,
        })),
        'saving_tips': analysis.savingTips.map((tip) => {
          'title': tip.title,
          'description': tip.description,
          'potential_saving': tip.potentialSaving,
          'category': tip.category,
          'priority': tip.priority,
        }).toList(),
        'price_alerts': analysis.priceAlerts.map((alert) => {
          'item_name': alert.itemName,
          'current_price': alert.currentPrice,
          'average_price': alert.averagePrice,
          'price_change': alert.priceChange,
          'alert_type': alert.alertType,
          'message': alert.message,
        }).toList(),
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(reportData);
      
      // Lưu file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/grocery_analysis_report_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);
      
      return file.path;
    } catch (e) {
      throw Exception('Lỗi export báo cáo: $e');
    }
  }

  /// Export danh sách grocery với chi phí ra CSV
  Future<String> exportGroceryListToCsv(List<GroceryItemWithCost> groceryItems) async {
    try {
      final csvLines = <String>[];
      
      // Header
      csvLines.add('Tên mặt hàng,Số lượng,Đơn vị,Danh mục,Giá đơn vị (VND),Chi phí ước tính (VND),Đã mua');
      
      // Data rows
      for (final item in groceryItems) {
        final row = [
          _escapeCsvField(item.name),
          item.amount,
          _escapeCsvField(item.unit),
          _escapeCsvField(item.category),
          item.pricePerUnit.toStringAsFixed(0),
          item.estimatedCost.toStringAsFixed(0),
          item.isChecked ? 'Có' : 'Không',
        ].join(',');
        
        csvLines.add(row);
      }
      
      // Tổng kết
      final totalCost = groceryItems.fold<double>(0.0, (sum, item) => sum + item.estimatedCost);
      csvLines.add('');
      csvLines.add('TỔNG KẾT');
      csvLines.add('Tổng số mặt hàng,${groceryItems.length}');
      csvLines.add('Tổng chi phí ước tính,${totalCost.toStringAsFixed(0)} VND');
      csvLines.add('Ngày tạo,${DateTime.now().toIso8601String()}');
      
      final csvContent = csvLines.join('\n');
      
      // Lưu file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/grocery_list_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent, encoding: utf8);
      
      return file.path;
    } catch (e) {
      throw Exception('Lỗi export danh sách grocery: $e');
    }
  }

  /// Export thống kê giá cả theo danh mục
  Future<String> exportCategoryStatistics() async {
    try {
      final stats = await _priceService.getPriceStatistics();
      final categoryStats = stats['category_stats'] as Map<String, dynamic>? ?? {};
      
      final csvLines = <String>[];
      
      // Header
      csvLines.add('Danh mục,Số lượng mặt hàng,Giá trung bình (VND),Giá thấp nhất (VND),Giá cao nhất (VND),Giá trung vị (VND)');
      
      // Data rows
      categoryStats.forEach((category, data) {
        final categoryData = data as Map<String, dynamic>;
        final row = [
          _escapeCsvField(category),
          categoryData['count']?.toInt().toString() ?? '0',
          categoryData['average']?.toStringAsFixed(0) ?? '0',
          categoryData['min']?.toStringAsFixed(0) ?? '0',
          categoryData['max']?.toStringAsFixed(0) ?? '0',
          categoryData['median']?.toStringAsFixed(0) ?? '0',
        ].join(',');
        
        csvLines.add(row);
      });
      
      // Tổng kết
      csvLines.add('');
      csvLines.add('TỔNG KẾT');
      csvLines.add('Tổng số danh mục,${categoryStats.length}');
      csvLines.add('Tổng số mặt hàng,${stats['total_items']?.toInt() ?? 0}');
      csvLines.add('Giá trung bình tổng thể,${stats['average_price']?.toStringAsFixed(0) ?? 0} VND');
      csvLines.add('Ngày tạo báo cáo,${DateTime.now().toIso8601String()}');
      
      final csvContent = csvLines.join('\n');
      
      // Lưu file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/category_statistics_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent, encoding: utf8);
      
      return file.path;
    } catch (e) {
      throw Exception('Lỗi export thống kê danh mục: $e');
    }
  }

  /// Export template để import dữ liệu mới
  Future<String> exportImportTemplate() async {
    try {
      final csvLines = <String>[];
      
      // Header với hướng dẫn
      csvLines.add('# Template để import dữ liệu giá cả thực phẩm');
      csvLines.add('# Các cột bắt buộc: Tên thực phẩm, Danh mục, Đơn vị, Giá, Loại giá');
      csvLines.add('# Loại giá có thể là: price_per_kg, price_per_liter, price_per_unit');
      csvLines.add('# Xóa các dòng comment này trước khi import');
      csvLines.add('');
      csvLines.add('Tên thực phẩm,Danh mục,Đơn vị,Giá (VND),Loại giá');
      
      // Một số ví dụ
      csvLines.add('thịt bò,🥩 Thịt tươi sống,kg,350000,price_per_kg');
      csvLines.add('cà chua,🥬 Rau củ quả,kg,25000,price_per_kg');
      csvLines.add('sữa tươi,🥛 Sữa & Trứng,lít,30000,price_per_liter');
      csvLines.add('trứng gà,🥛 Sữa & Trứng,quả,4000,price_per_unit');
      
      final csvContent = csvLines.join('\n');
      
      // Lưu file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/food_price_import_template.csv');
      await file.writeAsString(csvContent, encoding: utf8);
      
      return file.path;
    } catch (e) {
      throw Exception('Lỗi tạo template: $e');
    }
  }

  /// Escape CSV field để tránh lỗi với dấu phẩy và quotes
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Format currency cho display
  String formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}₫';
  }

  /// Lấy thông tin file đã export
  Future<Map<String, dynamic>> getExportInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stats = await file.stat();
      
      return {
        'file_path': filePath,
        'file_name': file.path.split('/').last,
        'file_size': stats.size,
        'created_at': stats.changed.toIso8601String(),
        'exists': await file.exists(),
      };
    } catch (e) {
      return {
        'error': 'Không thể lấy thông tin file: $e',
      };
    }
  }

  /// Import dữ liệu từ CSV template
  Future<void> importFromCsv(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString(encoding: utf8);
      final lines = content.split('\n');
      
      // Bỏ qua header và comment lines
      final dataLines = lines.where((line) => 
        line.trim().isNotEmpty && 
        !line.startsWith('#') && 
        !line.startsWith('Tên thực phẩm')
      ).toList();
      
      for (final line in dataLines) {
        final fields = _parseCsvLine(line);
        if (fields.length >= 5) {
          final foodName = fields[0].trim();
          final category = fields[1].trim();
          final unit = fields[2].trim();
          final price = double.tryParse(fields[3].trim()) ?? 0.0;
          final priceType = fields[4].trim();
          
          if (foodName.isNotEmpty && price > 0) {
            final priceData = {
              'category': category,
              'unit': unit,
              priceType: price,
            };
            
            await _priceService.addNewFood(foodName, priceData);
          }
        }
      }
    } catch (e) {
      throw Exception('Lỗi import từ CSV: $e');
    }
  }

  /// Parse CSV line với xử lý quotes
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    fields.add(buffer.toString());
    return fields;
  }
}
