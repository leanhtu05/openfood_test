import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/water_entry.dart';
import '../services/water_service.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class WaterProvider with ChangeNotifier {
  final WaterService _waterService = WaterService();
  
  List<WaterEntry> _entries = [];
  int _totalWaterToday = 0;
  DateTime? _lastWaterTime;
  bool _isLoading = false;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final FirebaseAuth _authService;
  
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
  WaterProvider({FirebaseAuth? authService})
      : _authService = authService ?? FirebaseAuth.instance {
    _loadInitialData();
  }
  
  // Phương thức khởi tạo dữ liệu
  Future<void> _loadInitialData() async {
    // Tải dữ liệu từ SharedPreferences trước
    await _loadWaterEntriesFromPrefs();
    
    // Cập nhật tổng lượng nước cho ngày đã chọn
    _updateTotalWaterForSelectedDate();
    
    // Lấy thời gian lần cuối uống nước
    _lastWaterTime = _getLastWaterTimeFromEntries(_entries);
    
    // Tải dữ liệu từ API nếu có người dùng đăng nhập
    loadData();
  }
  
  // Cập nhật tổng lượng nước cho ngày đã chọn
  void _updateTotalWaterForSelectedDate() {
    try {
      final selectedDateTime = DateTime.parse(_selectedDate);
      _totalWaterToday = getWaterAmountForDate(selectedDateTime);
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật tổng lượng nước: $e');
      _totalWaterToday = 0;
    }
  }
  
  // Thay đổi ngày đã chọn
  void setSelectedDate(String date) {
    if (_selectedDate != date) {
      _selectedDate = date;
      _updateTotalWaterForSelectedDate();
      notifyListeners();
      
      // Tải dữ liệu cho ngày mới
      loadData();
    } else {
      debugPrint('WaterProvider: Ngày đã được đặt là $date, không cần thay đổi');
    }
  }
  
  // Tải dữ liệu
  Future<void> loadData() async {
    if (_selectedDate.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Tải dữ liệu từ SharedPreferences trước
      await _loadWaterEntriesFromPrefs();
      
      // Nếu người dùng đã đăng nhập, thử tải từ Firebase
      final user = _authService.currentUser;
      if (user != null) {
        try {
          // Ưu tiên lấy dữ liệu từ Firestore trực tiếp
          try {
            final firestore = FirebaseFirestore.instance;
            final querySnapshot = await firestore
                .collection('water_entries')
                .where('user_id', isEqualTo: user.uid)
                .where('date', isEqualTo: _selectedDate)
                .get();
            
            if (querySnapshot.docs.isNotEmpty) {
              // Lọc các bản ghi hiện có cho ngày được chọn
              _entries.removeWhere((entry) => 
                DateFormat('yyyy-MM-dd').format(entry.timestamp) == _selectedDate);
              
              // Chuyển đổi dữ liệu từ Firestore sang WaterEntry
              final firestoreEntries = querySnapshot.docs.map((doc) {
                final data = doc.data();
                return WaterEntry.fromJson(data);
              }).toList();
              
              // Thêm các bản ghi mới từ Firestore
              _entries.addAll(firestoreEntries);
              
              // Cập nhật tổng lượng nước uống trong ngày
              _updateTotalWaterForSelectedDate();
              
              debugPrint('✅ Đã tải ${firestoreEntries.length} bản ghi nước từ Firestore trực tiếp');
              
              // Lưu vào bộ nhớ cục bộ
              await _saveWaterEntriesToPrefs();
              _isLoading = false;
              notifyListeners();
              return;
            }
          } catch (firestoreError) {
            debugPrint('⚠️ Lỗi khi lấy dữ liệu từ Firestore trực tiếp: $firestoreError');
          }
          
          // Nếu không thể lấy từ Firestore trực tiếp, thử lấy từ API
          final firebaseEntries = await ApiService.getWaterEntriesFromFirebase(user.uid, _selectedDate);
          
          if (firebaseEntries != null && firebaseEntries.isNotEmpty) {
            // Lọc các bản ghi hiện có cho ngày được chọn
            _entries.removeWhere((entry) => 
              DateFormat('yyyy-MM-dd').format(entry.timestamp) == _selectedDate);
            
            // Thêm các bản ghi mới từ Firebase
            _entries.addAll(firebaseEntries);
            
            // Cập nhật tổng lượng nước uống trong ngày
            _updateTotalWaterForSelectedDate();
            
            debugPrint('✅ Đã tải ${firebaseEntries.length} bản ghi nước từ API');
            
            // Lưu vào bộ nhớ cục bộ
            await _saveWaterEntriesToPrefs();
            _isLoading = false;
            notifyListeners();
            return;
          }
        } catch (e) {
          debugPrint('❌ Lỗi khi tải dữ liệu từ Firebase: $e');
        }
      }
      
      // Nếu không thể tải từ Firebase hoặc API, sử dụng dữ liệu cục bộ
      debugPrint('ℹ️ Sử dụng dữ liệu nước cục bộ cho ngày $_selectedDate');
      _updateTotalWaterForSelectedDate();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu nước: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Thêm bản ghi mới
  Future<bool> addWaterEntry(int amount, {DateTime? timestamp}) async {
    try {
      final newEntry = WaterEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: timestamp ?? DateTime.now(),
        amount: amount,
      );
      
      // Thêm vào danh sách local
      _entries.insert(0, newEntry); // Thêm vào đầu danh sách
      
      // Cập nhật tổng lượng nước và thời gian lần cuối
      _updateTotalWaterForSelectedDate();
      _lastWaterTime = newEntry.timestamp;
      
      notifyListeners();
      
      // Lưu vào SharedPreferences
      await _saveWaterEntriesToPrefs();
      
      // Gửi đến API
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          final result = await ApiService.sendWaterEntry(newEntry, userId);
          if (result) {
            debugPrint('✅ Đã gửi bản ghi nước đến API thành công');
          } else {
            debugPrint('⚠️ Không thể gửi bản ghi nước đến API');
          }
          return result;
        } catch (e) {
          debugPrint('❌ Lỗi khi gửi bản ghi nước đến API: $e');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi thêm bản ghi nước: $e');
      return false;
    }
  }
  
  // Xóa bản ghi
  Future<bool> deleteWaterEntry(String id) async {
    try {
      // Xóa khỏi danh sách local
      _entries.removeWhere((entry) => entry.id == id);
      
      // Cập nhật tổng lượng nước và thời gian lần cuối
      _updateTotalWaterForSelectedDate();
      _lastWaterTime = _getLastWaterTimeFromEntries(_entries);
      
      notifyListeners();
      
      // Lưu vào SharedPreferences
      await _saveWaterEntriesToPrefs();
      
      // Xóa trên API
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          final result = await ApiService.deleteWaterEntry(id, userId);
          if (result) {
            debugPrint('✅ Đã xóa bản ghi nước trên API thành công');
          } else {
            debugPrint('⚠️ Không thể xóa bản ghi nước trên API');
          }
          return result;
        } catch (e) {
          debugPrint('❌ Lỗi khi xóa bản ghi nước trên API: $e');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa bản ghi nước: $e');
      return false;
    }
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
    final Set<String> uniqueDates = {};
    final List<DateTime> result = [];
    
    for (var entry in _entries) {
      final dateKey = '${entry.timestamp.year}-${entry.timestamp.month}-${entry.timestamp.day}';
      if (!uniqueDates.contains(dateKey)) {
        uniqueDates.add(dateKey);
        result.add(DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day));
      }
    }
    
    // Sắp xếp theo ngày mới nhất
    result.sort((a, b) => b.compareTo(a));
    return result;
  }
  
  // Xóa tất cả bản ghi nước
  Future<bool> clearAllWaterEntries() async {
    try {
      _entries.clear();
      _totalWaterToday = 0;
      _lastWaterTime = null;
      
      notifyListeners();
      
      // Lưu vào SharedPreferences
      await _saveWaterEntriesToPrefs();
      
      // Xóa trên API
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          final result = await ApiService.clearAllWaterEntries(userId);
          if (result) {
            debugPrint('✅ Đã xóa tất cả bản ghi nước trên API thành công');
          } else {
            debugPrint('⚠️ Không thể xóa tất cả bản ghi nước trên API');
          }
          return result;
        } catch (e) {
          debugPrint('❌ Lỗi khi xóa tất cả bản ghi nước trên API: $e');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi khi xóa tất cả bản ghi nước: $e');
      return false;
    }
  }
  
  // Phương thức tìm thời gian cuối cùng từ danh sách bản ghi
  DateTime? _getLastWaterTimeFromEntries(List<WaterEntry> entries) {
    if (entries.isEmpty) return null;
    
    // Sắp xếp theo thời gian giảm dần và lấy bản ghi đầu tiên
    final sortedEntries = List<WaterEntry>.from(entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedEntries.first.timestamp;
  }
  
  // Trả về toàn bộ water entries dưới dạng List<Map<String, dynamic>> để đồng bộ
  List<Map<String, dynamic>> getAllWaterEntriesAsJson() {
    return _entries.map((e) => e.toMap()).toList();
  }
  
  // Lưu dữ liệu nước vào SharedPreferences
  Future<void> _saveWaterEntriesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> entriesMaps = _entries.map((e) => e.toMap()).toList();
      await prefs.setString('water_entries', jsonEncode(entriesMaps));
      debugPrint('✅ Đã lưu dữ liệu nước vào SharedPreferences');
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu dữ liệu nước vào SharedPreferences: $e');
    }
  }
  
  // Tải dữ liệu nước từ SharedPreferences
  Future<void> _loadWaterEntriesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? entriesJson = prefs.getString('water_entries');
      if (entriesJson != null) {
        final List<dynamic> decodedList = jsonDecode(entriesJson);
        _entries = decodedList.map((item) => WaterEntry.fromMap(item)).toList();
        debugPrint('✅ Đã tải ${_entries.length} bản ghi nước từ SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải dữ liệu nước từ SharedPreferences: $e');
    }
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
  
  // Phương thức getAllWaterLogsAsJson để tương thích với code cũ
  List<Map<String, dynamic>> getAllWaterLogsAsJson() {
    // Gọi đến phương thức getAllWaterEntriesAsJson mới
    return getAllWaterEntriesAsJson();
  }
} 