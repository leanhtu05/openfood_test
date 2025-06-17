import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/currency_formatter.dart';
import '../../services/real_price_service.dart';

class PriceInputDialog extends StatefulWidget {
  final String itemName;
  final String currentAmount;
  final String currentUnit;
  final double estimatedPrice;
  final Function(double newPrice) onPriceUpdated;

  const PriceInputDialog({
    Key? key,
    required this.itemName,
    required this.currentAmount,
    required this.currentUnit,
    required this.estimatedPrice,
    required this.onPriceUpdated,
  }) : super(key: key);

  @override
  _PriceInputDialogState createState() => _PriceInputDialogState();
}

class _PriceInputDialogState extends State<PriceInputDialog> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;
  String _selectedStore = 'Chợ truyền thống';
  
  final List<String> _storeTypes = [
    'Chợ truyền thống',
    'Siêu thị',
    'Cửa hàng tiện lợi',
    'Mua online',
    'Khác',
  ];

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.estimatedPrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue.shade600),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cập nhật giá thực tế',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin sản phẩm
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.itemName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Số lượng: ${widget.currentAmount} ${widget.currentUnit}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Giá ước tính: ${CurrencyFormatter.formatVND(widget.estimatedPrice)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            
            // Nhập giá thực tế
            Text(
              'Giá thực tế bạn mua:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Nhập giá (VND)',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'VND',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade600),
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Chọn loại cửa hàng
            Text(
              'Nơi mua:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedStore,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade600),
                ),
              ),
              items: _storeTypes.map((store) {
                return DropdownMenuItem(
                  value: store,
                  child: Text(store),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStore = value!;
                });
              },
            ),
            SizedBox(height: 16),
            
            // Nhập địa điểm (tùy chọn)
            Text(
              'Địa điểm (tùy chọn):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'VD: Quận 1, TP.HCM',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade600),
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Thông báo
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber.shade600, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thông tin này sẽ giúp cải thiện độ chính xác của hệ thống cho tất cả người dùng.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updatePrice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Cập nhật'),
        ),
      ],
    );
  }

  Future<void> _updatePrice() async {
    final priceText = _priceController.text.trim();
    if (priceText.isEmpty) {
      _showError('Vui lòng nhập giá');
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      _showError('Giá không hợp lệ');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Cập nhật giá lên server (nếu có)
      final success = await RealPriceService.updateUserPrice(
        itemName: widget.itemName,
        price: price,
        unit: widget.currentUnit,
        location: _locationController.text.trim().isNotEmpty 
            ? _locationController.text.trim() 
            : _selectedStore,
        userId: 'current_user', // Thay bằng user ID thực tế
      );

      if (success) {
        // Cập nhật giá trong ứng dụng
        widget.onPriceUpdated(price);
        
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật giá thành công!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else {
        _showError('Không thể cập nhật giá. Vui lòng thử lại.');
      }
    } catch (e) {
      _showError('Có lỗi xảy ra: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
