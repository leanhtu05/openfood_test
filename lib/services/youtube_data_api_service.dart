import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeDataAPIService {
  // Singleton pattern
  static final YouTubeDataAPIService _instance = YouTubeDataAPIService._internal();
  factory YouTubeDataAPIService() => _instance;
  YouTubeDataAPIService._internal();

  // YouTube Data API v3 Key
  static const String _API_KEY = 'AIzaSyAIYbul927kNqEk9eJYROHQE6BdYfmMBPc';
  static const String _BASE_URL = 'https://www.googleapis.com/youtube/v3';

  // Lấy thông tin chi tiết video từ YouTube Data API
  Future<Map<String, String>?> getVideoDetails(String videoId) async {
    // API key đã được cấu hình

    try {
      final url = '$_BASE_URL/videos'
          '?part=snippet,statistics,contentDetails'
          '&id=$videoId'
          '&key=$_API_KEY';

      print('🔍 Fetching video details from YouTube Data API: $videoId');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['items'] != null && data['items'].isNotEmpty) {
          final item = data['items'][0];
          final snippet = item['snippet'];
          final statistics = item['statistics'];
          final contentDetails = item['contentDetails'];

          final videoDetails = <String, String>{
            'title': snippet['title']?.toString() ?? 'Video không có tiêu đề',
            'channel': snippet['channelTitle']?.toString() ?? 'Kênh không xác định',
            'description': snippet['description']?.toString() ?? 'Không có mô tả',
            'thumbnail': snippet['thumbnails']['high']['url']?.toString() ?? '',
            'publishedAt': snippet['publishedAt']?.toString() ?? '',
            'views': _formatViewCount(statistics['viewCount']),
            'likes': _formatCount(statistics['likeCount']),
            'duration': _formatDuration(contentDetails['duration']),
            'videoId': videoId,
          };

          print('✅ Got real YouTube data: ${videoDetails['title']}');
          print('   Channel: ${videoDetails['channel']}');
          print('   Views: ${videoDetails['views']}');
          print('   Duration: ${videoDetails['duration']}');

          return videoDetails;
        } else {
          print('❌ No video found with ID: $videoId');
        }
      } else {
        print('❌ YouTube Data API error: ${response.statusCode}');
        print('   Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error calling YouTube Data API: $e');
    }

    return null;
  }

  // Tìm kiếm video theo từ khóa - Ưu tiên tiếng Việt
  Future<List<Map<String, String>>> searchVideos(String query, {int maxResults = 5}) async {
    // API key đã được cấu hình

    try {
      // Tạo query tiếng Việt
      final vietnameseQuery = _createVietnameseQuery(query);

      print('🔍 Searching YouTube for: $vietnameseQuery');

      final url = '$_BASE_URL/search'
          '?part=snippet'
          '&q=${Uri.encodeComponent(vietnameseQuery)}'
          '&type=video'
          '&videoCategoryId=26' // Howto & Style
          '&maxResults=$maxResults'
          '&order=relevance'
          '&regionCode=VN' // Ưu tiên video từ Vietnam
          '&relevanceLanguage=vi' // Ưu tiên tiếng Việt
          '&videoDuration=medium' // 4-20 minutes
          '&key=$_API_KEY';

      print('🔍 Searching YouTube for: $query');

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, String>> videos = [];

        for (final item in data['items']) {
          final snippet = item['snippet'];
          videos.add(<String, String>{
            'title': snippet['title']?.toString() ?? 'Video không có tiêu đề',
            'channel': snippet['channelTitle']?.toString() ?? 'Kênh không xác định',
            'description': snippet['description']?.toString() ?? 'Không có mô tả',
            'thumbnail': snippet['thumbnails']['high']['url']?.toString() ?? '',
            'publishedAt': snippet['publishedAt']?.toString() ?? '',
            'videoId': item['id']['videoId']?.toString() ?? '',
            'duration': 'N/A', // Search API không trả về duration
            'views': 'N/A', // Search API không trả về views
          });
        }

        print('✅ Found ${videos.length} videos for: $query');

        // Lấy thông tin chi tiết cho videos (duration, views)
        final enhancedVideos = await _enhanceVideosWithDetails(videos);
        return enhancedVideos;
      } else {
        print('❌ YouTube search API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error searching YouTube: $e');
    }

    return [];
  }

  // Enhance videos với thông tin chi tiết (duration, views)
  Future<List<Map<String, String>>> _enhanceVideosWithDetails(List<Map<String, String>> videos) async {
    if (videos.isEmpty) return videos;

    try {
      // Lấy danh sách video IDs
      final videoIds = videos
          .map((video) => video['videoId'])
          .where((id) => id != null && id.isNotEmpty)
          .join(',');

      if (videoIds.isEmpty) return videos;

      final url = '$_BASE_URL/videos'
          '?part=contentDetails,statistics'
          '&id=$videoIds'
          '&key=$_API_KEY';

      print('🔍 Getting video details for ${videos.length} videos');

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, Map<String, String>> videoDetails = {};

        // Parse video details
        for (final item in data['items']) {
          final videoId = item['id']?.toString() ?? '';
          final contentDetails = item['contentDetails'];
          final statistics = item['statistics'];

          videoDetails[videoId] = {
            'duration': _formatDuration(contentDetails['duration']),
            'views': _formatViewCount(statistics['viewCount']),
          };
        }

        // Enhance original videos với details
        final enhancedVideos = <Map<String, String>>[];
        for (final video in videos) {
          final videoId = video['videoId'] ?? '';
          final details = videoDetails[videoId];

          final enhancedVideo = Map<String, String>.from(video);
          if (details != null) {
            enhancedVideo['duration'] = details['duration'] ?? 'N/A';
            enhancedVideo['views'] = details['views'] ?? 'N/A';
          }

          enhancedVideos.add(enhancedVideo);
        }

        print('✅ Enhanced ${enhancedVideos.length} videos with details');
        return enhancedVideos;
      }
    } catch (e) {
      print('❌ Error enhancing videos: $e');
    }

    return videos; // Return original videos if enhancement fails
  }

  // Lấy video trending trong category nấu ăn
  Future<List<Map<String, String>>> getTrendingCookingVideos({int maxResults = 10}) async {
    // API key đã được cấu hình

    try {
      final url = '$_BASE_URL/videos'
          '?part=snippet,statistics'
          '&chart=mostPopular'
          '&videoCategoryId=26' // Howto & Style
          '&regionCode=VN' // Vietnam
          '&maxResults=$maxResults'
          '&key=$_API_KEY';

      print('🔍 Getting trending cooking videos');

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, String>> videos = [];

        for (final item in data['items']) {
          final snippet = item['snippet'];
          final statistics = item['statistics'];
          
          videos.add(<String, String>{
            'title': snippet['title']?.toString() ?? 'Video không có tiêu đề',
            'channel': snippet['channelTitle']?.toString() ?? 'Kênh không xác định',
            'description': snippet['description']?.toString() ?? 'Không có mô tả',
            'thumbnail': snippet['thumbnails']['high']['url']?.toString() ?? '',
            'views': _formatViewCount(statistics['viewCount']),
            'videoId': item['id']?.toString() ?? '',
            'duration': 'N/A', // Sẽ được cập nhật sau
          });
        }

        print('✅ Found ${videos.length} trending cooking videos');
        return videos;
      } else {
        print('❌ YouTube trending API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting trending videos: $e');
    }

    return [];
  }

  // Format view count (1234567 → 1.2M)
  String _formatViewCount(dynamic viewCount) {
    if (viewCount == null) return 'N/A';
    
    final count = int.tryParse(viewCount.toString()) ?? 0;
    
    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1)}B';
    } else if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  // Format count (likes, etc.)
  String _formatCount(dynamic count) {
    if (count == null) return 'N/A';
    return _formatViewCount(count);
  }

  // Format duration (PT15M30S → 15:30)
  String _formatDuration(String? duration) {
    if (duration == null) return 'N/A';
    
    try {
      // Parse ISO 8601 duration (PT15M30S)
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(duration);
      
      if (match != null) {
        final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
        final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        
        if (hours > 0) {
          return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else {
          return '$minutes:${seconds.toString().padLeft(2, '0')}';
        }
      }
    } catch (e) {
      print('Error parsing duration: $e');
    }
    
    return duration;
  }

  // Kiểm tra API key có hợp lệ không
  Future<bool> isAPIKeyValid() async {
    // API key đã được cấu hình

    try {
      final url = '$_BASE_URL/videos?part=snippet&id=dQw4w9WgXcQ&key=$_API_KEY';
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Lấy thông tin channel
  Future<Map<String, String>?> getChannelInfo(String channelId) async {
    // API key đã được cấu hình

    try {
      final url = '$_BASE_URL/channels'
          '?part=snippet,statistics'
          '&id=$channelId'
          '&key=$_API_KEY';

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['items'] != null && data['items'].isNotEmpty) {
          final item = data['items'][0];
          final snippet = item['snippet'];
          final statistics = item['statistics'];

          return <String, String>{
            'title': snippet['title']?.toString() ?? 'Kênh không xác định',
            'description': snippet['description']?.toString() ?? 'Không có mô tả',
            'thumbnail': snippet['thumbnails']['high']['url']?.toString() ?? '',
            'subscriberCount': _formatCount(statistics['subscriberCount']),
            'videoCount': statistics['videoCount']?.toString() ?? '0',
            'viewCount': _formatViewCount(statistics['viewCount']),
          };
        }
      }
    } catch (e) {
      print('Error getting channel info: $e');
    }

    return null;
  }

  // Tạo query tiếng Việt cho tìm kiếm
  String _createVietnameseQuery(String dishName) {
    // Map món ăn sang từ khóa tiếng Việt
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
    };

    // Nếu có query tiếng Việt cụ thể, dùng nó
    if (vietnameseQueries.containsKey(dishName)) {
      return vietnameseQueries[dishName]!;
    }

    // Nếu không, tạo query tiếng Việt generic
    return 'cách nấu $dishName ngon tiếng Việt';
  }
}
