import 'package:flutter_test/flutter_test.dart';
import 'package:openfood/services/finance_agent_service.dart';
import 'package:openfood/models/grocery_cost_analysis.dart';
import 'package:openfood/screens/grocery_list_screen.dart';
import 'package:openfood/utils/currency_formatter.dart';

void main() {
  group('AI Finance Agent Tests', () {
    test('Tính toán chi phí thịt bò chính xác', () {
      final item = GroceryItem(
        name: 'Thịt bò',
        amount: '500',
        unit: 'g',
        category: '🥩 Thịt tươi sống',
      );

      final cost = FinanceAgentService.calculateItemCost(item);
      
      // 500g thịt bò = 0.5kg * 350,000 VND/kg = 175,000 VND
      expect(cost, equals(175000.0));
    });

    test('Tính toán chi phí rau củ chính xác', () {
      final item = GroceryItem(
        name: 'Cà chua',
        amount: '300',
        unit: 'g',
        category: '🥬 Rau củ quả',
      );

      final cost = FinanceAgentService.calculateItemCost(item);
      
      // 300g cà chua = 0.3kg * 25,000 VND/kg = 7,500 VND
      expect(cost, equals(7500.0));
    });

    test('Tính toán chi phí trứng gà chính xác', () {
      final item = GroceryItem(
        name: 'Trứng gà',
        amount: '6',
        unit: 'quả',
        category: '🥛 Sản phẩm từ sữa',
      );

      final cost = FinanceAgentService.calculateItemCost(item);
      
      // 6 quả trứng * 4,000 VND/quả = 24,000 VND
      expect(cost, equals(24000.0));
    });

    test('Phân tích chi phí danh sách mua sắm', () async {
      final groceryItems = <String, GroceryItem>{
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
        'trứng gà': GroceryItem(
          name: 'Trứng gà',
          amount: '6',
          unit: 'quả',
          category: '🥛 Sản phẩm từ sữa',
        ),
      };

      final analysis = await FinanceAgentService.analyzeCosts(
        groceryItems,
        budgetLimit: 300000,
      );

      // Kiểm tra tổng chi phí
      final expectedTotal = 175000 + 7500 + 24000; // 206,500 VND
      expect(analysis.totalCost, equals(expectedTotal));

      // Kiểm tra số lượng danh mục
      expect(analysis.categoryBreakdown.length, equals(3));

      // Kiểm tra ngân sách
      expect(analysis.budgetComparison.budgetLimit, equals(300000));
      expect(analysis.budgetComparison.isOverBudget, isFalse);

      // Kiểm tra có mẹo tiết kiệm
      expect(analysis.savingTips.isNotEmpty, isTrue);
    });

    test('Cảnh báo vượt ngân sách', () async {
      final groceryItems = <String, GroceryItem>{
        'thịt bò': GroceryItem(
          name: 'Thịt bò',
          amount: '2',
          unit: 'kg',
          category: '🥩 Thịt tươi sống',
        ),
      };

      final analysis = await FinanceAgentService.analyzeCosts(
        groceryItems,
        budgetLimit: 500000, // 500k VND
      );

      // 2kg thịt bò = 2 * 350,000 = 700,000 VND > 500,000 VND
      expect(analysis.budgetComparison.isOverBudget, isTrue);
      expect(analysis.budgetComparison.difference, greaterThan(0));
    });

    test('Phân tích danh mục chính xác', () async {
      final groceryItems = <String, GroceryItem>{
        'thịt bò': GroceryItem(
          name: 'Thịt bò',
          amount: '500',
          unit: 'g',
          category: '🥩 Thịt tươi sống',
        ),
        'thịt gà': GroceryItem(
          name: 'Thịt gà',
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
      };

      final analysis = await FinanceAgentService.analyzeCosts(
        groceryItems,
        budgetLimit: 500000,
      );

      // Kiểm tra danh mục thịt
      final meatCategory = analysis.categoryBreakdown['🥩 Thịt tươi sống'];
      expect(meatCategory, isNotNull);
      expect(meatCategory!.itemCount, equals(2));
      
      // Thịt bò 500g = 175,000 + Thịt gà 500g = 60,000 = 235,000 VND
      expect(meatCategory.totalCost, equals(235000.0));

      // Kiểm tra danh mục rau củ
      final vegetableCategory = analysis.categoryBreakdown['🥬 Rau củ quả'];
      expect(vegetableCategory, isNotNull);
      expect(vegetableCategory!.itemCount, equals(1));
      expect(vegetableCategory.totalCost, equals(7500.0));
    });

    test('Tạo mẹo tiết kiệm phù hợp', () async {
      final groceryItems = <String, GroceryItem>{
        'thịt bò': GroceryItem(
          name: 'Thịt bò',
          amount: '1',
          unit: 'kg',
          category: '🥩 Thịt tươi sống',
        ),
      };

      final analysis = await FinanceAgentService.analyzeCosts(
        groceryItems,
        budgetLimit: 500000,
      );

      // Kiểm tra có mẹo tiết kiệm
      expect(analysis.savingTips.isNotEmpty, isTrue);
      
      // Mẹo đầu tiên nên liên quan đến danh mục đắt nhất
      final firstTip = analysis.savingTips.first;
      expect(firstTip.title.contains('🥩 Thịt tươi sống'), isTrue);
      expect(firstTip.potentialSaving, greaterThan(0));
    });

    test('Cảnh báo giá cao', () async {
      final groceryItems = <String, GroceryItem>{
        'thịt bò': GroceryItem(
          name: 'Thịt bò',
          amount: '1',
          unit: 'kg',
          category: '🥩 Thịt tươi sống',
        ),
      };

      final analysis = await FinanceAgentService.analyzeCosts(
        groceryItems,
        budgetLimit: 500000,
      );

      // Thịt bò 1kg = 350,000 VND > 100,000 VND threshold
      expect(analysis.priceAlerts.isNotEmpty, isTrue);
      
      final alert = analysis.priceAlerts.first;
      expect(alert.itemName, equals('Thịt bò'));
      expect(alert.alertType, equals('high'));
    });

    test('Xử lý danh sách rỗng', () async {
      final analysis = await FinanceAgentService.analyzeCosts(
        {},
        budgetLimit: 500000,
      );

      expect(analysis.totalCost, equals(0));
      expect(analysis.averageCostPerItem, equals(0));
      expect(analysis.categoryBreakdown.isEmpty, isTrue);
      expect(analysis.budgetComparison.isOverBudget, isFalse);
    });

    // Test này sẽ được thực hiện gián tiếp thông qua calculateItemCost
    test('Tính toán với số lượng khác nhau', () {
      final item1 = GroceryItem(
        name: 'Cà chua',
        amount: '1.5',
        unit: 'kg',
        category: '🥬 Rau củ quả',
      );

      final cost1 = FinanceAgentService.calculateItemCost(item1);
      expect(cost1, equals(37500.0)); // 1.5kg * 25,000 = 37,500
    });
  });

  group('Currency Formatter Tests', () {
    test('Format VND chính xác', () {
      expect(CurrencyFormatter.formatVND(175000), equals('175.000₫'));
      expect(CurrencyFormatter.formatVND(0), equals('0₫'));
      expect(CurrencyFormatter.formatVND(1000000), equals('1.000.000₫'));
    });

    test('Format VND compact', () {
      expect(CurrencyFormatter.formatVNDCompact(175000), contains('175'));
      expect(CurrencyFormatter.formatVNDCompact(1000000), contains('1M'));
    });

    test('Parse VND string', () {
      expect(CurrencyFormatter.parseVND('175.000₫'), equals(175000));
      expect(CurrencyFormatter.parseVND('1.000.000₫'), equals(1000000));
    });
  });
}
