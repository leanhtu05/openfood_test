import 'dart:math';
import '../models/water_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WaterService {
  // Danh sách các bản ghi nước 
  static List<WaterEntry> _entries = [];
  static bool _initialized = false;

  // Constructor
  WaterService() {
    if (!_initialized) {
      _initData();
      _initialized = true;
    }
  }

  // Khởi tạo dữ liệu từ SharedPreferences
  Future<void> _initData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? entriesJson = prefs.getString('water_entries');
      
      if (entriesJson != null) {
        final List<dynamic> decodedList = jsonDecode(entriesJson);
        _entries = decodedList.map((item) => WaterEntry.fromMap(item)).toList();
      } else {
        // Nếu không có dữ liệu, khởi tạo danh sách trống
        _entries = [];
        _saveToPrefs();
      }
    } catch (e) {
      _entries = [];
    }
  }

  // Lưu dữ liệu vào SharedPreferences
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> entriesMaps = _entries.map((e) => e.toMap()).toList();
      await prefs.setString('water_entries', jsonEncode(entriesMaps));
    } catch (e) {
    }
  }

  // Lấy tất cả bản ghi
  Future<List<WaterEntry>> getAllEntries() async {
    if (_entries.isEmpty) {
      await _initData();
    }
    return List.from(_entries);
  }
  
  // Lấy tất cả bản ghi (phiên bản đồng bộ)
  List<WaterEntry> getAllEntriesSync() {
    return List.from(_entries);
  }

  // Thêm bản ghi mới
  Future<void> addEntry(int amount, {DateTime? timestamp}) async {
    final newEntry = WaterEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: timestamp ?? DateTime.now(),
      amount: amount,
    );
    _entries.insert(0, newEntry); // Thêm vào đầu danh sách
    await _saveToPrefs();
  }

  // Xoá bản ghi
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    await _saveToPrefs();
  }

  // Lấy tổng lượng nước đã uống trong ngày
  Future<int> getTotalForDay(DateTime date) async {
    final entries = await getAllEntries();
    return _calculateTotalForDay(entries, date);
  }
  
  // Phiên bản đồng bộ để tính tổng lượng nước trong ngày
  int getTotalForDaySync(DateTime date) {
    return _calculateTotalForDay(_entries, date);
  }
  
  // Phương thức tính toán tổng lượng nước cho một danh sách bản ghi
  int _calculateTotalForDay(List<WaterEntry> entries, DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    
    return entries
        .where((entry) {
          final entryDate = DateTime(
            entry.timestamp.year, 
            entry.timestamp.month, 
            entry.timestamp.day
          );
          return entryDate.isAtSameMomentAs(targetDate);
        })
        .fold(0, (sum, entry) => sum + entry.amount);
  }

  // Lấy thời gian lần cuối uống nước
  Future<DateTime?> getLastWaterTime() async {
    final entries = await getAllEntries();
    return _getLastWaterTimeFromEntries(entries);
  }
  
  // Phiên bản đồng bộ để lấy thời gian lần cuối uống nước
  DateTime? getLastWaterTimeSync() {
    return _getLastWaterTimeFromEntries(_entries);
  }
  
  // Phương thức tìm thời gian cuối cùng từ danh sách bản ghi
  DateTime? _getLastWaterTimeFromEntries(List<WaterEntry> entries) {
    if (entries.isEmpty) return null;
    
    // Sắp xếp theo thời gian giảm dần và lấy bản ghi đầu tiên
    final sortedEntries = List<WaterEntry>.from(entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedEntries.first.timestamp;
  }
  
  // Lấy dữ liệu nước cho một phạm vi ngày
  Future<Map<String, List<WaterEntry>>> getEntriesForDateRange(DateTime startDate, DateTime endDate) async {
    final entries = await getAllEntries();
    Map<String, List<WaterEntry>> result = {};
    
    for (var entry in entries) {
      final entryDate = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      if (entryDate.isAtSameMomentAs(start) || entryDate.isAtSameMomentAs(end) ||
          (entryDate.isAfter(start) && entryDate.isBefore(end))) {
        final dateKey = '${entryDate.year}-${entryDate.month}-${entryDate.day}';
        if (!result.containsKey(dateKey)) {
          result[dateKey] = [];
        }
        result[dateKey]!.add(entry);
      }
    }
    
    return result;
  }
  
  // Lấy danh sách các ngày có dữ liệu nước
  Future<List<DateTime>> getDatesWithWaterData() async {
    final entries = await getAllEntries();
    final Set<String> uniqueDates = {};
    final List<DateTime> result = [];
    
    for (var entry in entries) {
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

  // Xóa tất cả bản ghi
  Future<void> clearAllEntries() async {
    _entries.clear();
    await _saveToPrefs();
  }
}