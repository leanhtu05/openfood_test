import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/food_entry.dart';
import '../providers/food_provider.dart';
import '../services/food_service.dart';

class FoodDetailScreen extends StatefulWidget {
  final String id;

  const FoodDetailScreen({Key? key, required this.id}) : super(key: key);

  @override
  _FoodDetailScreenState createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  bool _isLoading = true;
  FoodEntry? _foodEntry;
  final FoodService _foodService = FoodService();

  @override
  void initState() {
    super.initState();
    _loadFoodEntry();
  }

  Future<void> _loadFoodEntry() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entry = await _foodService.getFoodEntryById(widget.id);
      setState(() {
        _foodEntry = entry;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải thông tin: ${e.toString()}')),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    if (_foodEntry == null) return;

    try {
      final newIsFavorite = !_foodEntry!.isFavorite;
      await _foodService.toggleFavorite(_foodEntry!.id, newIsFavorite);

      setState(() {
        _foodEntry = _foodEntry!.copyWith(isFavorite: newIsFavorite);
      });

      // Cập nhật provider
      Provider.of<FoodProvider>(context, listen: false).updateFoodEntryInList(_foodEntry!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newIsFavorite 
            ? 'Đã thêm vào yêu thích' 
            : 'Đã xóa khỏi yêu thích'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteFoodEntry() async {
    if (_foodEntry == null) return;

    try {
      await _foodService.deleteFoodEntry(_foodEntry!.id);
      // Cập nhật provider
      Provider.of<FoodProvider>(context, listen: false).removeFoodEntry(_foodEntry!.id);
      Navigator.pop(context, true); // Trả về true để thông báo đã xóa thành công
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết bữa ăn'),
        actions: [
          if (_foodEntry != null) ...[
            IconButton(
              icon: Icon(
                _foodEntry!.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _foodEntry!.isFavorite ? Colors.red : null,
              ),
              onPressed: _toggleFavorite,
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Xác nhận xóa'),
                    content: Text('Bạn có chắc muốn xóa bữa ăn này không?'),
                    actions: [
                      TextButton(
                        child: Text('Hủy'),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      TextButton(
                        child: Text('Xóa'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _deleteFoodEntry();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _foodEntry == null
              ? Center(child: Text('Không tìm thấy thông tin bữa ăn'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_foodEntry!.imagePath != null && _foodEntry!.imagePath!.isNotEmpty) ...[
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_foodEntry!.imagePath!),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                      Text(
                        _foodEntry!.description,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ngày: ${DateFormat('dd/MM/yyyy - HH:mm').format(_foodEntry!.dateTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thông tin dinh dưỡng',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Calo',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '${_foodEntry!.calories} kcal',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Thêm các thông tin dinh dưỡng khác nếu có
                              if (_foodEntry!.nutritionInfo != null) ...[
                                SizedBox(height: 16),
                                Text(
                                  'Thông tin chi tiết',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _foodEntry!.nutritionInfo.toString(),
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      if (_foodEntry!.barcode != null && _foodEntry!.barcode!.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mã vạch',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _foodEntry!.barcode!,
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
} 