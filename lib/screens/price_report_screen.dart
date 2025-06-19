import 'package:flutter/material.dart';
import '../services/vietnamese_food_price_service.dart';

class PriceReportScreen extends StatefulWidget {
  final String foodName;
  final Map<String, dynamic> currentPriceData;
  
  const PriceReportScreen({
    Key? key,
    required this.foodName,
    required this.currentPriceData,
  }) : super(key: key);

  @override
  State<PriceReportScreen> createState() => _PriceReportScreenState();
}

class _PriceReportScreenState extends State<PriceReportScreen> {
  final VietnameseFoodPriceService _priceService = VietnameseFoodPriceService();
  final _formKey = GlobalKey<FormState>();
  
  final _suggestedPriceController = TextEditingController();
  final _reasonController = TextEditingController();
  
  String _selectedReason = 'Giá quá cao';
  bool _isSubmitting = false;
  
  final List<String> _reportReasons = [
    'Giá quá cao',
    'Giá quá thấp',
    'Không còn bán với giá này',
    'Giá đã thay đổi',
    'Thông tin sai lệch',
    'Khác',
  ];

  double get _currentPrice {
    if (widget.currentPriceData.containsKey('price_per_kg')) {
      return widget.currentPriceData['price_per_kg'].toDouble();
    } else if (widget.currentPriceData.containsKey('price_per_liter')) {
      return widget.currentPriceData['price_per_liter'].toDouble();
    } else if (widget.currentPriceData.containsKey('price_per_unit')) {
      return widget.currentPriceData['price_per_unit'].toDouble();
    }
    return 0.0;
  }

  String get _priceUnit {
    if (widget.currentPriceData.containsKey('price_per_kg')) {
      return '/kg';
    } else if (widget.currentPriceData.containsKey('price_per_liter')) {
      return '/lít';
    } else if (widget.currentPriceData.containsKey('price_per_unit')) {
      return '/${widget.currentPriceData['unit'] ?? 'đơn vị'}';
    }
    return '';
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final suggestedPrice = double.tryParse(_suggestedPriceController.text) ?? 0.0;
      final reason = _selectedReason == 'Khác' 
          ? _reasonController.text.trim()
          : _selectedReason;
      
      await _priceService.reportIncorrectPrice(
        foodName: widget.foodName,
        reason: reason,
        suggestedPrice: suggestedPrice,
        userId: 'current_user_id', // TODO: Get from auth
        userName: 'Current User', // TODO: Get from auth
      );
      
      _showSuccessSnackBar('✅ Đã gửi báo cáo thành công!');
      Navigator.pop(context, true);
      
    } catch (e) {
      _showErrorSnackBar('❌ Lỗi gửi báo cáo: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
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
        title: const Text('Báo cáo Giá sai'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current price info
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Thông tin hiện tại',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Thực phẩm: '),
                          Text(
                            widget.foodName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Giá hiện tại: '),
                          Text(
                            '${_formatCurrency(_currentPrice)}$_priceUnit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Danh mục: '),
                          Text(
                            widget.currentPriceData['category'] ?? 'N/A',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Report reason
              const Text(
                'Lý do báo cáo *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.report_problem),
                ),
                items: _reportReasons.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(reason),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedReason = value!);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng chọn lý do';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Custom reason if "Khác" is selected
              if (_selectedReason == 'Khác') ...[
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả chi tiết *',
                    hintText: 'Vui lòng mô tả lý do báo cáo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (_selectedReason == 'Khác' && (value == null || value.trim().isEmpty)) {
                      return 'Vui lòng mô tả lý do';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              // Suggested price
              const Text(
                'Giá đề xuất',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _suggestedPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Giá đề xuất',
                  hintText: 'VD: 25000',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: 'VND$_priceUnit',
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Giá không hợp lệ';
                    }
                    final price = double.parse(value);
                    if (price <= 0) {
                      return 'Giá phải lớn hơn 0';
                    }
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
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
                          'Thông tin quan trọng',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Báo cáo của bạn sẽ được xem xét bởi đội ngũ quản trị\n'
                      '• Nếu báo cáo chính xác, giá sẽ được cập nhật\n'
                      '• Bạn có thể đóng góp giá mới thông qua tính năng "Đóng góp giá"\n'
                      '• Thông tin báo cáo sẽ được bảo mật',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
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
                            Text('Đang gửi...'),
                          ],
                        )
                      : const Text(
                          'Gửi báo cáo',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Alternative action
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Navigate to price contribution screen
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Đóng góp giá mới thay vì báo cáo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _suggestedPriceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}
