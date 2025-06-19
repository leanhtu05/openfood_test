import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../utils/food_price_exporter.dart';
import '../models/grocery_cost_analysis.dart';

class FoodPriceExportScreen extends StatefulWidget {
  const FoodPriceExportScreen({Key? key}) : super(key: key);

  @override
  State<FoodPriceExportScreen> createState() => _FoodPriceExportScreenState();
}

class _FoodPriceExportScreenState extends State<FoodPriceExportScreen> {
  final FoodPriceExporter _exporter = FoodPriceExporter();
  bool _isExporting = false;
  List<Map<String, dynamic>> _exportHistory = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export/Import Dữ liệu Giá cả'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export Section
            _buildExportSection(),
            
            const SizedBox(height: 24),
            
            // Import Section
            _buildImportSection(),
            
            const SizedBox(height: 24),
            
            // Export History
            _buildExportHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📤 Export Dữ liệu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Export All Prices to JSON
            _buildExportButton(
              title: 'Export tất cả giá cả (JSON)',
              description: 'Xuất toàn bộ dữ liệu giá cả và thống kê ra file JSON',
              icon: Icons.code,
              color: Colors.green,
              onPressed: _isExporting ? null : () => _exportToJson(),
            ),
            
            const SizedBox(height: 12),
            
            // Export All Prices to CSV
            _buildExportButton(
              title: 'Export tất cả giá cả (CSV)',
              description: 'Xuất toàn bộ dữ liệu giá cả ra file CSV để xem trong Excel',
              icon: Icons.table_chart,
              color: Colors.blue,
              onPressed: _isExporting ? null : () => _exportToCsv(),
            ),
            
            const SizedBox(height: 12),
            
            // Export Category Statistics
            _buildExportButton(
              title: 'Export thống kê danh mục (CSV)',
              description: 'Xuất thống kê giá cả theo từng danh mục thực phẩm',
              icon: Icons.analytics,
              color: Colors.orange,
              onPressed: _isExporting ? null : () => _exportCategoryStats(),
            ),
            
            const SizedBox(height: 12),
            
            // Export Sample Grocery List
            _buildExportButton(
              title: 'Export danh sách grocery mẫu (CSV)',
              description: 'Xuất danh sách grocery mẫu với tính toán chi phí',
              icon: Icons.shopping_cart,
              color: Colors.purple,
              onPressed: _isExporting ? null : () => _exportSampleGroceryList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📥 Import Dữ liệu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Download Template
            _buildExportButton(
              title: 'Tải template import (CSV)',
              description: 'Tải file template để thêm dữ liệu giá cả mới',
              icon: Icons.download,
              color: Colors.teal,
              onPressed: _isExporting ? null : () => _downloadTemplate(),
            ),
            
            const SizedBox(height: 12),
            
            // Import Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Hướng dẫn Import',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Tải template CSV ở trên\n'
                    '2. Mở file bằng Excel hoặc Google Sheets\n'
                    '3. Thêm dữ liệu theo format mẫu\n'
                    '4. Lưu file và import vào ứng dụng\n'
                    '5. Dữ liệu sẽ được tự động đồng bộ lên Firebase',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 Lịch sử Export',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_exportHistory.isEmpty)
              const Text(
                'Chưa có file nào được export.',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ..._exportHistory.map((export) => _buildExportHistoryItem(export)),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (_isExporting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildExportHistoryItem(Map<String, dynamic> export) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.file_present,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  export['file_name'] ?? 'Unknown file',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Kích thước: ${_formatFileSize(export['file_size'] ?? 0)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Tạo lúc: ${_formatDateTime(export['created_at'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareFile(export['file_path']),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToJson() async {
    await _performExport(
      'Export JSON',
      () => _exporter.exportToJson(),
    );
  }

  Future<void> _exportToCsv() async {
    await _performExport(
      'Export CSV',
      () => _exporter.exportToCsv(),
    );
  }

  Future<void> _exportCategoryStats() async {
    await _performExport(
      'Export Category Statistics',
      () => _exporter.exportCategoryStatistics(),
    );
  }

  Future<void> _exportSampleGroceryList() async {
    // Create sample grocery list
    final sampleList = [
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

    await _performExport(
      'Export Sample Grocery List',
      () => _exporter.exportGroceryListToCsv(sampleList),
    );
  }

  Future<void> _downloadTemplate() async {
    await _performExport(
      'Download Template',
      () => _exporter.exportImportTemplate(),
    );
  }

  Future<void> _performExport(String operation, Future<String> Function() exportFunction) async {
    setState(() => _isExporting = true);
    
    try {
      final filePath = await exportFunction();
      final exportInfo = await _exporter.getExportInfo(filePath);
      
      setState(() {
        _exportHistory.insert(0, exportInfo);
        _isExporting = false;
      });
      
      _showSuccessSnackBar('✅ $operation thành công!\nFile: ${exportInfo['file_name']}');
      
      // Auto share file
      await _shareFile(filePath);
      
    } catch (e) {
      setState(() => _isExporting = false);
      _showErrorSnackBar('❌ Lỗi $operation: $e');
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      _showErrorSnackBar('❌ Lỗi chia sẻ file: $e');
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
