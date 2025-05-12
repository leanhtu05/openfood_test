import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/food_entry.dart';
import '../providers/food_provider.dart';
import '../utils/constants.dart';

class FoodHistoryScreen extends StatefulWidget {
  static const routeName = '/food-history';

  @override
  _FoodHistoryScreenState createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends State<FoodHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Tải dữ liệu khi màn hình được khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    await foodProvider.loadFoodEntries();
    await foodProvider.loadFavoriteFoodEntries();
    
    setState(() {
      _isLoading = false;
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch sử bữa ăn'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Gần đây'),
            Tab(text: 'Yêu thích'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFoodEntriesList(),
                _buildFavoriteEntriesList(),
              ],
            ),
    );
  }
  
  Widget _buildFoodEntriesList() {
    final foodProvider = Provider.of<FoodProvider>(context);
    final entries = foodProvider.entries;
    
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Chưa có bữa ăn nào được ghi lại',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    // Nhóm các bữa ăn theo ngày
    final groupedEntries = <String, List<FoodEntry>>{};
    for (var entry in entries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(entry.dateTime);
      if (!groupedEntries.containsKey(dateStr)) {
        groupedEntries[dateStr] = [];
      }
      groupedEntries[dateStr]!.add(entry);
    }
    
    return ListView.builder(
      itemCount: groupedEntries.length,
      itemBuilder: (context, index) {
        final dateStr = groupedEntries.keys.elementAt(index);
        final entriesForDate = groupedEntries[dateStr]!;
        final date = DateTime.parse(dateStr);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _formatDate(date),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            ...entriesForDate.map((entry) => _buildFoodEntryItem(entry)).toList(),
            Divider(thickness: 1),
          ],
        );
      },
    );
  }
  
  Widget _buildFavoriteEntriesList() {
    final foodProvider = Provider.of<FoodProvider>(context);
    final favoriteEntries = foodProvider.favoriteEntries;
    
    if (favoriteEntries.isEmpty) {
      return Center(
        child: Text(
          'Chưa có bữa ăn yêu thích nào',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: favoriteEntries.length,
      itemBuilder: (context, index) {
        return _buildFoodEntryItem(favoriteEntries[index]);
      },
    );
  }
  
  Widget _buildFoodEntryItem(FoodEntry entry) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/food_detail',
            arguments: {'id': entry.id},
          ).then((result) {
            if (result == true) {
              // Nếu trả về true, tức là đã xóa food entry
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã xóa bữa ăn')),
              );
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(entry.dateTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          entry.description,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (entry.calories > 0) ...[
                          SizedBox(height: 4),
                          Text(
                            '${entry.calories} kcal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: entry.isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () {
                      foodProvider.toggleFavorite(entry.id, !entry.isFavorite);
                    },
                  ),
                ],
              ),
              if (entry.imagePath != null && entry.imagePath!.isNotEmpty) ...[
                SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(entry.imagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (entry.audioPath != null && entry.audioPath!.isNotEmpty) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.audiotrack, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Ghi âm'),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: () {
                        // TODO: Phát audio
                      },
                    ),
                  ],
                ),
              ],
              if (entry.barcode != null && entry.barcode!.isNotEmpty) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.qr_code, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Mã sản phẩm: ${entry.barcode}'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      return 'Hôm nay';
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return 'Hôm qua';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
  
  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }
} 