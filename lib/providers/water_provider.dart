import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/water_entry.dart';
import '../services/water_service.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';

class WaterProvider with ChangeNotifier {
  final WaterService _waterService = WaterService();
  
  List<WaterEntry> _entries = [];
  int _totalWaterToday = 0;
  DateTime? _lastWaterTime;
  bool _isLoading = false;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  
  // Getters
  List<WaterEntry> get entries => _entries;
  int get totalWaterToday => _totalWaterToday;
  DateTime? get lastWaterTime => _lastWaterTime;
  bool get isLoading => _isLoading;
  bool get hasWaterEntriesForToday => _totalWaterToday > 0;
  String get selectedDate => _selectedDate;
  
  // Mục tiêu nước (có thể được điều chỉnh sau này)
  final int waterGoal = 3700; // mL
  
  // Constructor khởi tạo với dữ liệu sync
  WaterProvider() {
    _loadInitialData();
  }
  
  // Phương thức khởi tạo dữ liệu
  Future<void> _loadInitialData() async {
    _entries = _waterService.getAllEntriesSync();
    _updateTotalWaterForSelectedDate();
    _lastWaterTime = _waterService.getLastWaterTimeSync();
  }
  
  // Cập nhật tổng lượng nước cho ngày đã chọn
  void _updateTotalWaterForSelectedDate() {
    try {
      final selectedDateTime = DateTime.parse(_selectedDate);
      _totalWaterToday = getWaterAmountForDate(selectedDateTime);
    } catch (e) {
      print('Lỗi khi cập nhật tổng lượng nước: $e');
      _totalWaterToday = 0;
    }
  }
  
  // Thay đổi ngày đã chọn
  void setSelectedDate(String date) {
    _selectedDate = date;
    _updateTotalWaterForSelectedDate();
    notifyListeners();
  }
  
  // Tải dữ liệu ban đầu
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Lấy tất cả bản ghi
      _entries = await _waterService.getAllEntries();
      
      // Cập nhật tổng lượng nước cho ngày đã chọn
      _updateTotalWaterForSelectedDate();
      
      // Lấy thời gian lần cuối (sử dụng phiên bản đồng bộ)
      _lastWaterTime = _waterService.getLastWaterTimeSync();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // Thêm bản ghi mới
  Future<void> addWaterEntry(int amount, {DateTime? timestamp}) async {
    await _waterService.addEntry(amount, timestamp: timestamp);
    
    // Cập nhật dữ liệu cục bộ
    _entries = _waterService.getAllEntriesSync();
    _updateTotalWaterForSelectedDate();
    _lastWaterTime = _waterService.getLastWaterTimeSync();
    
    notifyListeners();
  }
  
  // Xóa bản ghi
  Future<void> deleteWaterEntry(String id) async {
    await _waterService.deleteEntry(id);
    
    // Cập nhật dữ liệu cục bộ
    _entries = _waterService.getAllEntriesSync();
    _updateTotalWaterForSelectedDate();
    _lastWaterTime = _waterService.getLastWaterTimeSync();
    
    notifyListeners();
  }
  
  // Tính tổng lượng nước cho ngày hiện tại
  int calculateTotalWaterForToday() {
    final now = DateTime.now();
    return _calculateWaterForDate(now);
  }
  
  // Tính tổng lượng nước cho ngày cụ thể
  int _calculateWaterForDate(DateTime date) {
    return _entries
        .where((entry) => 
            entry.timestamp.year == date.year &&
            entry.timestamp.month == date.month &&
            entry.timestamp.day == date.day)
        .fold(0, (sum, entry) => sum + entry.amount);
  }
  
