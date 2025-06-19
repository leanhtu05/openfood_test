import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/vietnamese_food_price_service.dart';
import '../models/grocery_cost_analysis.dart';

class PriceContributionScreen extends StatefulWidget {
  final String? initialFoodName;
  
  const PriceContributionScreen({Key? key, this.initialFoodName}) : super(key: key);

  @override
  State<PriceContributionScreen> createState() => _PriceContributionScreenState();
}

class _PriceContributionScreenState extends State<PriceContributionScreen> {
  final VietnameseFoodPriceService _priceService = VietnameseFoodPriceService();
  final _formKey = GlobalKey<FormState>();
  
  final _foodNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _storeNameController = TextEditingController();
  
  String _selectedPriceType = 'price_per_kg';
  String? _selectedCategory;
  List<String> _categories = [];
  bool _isSubmitting = false;
  XFile? _pricePhoto;
  
  final Map<String, String> _priceTypeLabels = {
    'price_per_kg': 'Giá/kg',
    'price_per_liter': 'Giá/lít',
    'price_per_unit': 'Giá/đơn vị',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialFoodName != null) {
      _foodNameController.text = widget.initialFoodName!;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _priceService.getAllCategories();
    setState(() {
      _categories = categories;
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _pricePhoto = image;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi chụp ảnh: $e');
    }
  }

  Future<void> _submitContribution() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      await _priceService.submitUserPriceContribution(
        foodName: _foodNameController.text.trim(),
        price: double.parse(_priceController.text),
        priceType: _selectedPriceType,
        location: _locationController.text.trim(),
        storeName: _storeNameController.text.trim(),
        userId: 'current_user_id', // TODO: Get from auth
        userName: 'Current User', // TODO: Get from auth
        photoUrl: _pricePhoto?.path,
      );
      
      _showSuccessSnackBar('✅ Đã gửi đóng góp giá cả thành công!');
      Navigator.pop(context, true);
      
    } catch (e) {
      _showErrorSnackBar('❌ Lỗi gửi đóng góp: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đóng góp Giá cả'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Đóng góp Giá cả',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Giúp cộng đồng có thông tin giá cả chính xác nhất bằng cách chia sẻ giá bạn mua được.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Food name
              TextFormField(
                controller: _foodNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên thực phẩm *',
                  hintText: 'VD: thịt bò, cà chua, gạo tẻ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.food_bank),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên thực phẩm';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Price and type
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá *',
                        hintText: '25000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        suffixText: 'VND',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập giá';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Giá không hợp lệ';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriceType,
                      decoration: const InputDecoration(
                        labelText: 'Đơn vị',
                        border: OutlineInputBorder(),
                      ),
                      items: _priceTypeLabels.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedPriceType = value!);
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Category
              if (_categories.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                ),
              
              const SizedBox(height: 16),
              
              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Địa điểm *',
                  hintText: 'VD: Quận 1, TP.HCM',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập địa điểm';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Store name
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên cửa hàng *',
                  hintText: 'VD: Chợ Bến Thành, Coopmart',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên cửa hàng';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Photo section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ảnh chứng minh (Tùy chọn)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chụp ảnh bảng giá hoặc hóa đơn để tăng độ tin cậy',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_pricePhoto != null)
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _pricePhoto!.path,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.image, size: 50),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Chưa có ảnh', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt),
                              label: Text(_pricePhoto != null ? 'Chụp lại' : 'Chụp ảnh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          if (_pricePhoto != null) ...[
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _pricePhoto = null),
                              icon: const Icon(Icons.delete),
                              label: const Text('Xóa'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitContribution,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
                          'Gửi đóng góp',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Terms
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Bằng cách gửi đóng góp, bạn đồng ý rằng thông tin này sẽ được xem xét và có thể được sử dụng để cập nhật giá cả trong ứng dụng.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
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
    _foodNameController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _storeNameController.dispose();
    super.dispose();
  }
}
