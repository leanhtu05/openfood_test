import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _vndFormatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat _compactFormatter = NumberFormat.compact(
    locale: 'vi_VN',
  );

  /// Format số tiền VND với ký hiệu ₫
  static String formatVND(double amount) {
    if (amount == 0) return '0₫';
    return _vndFormatter.format(amount);
  }

  /// Format số tiền VND dạng compact (1K, 1M, etc.)
  static String formatVNDCompact(double amount) {
    if (amount == 0) return '0₫';
    return '${_compactFormatter.format(amount)}₫';
  }

  /// Format số tiền không có ký hiệu
  static String formatNumber(double amount) {
    return NumberFormat('#,###', 'vi_VN').format(amount);
  }

  /// Parse chuỗi tiền tệ thành số
  static double parseVND(String amountStr) {
    // Loại bỏ ký hiệu tiền tệ và dấu phẩy
    String cleanStr = amountStr
        .replaceAll('₫', '')
        .replaceAll(',', '')
        .replaceAll('.', '')
        .trim();
    
    return double.tryParse(cleanStr) ?? 0.0;
  }

  /// Kiểm tra xem số tiền có lớn không (để hiển thị cảnh báo)
  static bool isHighAmount(double amount, {double threshold = 100000}) {
    return amount > threshold;
  }

  /// Tính phần trăm
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }

  /// Format số tiền với màu sắc (cho UI)
  static Map<String, dynamic> formatWithColor(double amount, {double budgetLimit = 500000}) {
    final isOverBudget = amount > budgetLimit;
    final percentage = budgetLimit > 0 ? (amount / budgetLimit) * 100 : 0;
    
    String color;
    if (percentage <= 50) {
      color = 'green';
    } else if (percentage <= 80) {
      color = 'orange';
    } else {
      color = 'red';
    }
    
    return {
      'formatted': formatVND(amount),
      'color': color,
      'isOverBudget': isOverBudget,
      'percentage': percentage,
    };
  }
}
