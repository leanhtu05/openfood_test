import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/water_entry.dart';
import '../services/water_service.dart';
import '../services/water_firebase_service.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';

class WaterProvider with ChangeNotifier {
  final WaterService _waterService = WaterService();
  final WaterFirebaseService _waterFirebaseService = WaterFirebaseService();
  
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
  
  // Mục tiêu nước động dựa trên profile người dùng
  int _waterGoal = 2500; // mL - giá trị mặc định

  // Getter cho mục tiêu nước
  int get waterGoal => _waterGoal;
  
  // Constructor khởi tạo với dữ liệu sync
  WaterProvider({FirebaseAuth? authService})
      : _authService = authService ?? FirebaseAuth.instance {
    _loadInitialData();
    
    // Listen for auth state changes
    _authService.authStateChanges().listen((User? user) {
      if (user != null) {
        // User logged in, sync data from Firebase
        syncFromFirebase();
      } else {
        // User logged out, clear data
        clearDataOnLogout();
      }
    });
  }
  
  // Phương thức khởi tạo dữ liệu
  Future<void> _loadInitialData() async {
    // Tải dữ liệu từ SharedPreferences trước
    await _loadWaterEntriesFromPrefs();

    // Cập nhật mục tiêu nước dựa trên profile người dùng
    await _updateWaterGoal();

    // Cập nhật tổng lượng nước cho ngày đã chọn
    _updateTotalWaterForSelectedDate();

    // Lấy thời gian lần cuối uống nước
    _lastWaterTime = _getLastWaterTimeFromEntries(_entries);

    // Tải dữ liệu từ API nếu có người dùng đăng nhập
    loadData();
  }
  
  // Cập nhật mục tiêu nước dựa trên profile người dùng
  Future<void> _updateWaterGoal() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Tạo instance UserService và lấy profile người dùng
        final userService = UserService();
        final userProfile = await userService.getUserProfile();

