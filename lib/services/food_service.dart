import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/food_entry.dart';

class FoodService {
  static final FoodService _instance = FoodService._internal();
  static Database? _database;

  // Singleton pattern
  factory FoodService() => _instance;

  FoodService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Lấy đường dẫn thư mục lưu trữ database
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'food_entries.db');

    // Mở database và tạo bảng nếu chưa tồn tại
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE food_entries(
            id TEXT PRIMARY KEY,
            description TEXT NOT NULL,
            imagePath TEXT,
            audioPath TEXT,
            timestamp TEXT NOT NULL,
            isFavorite INTEGER DEFAULT 0,
            barcode TEXT,
            calories INTEGER DEFAULT 0,
            nutritionInfo TEXT
          )
        ''');
      },
    );
  }

  // Thêm mới bữa ăn
  Future<FoodEntry> addFoodEntry(FoodEntry entry) async {
    final db = await database;
    Map<String, dynamic> data = entry.toMap();
    
    // Chuyển đổi nutritionInfo thành chuỗi JSON nếu có
    if (data['nutritionInfo'] != null) {
      data['nutritionInfo'] = data['nutritionInfo'].toString();
    }
    
    await db.insert('food_entries', data);
    return entry;
  }

  // Lấy tất cả bữa ăn
  Future<List<FoodEntry>> getAllFoodEntries() async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'food_entries',
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) {
      Map<String, dynamic> map = maps[i];
      // Chuyển đổi chuỗi JSON thành Map nếu có
      if (map['nutritionInfo'] != null && map['nutritionInfo'] is String) {
        try {
          // Thực hiện chuyển đổi từ String sang Map
          map['nutritionInfo'] = {'data': 'empty'}; // Placeholder
        } catch (e) {
          map['nutritionInfo'] = null;
        }
      }
      return FoodEntry.fromMap(map);
    });
  }

  // Lấy bữa ăn theo ngày
  Future<List<FoodEntry>> getFoodEntriesByDate(DateTime date) async {
    final db = await database;
    String dateString = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
    
    List<Map<String, dynamic>> maps = await db.query(
      'food_entries',
      where: 'timestamp LIKE ?',
      whereArgs: ['$dateString%'],
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) {
      Map<String, dynamic> map = maps[i];
      // Chuyển đổi chuỗi JSON thành Map nếu có
      if (map['nutritionInfo'] != null && map['nutritionInfo'] is String) {
        try {
          // Thực hiện chuyển đổi từ String sang Map
          map['nutritionInfo'] = {'data': 'empty'}; // Placeholder
        } catch (e) {
          map['nutritionInfo'] = null;
        }
      }
      return FoodEntry.fromMap(map);
    });
  }

  // Lấy bữa ăn yêu thích
  Future<List<FoodEntry>> getFavoriteFoodEntries() async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'food_entries',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) {
      Map<String, dynamic> map = maps[i];
      if (map['nutritionInfo'] != null && map['nutritionInfo'] is String) {
        try {
          map['nutritionInfo'] = {'data': 'empty'}; // Placeholder
        } catch (e) {
          map['nutritionInfo'] = null;
        }
      }
      return FoodEntry.fromMap(map);
    });
  }

  // Cập nhật bữa ăn
  Future<int> updateFoodEntry(FoodEntry entry) async {
    final db = await database;
    Map<String, dynamic> data = entry.toMap();
    
    if (data['nutritionInfo'] != null) {
      data['nutritionInfo'] = data['nutritionInfo'].toString();
    }
    
    return await db.update(
      'food_entries',
      data,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  // Đánh dấu/bỏ đánh dấu yêu thích
  Future<int> toggleFavorite(String id, bool isFavorite) async {
    final db = await database;
    return await db.update(
      'food_entries',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Lấy bữa ăn theo ID
  Future<FoodEntry?> getFoodEntryById(String id) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'food_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) {
      return null;
    }
    
    Map<String, dynamic> map = maps.first;
    // Chuyển đổi chuỗi JSON thành Map nếu có
    if (map['nutritionInfo'] != null && map['nutritionInfo'] is String) {
      try {
        // Thực hiện chuyển đổi từ String sang Map
        map['nutritionInfo'] = {'data': 'empty'}; // Placeholder
      } catch (e) {
        map['nutritionInfo'] = null;
      }
    }
    return FoodEntry.fromMap(map);
  }

  // Xóa bữa ăn
  Future<int> deleteFoodEntry(String id) async {
    final db = await database;
    return await db.delete(
      'food_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Lấy danh sách các ngày có dữ liệu thực phẩm
  Future<List<DateTime>> getDatesWithFoodEntries() async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT substr(timestamp, 1, 10) as date
      FROM food_entries
      ORDER BY date DESC
    ''');
    
    return maps.map((map) => DateTime.parse(map['date'])).toList();
  }
} 