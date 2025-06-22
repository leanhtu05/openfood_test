import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// YouTube Backend Service - Secure proxy to backend YouTube API
/// 
/// Benefits:
/// - API key secured in backend
/// - Caching reduces quota usage
/// - Quality filtering on server
/// - Rate limiting protection
class YouTubeBackendService {
  // static const String _baseUrl = 'http://localhost:8000'; // Local backend for testing
  static const String _baseUrl = 'https://backend-openfood.onrender.com'; // Production backend - CORRECTED URL
  
  // Singleton pattern
  static final YouTubeBackendService _instance = YouTubeBackendService._internal();
  factory YouTubeBackendService() => _instance;
  YouTubeBackendService._internal();

  /// Search for cooking videos via backend proxy
  /// 
  /// Benefits:
  /// - Server-side caching (24h)
  /// - Quality filtering
  /// - Vietnamese query optimization
  /// - Secure API key handling
  Future<List<Map<String, String>>> searchVideos(
    String dishName, {
    int maxResults = 5,
    String duration = 'medium',
    String order = 'relevance',
  }) async {
    try {
      print('🔍 Searching videos via backend for: $dishName');
      
      final url = Uri.parse('$_baseUrl/youtube/search');
      
      // Ensure proper UTF-8 encoding for Vietnamese text
      final requestBody = {
        'query': dishName.trim(), // Remove any whitespace
        'max_results': maxResults,
        'duration': duration,
        'order': order,
      };

      print('📡 Making request to: $url');
      print('📦 Request body: ${json.encode(requestBody, toEncodable: (obj) => obj.toString())}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'Accept-Charset': 'utf-8',
        },
        body: utf8.encode(json.encode(requestBody)),
      ).timeout(Duration(seconds: 30));
      
      print('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = List<Map<String, String>>.from(
          data['videos'].map((video) => Map<String, String>.from(video))
        );
        
        final cached = data['cached'] ?? false;
        print('✅ Found ${videos.length} videos (cached: $cached)');
        
        return videos;
      } else {
        print('❌ Backend error: ${response.statusCode} - ${response.body}');
        throw Exception('Backend search failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error searching videos via backend: $e');
      
      // Fallback to local mock data
      return _createFallbackVideos(dishName);
    }
  }

  /// Get trending cooking videos via backend
  Future<List<Map<String, String>>> getTrendingVideos({int maxResults = 10}) async {
    try {
      print('🔥 Getting trending videos via backend');
      
      final url = Uri.parse('$_baseUrl/youtube/trending?max_results=$maxResults');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = List<Map<String, String>>.from(
          data['videos'].map((video) => Map<String, String>.from(video))
        );
        
        final cached = data['cached'] ?? false;
        print('✅ Found ${videos.length} trending videos (cached: $cached)');
        
        return videos;
      } else {
        print('❌ Backend trending error: ${response.statusCode}');
        throw Exception('Backend trending failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting trending videos: $e');
      return [];
    }
  }

  /// Get cache statistics from backend
  Future<Map<String, dynamic>?> getCacheStats() async {
    try {
      final url = Uri.parse('$_baseUrl/youtube/cache/stats');
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('❌ Error getting cache stats: $e');
    }
    return null;
  }

  /// Clear backend cache (admin function)
  Future<bool> clearCache() async {
    try {
      final url = Uri.parse('$_baseUrl/youtube/cache/clear');
      
      final response = await http.delete(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ Cache cleared successfully');
        return true;
      }
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
    return false;
  }

  /// Create fallback videos when backend is unavailable
  List<Map<String, String>> _createFallbackVideos(String dishName) {
    print('🔄 Creating fallback videos for: $dishName');
    
    return [
      {
        'title': 'Tìm kiếm video: "$dishName hướng dẫn nấu ăn"',
        'videoId': 'SEARCH_YOUTUBE',
        'channel': 'YouTube Search',
        'duration': '∞',
        'views': 'Nhiều video',
        'description': 'Tìm kiếm video hướng dẫn nấu $dishName trên YouTube',
        'thumbnail': 'https://via.placeholder.com/480x360/FF6B35/FFFFFF?text=Search+YouTube',
      },
      {
        'title': 'Khám phá video nấu ăn: "$dishName"',
        'videoId': 'SEARCH_YOUTUBE_ALT',
        'channel': 'Cooking Videos',
        'duration': '∞',
        'views': 'Kết quả tìm kiếm',
        'description': 'Khám phá các video hướng dẫn nấu $dishName từ các chef chuyên nghiệp',
        'thumbnail': 'https://via.placeholder.com/480x360/4CAF50/FFFFFF?text=Cooking+Videos',
      },
    ];
  }

  /// Test backend connection
  Future<bool> testConnection() async {
    try {
      print('🔍 Testing backend connection...');
      
      final url = Uri.parse('$_baseUrl/youtube/cache/stats');
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 5));
      
      final isConnected = response.statusCode == 200;
      print(isConnected ? '✅ Backend connected' : '❌ Backend not available');
      
      return isConnected;
    } catch (e) {
      print('❌ Backend connection failed: $e');
      return false;
    }
  }

  /// Get video details by IDs (batch request)
  Future<List<Map<String, String>>> getVideoDetails(List<String> videoIds) async {
    try {
      print('📹 Getting video details for ${videoIds.length} videos');
      
      final url = Uri.parse('$_baseUrl/youtube/details');
      
      final requestBody = {
        'video_ids': videoIds,
      };
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = List<Map<String, String>>.from(
          data['videos'].map((video) => Map<String, String>.from(video))
        );
        
        print('✅ Got details for ${videos.length} videos');
        return videos;
      } else {
        print('❌ Video details error: ${response.statusCode}');
        throw Exception('Video details failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting video details: $e');
      return [];
    }
  }

  /// Create Vietnamese cooking query
  String createVietnameseQuery(String dishName) {
    final Map<String, String> vietnameseQueries = {
      'Phở Bò': 'cách nấu phở bò Hà Nội ngon',
      'Phở Gà': 'cách nấu phở gà ngon',
      'Phở Gà Nấu Dừa Miền Tây': 'cách nấu phở gà dừa miền Tây',
      'Bún Chả': 'cách làm bún chả Hà Nội',
      'Cơm Tấm': 'cách làm cơm tấm sườn nướng Sài Gòn',
      'Bánh Mì': 'cách làm bánh mì Việt Nam',
      'Gỏi Cuốn': 'cách cuốn gỏi cuốn tôm thịt',
      'Canh Chua': 'cách nấu canh chua cá miền Tây',
      'Bún Bò Huế': 'cách nấu bún bò Huế chuẩn vị',
      'Bánh Xèo': 'cách làm bánh xèo miền Tây',
      'Chả Cá': 'cách làm chả cá Lã Vọng Hà Nội',
      'Nem Nướng': 'cách làm nem nướng Nha Trang',
      'Bánh Mì Chả Cá Nha Trang': 'cách làm bánh mì chả cá Nha Trang',
      'Cá hồi nướng với khoai lang và rau củ': 'cách nướng cá hồi với khoai lang rau củ',
    };

    if (vietnameseQueries.containsKey(dishName)) {
      return vietnameseQueries[dishName]!;
    }

    return 'cách nấu $dishName ngon tiếng Việt';
  }

  /// Get backend health status
  Future<Map<String, dynamic>?> getHealthStatus() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('❌ Error getting health status: $e');
    }
    return null;
  }
}

/// YouTube Backend Service instance
final youtubeBackendService = YouTubeBackendService();