        if (userProfile != null) {
          // Tính toán mục tiêu nước dựa trên profile
          _waterGoal = _calculateWaterGoal(userProfile);
          debugPrint('✅ Đã cập nhật mục tiêu nước: $_waterGoal ml dựa trên profile người dùng');
        } else {
          // Sử dụng giá trị mặc định nếu không có profile
          _waterGoal = 2500;
          debugPrint('ℹ️ Sử dụng mục tiêu nước mặc định: $_waterGoal ml');
        }
      } else {
        // Người dùng chưa đăng nhập, sử dụng giá trị mặc định
        _waterGoal = 2500;
        debugPrint('ℹ️ Người dùng chưa đăng nhập, sử dụng mục tiêu nước mặc định: $_waterGoal ml');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi cập nhật mục tiêu nước: $e');
      _waterGoal = 2500; // Fallback
    }
  }

  // Tính toán mục tiêu nước dựa trên thông tin cá nhân
  int _calculateWaterGoal(Map<String, dynamic> userProfile) {
    try {
      // Lấy thông tin cơ bản với các field names có thể có trong Firebase
      final double weight = (userProfile['weightKg'] ?? userProfile['weight'] ?? 70.0).toDouble();
      final double height = (userProfile['heightCm'] ?? userProfile['height'] ?? 170.0).toDouble();
      final int age = userProfile['age'] ?? 25;
      final String gender = userProfile['gender'] ?? 'male';
      final String activityLevel = userProfile['activityLevel'] ?? 'moderate';

      // Công thức tính mục tiêu nước cơ bản: 35ml/kg cân nặng
      double baseWater = weight * 35;

      // Điều chỉnh theo giới tính
      if (gender.toLowerCase() == 'female') {
        baseWater *= 0.9; // Phụ nữ cần ít nước hơn 10%
      }

      // Điều chỉnh theo tuổi
      if (age > 65) {
        baseWater *= 0.85; // Người cao tuổi cần ít nước hơn
      } else if (age < 18) {
        baseWater *= 1.1; // Trẻ em/thanh thiếu niên cần nhiều nước hơn
      }

      // Điều chỉnh theo mức độ hoạt động
      switch (activityLevel.toLowerCase()) {
        case 'sedentary':
        case 'low':
          baseWater *= 1.0; // Không thay đổi
          break;
        case 'moderate':
        case 'medium':
          baseWater *= 1.15; // Tăng 15%
          break;
        case 'active':
        case 'high':
          baseWater *= 1.3; // Tăng 30%
          break;
        case 'very_active':
        case 'very high':
          baseWater *= 1.5; // Tăng 50%
          break;
      }

      // Điều chỉnh theo BMI (nếu có thông tin chiều cao)
      if (height > 0) {
        final double bmi = weight / ((height / 100) * (height / 100));
        if (bmi > 30) {
          baseWater *= 1.1; // Người béo phì cần nhiều nước hơn
        } else if (bmi < 18.5) {
          baseWater *= 0.95; // Người gầy cần ít nước hơn
        }
      }

      // Làm tròn và đảm bảo trong khoảng hợp lý (1500-5000ml)
      int finalGoal = baseWater.round();
      finalGoal = finalGoal.clamp(1500, 5000);

      debugPrint('💧 Tính toán mục tiêu nước:');
      debugPrint('   Cân nặng: ${weight}kg');
      debugPrint('   Chiều cao: ${height}cm');
      debugPrint('   Tuổi: $age');
      debugPrint('   Giới tính: $gender');
      debugPrint('   Mức độ hoạt động: $activityLevel');
      debugPrint('   Mục tiêu nước: ${finalGoal}ml');

      return finalGoal;
    } catch (e) {
      debugPrint('❌ Lỗi khi tính toán mục tiêu nước: $e');
      return 2500; // Giá trị mặc định
    }
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
    
    // Đặt cờ đang tải dữ liệu
    _isLoading = true;
    // Sử dụng Future.microtask để tránh gọi notifyListeners trong quá trình build
    Future.microtask(() => notifyListeners());
    
    try {
      // Tải dữ liệu từ SharedPreferences trước
      await _loadWaterEntriesFromPrefs();
      
      // Nếu người dùng đã đăng nhập, ưu tiên lấy dữ liệu từ Firebase
      final user = _authService.currentUser;
      if (user != null) {
        // Cập nhật mục tiêu nước dựa trên profile
        await _updateWaterGoal();

        debugPrint('🔄 Đang tải dữ liệu nước từ Firebase cho ngày $_selectedDate');
        try {
          // Chuyển đổi selectedDate thành đối tượng DateTime
          final selectedDateTime = DateTime.parse(_selectedDate);
          
          // Sử dụng WaterFirebaseService để tải dữ liệu cho ngày được chọn
          final firebaseEntries = await _waterFirebaseService.getWaterEntriesForDate(selectedDateTime);
          
          if (firebaseEntries.isNotEmpty) {
            debugPrint('✅ Đã tải ${firebaseEntries.length} bản ghi nước từ Firebase');
            
            // Lọc các bản ghi hiện có cho ngày được chọn
            _entries.removeWhere((entry) => 
              DateFormat('yyyy-MM-dd').format(entry.timestamp) == _selectedDate);
            
            // Thêm các bản ghi mới từ Firebase
            _entries.addAll(firebaseEntries);
            
            // Sắp xếp lại danh sách theo thời gian gần nhất trước
            _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          } else {
            debugPrint('ℹ️ Không tìm thấy bản ghi nước nào trên Firebase cho ngày $_selectedDate');
          }
        } catch (e) {
          debugPrint('❌ Lỗi khi tải dữ liệu nước từ Firebase: $e');
        }
      } else {
        debugPrint('ℹ️ Người dùng chưa đăng nhập, chỉ sử dụng dữ liệu local');
      }
      
      // Cập nhật tổng lượng nước và thời gian lần cuối
      _updateTotalWaterForSelectedDate();
      _lastWaterTime = _getLastWaterTimeFromEntries(_entries);
      
      // Lưu vào SharedPreferences
      await _saveWaterEntriesToPrefs();
    } finally {
      // Đặt lại cờ đang tải dữ liệu
      _isLoading = false;
      // Sử dụng Future.microtask để tránh gọi notifyListeners trong quá trình build
      Future.microtask(() => notifyListeners());
    }
  }
  
  // Thêm một bản ghi nước mới
  Future<bool> addWaterEntry(int amount, {DateTime? timestamp}) async {
    try {
      final now = timestamp ?? DateTime.now();
      final id = 'water_${now.millisecondsSinceEpoch}';
      
      // Tạo bản ghi mới
      final entry = WaterEntry(
        id: id,
        amount: amount,
        timestamp: now,
      );
      
      // Thêm vào danh sách local
      _entries.insert(0, entry); // Thêm vào đầu danh sách
      
      // Cập nhật tổng lượng nước và thời gian lần cuối
      _updateTotalWaterForSelectedDate();
      _lastWaterTime = entry.timestamp;
      
      notifyListeners();
      
      // Lưu vào SharedPreferences
      await _saveWaterEntriesToPrefs();
      
      // Lưu trực tiếp vào Firebase nếu đã đăng nhập
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          // Sử dụng WaterFirebaseService để lưu trực tiếp vào Firebase
          final success = await _waterFirebaseService.saveWaterEntry(entry);
          
          if (success) {
            debugPrint('✅ Đã lưu bản ghi nước vào Firebase thành công');
          } else {
            debugPrint('❌ Không thể lưu bản ghi nước vào Firebase');
          }
          
          // Chỉ gửi đến API nếu cần phân tích nâng cao
          try {
            await ApiService.sendWaterEntry(entry, userId);
            debugPrint('✅ Đã thông báo API về bản ghi nước mới');
          } catch (apiError) {
            // Không quan trọng nếu API không nhận được thông báo
            debugPrint('ℹ️ Không thể thông báo API về bản ghi nước mới: $apiError');
          }
          return true;
        } catch (e) {
          debugPrint('❌ Lỗi khi lưu bản ghi nước vào Firebase: $e');
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
      
      // Xóa trực tiếp trên Firebase
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          // Xóa từ Firestore trực tiếp
          await FirebaseFirestore.instance
              .collection('water_entries')
              .doc(id)
              .delete();
          
          debugPrint('✅ Đã xóa bản ghi nước trên Firebase thành công');
          
          // Thông báo cho API về việc xóa (nếu cần)
          try {
            await ApiService.deleteWaterEntry(id, userId);
            debugPrint('✅ Đã thông báo API về việc xóa bản ghi nước');
          } catch (apiError) {
            // Không quan trọng nếu API không nhận được thông báo
            debugPrint('ℹ️ Không thể thông báo API về việc xóa bản ghi nước: $apiError');
          }
          
          return true;
        } catch (e) {
          debugPrint('❌ Lỗi khi xóa bản ghi nước trên Firebase: $e');
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
      
      // Xóa trực tiếp trên Firebase
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          // Xóa tất cả bản ghi nước của người dùng từ Firestore
          final batch = FirebaseFirestore.instance.batch();
          final snapshot = await FirebaseFirestore.instance
              .collection('water_entries')
              .where('user_id', isEqualTo: userId)
              .get();
          
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          
          await batch.commit();
          
          debugPrint('✅ Đã xóa tất cả bản ghi nước trên Firebase thành công');
          
          // Thông báo cho API về việc xóa (nếu cần)
          try {
            await ApiService.clearAllWaterEntries(userId);
            debugPrint('✅ Đã thông báo API về việc xóa tất cả bản ghi nước');
          } catch (apiError) {
            // Không quan trọng nếu API không nhận được thông báo
            debugPrint('ℹ️ Không thể thông báo API về việc xóa tất cả bản ghi nước: $apiError');
          }
          
          return true;
        } catch (e) {
          debugPrint('❌ Lỗi khi xóa tất cả bản ghi nước trên Firebase: $e');
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
                      Material(
                        color: Colors.transparent,
                        child: SliderTheme(
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
                                  behavior: SnackBarBehavior.fixed,
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
  
  // Đồng bộ dữ liệu từ Firebase khi đăng nhập lại
  Future<void> syncFromFirebase() async {
    final user = _authService.currentUser;
    if (user == null) return;
    
    try {
      debugPrint('🔄 Đang đồng bộ dữ liệu nước từ Firebase...');
      
      // Sử dụng WaterFirebaseService để lấy dữ liệu cho ngày hiện tại
      final today = DateTime.now();
      final entries = await _waterFirebaseService.getWaterEntriesForDate(today);
      
      if (entries.isNotEmpty) {
        // Sắp xếp dữ liệu theo thời gian gần nhất trước
        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        // Ghi đè dữ liệu local bằng dữ liệu từ Firebase
        _entries = entries;
        
        // Cập nhật tổng lượng nước cho ngày đã chọn
        _updateTotalWaterForSelectedDate();
        
        // Lấy thời gian lần cuối uống nước
        _lastWaterTime = _getLastWaterTimeFromEntries(_entries);
        
        // Cập nhật SharedPreferences
        await _saveWaterEntriesToPrefs();
        
        // Thông báo UI cập nhật
        notifyListeners();
        
        debugPrint('✅ Đã đồng bộ ${entries.length} bản ghi nước từ Firebase');
      } else {
        debugPrint('ℹ️ Không có dữ liệu nước trên Firebase cho ngày hôm nay');
        
        // Đồng bộ dữ liệu local lên Firebase nếu có
        final localEntries = _entries.where((entry) => 
          DateFormat('yyyy-MM-dd').format(entry.timestamp) == 
          DateFormat('yyyy-MM-dd').format(today)).toList();
        
        if (localEntries.isNotEmpty) {
          final success = await _waterFirebaseService.syncAllWaterEntries(localEntries);
          if (success) {
            debugPrint('✅ Đã đồng bộ ${localEntries.length} bản ghi nước local lên Firebase');
          } else {
            debugPrint('❌ Không thể đồng bộ dữ liệu nước local lên Firebase');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi đồng bộ dữ liệu nước từ Firebase: $e');
    }
  }

  // Method to manually update water goal (public method)
  Future<void> updateWaterGoal() async {
    await _updateWaterGoal();
    notifyListeners();
  }

  // Method to set custom water goal
  void setCustomWaterGoal(int goal) {
    if (goal >= 1000 && goal <= 6000) {
      _waterGoal = goal;
      notifyListeners();
      debugPrint('✅ Đã đặt mục tiêu nước tùy chỉnh: $goal ml');
    } else {
      debugPrint('❌ Mục tiêu nước không hợp lệ: $goal ml (phải từ 1000-6000ml)');
    }
  }

  // Method to get water goal percentage
  double getWaterGoalPercentage() {
    if (_waterGoal <= 0) return 0.0;
    return (_totalWaterToday / _waterGoal).clamp(0.0, 1.0);
  }

  // Method to get remaining water needed
  int getRemainingWaterNeeded() {
    final remaining = _waterGoal - _totalWaterToday;
    return remaining > 0 ? remaining : 0;
  }

  // Method to check if goal is achieved
  bool isGoalAchieved() {
    return _totalWaterToday >= _waterGoal;
  }

  // Method to clear data when user logs out
  Future<void> clearDataOnLogout() async {
    try {
      debugPrint('🧹 WaterProvider: Clearing data on logout...');

      // Clear all water entries
      _entries = [];

      // Reset water statistics
      _totalWaterToday = 0;
      _lastWaterTime = null;

      // Reset water goal to default
      _waterGoal = 2500;

      // Update SharedPreferences
      await _saveWaterEntriesToPrefs();

      // Notify UI to update
      notifyListeners();

      debugPrint('✅ WaterProvider: Data cleared successfully on logout');
    } catch (e) {
      debugPrint('❌ WaterProvider: Error clearing data on logout: $e');
    }
  }
}