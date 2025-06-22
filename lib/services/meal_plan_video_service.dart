import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'youtube_api_service.dart';
import 'video_service.dart';

class MealPlanVideoService {
  static const String _currentMealPlanKey = 'current_meal_plan';
  static const String _mealPlanVideosKey = 'meal_plan_videos';
  static const String _lastUpdateKey = 'last_video_update';

  final YouTubeApiService _youtubeService = YouTubeApiService();
  final VideoService _videoService = VideoService();

  // Singleton pattern
  static final MealPlanVideoService _instance = MealPlanVideoService._internal();
  factory MealPlanVideoService() => _instance;
  MealPlanVideoService._internal();

  // Theo dõi thay đổi meal plan và cập nhật video
  Future<void> onMealPlanChanged(Map<String, dynamic> newMealPlan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Lưu meal plan mới
      await prefs.setString(_currentMealPlanKey, json.encode(newMealPlan));
      
      // Cập nhật video cho meal plan mới
      await _updateVideosForMealPlan(newMealPlan);
      
      // Lưu timestamp cập nhật
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      
      print('✅ Meal plan changed - Videos updated successfully');
    } catch (e) {
      print('❌ Error updating videos for meal plan: $e');
    }
  }

  // Cập nhật video cho meal plan mới
  Future<void> _updateVideosForMealPlan(Map<String, dynamic> mealPlan) async {
    final Map<String, List<Map<String, String>>> mealPlanVideos = {};
    
    // Duyệt qua từng ngày trong tuần
    for (final day in mealPlan.keys) {
      if (day == 'nutrition_targets') continue; // Skip nutrition targets
      
      final dayPlan = mealPlan[day] as Map<String, dynamic>?;
      if (dayPlan == null) continue;
      
      final dayVideos = <Map<String, String>>[];
      
      // Duyệt qua từng bữa ăn (breakfast, lunch, dinner)
      for (final mealType in ['breakfast', 'lunch', 'dinner']) {
        final meals = dayPlan[mealType] as List<dynamic>?;
        if (meals == null) continue;
        
        // Lấy video cho từng món ăn
        for (final meal in meals) {
          final mealData = meal as Map<String, dynamic>?;
          if (mealData == null) continue;
          
          final dishes = mealData['dishes'] as List<dynamic>?;
          if (dishes == null) continue;
          
          for (final dish in dishes) {
            final dishData = dish as Map<String, dynamic>?;
            if (dishData == null) continue;
            
            final dishName = dishData['name'] as String?;
            if (dishName == null) continue;
            
            // Tìm video cho món ăn này
            final videos = await _youtubeService.searchVideosForDish(dishName);
            if (videos.isNotEmpty) {
              // Thêm thông tin bổ sung
              final videoWithMealInfo = Map<String, String>.from(videos.first);
              videoWithMealInfo['dishName'] = dishName;
              videoWithMealInfo['mealType'] = mealType;
              videoWithMealInfo['day'] = day;
              
              dayVideos.add(videoWithMealInfo);
            }
          }
        }
      }
      
      mealPlanVideos[day] = dayVideos;
    }
    
    // Lưu video cho meal plan
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mealPlanVideosKey, json.encode(mealPlanVideos));
  }

  // Lấy video cho ngày cụ thể
  Future<List<Map<String, String>>> getVideosForDay(String day) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = prefs.getString(_mealPlanVideosKey);
      
      if (videosJson == null) return [];
      
      final allVideos = json.decode(videosJson) as Map<String, dynamic>;
      final dayVideos = allVideos[day] as List<dynamic>?;
      
      if (dayVideos == null) return [];
      
      return dayVideos.map((video) => Map<String, String>.from(video)).toList();
    } catch (e) {
      print('Error getting videos for day $day: $e');
      return [];
    }
  }

  // Lấy video cho bữa ăn cụ thể
  Future<List<Map<String, String>>> getVideosForMeal(String day, String mealType) async {
    final dayVideos = await getVideosForDay(day);
    return dayVideos.where((video) => video['mealType'] == mealType).toList();
  }

  // Lấy video trending cho tuần này
  Future<List<Map<String, String>>> getWeeklyTrendingVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = prefs.getString(_mealPlanVideosKey);
      
      if (videosJson == null) return [];
      
      final allVideos = json.decode(videosJson) as Map<String, dynamic>;
      final List<Map<String, String>> trendingVideos = [];
      
      // Lấy video từ tất cả các ngày
      for (final dayVideos in allVideos.values) {
        final videos = (dayVideos as List<dynamic>)
            .map((video) => Map<String, String>.from(video))
            .toList();
        trendingVideos.addAll(videos);
      }
      
      // Sắp xếp theo view count (nếu có)
      trendingVideos.sort((a, b) {
        final viewsA = _parseViewCount(a['views'] ?? '0');
        final viewsB = _parseViewCount(b['views'] ?? '0');
        return viewsB.compareTo(viewsA);
      });
      
      return trendingVideos.take(10).toList();
    } catch (e) {
      print('Error getting weekly trending videos: $e');
      return [];
    }
  }

  // Parse view count string to number for sorting
  int _parseViewCount(String viewsStr) {
    try {
      // Remove 'M', 'K' and convert to number
      final cleanStr = viewsStr.replaceAll(RegExp(r'[MK]'), '');
      final number = double.parse(cleanStr);
      
      if (viewsStr.contains('M')) {
        return (number * 1000000).toInt();
      } else if (viewsStr.contains('K')) {
        return (number * 1000).toInt();
      } else {
        return number.toInt();
      }
    } catch (e) {
      return 0;
    }
  }

  // Lấy video gợi ý dựa trên meal plan hiện tại
  Future<List<Map<String, String>>> getRecommendedVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mealPlanJson = prefs.getString(_currentMealPlanKey);
      
      if (mealPlanJson == null) {
        // Nếu không có meal plan, trả về video trending
        return await _youtubeService.getTrendingCookingVideos();
      }
      
      final mealPlan = json.decode(mealPlanJson) as Map<String, dynamic>;
      
      // Lấy danh sách món ăn từ meal plan
      final Set<String> dishes = {};
      for (final day in mealPlan.keys) {
        if (day == 'nutrition_targets') continue;
        
        final dayPlan = mealPlan[day] as Map<String, dynamic>?;
        if (dayPlan == null) continue;
        
        for (final mealType in ['breakfast', 'lunch', 'dinner']) {
          final meals = dayPlan[mealType] as List<dynamic>?;
          if (meals == null) continue;
          
          for (final meal in meals) {
            final mealData = meal as Map<String, dynamic>?;
            if (mealData == null) continue;
            
            final dishesInMeal = mealData['dishes'] as List<dynamic>?;
            if (dishesInMeal == null) continue;
            
            for (final dish in dishesInMeal) {
              final dishData = dish as Map<String, dynamic>?;
              final dishName = dishData?['name'] as String?;
              if (dishName != null) {
                dishes.add(dishName);
              }
            }
          }
        }
      }
      
      // Lấy video cho các món ăn trong meal plan
      return await _youtubeService.getRecommendedVideosForUser(
        dishes.toList(),
        [], // Favorite dishes - có thể lấy từ VideoService
      );
    } catch (e) {
      print('Error getting recommended videos: $e');
      return [];
    }
  }

  // Kiểm tra xem có cần cập nhật video không
  Future<bool> shouldUpdateVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString(_lastUpdateKey);
      
      if (lastUpdateStr == null) return true;
      
      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);
      
      // Cập nhật video mỗi 24 giờ
      return difference.inHours >= 24;
    } catch (e) {
      return true;
    }
  }

  // Force update videos
  Future<void> forceUpdateVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mealPlanJson = prefs.getString(_currentMealPlanKey);
      
      if (mealPlanJson != null) {
        final mealPlan = json.decode(mealPlanJson) as Map<String, dynamic>;
        await _updateVideosForMealPlan(mealPlan);
        await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
      print('Error force updating videos: $e');
    }
  }

  // Clear all cached videos
  Future<void> clearVideoCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_mealPlanVideosKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      print('Error clearing video cache: $e');
    }
  }

  // Get statistics about video usage
  Future<Map<String, dynamic>> getVideoStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = prefs.getString(_mealPlanVideosKey);
      
      if (videosJson == null) {
        return {
          'totalVideos': 0,
          'totalDays': 0,
          'averageVideosPerDay': 0.0,
          'lastUpdate': null,
        };
      }
      
      final allVideos = json.decode(videosJson) as Map<String, dynamic>;
      final totalDays = allVideos.keys.length;
      final totalVideos = allVideos.values
          .map((dayVideos) => (dayVideos as List).length)
          .fold(0, (sum, count) => sum + count);
      
      final lastUpdateStr = prefs.getString(_lastUpdateKey);
      
      return {
        'totalVideos': totalVideos,
        'totalDays': totalDays,
        'averageVideosPerDay': totalDays > 0 ? totalVideos / totalDays : 0.0,
        'lastUpdate': lastUpdateStr,
      };
    } catch (e) {
      print('Error getting video statistics: $e');
      return {
        'totalVideos': 0,
        'totalDays': 0,
        'averageVideosPerDay': 0.0,
        'lastUpdate': null,
      };
    }
  }
}