  // Nhóm bản ghi theo ngày để hiển thị
  Map<String, List<WaterEntry>> getEntriesByDay() {
    Map<String, List<WaterEntry>> grouped = {};
    
    // Tạo danh sách bản ghi có sắp xếp theo thời gian mới nhất
    final sortedEntries = List<WaterEntry>.from(_entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    for (var entry in sortedEntries) {
      final date = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      final key = _getDateKey(date);
      
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      
      grouped[key]!.add(entry);
    }
    
    return grouped;
  }
  
  // Lấy dữ liệu nước cho ngày cụ thể
  int getWaterAmountForDate(DateTime date) {
    return _entries
        .where((entry) => 
            entry.timestamp.year == date.year &&
            entry.timestamp.month == date.month &&
            entry.timestamp.day == date.day)
        .fold(0, (sum, entry) => sum + entry.amount);
  }
  
  // Kiểm tra liệu có bản ghi nào cho ngày cụ thể hay không
  bool hasEntriesForDate(DateTime date) {
    return getWaterAmountForDate(date) > 0;
  }
  
  // Tạo key cho nhóm ngày
  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Hôm nay';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Hôm qua';
    } else {
      return 'Ngày ${date.day} tháng ${date.month}';
    }
  }
  
  // Lấy danh sách các ngày có dữ liệu nước
  Future<List<DateTime>> getDatesWithWaterData() async {
    return await _waterService.getDatesWithWaterData();
  }
  
  // Xóa tất cả bản ghi nước
  Future<void> clearAllWaterEntries() async {
    await _waterService.clearAllEntries();
    
    // Cập nhật dữ liệu cục bộ
    _entries = [];
    _totalWaterToday = 0;
    _lastWaterTime = null;
    
    notifyListeners();
  }
  
  // Hiển thị dialog thêm nước
  Future<void> showWaterInputDialog(BuildContext context) async {
    int selectedAmount = 200; // Giá trị mặc định (ml)
    String selectedType = 'water'; // Loại đồ uống mặc định
    
    Map<String, Color> drinkColors = {
      'water': Colors.blue,
      'tea': Colors.green,
      'coffee': Colors.brown,
      'juice': Colors.orange,
    };
    
    Map<String, String> drinkEmojis = {
      'water': '💧',
      'tea': '🍵',
      'coffee': '☕',
      'juice': '🧃',
    };
    
    Map<String, String> drinkNames = {
      'water': 'Nước',
      'tea': 'Trà',
      'coffee': 'Cà phê',
      'juice': 'Nước ép',
    };
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Thêm nước',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: drinkColors[selectedType],
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Lựa chọn loại đồ uống
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: drinkTypes.map((type) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedType = type;
                              });
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selectedType == type 
                                    ? drinkColors[type]!.withOpacity(0.2) 
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: selectedType == type 
                                      ? drinkColors[type]! 
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    drinkEmojis[type]!,
                                    style: TextStyle(fontSize: 24),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    drinkNames[type]!,
                                    style: TextStyle(
                                      color: selectedType == type
                                          ? drinkColors[type]
                                          : Colors.grey[700],
                                      fontWeight: selectedType == type
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      SizedBox(height: 30),
                      
                      // Hiển thị lượng nước đã chọn
                      Text(
                        '$selectedAmount ml',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: drinkColors[selectedType],
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Thanh trượt chọn lượng nước
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: drinkColors[selectedType],
                          thumbColor: drinkColors[selectedType],
                          overlayColor: drinkColors[selectedType]!.withOpacity(0.2),
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                        ),
                        child: Slider(
                          min: 50,
                          max: 1000,
                          divisions: 19,
                          value: selectedAmount.toDouble(),
                          onChanged: (value) {
                            setState(() {
                              selectedAmount = value.round();
                            });
                          },
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Nút chọn nhanh
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [100, 200, 300, 500].map((amount) {
                          return ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedAmount = amount;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedAmount == amount
                                  ? drinkColors[selectedType]
                                  : Colors.grey.shade200,
                              foregroundColor: selectedAmount == amount
                                  ? Colors.white
                                  : Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text('$amount ml'),
                          );
                        }).toList(),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Nút xác nhận
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Hủy',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await addWaterEntry(selectedAmount);
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã thêm $selectedAmount ml ${drinkNames[selectedType]}'),
                                  backgroundColor: drinkColors[selectedType],
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: drinkColors[selectedType],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: Text('Xác nhận'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // Danh sách loại đồ uống có sẵn
  List<String> get drinkTypes => ['water', 'tea', 'coffee', 'juice'];
} 